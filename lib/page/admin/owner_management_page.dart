import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quanlynhahang/constants/user_roles.dart';

class OwnerManagementPage extends StatefulWidget {
  const OwnerManagementPage({super.key});

  @override
  State<OwnerManagementPage> createState() => _OwnerManagementPageState();
}

class _OwnerManagementPageState extends State<OwnerManagementPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  List<Map<String, dynamic>> _owners = [];
  List<Map<String, dynamic>> _restaurants = [];
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadOwners();
    _loadRestaurants();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadOwners() async {
    setState(() => _isLoading = true);

    try {
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL:
            'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

      final snapshot = await database.ref('users').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final owners = <Map<String, dynamic>>[];

        data.forEach((key, value) {
          if (value is Map && value['role'] == UserRole.owner) {
            owners.add({'id': key, ...Map<String, dynamic>.from(value)});
          }
        });

        setState(() {
          _owners = owners;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading owners: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải danh sách Owner: $e')));
      }
    }
  }

  Future<void> _loadRestaurants() async {
    try {
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL:
            'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

      final snapshot = await database.ref('restaurants').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final restaurants = <Map<String, dynamic>>[];

        data.forEach((key, value) {
          if (value is Map) {
            restaurants.add({
              'id': key,
              'name': value['name'] ?? '',
              'ownerId': value['ownerId'] ?? '',
            });
          }
        });

        setState(() {
          _restaurants = restaurants;
        });
      }
    } catch (e) {
      print('Error loading restaurants: $e');
    }
  }

  Future<void> _assignRestaurant(String ownerId, String ownerName) async {
    // Lọc các nhà hàng chưa có owner hoặc đã có owner này
    final availableRestaurants = _restaurants.where((r) {
      final restaurantOwnerId = r['ownerId'] as String?;
      return restaurantOwnerId == null || restaurantOwnerId.isEmpty || restaurantOwnerId == ownerId;
    }).toList();

    if (availableRestaurants.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có nhà hàng nào để gán')),
        );
      }
      return;
    }

    String? selectedRestaurantId;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Gán nhà hàng cho $ownerName'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Chọn nhà hàng:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRestaurantId,
                decoration: const InputDecoration(
                  labelText: 'Nhà hàng',
                  border: OutlineInputBorder(),
                ),
                items: availableRestaurants.map((restaurant) {
                  return DropdownMenuItem<String>(
                    value: restaurant['id'],
                    child: Text(restaurant['name'] ?? 'Không có tên'),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedRestaurantId = value;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedRestaurantId != null) {
                await _updateOwnerRestaurant(ownerId, selectedRestaurantId!);
                if (mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: const Text('Gán'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateOwnerRestaurant(String ownerId, String restaurantId) async {
    try {
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL:
            'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

      // Cập nhật restaurantID cho owner
      await database.ref('users/$ownerId').update({
        'restaurantID': restaurantId,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Cập nhật ownerId cho restaurant
      await database.ref('restaurants/$restaurantId').update({
        'ownerId': ownerId,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await _loadOwners();
      await _loadRestaurants();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gán nhà hàng thành công')),
        );
      }
    } catch (e) {
      print('Error assigning restaurant: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gán nhà hàng: $e')),
        );
      }
    }
  }

  Future<void> _createOwner() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Create Firebase Auth account
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      // Add user data to database
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL:
            'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

      await database.ref('users/${userCredential.user!.uid}').set({
        'email': _emailController.text.trim(),
        'name': _nameController.text,
        'phone': _phoneController.text,
        'role': UserRole.owner,
        'restaurantID': null,
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Clear form
      _emailController.clear();
      _passwordController.clear();
      _nameController.clear();
      _phoneController.clear();

      // Reload owners list
      await _loadOwners();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tạo Owner thành công')));
        Navigator.of(context).pop(); // Close dialog
      }
    } catch (e) {
      print('Error creating owner: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tạo Owner: $e')));
      }
    } finally {
      setState(() => _isCreating = false);
    }
  }

  Future<void> _toggleOwnerStatus(String ownerId, bool currentStatus) async {
    try {
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL:
            'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

      await database.ref('users/$ownerId').update({
        'isActive': !currentStatus,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await _loadOwners();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentStatus
                  ? 'Đã khóa tài khoản Owner'
                  : 'Đã mở khóa tài khoản Owner',
            ),
          ),
        );
      }
    } catch (e) {
      print('Error toggling owner status: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi cập nhật trạng thái: $e')));
      }
    }
  }

  void _showCreateOwnerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo Owner mới'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'owner@example.com',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu',
                  hintText: 'Ít nhất 6 ký tự',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Họ tên',
                  hintText: 'Nguyễn Văn A',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  hintText: '0123456789',
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: _isCreating ? null : _createOwner,
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Owner'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateOwnerDialog,
            tooltip: 'Tạo Owner mới',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOwners,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _owners.isEmpty
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
                    'Chưa có Owner nào',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showCreateOwnerDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Tạo Owner đầu tiên'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _owners.length,
              itemBuilder: (context, index) {
                final owner = _owners[index];
                final isActive = owner['isActive'] ?? true;
                final restaurantID = owner['restaurantID'];
                
                // Tìm tên nhà hàng nếu có
                String restaurantName = 'Chưa gán';
                if (restaurantID != null) {
                  final restaurant = _restaurants.firstWhere(
                    (r) => r['id'] == restaurantID,
                    orElse: () => {},
                  );
                  restaurantName = restaurant['name'] ?? 'Không tìm thấy';
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      child: Icon(
                        isActive ? Icons.check : Icons.block,
                        color: isActive ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(
                      owner['name'] ?? 'Chưa cập nhật',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(owner['email'] ?? ''),
                        Text(
                          'SĐT: ${owner['phone'] ?? 'Chưa cập nhật'}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        Text(
                          'Nhà hàng: $restaurantName',
                          style: TextStyle(
                            color: restaurantID != null ? Colors.blue : Colors.orange,
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.restaurant, color: Colors.blue),
                          onPressed: () => _assignRestaurant(
                            owner['id'],
                            owner['name'] ?? owner['email'] ?? 'Owner',
                          ),
                          tooltip: 'Gán nhà hàng',
                        ),
                        IconButton(
                          icon: Icon(
                            isActive ? Icons.block : Icons.check_circle,
                            color: isActive ? Colors.red : Colors.green,
                          ),
                          onPressed: () =>
                              _toggleOwnerStatus(owner['id'], isActive),
                          tooltip: isActive
                              ? 'Khóa tài khoản'
                              : 'Mở khóa tài khoản',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
