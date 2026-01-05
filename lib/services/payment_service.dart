import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:quanlynhahang/models/order.dart';
import 'package:quanlynhahang/services/revenue_service.dart';

class PayOSConfig {
  static String clientId = '11fb616f-19d4-4efc-a23e-cad449b7c0d6';           
  static String apiKey = 'e50081f1-2aa2-49ad-82af-a3498c8f2151';               
  static String checksumKey = 'b023b5656442d238ca5fec5c8ae776243fdbb08e3bf497a2f2e0d993622d6050';
  
  // Endpoints
  static const String baseUrl = 'https://api-merchant.payos.vn';
  static const String createPaymentUrl = '$baseUrl/v2/payment-requests';
  
  // Callback URLs
  static const String returnUrl = 'quanlynhahang://payment/success';
  static const String cancelUrl = 'quanlynhahang://payment/cancel';
  
  // Kiểm tra PayOS đã được cấu hình chưa
  // Luôn true nếu có credentials (credentials hiện tại là thật)
  static bool get isConfigured => 
      clientId.isNotEmpty && 
      apiKey.isNotEmpty &&
      checksumKey.isNotEmpty;
  
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

///Response từ API của PayOS
class PayOSPaymentResponse {
  final bool success;
  final String? orderCode;
  final String? qrCode; 
  final String? paymentUrl;
  final String? message;

  PayOSPaymentResponse({
    required this.success,
    this.orderCode,
    this.qrCode,
    this.paymentUrl,
    this.message,
  });
}

///Trạng thái thanh toán PayOS
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
  final RevenueService _revenueService = RevenueService();
  
  /// Thanh toán bằng tiền mặt
  Future<PaymentResult> payWithCash(Order order) async {
    final transactionId = 'CASH_${DateTime.now().millisecondsSinceEpoch}';
    
    // Ghi nhận doanh thu với platform fee
    await _revenueService.recordRevenue(
      order: order,
      transactionId: transactionId,
      paymentMethod: 'cash',
    );
    
    return PaymentResult(
      success: true,
      transactionId: transactionId,
      message: 'Thanh toán tiền mặt thành công',
      method: PaymentMethod.cash,
    );
  }

  /// Thanh toán qua PayOS
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
      
      print('PayOS Response Status: ${response.statusCode}');
      print('PayOS Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['code'] == '00') {
          final data = responseData['data'];
          final qrCode = data['qrCode'];
          final checkoutUrl = data['checkoutUrl'];
          
          print('PayOS QR Code: $qrCode');
          print('PayOS Checkout URL: $checkoutUrl');
          
          return PayOSPaymentResponse(
            success: true,
            orderCode: orderCode.toString(),
            qrCode: qrCode,
            paymentUrl: checkoutUrl,
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
  /// Tạo thanh toán PayOS cho gói dịch vụ
  /// Dùng khi Customer đăng ký Owner với service package
  Future<PayOSPaymentResponse> createPackagePayment({
    required String packageId,
    required String packageName,
    required double price,
    required int durationMonths,
    required String userEmail,
  }) async {
    if (!PayOSConfig.isConfigured) {
      return PayOSPaymentResponse(
        success: false,
        message: 'PayOS chưa được cấu hình. Vui lòng liên hệ quản trị viên.',
      );
    }

    try {
      // Tạo order code unique (số nguyên)
      final orderCode = DateTime.now().millisecondsSinceEpoch % 9007199254740991;
      final amount = price.toInt();
      final description = 'Goi $packageName - $durationMonths thang';
      
      // Tạo checksum signature
      final dataToSign = 'amount=$amount&cancelUrl=${PayOSConfig.cancelUrl}&description=$description&orderCode=$orderCode&returnUrl=${PayOSConfig.returnUrl}';
      final signature = _generateHmacSHA256(dataToSign, PayOSConfig.checksumKey);
      
      // Tạo request body
      final requestBody = {
        'orderCode': orderCode,
        'amount': amount,
        'description': description,
        'items': [
          {
            'name': packageName,
            'quantity': 1,
            'price': amount,
          }
        ],
        'buyerName': userEmail,
        'buyerEmail': userEmail,
        'cancelUrl': PayOSConfig.cancelUrl,
        'returnUrl': PayOSConfig.returnUrl,
        'signature': signature,
        'expiredAt': DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000,
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
      
      print('PayOS Package Payment Response Status: ${response.statusCode}');
      print('PayOS Package Payment Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['code'] == '00') {
          final data = responseData['data'];
          final qrCode = data['qrCode'];
          final checkoutUrl = data['checkoutUrl'];
          
          // Lưu thông tin thanh toán vào Firebase để theo dõi
          await _createPendingPackagePayment(
            orderCode: orderCode.toString(),
            packageId: packageId,
            packageName: packageName,
            price: price,
            durationMonths: durationMonths,
            userEmail: userEmail,
          );
          
          return PayOSPaymentResponse(
            success: true,
            orderCode: orderCode.toString(),
            qrCode: qrCode,
            paymentUrl: checkoutUrl,
            message: 'Tạo thanh toán gói dịch vụ thành công',
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

  /// Tạo pending payment record cho package trong Firebase
  Future<void> _createPendingPackagePayment({
    required String orderCode,
    required String packageId,
    required String packageName,
    required double price,
    required int durationMonths,
    required String userEmail,
  }) async {
    try {
      final paymentRef = FirebaseDatabase.instance.ref()
          .child('pending_package_payments')
          .child(orderCode);
      
      await paymentRef.set({
        'orderCode': orderCode,
        'packageId': packageId,
        'packageName': packageName,
        'price': price,
        'durationMonths': durationMonths,
        'userEmail': userEmail,
        'status': 'pending',
        'createdAt': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error creating pending package payment: $e');
    }
  }

  /// Xác nhận thanh toán gói dịch vụ thành công
  Future<bool> confirmPackagePayment(String orderCode, String transactionId) async {
    try {
      final paymentRef = FirebaseDatabase.instance.ref()
          .child('pending_package_payments')
          .child(orderCode);
      
      await paymentRef.update({
        'status': 'completed',
        'transactionId': transactionId,
        'completedAt': ServerValue.timestamp,
      });
      
      return true;
    } catch (e) {
      print('Error confirming package payment: $e');
      return false;
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
  /// Sử dụng VietQR format chuẩn - NAPAS EMVCo
  /// Cấu hình thông tin ngân hàng của platform
  String generatePayOSQRData(Order order, String orderCode) {
    final amount = order.totalAmount.toInt();
    final description = 'TT Ban ${order.tableId} DH $orderCode';
    
    // VietQR format chuẩn EMVCo - Cần thay bằng thông tin ngân hàng thực
    // Format: https://img.vietqr.io/image/{BANK_ID}-{ACCOUNT_NO}-{TEMPLATE}.png?amount={AMOUNT}&addInfo={DESCRIPTION}
    // Hoặc dùng QR data string trực tiếp
    
    // Cấu hình ngân hàng platform (thay bằng thông tin thực)
    const bankId = 'MB'; // Mã ngân hàng: MB, VCB, TCB, BIDV, VTB, ACB, TPB, STB, HDB, VIB, SHB, EIB, MSB, OCB, LPB, BAB, NCB, PGB, SCB, ABB, NAB, SEAB, COOPBANK, VRB, GPB, VAB, BVB, VietÁBank, IVB, CBBank, BIDC, NASB, VBSP, KHBANK, SHBVN
    const accountNo = '0933592953'; // Số tài khoản
    const accountName = 'PLATFORM QLNH'; // Tên tài khoản
    
    // Trả về VietQR URL - định dạng này app ngân hàng đọc được
    final encodedDesc = Uri.encodeComponent(description);
    final vietQRUrl = 'https://img.vietqr.io/image/$bankId-$accountNo-compact2.png?amount=$amount&addInfo=$encodedDesc&accountName=${Uri.encodeComponent(accountName)}';
    
    print('VietQR Fallback URL: $vietQRUrl');
    
    // Trả về VietQR data string (EMVCo format) - dùng cho QR code trực tiếp
    // Format này các app ngân hàng và Momo đều hỗ trợ
    return _generateVietQRString(
      bankBin: '970422', // BIN của MB Bank
      accountNo: accountNo,
      amount: amount,
      description: description,
    );
  }
  
  /// Tạo VietQR data string theo chuẩn EMVCo
  String _generateVietQRString({
    required String bankBin,
    required String accountNo,
    required int amount,
    required String description,
  }) {
    // EMVCo QR Code format cho VietQR
    // Tham khảo: https://www.emvco.com/emv-technologies/qrcodes/
    
    final StringBuffer qrData = StringBuffer();
    
    // Payload Format Indicator
    qrData.write('000201');
    
    // Point of Initiation Method (12 = Dynamic QR)
    qrData.write('010212');
    
    // Merchant Account Information - VietQR
    // ID 38 = VietQR
    final napasData = '0010A000000727' + // NAPAS AID
        '01' + _tlv(bankBin) + // Bank BIN
        '02' + _tlv(accountNo); // Account Number
    qrData.write('38${_tlv(napasData)}');
    
    // Transaction Currency (VND = 704)
    qrData.write('5303704');
    
    // Transaction Amount
    if (amount > 0) {
      qrData.write('54${_tlv(amount.toString())}');
    }
    
    // Country Code (VN)
    qrData.write('5802VN');
    
    // Additional Data Field Template
    if (description.isNotEmpty) {
      // Description (ID 08)
      final descTlv = '08${_tlv(description)}';
      qrData.write('62${_tlv(descTlv)}');
    }
    
    // CRC placeholder (will be calculated)
    final dataWithoutCRC = qrData.toString() + '6304';
    final crc = _calculateCRC16(dataWithoutCRC);
    
    return dataWithoutCRC + crc;
  }
  
  /// Tạo TLV (Tag-Length-Value)
  String _tlv(String value) {
    final length = value.length.toString().padLeft(2, '0');
    return '$length$value';
  }
  
  /// Tính CRC-16/CCITT-FALSE cho VietQR
  String _calculateCRC16(String data) {
    int crc = 0xFFFF;
    final polynomial = 0x1021;
    
    for (int i = 0; i < data.length; i++) {
      crc ^= (data.codeUnitAt(i) << 8);
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ polynomial) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
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
  /// Nếu truyền order sẽ ghi nhận doanh thu
  Future<bool> confirmPayment(
    String restaurantId, 
    String orderId, 
    String transactionId, {
    Order? order,
  }) async {
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
      
      // Ghi nhận doanh thu nếu có order
      if (order != null) {
        await _revenueService.recordRevenue(
          order: order,
          transactionId: transactionId,
          paymentMethod: 'payos',
        );
      }
      
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
