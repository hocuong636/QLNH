import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quanlynhahang/constants/user_roles.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/models/request.dart';

class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({super.key});

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _myStaff = [];
  List<Request> _pendingRequests = [];
  bool _isLoading = true;
  String? _myRestaurantId;
  String? _currentOwnerId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadCurrentUserInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserInfo() async {
    try {
      final localStorageService = LocalStorageService();
      final userId = localStorageService.getUserId();
      _currentOwnerId = userId;
      await _loadData();
      await _loadPendingRequests();
    } catch (e) {
      print('Error loading user info: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final localStorageService = LocalStorageService();
      _myRestaurantId = localStorageService.getRestaurantId();

      if (_myRestaurantId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bạn chưa được gán vào nhà hàng nào. Vui lòng liên hệ Admin.',
              ),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final database = FirebaseDatabase.instance;

      final snapshot = await database.ref('users').get();

      if (snapshot.exists && snapshot.value != null) {
        // Kiểm tra kiểu dữ liệu trước khi xử lý
        if (snapshot.value is! Map) {
          throw Exception(
            'Dữ liệu không đúng định dạng. Có thể do quyền truy cập bị giới hạn.',
          );
        }

        final data = snapshot.value as Map<dynamic, dynamic>;
        final allUsers = <Map<String, dynamic>>[];
        final myStaff = <Map<String, dynamic>>[];

        data.forEach((key, value) {
          if (value is Map) {
            final user = {'id': key, ...Map<String, dynamic>.from(value)};
            final userRole = value['role'];
            final restaurantID = value['restaurantID'];

            // Chỉ lấy user có role là staff (KITCHEN, ORDER)
            if (userRole == UserRole.kitchen || userRole == UserRole.order) {
              // User chưa thuộc nhà hàng nào
              if (restaurantID == null) {
                allUsers.add(user);
              }
              // User đã thuộc nhà hàng của mình
              else if (restaurantID == _myRestaurantId) {
                myStaff.add(user);
              }
            }
          }
        });

        setState(() {
          _allUsers = allUsers;
          _myStaff = myStaff;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        String errorMessage = 'Lỗi tải dữ liệu: $e';

        // Xử lý thông báo lỗi cụ thể
        if (e.toString().contains('permission') ||
            e.toString().contains('Permission denied')) {
          errorMessage =
              'Không có quyền truy cập dữ liệu người dùng. Vui lòng kiểm tra Firebase Rules.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'Đóng', onPressed: () {}),
          ),
        );
      }
    }
  }

  Future<void> _addStaffToRestaurant(String userId, String role) async {
    try {
      final database = FirebaseDatabase.instance;

      await database.ref('users/$userId').update({
        'restaurantID': _myRestaurantId,
        'role': role,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await _loadData();
      await _loadPendingRequests();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã thêm nhân viên với vai trò ${UserRole.getDisplayName(role)}',
            ),
          ),
        );
      }
    } catch (e) {
      print('Error adding staff: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi thêm nhân viên: $e')));
      }
    }
  }

  Future<void> _showRoleSelectionDialog(String userId, String userName) async {
    final selectedRole = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn vai trò cho nhân viên'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhân viên: $userName'),
            const SizedBox(height: 16),
            const Text('Chọn vai trò:'),
            const SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: const Icon(Icons.shopping_cart, color: Colors.blue),
              ),
              title: Text(UserRole.getDisplayName(UserRole.order)),
              subtitle: const Text('Quản lý đơn hàng, phục vụ khách'),
              onTap: () => Navigator.of(context).pop(UserRole.order),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                child: const Icon(Icons.restaurant, color: Colors.orange),
              ),
              title: Text(UserRole.getDisplayName(UserRole.kitchen)),
              subtitle: const Text('Quản lý bếp, chế biến món ăn'),
              onTap: () => Navigator.of(context).pop(UserRole.kitchen),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );

    if (selectedRole != null) {
      await _addStaffToRestaurant(userId, selectedRole);
    }
  }

  Future<void> _removeStaffFromRestaurant(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text(
          'Bạn có chắc muốn xóa nhân viên này khỏi nhà hàng?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final database = FirebaseDatabase.instance;

      await database.ref('users/$userId').update({
        'restaurantID': null,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await _loadData();
      await _loadPendingRequests();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa nhân viên khỏi nhà hàng')),
        );
      }
    } catch (e) {
      print('Error removing staff: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi xóa nhân viên: $e')));
      }
    }
  }

  Future<void> _loadPendingRequests() async {
    if (_myRestaurantId == null || _currentOwnerId == null) return;

    try {
      final database = FirebaseDatabase.instance;
      final snapshot = await database.ref('requests').get();
      final requests = <Request>[];

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final request = Request.fromJson({
                'id': key.toString(),
                ...Map<String, dynamic>.from(value),
              });
              // Chỉ lấy yêu cầu nhân viên (staff) thuộc về nhà hàng của owner này và đang chờ duyệt
              if (request.type == RequestType.staff &&
                  request.ownerId == _currentOwnerId &&
                  request.restaurantId == _myRestaurantId &&
                  request.status == RequestStatus.pending) {
                requests.add(request);
              }
            } catch (e) {
              print('Error parsing request $key: $e');
            }
          }
        });
      }

      // Sắp xếp theo thời gian tạo (mới nhất trước)
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _pendingRequests = requests;
      });
    } catch (e) {
      print('Error loading pending requests: $e');
    }
  }

  Future<void> _approveStaffRequest(Request request) async {
    try {
      final database = FirebaseDatabase.instance;

      // Cập nhật trạng thái yêu cầu
      await database.ref('requests/${request.id}').update({
        'status': 'approved',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Cập nhật role và restaurantID của user
      await database.ref('users/${request.userId}').update({
        'role': request.requestedRole,
        'restaurantID': request.restaurantId,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Gửi thông báo cho user
      await database.ref('notifications').push().set({
        'userId': request.userId,
        'title': 'Yêu cầu đăng ký Nhân viên đã được phê duyệt',
        'message': 'Yêu cầu đăng ký làm ${request.requestedRole == UserRole.order ? "Nhân viên Order" : "Nhân viên Bếp"} tại ${request.restaurantName} đã được Owner phê duyệt. Bạn có thể đăng nhập lại để sử dụng tài khoản.',
        'type': 'request_approved',
        'requestId': request.id,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      });

      // Reload data
      await _loadData();
      await _loadPendingRequests();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã phê duyệt yêu cầu thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error approving staff request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi phê duyệt yêu cầu: $e')),
        );
      }
    }
  }

  Future<void> _rejectStaffRequest(Request request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận từ chối'),
        content: Text('Bạn có chắc muốn từ chối yêu cầu của ${request.userName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final database = FirebaseDatabase.instance;

      // Cập nhật trạng thái yêu cầu
      await database.ref('requests/${request.id}').update({
        'status': 'rejected',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Gửi thông báo cho user
      await database.ref('notifications').push().set({
        'userId': request.userId,
        'title': 'Yêu cầu đăng ký Nhân viên đã bị từ chối',
        'message': 'Yêu cầu đăng ký làm ${request.requestedRole == UserRole.order ? "Nhân viên Order" : "Nhân viên Bếp"} tại ${request.restaurantName} đã bị Owner từ chối. Vui lòng liên hệ Owner để biết thêm chi tiết.',
        'type': 'request_rejected',
        'requestId': request.id,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      });

      // Reload data
      await _loadPendingRequests();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã từ chối yêu cầu'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error rejecting staff request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi từ chối yêu cầu: $e')),
        );
      }
    }
  }

  void _showAvailableStaff() {
    if (_allUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có nhân viên nào để thêm')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Chọn nhân viên để thêm',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _allUsers.length,
                  itemBuilder: (context, index) {
                    final user = _allUsers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: user['role'] == UserRole.kitchen
                              ? Colors.orange.shade100
                              : Colors.blue.shade100,
                          child: Icon(
                            user['role'] == UserRole.kitchen
                                ? Icons.restaurant
                                : Icons.shopping_cart,
                            color: user['role'] == UserRole.kitchen
                                ? Colors.orange
                                : Colors.blue,
                          ),
                        ),
                        title: Text(
                          user['fullName'] ?? user['name'] ?? 'Không có tên',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['email'] ?? ''),
                            Text(
                              UserRole.getDisplayName(user['role']),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showRoleSelectionDialog(
                              user['id'],
                              user['fullName'] ??
                                  user['name'] ??
                                  'Không có tên',
                            );
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Thêm'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
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
      appBar: AppBar(
        title: const Text('Quản lý Nhân viên'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_tabController.index == 0)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _showAvailableStaff,
              tooltip: 'Thêm nhân viên',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadData();
              _loadPendingRequests();
            },
            tooltip: 'Làm mới',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(
                  icon: const Icon(Icons.people),
                  text: 'Nhân viên (${_myStaff.length})',
                ),
                Tab(
                  icon: Stack(
                    children: [
                      const Icon(Icons.request_quote),
                      if (_pendingRequests.isNotEmpty)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${_pendingRequests.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  text: 'Yêu cầu (${_pendingRequests.length})',
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myRestaurantId == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 80,
                    color: Colors.orange.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bạn chưa được gán vào nhà hàng nào',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vui lòng liên hệ Admin để được gán',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : _tabController.index == 0
          ? _buildStaffList()
          : _buildPendingRequestsList(),
    );
  }

  Widget _buildStaffList() {
    if (_myStaff.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có nhân viên nào',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAvailableStaff,
              icon: const Icon(Icons.person_add),
              label: const Text('Thêm nhân viên'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myStaff.length,
      itemBuilder: (context, index) {
        final staff = _myStaff[index];
        final isActive = staff['isActive'] ?? true;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: staff['role'] == UserRole.kitchen
                  ? Colors.orange.shade100
                  : Colors.blue.shade100,
              child: Icon(
                staff['role'] == UserRole.kitchen
                    ? Icons.restaurant
                    : Icons.shopping_cart,
                color: staff['role'] == UserRole.kitchen
                    ? Colors.orange
                    : Colors.blue,
              ),
            ),
            title: Text(
              staff['fullName'] ?? staff['name'] ?? 'Không có tên',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(staff['email'] ?? ''),
                Text(
                  'SĐT: ${staff['phoneNumber'] ?? staff['phone'] ?? 'Chưa cập nhật'}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                Text(
                  UserRole.getDisplayName(staff['role']),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Trạng thái: ${isActive ? 'Hoạt động' : 'Đã khóa'}',
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              onPressed: () => _removeStaffFromRestaurant(staff['id']),
              tooltip: 'Xóa khỏi nhà hàng',
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingRequestsList() {
    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Không có yêu cầu nào chờ phê duyệt',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final request = _pendingRequests[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: request.requestedRole == UserRole.kitchen
                  ? Colors.orange.shade100
                  : Colors.blue.shade100,
              child: Icon(
                request.requestedRole == UserRole.kitchen
                    ? Icons.restaurant
                    : Icons.shopping_cart,
                color: request.requestedRole == UserRole.kitchen
                    ? Colors.orange
                    : Colors.blue,
              ),
            ),
            title: Text(
              request.userName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.userEmail),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Chờ phê duyệt',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
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
                    _buildInfoRow('Vai trò yêu cầu', 
                      request.requestedRole == UserRole.order 
                          ? 'Nhân viên Order' 
                          : 'Nhân viên Bếp'),
                    _buildInfoRow('Nhà hàng', request.restaurantName ?? ''),
                    _buildInfoRow(
                      'Ngày gửi',
                      '${request.createdAt.day}/${request.createdAt.month}/${request.createdAt.year} ${request.createdAt.hour}:${request.createdAt.minute.toString().padLeft(2, '0')}',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _rejectStaffRequest(request),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Từ chối'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => _approveStaffRequest(request),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Phê duyệt'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
