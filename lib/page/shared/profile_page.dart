import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/auth_service.dart';
import 'package:quanlynhahang/constants/user_roles.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  User? _user;
  Map<String, dynamic>? _userData;
  String? _restaurantName;
  bool _isLoading = true;

  // Controllers for editing
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    _user = _authService.getCurrentUser();

    if (_user != null) {
      try {
        final ref = FirebaseDatabase.instance.ref('users/${_user!.uid}');
        final snapshot = await ref.get();
        if (snapshot.exists) {
          _userData = Map<String, dynamic>.from(snapshot.value as Map);
          
          // Load restaurant name if user belongs to a restaurant
          final restaurantId = _userData?['restaurantID'];
          if (restaurantId != null && restaurantId.toString().isNotEmpty) {
            await _loadRestaurantName(restaurantId);
          }
        } else {
          print('Không tìm thấy dữ liệu người dùng.');
        }
      } catch (e) {
        print('Lỗi khi tải dữ liệu người dùng: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi tải dữ liệu: $e')),
          );
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadRestaurantName(String restaurantId) async {
    try {
      final ref = FirebaseDatabase.instance.ref('restaurants/$restaurantId');
      final snapshot = await ref.get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        _restaurantName = data['name'];
      }
    } catch (e) {
      print('Lỗi khi tải thông tin nhà hàng: $e');
    }
  }

  Future<void> _showEditProfileDialog() async {
    _fullNameController.text = _userData?['fullName'] ?? '';
    _phoneController.text = _userData?['phoneNumber'] ?? '';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Chỉnh Sửa Hồ Sơ'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Họ và Tên',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Số Điện Thoại',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email, color: Colors.grey.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            _userData?['email'] ?? '',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.lock, size: 16, color: Colors.grey.shade400),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Email không thể thay đổi',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _saveProfile();
    }
  }

  Future<void> _saveProfile() async {
    final newFullName = _fullNameController.text.trim();
    final newPhone = _phoneController.text.trim();

    if (newFullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Họ và tên không được để trống'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final ref = FirebaseDatabase.instance.ref('users/${_user!.uid}');
      await ref.update({
        'fullName': newFullName,
        'phoneNumber': newPhone,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Reload user data
      await _loadUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật hồ sơ thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Lỗi khi cập nhật hồ sơ: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(
                  child: Text(
                  'Không có người dùng nào đăng nhập',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ))
              : _buildProfileView(),
    );
  }

  Widget _buildProfileView() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const SizedBox(height: 20),
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.deepPurple.shade100,
          child: Text(
            _userData?['fullName']?.substring(0, 1).toUpperCase() ?? 'A',
            style: const TextStyle(
              fontSize: 50,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _userData?['fullName'] ?? 'Tên Người Dùng',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _userData?['email'] ?? 'email@example.com',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 30),
        const Divider(),
        _buildProfileInfoTile(
          icon: Icons.person,
          title: 'Họ và Tên',
          subtitle: _userData?['fullName'] ?? 'Chưa cập nhật',
        ),
        _buildProfileInfoTile(
          icon: Icons.email,
          title: 'Email',
          subtitle: _userData?['email'] ?? 'Chưa cập nhật',
        ),
        _buildProfileInfoTile(
          icon: Icons.phone,
          title: 'Số Điện Thoại',
          subtitle: _userData?['phoneNumber'] ?? 'Chưa cập nhật',
        ),
        _buildProfileInfoTile(
          icon: Icons.badge,
          title: 'Vai trò',
          subtitle: UserRole.getDisplayName(_userData?['role']),
        ),
        if (_restaurantName != null && _restaurantName!.isNotEmpty)
          _buildProfileInfoTile(
            icon: Icons.restaurant,
            title: 'Nhà hàng',
            subtitle: _restaurantName!,
          ),
        const Divider(),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _showEditProfileDialog,
          icon: const Icon(Icons.edit),
          label: const Text('Chỉnh Sửa Hồ Sơ'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }
}
