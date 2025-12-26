import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:quanlynhahang/constants/user_roles.dart';

class OwnerManagementPage extends StatefulWidget {
  const OwnerManagementPage({super.key});

  @override
  State<OwnerManagementPage> createState() => _OwnerManagementPageState();
}

class _OwnerManagementPageState extends State<OwnerManagementPage> {
  // Sử dụng cùng database instance như AuthService
  FirebaseDatabase get _database {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
    );
  }
  
  DatabaseReference get _dbRef => _database.ref();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _createOwner() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _fullNameController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng điền đầy đủ thông tin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      print('Starting owner creation process...');
      print('Email: ${_emailController.text.trim()}');
      print('FullName: ${_fullNameController.text.trim()}');
      
      // Tạo user trên Firebase Auth
      UserCredential userCredential;
      try {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        print('Firebase Auth user created: ${userCredential.user?.uid}');
      } catch (authError) {
        print('Firebase Auth error: $authError');
        rethrow;
      }

      // Lưu thông tin vào Realtime Database
      final ownerData = {
        'uid': userCredential.user!.uid,
        'email': _emailController.text.trim(),
        'fullName': _fullNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'role': UserRole.owner, // 'OWNER'
        'resID': null, // Owner có thể quản lý nhiều nhà hàng nên resID có thể null
        'status': 'active',
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      print('Creating owner in database with data: $ownerData');
      print('Database path: users/${userCredential.user!.uid}');
      
      try {
        await _dbRef.child('users/${userCredential.user!.uid}').set(ownerData);
        print('Owner data saved successfully to database');
        
        // Verify the data was saved
        final verifySnapshot = await _dbRef.child('users/${userCredential.user!.uid}').get();
        if (verifySnapshot.exists) {
          print('Verified: Owner data exists in database');
          print('Saved data: ${verifySnapshot.value}');
        } else {
          print('WARNING: Owner data was not found after saving!');
        }
      } catch (dbError) {
        print('Database error: $dbError');
        // Nếu lưu database thất bại nhưng Auth đã tạo, vẫn cần xử lý
        rethrow;
      }

      // Đóng dialog và reset form
      Navigator.of(context).pop();
      _emailController.clear();
      _passwordController.clear();
      _fullNameController.clear();
      _phoneController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tạo tài khoản Owner thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      String errorMessage = 'Lỗi tạo tài khoản: ';
      if (e.code == 'email-already-in-use') {
        errorMessage += 'Email này đã được sử dụng';
      } else if (e.code == 'weak-password') {
        errorMessage += 'Mật khẩu quá yếu';
      } else if (e.code == 'invalid-email') {
        errorMessage += 'Email không hợp lệ';
      } else {
        errorMessage += e.message ?? e.code;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('General error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateOwnerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Tạo Tài Khoản Owner'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và Tên',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Số Điện Thoại',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Mật Khẩu',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
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
              onPressed: _createOwner,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
              ),
              child: const Text('Tạo'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetOwnerPassword(String userId, String email) async {
    final TextEditingController newPasswordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Mật Khẩu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reset mật khẩu cho: $email'),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu mới',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                newPasswordController.dispose();
                Navigator.of(context).pop();
              },
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newPasswordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập mật khẩu mới'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  // Gửi email reset password (Firebase Admin SDK không có trong Flutter)
                  // Thay vào đó, lưu mật khẩu tạm thời vào database để Owner có thể đăng nhập và đổi
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: email,
                  );
                  
                  // Lưu lịch sử reset password
                  await _dbRef.child('users/$userId/passwordResetHistory').push().set({
                    'resetAt': DateTime.now().toIso8601String(),
                    'resetBy': 'admin',
                    'method': 'email_reset',
                  });

                  newPasswordController.dispose();
                  Navigator.of(context).pop();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã gửi email reset mật khẩu đến Owner!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Lỗi: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  void _showLoginHistory(String userId, Map<dynamic, dynamic> owner) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Lịch Sử Đăng Nhập'),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<DatabaseEvent>(
              stream: _dbRef.child('users/$userId/loginHistory').onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || 
                    !snapshot.data!.snapshot.exists ||
                    snapshot.data!.snapshot.value == null) {
                  return const Text('Chưa có lịch sử đăng nhập');
                }

                final data = snapshot.data!.snapshot.value;
                if (data is! Map) {
                  return const Text('Không có dữ liệu');
                }

                final loginHistory = data as Map<dynamic, dynamic>;
                final historyList = loginHistory.entries.toList()
                  ..sort((a, b) {
                    final aTime = a.value['loginAt']?.toString() ?? '';
                    final bTime = b.value['loginAt']?.toString() ?? '';
                    return bTime.compareTo(aTime);
                  });

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: historyList.length > 10 ? 10 : historyList.length,
                  itemBuilder: (context, index) {
                    final entry = historyList[index];
                    final loginData = entry.value as Map<dynamic, dynamic>;
                    final loginAt = loginData['loginAt']?.toString() ?? 'N/A';
                    
                    return ListTile(
                      leading: const Icon(Icons.login, size: 20),
                      title: Text('Đăng nhập'),
                      subtitle: Text(loginAt.length > 19 ? loginAt.substring(0, 19) : loginAt),
                      dense: true,
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleOwnerStatus(String userId, String currentStatus) async {
    final newStatus = currentStatus == 'active' ? 'inactive' : 'active';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(newStatus == 'active' ? 'Mở Khóa Owner' : 'Khóa Owner'),
          content: Text(
            newStatus == 'active'
                ? 'Bạn có chắc chắn muốn mở khóa tài khoản này?'
                : 'Bạn có chắc chắn muốn khóa tài khoản này?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _dbRef.child('users/$userId/status').set(newStatus);
                Navigator.of(context).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        newStatus == 'active'
                            ? 'Đã mở khóa tài khoản'
                            : 'Đã khóa tài khoản',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: newStatus == 'active' ? Colors.green : Colors.red,
              ),
              child: const Text('Xác Nhận'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quản Lý Owner',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Quản lý tài khoản chủ nhà hàng',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              FloatingActionButton(
                onPressed: _showCreateOwnerDialog,
                backgroundColor: Colors.blue.shade700,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: _dbRef.child('users').onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return const Center(
                  child: Text('Không có Owner nào'),
                );
              }

              final data = snapshot.data!.snapshot.value;
              
              if (data == null || data is! Map) {
                return const Center(
                  child: Text('Không có Owner nào'),
                );
              }
              
              final dataMap = data as Map<dynamic, dynamic>;
              
              // Debug: In ra tất cả users để kiểm tra
              print('Total users in database: ${dataMap.length}');
              dataMap.forEach((key, value) {
                if (value is Map) {
                  print('User $key: role = ${value['role']}, name = ${value['fullName']}');
                }
              });
              
              final ownersList = dataMap.entries
                  .where((entry) {
                    if (entry.value is! Map) return false;
                    final user = entry.value as Map<dynamic, dynamic>;
                    final role = user['role']?.toString();
                    // So sánh không phân biệt hoa thường để đảm bảo tương thích
                    final isOwner = role != null && 
                           (role == UserRole.owner || 
                            role.toUpperCase() == UserRole.owner.toUpperCase());
                    if (isOwner) {
                      print('Found owner: ${user['fullName']} with role: $role');
                    }
                    return isOwner;
                  })
                  .toList();
              
              print('Total owners found: ${ownersList.length}');

              if (ownersList.isEmpty) {
                return const Center(
                  child: Text('Không có Owner nào'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: ownersList.length,
                itemBuilder: (context, index) {
                  final owner = ownersList[index].value as Map<dynamic, dynamic>;
                  final ownerId = ownersList[index].key as String;
                  final status = owner['status'] ?? 'active';
                  
                  return _buildOwnerCard(owner, ownerId, status);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOwnerCard(Map<dynamic, dynamic> owner, String ownerId, String status) {
    final isActive = status == 'active';
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(
            (owner['fullName'] ?? 'O')[0].toUpperCase(),
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          owner['fullName'] ?? 'N/A',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              owner['email'] ?? 'N/A',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isActive ? 'Hoạt động' : 'Đã khóa',
                style: TextStyle(
                  color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.lock_reset, size: 20),
                  SizedBox(width: 8),
                  Text('Reset Mật Khẩu'),
                ],
              ),
              onTap: () {
                Future.delayed(const Duration(milliseconds: 100), () {
                  _resetOwnerPassword(ownerId, owner['email']);
                });
              },
            ),
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.history, size: 20),
                  SizedBox(width: 8),
                  Text('Lịch Sử Đăng Nhập'),
                ],
              ),
              onTap: () {
                Future.delayed(const Duration(milliseconds: 100), () {
                  _showLoginHistory(ownerId, owner);
                });
              },
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(
                    isActive ? Icons.lock_outline : Icons.lock_open,
                    size: 20,
                    color: isActive ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isActive ? 'Khóa Tài Khoản' : 'Mở Khóa Tài Khoản',
                    style: TextStyle(
                      color: isActive ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              onTap: () {
                Future.delayed(const Duration(milliseconds: 100), () {
                  _toggleOwnerStatus(ownerId, status);
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

