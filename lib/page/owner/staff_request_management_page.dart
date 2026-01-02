import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:quanlynhahang/models/request.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/constants/user_roles.dart';

class StaffRequestManagementPage extends StatefulWidget {
  const StaffRequestManagementPage({super.key});

  @override
  State<StaffRequestManagementPage> createState() => _StaffRequestManagementPageState();
}

class _StaffRequestManagementPageState extends State<StaffRequestManagementPage> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final LocalStorageService _localStorageService = LocalStorageService();
  List<Request> _requests = [];
  List<Request> _filteredRequests = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'
  String? _currentOwnerId;
  String? _currentRestaurantId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserInfo();
  }

  Future<void> _loadCurrentUserInfo() async {
    try {
      final userId = _localStorageService.getUserId() ?? '';
      if (userId.isEmpty) return;

      final userSnapshot = await _database.ref('users/$userId').get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _currentOwnerId = userId;
          _currentRestaurantId = userData['restaurantID']?.toString();
        });
        _loadRequests();
      }
    } catch (e) {
      print('Error loading user info: $e');
      setState(() => _isLoading = false);
    }
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
                // Chỉ lấy yêu cầu nhân viên (staff) và thuộc về nhà hàng của owner này
                if (request.type == RequestType.staff &&
                    request.ownerId == _currentOwnerId &&
                    request.restaurantId == _currentRestaurantId) {
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
        return _selectedFilter == 'all' ||
            (_selectedFilter == 'pending' && request.status == RequestStatus.pending) ||
            (_selectedFilter == 'approved' && request.status == RequestStatus.approved) ||
            (_selectedFilter == 'rejected' && request.status == RequestStatus.rejected);
      }).toList();
    });
  }

  Future<void> _approveRequest(Request request) async {
    try {
      // Cập nhật trạng thái yêu cầu
      await _database.ref('requests/${request.id}').update({
        'status': 'approved',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Cập nhật role của user thành role được yêu cầu
      await _database.ref('users/${request.userId}').update({
        'role': request.requestedRole,
        'restaurantID': request.restaurantId,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Gửi thông báo cho user
      await _database.ref('notifications').push().set({
        'userId': request.userId,
        'title': 'Yêu cầu đăng ký Nhân viên đã được phê duyệt',
        'message': 'Yêu cầu đăng ký làm ${request.requestedRole == UserRole.order ? "Nhân viên Order" : "Nhân viên Bếp"} tại ${request.restaurantName} đã được Owner phê duyệt. Bạn có thể đăng nhập lại để sử dụng tài khoản.',
        'type': 'request_approved',
        'requestId': request.id,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      });

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
        'title': 'Yêu cầu đăng ký Nhân viên đã bị từ chối',
        'message': 'Yêu cầu đăng ký làm ${request.requestedRole == UserRole.order ? "Nhân viên Order" : "Nhân viên Bếp"} tại ${request.restaurantName} đã bị Owner từ chối. Vui lòng liên hệ Owner để biết thêm chi tiết.',
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
        return Colors.orange;
      case RequestStatus.approved:
        return Colors.green;
      case RequestStatus.rejected:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Quản lý Yêu cầu Nhân viên',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Text(
                  'Trạng thái:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('Tất cả')),
                      ButtonSegment(value: 'pending', label: Text('Chờ duyệt')),
                      ButtonSegment(value: 'approved', label: Text('Đã duyệt')),
                      ButtonSegment(value: 'rejected', label: Text('Từ chối')),
                    ],
                    selected: {_selectedFilter},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedFilter = newSelection.first;
                        _applyFilters();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Không có yêu cầu nào',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredRequests.length,
                    itemBuilder: (context, index) {
                      final request = _filteredRequests[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: _getStatusColor(request.status).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: ExpansionTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getStatusColor(request.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.work_outline,
                              color: _getStatusColor(request.status),
                            ),
                          ),
                          title: Text(
                            request.userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                request.requestedRole == UserRole.order
                                    ? 'Nhân viên Order'
                                    : 'Nhân viên Bếp',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(request.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _getStatusText(request.status),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _getStatusColor(request.status),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoRow('Email', request.userEmail),
                                  if (request.restaurantName != null)
                                    _buildInfoRow('Nhà hàng', request.restaurantName!),
                                  if (request.requestedRole != null)
                                    _buildInfoRow(
                                      'Vai trò',
                                      request.requestedRole == UserRole.order
                                          ? 'Nhân viên Order'
                                          : 'Nhân viên Bếp',
                                    ),
                                  _buildInfoRow(
                                    'Ngày tạo',
                                    '${request.createdAt.day}/${request.createdAt.month}/${request.createdAt.year} ${request.createdAt.hour}:${request.createdAt.minute.toString().padLeft(2, '0')}',
                                  ),
                                  if (request.status == RequestStatus.pending) ...[
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () => _rejectRequest(request),
                                          child: const Text('Từ chối'),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton(
                                          onPressed: () => _approveRequest(request),
                                          child: const Text('Phê duyệt'),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

