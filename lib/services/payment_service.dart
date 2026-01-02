import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:quanlynhahang/models/order.dart';

/// ⚠️ CẤU HÌNH PAYOS
/// Đăng ký tại: https://payos.vn để lấy thông tin
/// PayOS hỗ trợ: QR Code, Thẻ ngân hàng, Ví điện tử
class PayOSConfig {
  // ⚠️ THAY BẰNG THÔNG TIN THẬT TỪ PAYOS DASHBOARD
  static String clientId = '11fb616f-19d4-4efc-a23e-cad449b7c0d6';           // Client ID từ PayOS
  static String apiKey = 'e50081f1-2aa2-49ad-82af-a3498c8f2151';               // API Key từ PayOS  
  static String checksumKey = 'b023b5656442d238ca5fec5c8ae776243fdbb08e3bf497a2f2e0d993622d6050';     // Checksum Key từ PayOS
  
  // Endpoints
  static const String baseUrl = 'https://api-merchant.payos.vn';
  static const String createPaymentUrl = '$baseUrl/v2/payment-requests';
  
  // Callback URLs
  static const String returnUrl = 'quanlynhahang://payment/success';
  static const String cancelUrl = 'quanlynhahang://payment/cancel';
  
  static bool get isConfigured => 
      clientId.isNotEmpty && 
      clientId != 'your_client_id' &&
      apiKey.isNotEmpty && 
      apiKey != 'your_api_key';
  
  // Cập nhật cấu hình từ Firebase
  static void updateConfig({String? client, String? api, String? checksum}) {
    if (client != null && client.isNotEmpty) clientId = client;
    if (api != null && api.isNotEmpty) apiKey = api;
    if (checksum != null && checksum.isNotEmpty) checksumKey = checksum;
  }
}

class PaymentResult {
  final bool success;
  final String? transactionId;
  final String? message;
  final PaymentMethod method;

  PaymentResult({
    required this.success,
    this.transactionId,
    this.message,
    required this.method,
  });
}

/// Response từ API tạo thanh toán PayOS
class PayOSPaymentResponse {
  final bool success;
  final String? orderCode;
  final String? qrCode;         // QR code image URL hoặc data
  final String? paymentUrl;     // URL checkout page
  final String? message;

  PayOSPaymentResponse({
    required this.success,
    this.orderCode,
    this.qrCode,
    this.paymentUrl,
    this.message,
  });
}

/// Trạng thái thanh toán PayOS
class PayOSPaymentStatus {
  final bool success;
  final String status;          // PENDING, PAID, CANCELLED, EXPIRED
  final bool isPaid;
  final String? transactionId;

  PayOSPaymentStatus({
    required this.success,
    required this.status,
    required this.isPaid,
    this.transactionId,
  });
}

class PaymentService {
  
  /// Thanh toán bằng tiền mặt
  Future<PaymentResult> payWithCash(Order order) async {
    // Thanh toán tiền mặt luôn thành công (xác nhận tại quầy)
    return PaymentResult(
      success: true,
      transactionId: 'CASH_${DateTime.now().millisecondsSinceEpoch}',
      message: 'Thanh toán tiền mặt thành công',
      method: PaymentMethod.cash,
    );
  }

  /// Thanh toán qua PayOS
  /// Tạo payment request và trả về thông tin QR code
  Future<PayOSPaymentResponse> createPayOSPayment(Order order) async {
    if (!PayOSConfig.isConfigured) {
      return PayOSPaymentResponse(
        success: false,
        message: 'PayOS chưa được cấu hình. Vui lòng liên hệ quản trị viên.',
      );
    }

    try {
      // Tạo order code unique (số nguyên)
      final orderCode = DateTime.now().millisecondsSinceEpoch % 9007199254740991;
      final amount = order.totalAmount.toInt();
      final description = 'Thanh toan ban ${order.tableId}';
      
      // Tạo checksum signature
      final dataToSign = 'amount=$amount&cancelUrl=${PayOSConfig.cancelUrl}&description=$description&orderCode=$orderCode&returnUrl=${PayOSConfig.returnUrl}';
      final signature = _generateHmacSHA256(dataToSign, PayOSConfig.checksumKey);
      
      // Tạo request body
      final requestBody = {
        'orderCode': orderCode,
        'amount': amount,
        'description': description,
        'items': order.items.map((item) => {
          'name': item.name,
          'quantity': item.quantity,
          'price': item.price.toInt(),
        }).toList(),
        'cancelUrl': PayOSConfig.cancelUrl,
        'returnUrl': PayOSConfig.returnUrl,
        'signature': signature,
        'expiredAt': DateTime.now().add(const Duration(minutes: 15)).millisecondsSinceEpoch ~/ 1000,
      };

      // Gọi API PayOS
      final response = await http.post(
        Uri.parse(PayOSConfig.createPaymentUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-client-id': PayOSConfig.clientId,
          'x-api-key': PayOSConfig.apiKey,
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['code'] == '00') {
          final data = responseData['data'];
          return PayOSPaymentResponse(
            success: true,
            orderCode: orderCode.toString(),
            qrCode: data['qrCode'],
            paymentUrl: data['checkoutUrl'],
            message: 'Tạo thanh toán thành công',
          );
        } else {
          return PayOSPaymentResponse(
            success: false,
            message: responseData['desc'] ?? 'Lỗi từ PayOS',
          );
        }
      } else {
        return PayOSPaymentResponse(
          success: false,
          message: 'Lỗi kết nối tới PayOS (${response.statusCode})',
        );
      }
    } catch (e) {
      return PayOSPaymentResponse(
        success: false,
        message: 'Lỗi thanh toán PayOS: $e',
      );
    }
  }
  
  /// Kiểm tra trạng thái thanh toán PayOS
  Future<PayOSPaymentStatus> checkPayOSPaymentStatus(String orderCode) async {
    try {
      final response = await http.get(
        Uri.parse('${PayOSConfig.baseUrl}/v2/payment-requests/$orderCode'),
        headers: {
          'x-client-id': PayOSConfig.clientId,
          'x-api-key': PayOSConfig.apiKey,
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['code'] == '00') {
          final data = responseData['data'];
          final status = data['status'];
          
          return PayOSPaymentStatus(
            success: true,
            status: status,
            isPaid: status == 'PAID',
            transactionId: data['id']?.toString(),
          );
        }
      }
      
      return PayOSPaymentStatus(success: false, status: 'UNKNOWN', isPaid: false);
    } catch (e) {
      return PayOSPaymentStatus(success: false, status: 'ERROR', isPaid: false);
    }
  }

  /// Tạo HMAC-SHA256 signature
  String _generateHmacSHA256(String data, String key) {
    final hmacSha256 = Hmac(sha256, utf8.encode(key));
    final digest = hmacSha256.convert(utf8.encode(data));
    return digest.toString();
  }
  
  /// Tạo QR Code data cho PayOS (fallback nếu API không trả về QR)
  /// Sử dụng VietQR format chuẩn
  String generatePayOSQRData(Order order, String orderCode) {
    final amount = order.totalAmount.toInt();
    final description = 'TT Ban ${order.tableId} - $orderCode';
    
    // VietQR format - có thể customize theo bank của nhà hàng
    return 'https://payos.vn/pay/$orderCode';
  }
  
  /// Tạo pending payment record trong Firebase để theo dõi
  Future<String> createPendingPayment(Order order) async {
    try {
      final paymentRef = FirebaseDatabase.instance.ref()
          .child('pending_payments')
          .child(order.restaurantId)
          .child(order.id);
      
      final orderId = order.id.length > 8 ? order.id.substring(0, 8) : order.id;
      
      final paymentData = {
        'orderId': order.id,
        'restaurantId': order.restaurantId,
        'tableId': order.tableId,
        'amount': order.totalAmount,
        'status': 'pending',
        'createdAt': ServerValue.timestamp,
        'qrContent': 'TT Ban ${order.tableId} DH $orderId',
      };
      
      await paymentRef.set(paymentData);
      return order.id;
    } catch (e) {
      print('Error creating pending payment: $e');
      return '';
    }
  }
  
  /// Lắng nghe thay đổi trạng thái thanh toán từ Firebase
  /// Trả về Stream để UI có thể listen
  Stream<DatabaseEvent> listenPaymentStatus(String restaurantId, String orderId) {
    return FirebaseDatabase.instance.ref()
        .child('pending_payments')
        .child(restaurantId)
        .child(orderId)
        .onValue;
  }
  
  /// Xác nhận thanh toán thành công (gọi từ UI hoặc webhook)
  Future<bool> confirmPayment(String restaurantId, String orderId, String transactionId) async {
    try {
      final paymentRef = FirebaseDatabase.instance.ref()
          .child('pending_payments')
          .child(restaurantId)
          .child(orderId);
      
      await paymentRef.update({
        'status': 'completed',
        'transactionId': transactionId,
        'completedAt': ServerValue.timestamp,
      });
      
      return true;
    } catch (e) {
      print('Error confirming payment: $e');
      return false;
    }
  }
  
  /// Hủy pending payment
  Future<void> cancelPendingPayment(String restaurantId, String orderId) async {
    try {
      await FirebaseDatabase.instance.ref()
          .child('pending_payments')
          .child(restaurantId)
          .child(orderId)
          .remove();
    } catch (e) {
      print('Error canceling pending payment: $e');
    }
  }
}
