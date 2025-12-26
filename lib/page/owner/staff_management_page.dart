import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quanlynhahang/constants/user_roles.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';

class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({super.key});

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _myStaff = [];
  bool _isLoading = true;
  String? _myRestaurantId;

  @override
  void initState() {
    super.initState();
    _loadData();
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
              content: Text('Bạn chưa được gán vào nhà hàng nào. Vui lòng liên hệ Admin.'),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL:
            'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

      final snapshot = await database.ref('users').get();

      if (snapshot.exists && snapshot.value != null) {
        // Kiểm tra kiểu dữ liệu trước khi xử lý
        if (snapshot.value is! Map) {
          throw Exception('Dữ liệu không đúng định dạng. Có thể do quyền truy cập bị giới hạn.');
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
          errorMessage = 'Không có quyền truy cập dữ liệu người dùng. Vui lòng kiểm tra Firebase Rules.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Đóng',
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Future<void> _addStaffToRestaurant(String userId) async {
    try {
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL:
            'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

      await database.ref('users/$userId').update({
        'restaurantID': _myRestaurantId,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm nhân viên thành công')),
        );
      }
    } catch (e) {
      print('Error adding staff: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi thêm nhân viên: $e')),
        );
      }
    }
  }

  Future<void> _removeStaffFromRestaurant(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xóa nhân viên này khỏi nhà hàng?'),
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
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL:
            'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

      await database.ref('users/$userId').update({
        'restaurantID': null,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa nhân viên khỏi nhà hàng')),
        );
      }
    } catch (e) {
      print('Error removing staff: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa nhân viên: $e')),
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
                            _addStaffToRestaurant(user['id']);
                            Navigator.of(context).pop();
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
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showAvailableStaff,
            tooltip: 'Thêm nhân viên',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Làm mới',
          ),
        ],
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
              : _myStaff.isEmpty
                  ? Center(
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
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _showAvailableStaff,
                            icon: const Icon(Icons.person_add),
                            label: const Text('Thêm nhân viên'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _myStaff.length,
                      itemBuilder: (context, index) {
                        final staff = _myStaff[index];
                        final isActive = staff['isActive'] ?? true;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  staff['role'] == UserRole.kitchen
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
                              staff['fullName'] ??
                                  staff['name'] ??
                                  'Không có tên',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
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
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.red),
                              onPressed: () =>
                                  _removeStaffFromRestaurant(staff['id']),
                              tooltip: 'Xóa khỏi nhà hàng',
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
