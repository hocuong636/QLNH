import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quanlynhahang/constants/user_roles.dart';
import 'package:quanlynhahang/models/user.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final database = FirebaseDatabase.instance;
      final snapshot = await database.ref('users').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final users = <UserModel>[];

        data.forEach((key, value) {
          if (value is Map) {
            try {
              final user = UserModel.fromJson({
                'uid': key,
                ...Map<String, dynamic>.from(value),
              });
              users.add(user);
            } catch (e) {
              print('Error parsing user $key: $e');
            }
          }
        });

        setState(() {
          _users = users;
          _applyFilters();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading users: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải danh sách người dùng: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    List<UserModel> filtered = List.from(_users);

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final query = _searchQuery.toLowerCase();
        return user.email.toLowerCase().contains(query) ||
            user.fullName.toLowerCase().contains(query) ||
            user.phoneNumber.contains(query);
      }).toList();
    }

    // Filter by status
    if (_selectedStatusFilter != 'all') {
      if (_selectedStatusFilter == 'active') {
        filtered = filtered.where((user) => user.isActive).toList();
      } else if (_selectedStatusFilter == 'inactive') {
        filtered = filtered.where((user) => !user.isActive).toList();
      }
    }

    setState(() {
      _filteredUsers = filtered;
    });
  }

  Future<void> _toggleUserStatus(UserModel user) async {
    try {
      final database = FirebaseDatabase.instance;
      await database.ref('users/${user.uid}').update({
        'isActive': !user.isActive,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await _loadUsers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              user.isActive
                  ? 'Đã khóa tài khoản ${user.fullName}'
                  : 'Đã mở khóa tài khoản ${user.fullName}',
            ),
          ),
        );
      }
    } catch (e) {
      print('Error toggling user status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật trạng thái: $e')),
        );
      }
    }
  }

  Future<void> _resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gửi email reset mật khẩu đến $email')),
        );
      }
    } catch (e) {
      print('Error sending password reset: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi email reset: $e')),
        );
      }
    }
  }

  void _showUserDetails(UserModel user) {
    const Color primaryGreen = Color(0xFF4CAF50);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: primaryGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                user.fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(Icons.email_rounded, 'Email', user.email),
              _buildDetailRow(Icons.phone_rounded, 'Số điện thoại', user.phoneNumber),
              if (user.role == UserRole.admin)
                _buildDetailRow(Icons.admin_panel_settings_rounded, 'Vai trò', _getRoleDisplayName(user.role)),
              _buildDetailRow(
                user.isActive ? Icons.check_circle_rounded : Icons.block_rounded,
                'Trạng thái',
                user.isActive ? 'Hoạt động' : 'Đã khóa',
                color: user.isActive ? primaryGreen : Colors.red,
              ),
              if (user.restaurantID != null)
                _buildDetailRow(Icons.restaurant_rounded, 'Nhà hàng ID', user.restaurantID!),
              _buildDetailRow(Icons.calendar_today_rounded, 'Ngày tạo', _formatDate(user.createdAt)),
              if (user.updatedAt != null)
                _buildDetailRow(Icons.update_rounded, 'Cập nhật lần cuối', _formatDate(user.updatedAt!)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
          if (user.role != UserRole.admin)
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _resetPassword(user.email);
              },
              icon: const Icon(Icons.lock_reset_rounded, size: 18),
              label: const Text('Reset mật khẩu'),
              style: FilledButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? color}) {
    const Color primaryGreen = Color(0xFF4CAF50);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (color ?? primaryGreen).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: color ?? primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case UserRole.admin:
        return 'Quản trị viên';
      case UserRole.owner:
        return 'Chủ nhà hàng';
      case UserRole.order:
        return 'Nhân viên';
      case UserRole.kitchen:
        return 'Bếp';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.owner:
        return Colors.blue;
      case UserRole.order:
        return Colors.green;
      case UserRole.kitchen:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedStatusFilter == value;
    const Color primaryGreen = Color(0xFF4CAF50);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedStatusFilter = value;
              _applyFilters();
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? primaryGreen.withOpacity(0.3) : Colors.grey.shade300,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: primaryGreen.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
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
                  size: 16,
                  color: isSelected ? primaryGreen : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? primaryGreen : Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF4CAF50);
    return Column(
        children: [
          // Header section với title lớn
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quản lý Người dùng',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 16),
                // Search và filter section
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilters();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm theo tên, email, SĐT...',
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade600),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: primaryGreen, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildFilterChip('all', 'Tất cả', Icons.filter_list_rounded),
                    const SizedBox(width: 8),
                    _buildFilterChip('active', 'Hoạt động', Icons.check_circle_rounded),
                    const SizedBox(width: 8),
                    _buildFilterChip('inactive', 'Đã khóa', Icons.block_rounded),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: _loadUsers,
                        tooltip: 'Làm mới',
                        color: primaryGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Body content
          Expanded(
            child: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
              ),
            )
          : _filteredUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.people_outline_rounded,
                          size: 64,
                          color: primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Chưa có người dùng nào'
                            : 'Không tìm thấy người dùng',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Hãy thêm người dùng mới vào hệ thống'
                            : 'Thử tìm kiếm với từ khóa khác',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showUserDetails(user),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(user.role).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: _getRoleColor(user.role),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.fullName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.email,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          // Chỉ hiển thị role badge cho admin
                                          if (user.role == UserRole.admin)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: _getRoleColor(user.role).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.admin_panel_settings_rounded,
                                                    size: 14,
                                                    color: _getRoleColor(user.role),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _getRoleDisplayName(user.role),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: _getRoleColor(user.role),
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          // Luôn hiển thị trạng thái tài khoản
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: (user.isActive ? primaryGreen : Colors.red).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: user.isActive ? primaryGreen : Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  user.isActive ? 'Hoạt động' : 'Đã khóa',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: user.isActive ? primaryGreen : Colors.red,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.info_outline_rounded),
                                      onPressed: () => _showUserDetails(user),
                                      tooltip: 'Chi tiết',
                                      color: Colors.grey.shade600,
                                    ),
                                    if (user.role != UserRole.admin)
                                      IconButton(
                                        icon: Icon(
                                          user.isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                                          color: user.isActive ? Colors.red : primaryGreen,
                                        ),
                                        onPressed: () => _toggleUserStatus(user),
                                        tooltip: user.isActive ? 'Khóa tài khoản' : 'Mở khóa tài khoản',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
    );
  }
}

