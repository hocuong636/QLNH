import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/services/payment_service.dart';
import 'package:quanlynhahang/models/service_package.dart';

class PackageRenewalPage extends StatefulWidget {
  const PackageRenewalPage({super.key});

  @override
  State<PackageRenewalPage> createState() => _PackageRenewalPageState();
}

class _PackageRenewalPageState extends State<PackageRenewalPage> {
  final LocalStorageService _localStorageService = LocalStorageService();
  final PaymentService _paymentService = PaymentService();
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  bool _isLoading = true;
  List<ServicePackage> _packages = [];
  
  // Thông tin gói hiện tại
  String? _currentPackageId;
  String? _currentPackageName;
  DateTime? _packageExpiryDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load thông tin user hiện tại
      final userId = _localStorageService.getUserId();
      if (userId != null) {
        final userSnapshot = await _database.ref('users/$userId').get();
        if (userSnapshot.exists) {
          final userData = userSnapshot.value as Map<dynamic, dynamic>;
          _currentPackageId = userData['packageId']?.toString();
          
          if (userData['packageExpiryDate'] != null) {
            _packageExpiryDate = DateTime.parse(userData['packageExpiryDate']);
          }
        }
      }

      // Load danh sách gói dịch vụ
      final packagesSnapshot = await _database.ref('service_packages').get();
      if (packagesSnapshot.exists) {
        final data = packagesSnapshot.value as Map<dynamic, dynamic>;
        _packages = [];
        
        data.forEach((key, value) {
          if (value is Map) {
            final package = ServicePackage.fromJson({
              'id': key.toString(),
              ...Map<String, dynamic>.from(value),
            });
            if (package.isActive) {
              _packages.add(package);
              
              // Lấy tên gói hiện tại
              if (package.id == _currentPackageId) {
                _currentPackageName = package.name;
              }
            }
          }
        });

        // Sắp xếp theo giá
        _packages.sort((a, b) => a.price.compareTo(b.price));
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return formatter.format(amount);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chưa xác định';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  bool _isExpired() {
    if (_packageExpiryDate == null) return true;
    return _packageExpiryDate!.isBefore(DateTime.now());
  }

  int _daysRemaining() {
    if (_packageExpiryDate == null) return 0;
    final remaining = _packageExpiryDate!.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  Color _getExpiryColor() {
    if (_isExpired()) return Colors.red;
    if (_daysRemaining() <= 7) return Colors.orange;
    if (_daysRemaining() <= 30) return Colors.amber;
    return Colors.green;
  }

  DateTime _calculateNewExpiry(int months) {
    final baseDate = _packageExpiryDate != null && _packageExpiryDate!.isAfter(DateTime.now())
        ? _packageExpiryDate!
        : DateTime.now();
    return DateTime(baseDate.year, baseDate.month + months, baseDate.day);
  }

  void _showRenewalDialog(ServicePackage package) {
    String selectedPaymentMethod = 'payos';
    bool isProcessing = false;
    PayOSPaymentResponse? paymentResponse;
    Timer? statusCheckTimer;
    bool paymentCompleted = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void cleanupTimer() {
            statusCheckTimer?.cancel();
            statusCheckTimer = null;
          }

          return PopScope(
            onPopInvokedWithResult: (bool didPop, dynamic result) {
              cleanupTimer();
            },
            child: AlertDialog(
              title: Text(paymentResponse != null ? 'Quét mã thanh toán' : 'Gia hạn gói dịch vụ'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thông tin gói
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.card_membership, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    package.name,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow('Thời hạn:', '${package.durationMonths} tháng'),
                            const SizedBox(height: 4),
                            _buildInfoRow('Giá gói:', _formatCurrency(package.price), 
                              valueColor: Colors.green.shade700, valueBold: true),
                            if (_packageExpiryDate != null) ...[
                              const Divider(height: 20),
                              _buildInfoRow('Hiện tại hết hạn:', _formatDate(_packageExpiryDate)),
                              const SizedBox(height: 4),
                              _buildInfoRow(
                                'Sau gia hạn:',
                                _formatDate(_calculateNewExpiry(package.durationMonths)),
                                valueColor: Colors.blue.shade700,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // QR Code hoặc Options
                      if (paymentResponse != null && paymentResponse!.success) ...[
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withAlpha(50),
                                      spreadRadius: 2,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: paymentResponse!.qrCode != null
                                    ? QrImageView(
                                        data: paymentResponse!.qrCode!,
                                        version: QrVersions.auto,
                                        size: 200,
                                      )
                                    : const Icon(Icons.qr_code, size: 200, color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Quét mã QR bằng app ngân hàng',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  if (paymentResponse!.paymentUrl != null) {
                                    final uri = Uri.parse(paymentResponse!.paymentUrl!);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  }
                                },
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Mở trang thanh toán'),
                              ),
                              const SizedBox(height: 16),
                              if (isProcessing)
                                Column(
                                  children: [
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Đang chờ thanh toán...',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'Chọn phương thức thanh toán:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        RadioListTile<String>(
                          title: const Text('Thanh toán qua PayOS'),
                          subtitle: const Text('Quét mã QR để thanh toán nhanh'),
                          value: 'payos',
                          groupValue: selectedPaymentMethod,
                          onChanged: isProcessing ? null : (value) {
                            setDialogState(() => selectedPaymentMethod = value!);
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text('Tiền mặt'),
                          subtitle: const Text('Thanh toán tại văn phòng'),
                          value: 'cash',
                          groupValue: selectedPaymentMethod,
                          onChanged: isProcessing ? null : (value) {
                            setDialogState(() => selectedPaymentMethod = value!);
                          },
                        ),
                        if (isProcessing) ...[
                          const SizedBox(height: 16),
                          const Center(child: CircularProgressIndicator()),
                          const SizedBox(height: 8),
                          const Center(
                            child: Text('Đang xử lý...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                if (!paymentCompleted)
                  TextButton(
                    onPressed: isProcessing && paymentResponse == null ? null : () {
                      cleanupTimer();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Hủy'),
                  ),
                if (paymentResponse == null)
                  FilledButton(
                    onPressed: isProcessing ? null : () async {
                      setDialogState(() => isProcessing = true);

                      if (selectedPaymentMethod == 'payos') {
                        await _processPayOSPayment(
                          package,
                          setDialogState,
                          (response) => paymentResponse = response,
                          (timer) => statusCheckTimer = timer,
                          () => paymentCompleted = true,
                          cleanupTimer,
                        );
                      } else {
                        // Thanh toán tiền mặt - tạo yêu cầu gia hạn
                        await _processCashRenewal(package);
                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      }
                    },
                    child: const Text('Thanh toán'),
                  ),
                if (paymentResponse != null && !paymentCompleted)
                  FilledButton(
                    onPressed: () async {
                      setDialogState(() => isProcessing = true);

                      final status = await _paymentService.checkPayOSPaymentStatus(
                        paymentResponse!.orderCode!,
                      );

                      if (status.isPaid) {
                        paymentCompleted = true;
                        cleanupTimer();

                        await _paymentService.confirmPackagePayment(
                          paymentResponse!.orderCode!,
                          status.transactionId ?? '',
                        );

                        await _applyRenewal(package, 'PayOS', status.transactionId);

                        if (mounted) {
                          Navigator.of(context).pop();
                          _showSuccessDialog(package);
                        }
                      } else {
                        setDialogState(() => isProcessing = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Chưa nhận được thanh toán. Vui lòng thử lại.')),
                          );
                        }
                      }
                    },
                    child: isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Đã thanh toán'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor, bool valueBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: valueBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Future<void> _processPayOSPayment(
    ServicePackage package,
    StateSetter setDialogState,
    Function(PayOSPaymentResponse) setPaymentResponse,
    Function(Timer) setTimer,
    VoidCallback setCompleted,
    VoidCallback cleanupTimer,
  ) async {
    final userEmail = _localStorageService.getUserEmail() ?? '';

    final response = await _paymentService.createPackagePayment(
      packageId: package.id,
      packageName: '${package.name} (Gia hạn)',
      price: package.price,
      durationMonths: package.durationMonths,
      userEmail: userEmail,
    );

    if (!mounted) return;

    if (response.success) {
      setDialogState(() {
        setPaymentResponse(response);
      });

      // Auto check status
      final timer = Timer.periodic(
        const Duration(seconds: 3),
        (timer) async {
          if (!mounted) {
            timer.cancel();
            return;
          }

          final status = await _paymentService.checkPayOSPaymentStatus(response.orderCode!);

          if (status.isPaid) {
            timer.cancel();
            setCompleted();

            await _paymentService.confirmPackagePayment(
              response.orderCode!,
              status.transactionId ?? '',
            );

            await _applyRenewal(package, 'PayOS', status.transactionId);

            if (mounted) {
              Navigator.of(context).pop();
              _showSuccessDialog(package);
            }
          }
        },
      );
      setTimer(timer);
    } else {
      setDialogState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message ?? 'Lỗi tạo thanh toán')),
        );
      }
    }
  }

  Future<void> _processCashRenewal(ServicePackage package) async {
    try {
      final userId = _localStorageService.getUserId() ?? '';
      final userEmail = _localStorageService.getUserEmail() ?? '';
      final userName = _localStorageService.getUserName() ?? '';

      // Tạo yêu cầu gia hạn - Admin sẽ xác nhận sau khi nhận tiền mặt
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();
      
      await _database.ref('renewal_requests/$requestId').set({
        'id': requestId,
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'packageId': package.id,
        'packageName': package.name,
        'packagePrice': package.price,
        'durationMonths': package.durationMonths,
        'paymentMethod': 'cash',
        'status': 'pending',
        'currentExpiryDate': _packageExpiryDate?.toIso8601String(),
        'newExpiryDate': _calculateNewExpiry(package.durationMonths).toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Thông báo cho admin
      final usersSnapshot = await _database.ref('users').get();
      if (usersSnapshot.exists) {
        final usersData = usersSnapshot.value as Map<dynamic, dynamic>?;
        if (usersData != null) {
          usersData.forEach((key, value) {
            if (value is Map && value['role'] == 'admin') {
              _database.ref('notifications').push().set({
                'userId': key.toString(),
                'title': 'Yêu cầu gia hạn gói dịch vụ',
                'message': '$userName yêu cầu gia hạn gói ${package.name} - Thanh toán tiền mặt',
                'type': 'renewal_request',
                'requestId': requestId,
                'timestamp': DateTime.now().toIso8601String(),
                'read': false,
              });
            }
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi yêu cầu gia hạn. Vui lòng thanh toán tại văn phòng.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error creating cash renewal request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _applyRenewal(ServicePackage package, String paymentMethod, String? transactionId) async {
    try {
      final userId = _localStorageService.getUserId();
      if (userId == null) return;

      final newExpiryDate = _calculateNewExpiry(package.durationMonths);

      // Cập nhật user
      await _database.ref('users/$userId').update({
        'packageId': package.id,
        'packageExpiryDate': newExpiryDate.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Lưu lịch sử gia hạn
      await _database.ref('renewal_history').push().set({
        'userId': userId,
        'packageId': package.id,
        'packageName': package.name,
        'packagePrice': package.price,
        'durationMonths': package.durationMonths,
        'paymentMethod': paymentMethod,
        'transactionId': transactionId,
        'previousExpiryDate': _packageExpiryDate?.toIso8601String(),
        'newExpiryDate': newExpiryDate.toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Reload data
      await _loadData();
    } catch (e) {
      print('Error applying renewal: $e');
    }
  }

  void _showSuccessDialog(ServicePackage package) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.check_circle, color: Colors.green.shade600, size: 64),
        title: const Text('Gia hạn thành công!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Bạn đã gia hạn gói ${package.name}'),
            const SizedBox(height: 8),
            Text(
              'Hạn mới: ${_formatDate(_calculateNewExpiry(package.durationMonths))}',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gia hạn gói dịch vụ'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thông tin gói hiện tại
                    _buildCurrentPackageCard(),
                    const SizedBox(height: 24),

                    // Danh sách gói có thể gia hạn
                    const Text(
                      'Chọn gói để gia hạn',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ..._packages.map((package) => _buildPackageCard(package)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCurrentPackageCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.blue.shade600, Colors.blue.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.card_membership, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'Gói dịch vụ hiện tại',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _currentPackageName ?? 'Chưa có gói',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getExpiryColor().withAlpha(50),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getExpiryColor()),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isExpired() ? Icons.warning : Icons.access_time,
                    color: _getExpiryColor(),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isExpired() ? 'Đã hết hạn' : 'Còn ${_daysRemaining()} ngày',
                    style: TextStyle(color: _getExpiryColor(), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hết hạn: ${_formatDate(_packageExpiryDate)}',
              style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageCard(ServicePackage package) {
    final isCurrentPackage = package.id == _currentPackageId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentPackage
            ? BorderSide(color: Colors.blue.shade400, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _showRenewalDialog(package),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getPackageColor(package.level).withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getPackageIcon(package.level),
                  color: _getPackageColor(package.level),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          package.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        if (isCurrentPackage) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Đang dùng',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${package.durationMonths} tháng',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(package.price),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPackageColor(String level) {
    switch (level) {
      case 'premium':
        return Colors.purple;
      case 'standard':
        return Colors.blue;
      default:
        return Colors.teal;
    }
  }

  IconData _getPackageIcon(String level) {
    switch (level) {
      case 'premium':
        return Icons.diamond;
      case 'standard':
        return Icons.star;
      default:
        return Icons.check_circle;
    }
  }
}
