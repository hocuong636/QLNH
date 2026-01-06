import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/auth_service.dart';
import 'package:quanlynhahang/constants/user_roles.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

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
  String? _profileImageUrl;
  bool _isLoading = true;

  // Controllers for editing
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Define primary color
  static const Color primaryColor = Color(0xFF81C784); // Light green
  static const Color primaryLight = Color(0xFFE8F5E8); // Very light green for backgrounds
  static const Color primaryAccent = Color(0xFF4CAF50); // Darker green for accents

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
          _profileImageUrl = _userData?['profileImageUrl'];
          
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

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);

    if (pickedFile != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Upload to Firebase Storage
        final file = File(pickedFile.path);
        final fileName = '${_user!.uid}_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child('profile_images/$fileName');
        print('Uploading to: ${ref.fullPath}');
        await ref.putFile(file);
        print('Upload successful');

        // Get download URL
        final downloadUrl = await ref.getDownloadURL();
        print('Download URL: $downloadUrl');

        // Update database
        final userRef = FirebaseDatabase.instance.ref('users/${_user!.uid}');
        await userRef.update({
          'profileImageUrl': downloadUrl,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        // Update local state
        setState(() {
          _profileImageUrl = downloadUrl;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ảnh hồ sơ đã được cập nhật!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('Lỗi khi upload ảnh: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi upload ảnh: $e'),
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
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog() async {
    _fullNameController.text = _userData?['fullName'] ?? '';
    _phoneController.text = _userData?['phoneNumber'] ?? '';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: primaryColor),
            const SizedBox(width: 8),
            const Text('Chỉnh Sửa Hồ Sơ'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: 'Họ và Tên',
                  prefixIcon: Icon(Icons.person, color: primaryColor),
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Số Điện Thoại',
                  prefixIcon: Icon(Icons.phone, color: primaryColor),
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: primaryColor),
                  ),
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
            child: Text('Hủy', style: TextStyle(color: primaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
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
      appBar: AppBar(
        title: const Text('Hồ Sơ Cá Nhân'),

        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : _user == null
              ? const Center(
                  child: Text(
                    'Không có người dùng nào đăng nhập',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : _buildProfileView(),
    );
  }

  Widget _buildProfileView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Profile Avatar with Edit Button
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 80,
                  backgroundColor: primaryLight,
                  backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                      ? NetworkImage(_profileImageUrl!)
                      : null,
                  child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                      ? Text(
                          _userData?['fullName']?.substring(0, 1).toUpperCase() ?? 'A',
                          style: TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.bold,
                            color: primaryAccent,
                          ),
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Info Cards
          _buildInfoCard(
            icon: Icons.person,
            title: 'Họ và Tên',
            subtitle: _userData?['fullName'] ?? 'Chưa cập nhật',
          ),
          _buildInfoCard(
            icon: Icons.email,
            title: 'Email',
            subtitle: _userData?['email'] ?? 'Chưa cập nhật',
          ),
          _buildInfoCard(
            icon: Icons.phone,
            title: 'Số Điện Thoại',
            subtitle: _userData?['phoneNumber'] ?? 'Chưa cập nhật',
          ),
          _buildInfoCard(
            icon: Icons.badge,
            title: 'Vai trò',
            subtitle: UserRole.getDisplayName(_userData?['role']),
          ),
          if (_restaurantName != null && _restaurantName!.isNotEmpty)
            _buildInfoCard(
              icon: Icons.restaurant,
              title: 'Nhà hàng',
              subtitle: _restaurantName!,
            ),
          const SizedBox(height: 32),
          // Edit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showEditProfileDialog,
              icon: const Icon(Icons.edit),
              label: const Text('Chỉnh Sửa Hồ Sơ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: primaryLight,
          child: Icon(icon, color: primaryAccent),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
