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
  String? _selectedRoleFilter;
  String? _selectedStatusFilter;

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

    // Filter by role
    if (_selectedRoleFilter != null && _selectedRoleFilter!.isNotEmpty) {
      filtered = filtered.where((user) => user.role == _selectedRoleFilter).toList();
    }

    // Filter by status
    if (_selectedStatusFilter != null && _selectedStatusFilter!.isNotEmpty) {
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.fullName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Email', user.email),
              _buildDetailRow('Số điện thoại', user.phoneNumber),
              _buildDetailRow('Vai trò', _getRoleDisplayName(user.role)),
              _buildDetailRow('Trạng thái', user.isActive ? 'Hoạt động' : 'Đã khóa'),
              if (user.restaurantID != null)
                _buildDetailRow('Nhà hàng ID', user.restaurantID!),
              _buildDetailRow('Ngày tạo', _formatDate(user.createdAt)),
              if (user.updatedAt != null)
                _buildDetailRow('Cập nhật lần cuối', _formatDate(user.updatedAt!)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
          if (user.role != UserRole.admin)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetPassword(user.email);
              },
              child: const Text('Reset mật khẩu'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      appBar: AppBar(
        title: const Text(
          'Quản lý Người dùng',
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Làm mới',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilters();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm theo tên, email, SĐT...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedRoleFilter,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Tất cả vai trò',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Tất cả vai trò', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: UserRole.admin, child: Text(_getRoleDisplayName(UserRole.admin), overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: UserRole.owner, child: Text(_getRoleDisplayName(UserRole.owner), overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: UserRole.kitchen, child: Text(_getRoleDisplayName(UserRole.kitchen), overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: UserRole.order, child: Text(_getRoleDisplayName(UserRole.order), overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedRoleFilter = value;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatusFilter,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Tất cả trạng thái',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Tất cả trạng thái', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'active', child: Text('Hoạt động', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'inactive', child: Text('Đã khóa', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatusFilter = value;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredUsers.isEmpty
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
                        _searchQuery.isEmpty
                            ? 'Chưa có người dùng nào'
                            : 'Không tìm thấy người dùng',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: _getRoleColor(user.role).withOpacity(0.1),
                          child: Icon(
                            Icons.person,
                            color: _getRoleColor(user.role),
                          ),
                        ),
                        title: Text(
                          user.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(user.email),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                // Chỉ hiển thị role badge cho admin
                                if (user.role == UserRole.admin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getRoleColor(user.role).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _getRoleDisplayName(user.role),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _getRoleColor(user.role),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                // Luôn hiển thị trạng thái tài khoản
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (user.isActive ? Colors.green : Colors.red).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    user.isActive ? 'Hoạt động' : 'Đã khóa',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: user.isActive ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.info_outline),
                              onPressed: () => _showUserDetails(user),
                              tooltip: 'Chi tiết',
                            ),
                            if (user.role != UserRole.admin)
                              IconButton(
                                icon: Icon(
                                  user.isActive ? Icons.block : Icons.check_circle,
                                  color: user.isActive ? Colors.red : Colors.green,
                                ),
                                onPressed: () => _toggleUserStatus(user),
                                tooltip: user.isActive ? 'Khóa tài khoản' : 'Mở khóa tài khoản',
                              ),
                          ],
                        ),
                        onTap: () => _showUserDetails(user),
                      ),
                    );
                  },
                ),
    );
  }
}

