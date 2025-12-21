import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:quanlynhahang/constants/user_roles.dart';

class RestaurantManagementPage extends StatefulWidget {
  const RestaurantManagementPage({super.key});

  @override
  State<RestaurantManagementPage> createState() => _RestaurantManagementPageState();
}

class _RestaurantManagementPageState extends State<RestaurantManagementPage> {
  // Sử dụng cùng database instance như AuthService
  FirebaseDatabase get _database {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
    );
  }
  
  DatabaseReference get _dbRef => _database.ref();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedOwnerId;
  String? _editingRestaurantId;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveRestaurant() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên nhà hàng'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final restaurantData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'ownerId': _selectedOwnerId?.isEmpty == true ? null : _selectedOwnerId,
        'status': 'active',
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (_editingRestaurantId != null) {
        // Cập nhật nhà hàng
        restaurantData['createdAt'] = null; // Giữ nguyên createdAt
        await _dbRef.child('restaurants/$_editingRestaurantId').update(restaurantData);
      } else {
        // Tạo mới nhà hàng
        restaurantData['createdAt'] = DateTime.now().toIso8601String();
        await _dbRef.child('restaurants').push().set(restaurantData);
      }

      // Đóng dialog và reset form
      Navigator.of(context).pop();
      _nameController.clear();
      _descriptionController.clear();
      _selectedOwnerId = null;
      _editingRestaurantId = null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingRestaurantId != null
                ? 'Cập nhật nhà hàng thành công!'
                : 'Tạo nhà hàng thành công!'),
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
  }

  void _showRestaurantDialog({Map<dynamic, dynamic>? restaurant, String? restaurantId}) {
    if (restaurant != null && restaurantId != null) {
      _editingRestaurantId = restaurantId;
      _nameController.text = restaurant['name'] ?? '';
      _descriptionController.text = restaurant['description'] ?? '';
      _selectedOwnerId = restaurant['ownerId'];
    } else {
      _editingRestaurantId = null;
      _nameController.clear();
      _descriptionController.clear();
      _selectedOwnerId = null;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(_editingRestaurantId != null ? 'Cập Nhật Nhà Hàng' : 'Tạo Nhà Hàng Mới'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên Nhà Hàng *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Mô Tả',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    _buildOwnerDropdown(setDialogState),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _nameController.clear();
                    _descriptionController.clear();
                    _selectedOwnerId = null;
                    _editingRestaurantId = null;
                  },
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: _saveRestaurant,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                  ),
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOwnerDropdown(StateSetter setDialogState) {
    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('users').onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        List<MapEntry<String, Map<dynamic, dynamic>>> ownersList = [];
        
        if (snapshot.hasData && snapshot.data!.snapshot.exists) {
          final data = snapshot.data!.snapshot.value;
          if (data != null && data is Map) {
            final dataMap = data as Map<dynamic, dynamic>;
            ownersList = dataMap.entries
                .where((entry) {
                  if (entry.value is! Map) return false;
                  final user = entry.value as Map<dynamic, dynamic>;
                  final role = user['role']?.toString();
                  final status = user['status']?.toString();
                  return role != null && 
                         (role == UserRole.owner || 
                          role.toUpperCase() == UserRole.owner.toUpperCase()) &&
                         status == 'active';
                })
                .map((entry) => MapEntry(
                      entry.key as String,
                      entry.value as Map<dynamic, dynamic>,
                    ))
                .toList();
          }
        }

        return DropdownButtonFormField<String>(
          value: _selectedOwnerId,
          decoration: const InputDecoration(
            labelText: 'Chọn Owner (tùy chọn)',
            border: OutlineInputBorder(),
            helperText: 'Chọn owner để gán cho nhà hàng',
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Không chọn Owner'),
            ),
            ...ownersList.map((entry) {
              final ownerId = entry.key;
              final owner = entry.value;
              final ownerName = owner['fullName'] ?? owner['email'] ?? ownerId;
              return DropdownMenuItem<String>(
                value: ownerId,
                child: Text(ownerName),
              );
            }),
          ],
          onChanged: (value) {
            setDialogState(() {
              _selectedOwnerId = value;
            });
          },
        );
      },
    );
  }

  Future<void> _toggleRestaurantStatus(String restaurantId, String currentStatus) async {
    final newStatus = currentStatus == 'active' ? 'inactive' : 'active';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(newStatus == 'active' ? 'Kích Hoạt Nhà Hàng' : 'Ngừng Hoạt Động'),
          content: Text(
            newStatus == 'active'
                ? 'Bạn có chắc chắn muốn kích hoạt nhà hàng này?'
                : 'Bạn có chắc chắn muốn ngừng hoạt động nhà hàng này?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _dbRef.child('restaurants/$restaurantId/status').set(newStatus);
                await _dbRef.child('restaurants/$restaurantId/updatedAt')
                    .set(DateTime.now().toIso8601String());
                Navigator.of(context).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        newStatus == 'active'
                            ? 'Đã kích hoạt nhà hàng'
                            : 'Đã ngừng hoạt động nhà hàng',
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

  Future<String?> _getOwnerName(String? ownerId) async {
    if (ownerId == null || ownerId.isEmpty) return null;
    try {
      final snapshot = await _dbRef.child('users/$ownerId/fullName').get();
      return snapshot.value as String?;
    } catch (e) {
      return null;
    }
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
                      'Quản Lý Nhà Hàng',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Quản lý thông tin các nhà hàng',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              FloatingActionButton(
                onPressed: () => _showRestaurantDialog(),
                backgroundColor: Colors.blue.shade700,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: _dbRef.child('restaurants').onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return const Center(
                  child: Text('Không có nhà hàng nào'),
                );
              }

              final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
              final restaurantsList = data.entries.toList();

              if (restaurantsList.isEmpty) {
                return const Center(
                  child: Text('Không có nhà hàng nào'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: restaurantsList.length,
                itemBuilder: (context, index) {
                  final restaurant = restaurantsList[index].value as Map<dynamic, dynamic>;
                  final restaurantId = restaurantsList[index].key as String;
                  final status = restaurant['status'] ?? 'active';
                  
                  return _buildRestaurantCard(restaurant, restaurantId, status);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantCard(
    Map<dynamic, dynamic> restaurant,
    String restaurantId,
    String status,
  ) {
    final isActive = status == 'active';
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.restaurant,
            color: Colors.green.shade700,
            size: 28,
          ),
        ),
        title: Text(
          restaurant['name'] ?? 'N/A',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (restaurant['description'] != null && restaurant['description'].toString().isNotEmpty)
              Text(
                restaurant['description'],
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isActive ? 'Hoạt động' : 'Ngừng hoạt động',
                    style: TextStyle(
                      color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
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
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showRestaurantDialog(
                restaurant: restaurant,
                restaurantId: restaurantId,
              ),
              tooltip: 'Chỉnh sửa',
            ),
            IconButton(
              icon: Icon(
                isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                color: isActive ? Colors.red.shade700 : Colors.green.shade700,
              ),
              onPressed: () => _toggleRestaurantStatus(restaurantId, status),
              tooltip: isActive ? 'Ngừng hoạt động' : 'Kích hoạt',
            ),
          ],
        ),
      ),
    );
  }
}

