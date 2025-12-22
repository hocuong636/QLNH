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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
        const Divider(),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chức năng chỉnh sửa sắp có')),
            );
          },
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
