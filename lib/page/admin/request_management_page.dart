import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:quanlynhahang/models/request.dart';
import 'package:quanlynhahang/models/user.dart';
import 'package:quanlynhahang/models/service_package.dart';
import 'package:quanlynhahang/constants/user_roles.dart';

class RequestManagementPage extends StatefulWidget {
  const RequestManagementPage({super.key});

  @override
  State<RequestManagementPage> createState() => _RequestManagementPageState();
}

class _RequestManagementPageState extends State<RequestManagementPage> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  List<Request> _requests = [];
  List<Request> _filteredRequests = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await _database.ref('requests').get();
      final requests = <Request>[];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          data.forEach((key, value) {
            if (value is Map) {
              try {
                final request = Request.fromJson({
                  'id': key.toString(),
                  ...Map<String, dynamic>.from(value),
                });
                // Chỉ lấy yêu cầu Owner
                if (request.type == RequestType.owner) {
                  requests.add(request);
                }
              } catch (e) {
                print('Error parsing request $key: $e');
              }
            }
          });
        }
      }

      // Sắp xếp theo thời gian tạo (mới nhất trước)
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _requests = requests;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading requests: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải danh sách yêu cầu: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredRequests = _requests.where((request) {
        // Chỉ filter theo status (đã lọc chỉ Owner ở _loadRequests)
        return _selectedFilter == 'all' ||
            (_selectedFilter == 'pending' && request.status == RequestStatus.pending) ||
            (_selectedFilter == 'approved' && request.status == RequestStatus.approved) ||
            (_selectedFilter == 'rejected' && request.status == RequestStatus.rejected);
      }).toList();
    });
  }

  Map<String, int> _getStatusCounts() {
    return {
      'pending': _requests.where((r) => r.status == RequestStatus.pending).length,
      'approved': _requests.where((r) => r.status == RequestStatus.approved).length,
      'rejected': _requests.where((r) => r.status == RequestStatus.rejected).length,
    };
  }

  Future<void> _approveRequest(Request request) async {
    try {
      // Cập nhật trạng thái yêu cầu
      await _database.ref('requests/${request.id}').update({
        'status': 'approved',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      if (request.type == RequestType.owner) {
        // Cập nhật role của user thành OWNER
        await _database.ref('users/${request.userId}').update({
          'role': UserRole.owner,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        // Nếu có package, cập nhật thông tin package cho user
        if (request.packageId != null) {
          final expiryDate = DateTime.now().add(Duration(days: (request.packageDurationMonths ?? 3) * 30));
          await _database.ref('users/${request.userId}').update({
            'packageId': request.packageId,
            'packageExpiryDate': expiryDate.toIso8601String(),
          });
        }

        // Tạo nhà hàng từ thông tin trong request
        if (request.restaurantInfo != null) {
          final restaurantId = DateTime.now().millisecondsSinceEpoch.toString();
          final restaurantData = {
            'id': restaurantId,
            'ownerId': request.userId,
            'name': request.restaurantInfo!['name'] ?? '',
            'address': request.restaurantInfo!['address'] ?? '',
            'phone': request.restaurantInfo!['phone'] ?? '',
            'email': request.restaurantInfo!['email'] ?? '',
            'description': request.restaurantInfo!['description'] ?? '',
            'openingHours': request.restaurantInfo!['openingHours'] ?? '',
            'capacity': request.restaurantInfo!['capacity'] ?? 0,
            'isOpen': true,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          };
          
          await _database.ref('restaurants/$restaurantId').set(restaurantData);
          
          // Cập nhật restaurantID cho user
          await _database.ref('users/${request.userId}').update({
            'restaurantID': restaurantId,
          });
        }

        // Gửi thông báo cho user
        await _database.ref('notifications').push().set({
          'userId': request.userId,
          'title': 'Yêu cầu đăng ký Owner đã được phê duyệt',
          'message': 'Yêu cầu đăng ký làm Owner của bạn đã được Admin phê duyệt. Bạn có thể đăng nhập lại để sử dụng tài khoản Owner.',
          'type': 'request_approved',
          'requestId': request.id,
          'timestamp': DateTime.now().toIso8601String(),
          'read': false,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã phê duyệt yêu cầu thành công'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      print('Error approving request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi phê duyệt yêu cầu: $e')),
        );
      }
    }
  }

  Future<void> _rejectRequest(Request request) async {
    try {
      await _database.ref('requests/${request.id}').update({
        'status': 'rejected',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Gửi thông báo cho user
      await _database.ref('notifications').push().set({
        'userId': request.userId,
        'title': 'Yêu cầu đăng ký đã bị từ chối',
        'message': 'Yêu cầu đăng ký của bạn đã bị Admin từ chối. Vui lòng liên hệ Admin để biết thêm chi tiết.',
        'type': 'request_rejected',
        'requestId': request.id,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã từ chối yêu cầu'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      print('Error rejecting request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi từ chối yêu cầu: $e')),
        );
      }
    }
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )} VND';
  }

  String _getStatusText(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return 'Chờ duyệt';
      case RequestStatus.approved:
        return 'Đã duyệt';
      case RequestStatus.rejected:
        return 'Đã từ chối';
    }
  }

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return const Color(0xFFFF9800);
      case RequestStatus.approved:
        return const Color(0xFF4CAF50);
      case RequestStatus.rejected:
        return const Color(0xFFF44336);
    }
  }

  IconData _getStatusIcon(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return Icons.pending_actions_rounded;
      case RequestStatus.approved:
        return Icons.check_circle_rounded;
      case RequestStatus.rejected:
        return Icons.cancel_rounded;
    }
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedFilter = value;
              _applyFilters();
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

 Widget _buildStatusStats() {
  final counts = _getStatusCounts();
  final total = _requests.length;

  if (total == 0) {
    return const SizedBox.shrink();
  }

  final pendingCount = counts['pending'] ?? 0;
  final approvedCount = counts['approved'] ?? 0;
  final rejectedCount = counts['rejected'] ?? 0;

   return Container(
     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
     decoration: BoxDecoration(
       gradient: LinearGradient(
         colors: [Colors.white, Colors.blue.shade50],
         begin: Alignment.topLeft,
         end: Alignment.bottomRight,
       ),
       borderRadius: BorderRadius.circular(12),
       border: Border.all(color: Colors.blue.shade100),
       boxShadow: [
         BoxShadow(
           color: Colors.blue.withOpacity(0.08),
           blurRadius: 6,
           offset: const Offset(0, 2),
         ),
       ],
     ),
     child: Row(
       children: [
         Expanded(
           child: _buildStatItem(
             icon: Icons.pending_actions_rounded,
             label: 'Chờ duyệt',
             count: pendingCount,
             color: Color(0xFFFF9800),
             bgColor: Color(0xFFFFF3E0),
             total: total,
           ),
         ),
         const SizedBox(width: 4),
         Expanded(
           child: _buildStatItem(
             icon: Icons.check_circle_rounded,
             label: 'Đã duyệt',
             count: approvedCount,
             color: Color(0xFF4CAF50),
             bgColor: Color(0xFFE8F5E9),
             total: total,
           ),
         ),
         const SizedBox(width: 4),
         Expanded(
           child: _buildStatItem(
             icon: Icons.cancel_rounded,
             label: 'Từ chối',
             count: rejectedCount,
             color: Color(0xFFF44336),
             bgColor: Color(0xFFFFEBEE),
             total: total,
           ),
         ),
       ],
     ),
   );
}

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
    required int total,
  }) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;
    final isSelected = (_selectedFilter == 'pending' && label == 'Chờ duyệt') ||
        (_selectedFilter == 'approved' && label == 'Đã duyệt') ||
        (_selectedFilter == 'rejected' && label == 'Từ chối') ||
        (_selectedFilter == 'all');
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (label == 'Chờ duyệt') {
              _selectedFilter = 'pending';
            } else if (label == 'Đã duyệt') {
              _selectedFilter = 'approved';
            } else if (label == 'Từ chối') {
              _selectedFilter = 'rejected';
            }
            _applyFilters();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? bgColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: color.withOpacity(0.3), width: 1) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Container(
                width: double.infinity,
                height: 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  color: Colors.grey.shade200,
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: percentage / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.7)],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.assignment_rounded,
                color: Color(0xFF6366F1),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quản lý Yêu cầu',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  'Phê duyệt đăng ký Owner',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadRequests,
            tooltip: 'Làm mới',
            color: const Color(0xFF6366F1),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFilterChip('all', 'Tất cả', Icons.list_rounded),
                  _buildFilterChip('pending', 'Chờ duyệt', Icons.pending_actions_rounded),
                  _buildFilterChip('approved', 'Đã duyệt', Icons.check_circle_rounded),
                  _buildFilterChip('rejected', 'Từ chối', Icons.cancel_rounded),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Đang tải yêu cầu...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : _filteredRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.blue.shade300,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Không có yêu cầu nào',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tất cả yêu cầu đã được xử lý',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRequests,
                  color: const Color(0xFF6366F1),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredRequests.length,
                    itemBuilder: (context, index) {
                      final request = _filteredRequests[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _getStatusColor(request.status).withOpacity(0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: _getStatusColor(request.status).withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          childrenPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _getStatusColor(request.status).withOpacity(0.2),
                                  _getStatusColor(request.status).withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.business_center_rounded,
                              color: _getStatusColor(request.status),
                              size: 28,
                            ),
                          ),
                          title: Text(
                            request.userName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(request.status).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _getStatusColor(request.status).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getStatusIcon(request.status),
                                        size: 14,
                                        color: _getStatusColor(request.status),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _getStatusText(request.status),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _getStatusColor(request.status),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoRow(Icons.email_rounded, 'Email', request.userEmail),
                                  if (request.type == RequestType.owner) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.purple.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.card_giftcard_rounded, 
                                                color: Colors.purple.shade700, size: 18),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Thông tin gói dịch vụ',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.purple.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          if (request.packageName != null)
                                            _buildInfoRow(Icons.label_rounded, 'Gói dịch vụ', request.packageName!),
                                          if (request.packagePrice != null)
                                            _buildInfoRow(Icons.attach_money_rounded, 'Giá', _formatCurrency(request.packagePrice!)),
                                          if (request.packageDurationMonths != null)
                                            _buildInfoRow(Icons.calendar_today_rounded, 'Thời hạn', '${request.packageDurationMonths} tháng'),
                                          if (request.paymentMethod != null)
                                            _buildInfoRow(Icons.payment_rounded, 'Phương thức thanh toán', request.paymentMethod!),
                                        ],
                                      ),
                                    ),
                                    if (request.paymentStatus != null) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: request.paymentStatus == 'paid'
                                                ? [Colors.green.shade50, Colors.green.shade100.withOpacity(0.3)]
                                                : request.paymentStatus == 'pending'
                                                    ? [Colors.orange.shade50, Colors.orange.shade100.withOpacity(0.3)]
                                                    : [Colors.red.shade50, Colors.red.shade100.withOpacity(0.3)],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: request.paymentStatus == 'paid'
                                                ? Colors.green.shade300
                                                : request.paymentStatus == 'pending'
                                                    ? Colors.orange.shade300
                                                    : Colors.red.shade300,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: request.paymentStatus == 'paid'
                                                    ? Colors.green
                                                    : request.paymentStatus == 'pending'
                                                        ? Colors.orange
                                                        : Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                request.paymentStatus == 'paid'
                                                    ? Icons.check_circle_rounded
                                                    : request.paymentStatus == 'pending'
                                                        ? Icons.pending_rounded
                                                        : Icons.cancel_rounded,
                                                size: 20,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Trạng thái thanh toán',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey.shade700,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    request.paymentStatus == 'paid'
                                                        ? 'Đã thanh toán'
                                                        : request.paymentStatus == 'pending'
                                                            ? 'Chờ thanh toán'
                                                            : 'Thanh toán thất bại',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                      color: request.paymentStatus == 'paid'
                                                          ? Colors.green.shade800
                                                          : request.paymentStatus == 'pending'
                                                              ? Colors.orange.shade800
                                                              : Colors.red.shade800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (request.restaurantInfo != null) ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blue.shade50,
                                              Colors.cyan.shade50,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.blue.shade200,
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.blue.withOpacity(0.1),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade700,
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: const Icon(
                                                    Icons.restaurant_rounded,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                const Text(
                                                  'Thông tin nhà hàng',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1A1A1A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            if (request.restaurantInfo!['name'] != null)
                                              _buildInfoRow(Icons.store_rounded, 'Tên nhà hàng', request.restaurantInfo!['name']),
                                            if (request.restaurantInfo!['address'] != null)
                                              _buildInfoRow(Icons.location_on_rounded, 'Địa chỉ', request.restaurantInfo!['address']),
                                            if (request.restaurantInfo!['phone'] != null)
                                              _buildInfoRow(Icons.phone_rounded, 'Số điện thoại', request.restaurantInfo!['phone']),
                                            if (request.restaurantInfo!['email'] != null)
                                              _buildInfoRow(Icons.email_rounded, 'Email', request.restaurantInfo!['email']),
                                            if (request.restaurantInfo!['openingHours'] != null)
                                              _buildInfoRow(Icons.access_time_rounded, 'Giờ mở cửa', request.restaurantInfo!['openingHours']),
                                            if (request.restaurantInfo!['capacity'] != null)
                                              _buildInfoRow(Icons.table_restaurant_rounded, 'Sức chứa', '${request.restaurantInfo!['capacity']} bàn'),
                                            if (request.restaurantInfo!['description'] != null && 
                                                request.restaurantInfo!['description'].toString().isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 8),
                                                child: Text(
                                                  'Mô tả: ${request.restaurantInfo!['description']}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade700,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today_rounded, 
                                          size: 16, color: Colors.grey.shade700),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Ngày tạo: ${request.createdAt.day}/${request.createdAt.month}/${request.createdAt.year} ${request.createdAt.hour}:${request.createdAt.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (request.status == RequestStatus.pending) ...[
                                    const SizedBox(height: 20),
                                    if (request.type == RequestType.owner && request.paymentStatus != 'paid')
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        margin: const EdgeInsets.only(bottom: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.orange.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.warning_amber_rounded, 
                                              color: Colors.orange.shade700, size: 20),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Lưu ý: Yêu cầu chưa được thanh toán',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.orange.shade800,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _rejectRequest(request),
                                            icon: const Icon(Icons.close_rounded, size: 18),
                                            label: const Text('Từ chối'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: BorderSide(color: Colors.red.shade300),
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 2,
                                          child: FilledButton.icon(
                                            onPressed: request.type == RequestType.owner && 
                                                     request.paymentStatus != 'paid'
                                                ? null
                                                : () => _approveRequest(request),
                                            icon: const Icon(Icons.check_circle_rounded, size: 20),
                                            label: const Text('Phê duyệt'),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(0xFF4CAF50),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              elevation: 2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A1A1A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

