import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:quanlynhahang/constants/user_roles.dart';
import 'package:quanlynhahang/constants/restaurant_types.dart';
import 'package:quanlynhahang/constants/subscription_plans.dart';
import 'package:quanlynhahang/constants/restaurant_status.dart';

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
  final TextEditingController _lockReasonController = TextEditingController();
  String? _selectedOwnerId;
  String? _selectedRestaurantType;
  String? _selectedSubscriptionPlan;
  String? _selectedStatus;
  int? _trialDays;
  String? _editingRestaurantId;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _lockReasonController.dispose();
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
      final now = DateTime.now();
      final trialEndDate = _trialDays != null && _trialDays! > 0
          ? now.add(Duration(days: _trialDays!)).toIso8601String()
          : null;

      final restaurantData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'ownerId': _selectedOwnerId?.isEmpty == true ? null : _selectedOwnerId,
        'restaurantType': _selectedRestaurantType,
        'subscriptionPlan': _selectedSubscriptionPlan ?? SubscriptionPlan.free,
        'status': _selectedStatus ?? RestaurantStatus.active,
        'trialDays': _trialDays,
        'trialEndDate': trialEndDate,
        'updatedAt': now.toIso8601String(),
      };

      if (_editingRestaurantId != null) {
        // Cập nhật nhà hàng - giữ nguyên createdAt và lockReason nếu không thay đổi
        final existingSnapshot = await _dbRef.child('restaurants/$_editingRestaurantId').get();
        if (existingSnapshot.exists) {
          final existing = existingSnapshot.value as Map<dynamic, dynamic>;
          restaurantData['createdAt'] = existing['createdAt'];
          if (_lockReasonController.text.isNotEmpty) {
            restaurantData['lockReason'] = _lockReasonController.text.trim();
          } else if (existing['lockReason'] != null && _selectedStatus == RestaurantStatus.locked) {
            restaurantData['lockReason'] = existing['lockReason'];
          }
        }
        await _dbRef.child('restaurants/$_editingRestaurantId').update(restaurantData);
      } else {
        // Tạo mới nhà hàng
        restaurantData['createdAt'] = now.toIso8601String();
        if (_lockReasonController.text.isNotEmpty) {
          restaurantData['lockReason'] = _lockReasonController.text.trim();
        }
        await _dbRef.child('restaurants').push().set(restaurantData);
      }

      // Đóng dialog và reset form
      Navigator.of(context).pop();
      _nameController.clear();
      _descriptionController.clear();
      _lockReasonController.clear();
      _selectedOwnerId = null;
      _selectedRestaurantType = null;
      _selectedSubscriptionPlan = null;
      _selectedStatus = null;
      _trialDays = null;
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
      _selectedRestaurantType = restaurant['restaurantType'];
      _selectedSubscriptionPlan = restaurant['subscriptionPlan'] ?? SubscriptionPlan.free;
      _selectedStatus = restaurant['status'] ?? RestaurantStatus.active;
      _trialDays = restaurant['trialDays'];
      _lockReasonController.text = restaurant['lockReason'] ?? '';
    } else {
      _editingRestaurantId = null;
      _nameController.clear();
      _descriptionController.clear();
      _lockReasonController.clear();
      _selectedOwnerId = null;
      _selectedRestaurantType = null;
      _selectedSubscriptionPlan = SubscriptionPlan.free;
      _selectedStatus = RestaurantStatus.active;
      _trialDays = null;
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
                    const SizedBox(height: 12),
                    _buildRestaurantTypeDropdown(setDialogState),
                    const SizedBox(height: 12),
                    _buildSubscriptionPlanDropdown(setDialogState),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final trialController = TextEditingController(
                          text: _trialDays?.toString() ?? '',
                        );
                        return TextField(
                          controller: trialController,
                          decoration: const InputDecoration(
                            labelText: 'Thời gian dùng thử (ngày)',
                            border: OutlineInputBorder(),
                            helperText: 'Nhập số ngày dùng thử (0 = không có trial)',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setDialogState(() {
                              _trialDays = value.isEmpty ? null : int.tryParse(value);
                            });
                          },
                        );
                      },
                    ),
                    if (_editingRestaurantId != null) ...[
                      const SizedBox(height: 12),
                      _buildStatusDropdown(setDialogState),
                      if (_selectedStatus == RestaurantStatus.locked || 
                          _selectedStatus == RestaurantStatus.suspended) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _lockReasonController,
                          decoration: const InputDecoration(
                            labelText: 'Lý do khóa/tạm ngưng',
                            border: OutlineInputBorder(),
                            helperText: 'Nhập lý do khóa hoặc tạm ngưng nhà hàng',
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ],
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

  Widget _buildRestaurantTypeDropdown(StateSetter setDialogState) {
    return DropdownButtonFormField<String>(
      value: _selectedRestaurantType,
      decoration: const InputDecoration(
        labelText: 'Loại hình nhà hàng',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Chọn loại hình'),
        ),
        ...RestaurantType.allTypes.map((type) {
          return DropdownMenuItem<String>(
            value: type,
            child: Text(RestaurantType.getDisplayName(type)),
          );
        }),
      ],
      onChanged: (value) {
        setDialogState(() {
          _selectedRestaurantType = value;
        });
      },
    );
  }

  Widget _buildSubscriptionPlanDropdown(StateSetter setDialogState) {
    return DropdownButtonFormField<String>(
      value: _selectedSubscriptionPlan ?? SubscriptionPlan.free,
      decoration: const InputDecoration(
        labelText: 'Gói dịch vụ',
        border: OutlineInputBorder(),
      ),
      items: SubscriptionPlan.allPlans.map((plan) {
        return DropdownMenuItem<String>(
          value: plan,
          child: Text(SubscriptionPlan.getDisplayName(plan)),
        );
      }).toList(),
      onChanged: (value) {
        setDialogState(() {
          _selectedSubscriptionPlan = value;
        });
      },
    );
  }

  Widget _buildStatusDropdown(StateSetter setDialogState) {
    return DropdownButtonFormField<String>(
      value: _selectedStatus ?? RestaurantStatus.active,
      decoration: const InputDecoration(
        labelText: 'Trạng thái',
        border: OutlineInputBorder(),
      ),
      items: RestaurantStatus.allStatuses.map((status) {
        final color = RestaurantStatus.getStatusColor(status);
        return DropdownMenuItem<String>(
          value: status,
          child: Row(
            children: [
              Icon(
                RestaurantStatus.getStatusIcon(status),
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(RestaurantStatus.getDisplayName(status)),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        setDialogState(() {
          _selectedStatus = value;
        });
      },
    );
  }

  Future<void> _showStatusChangeDialog(String restaurantId, String currentStatus) async {
    final TextEditingController reasonController = TextEditingController();
    String? newStatus;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Thay Đổi Trạng Thái Nhà Hàng'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: newStatus ?? currentStatus,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái mới',
                        border: OutlineInputBorder(),
                      ),
                      items: RestaurantStatus.allStatuses.map((status) {
                        final color = RestaurantStatus.getStatusColor(status);
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Row(
                            children: [
                              Icon(
                                RestaurantStatus.getStatusIcon(status),
                                color: color,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(RestaurantStatus.getDisplayName(status)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          newStatus = value;
                        });
                      },
                    ),
                    if (newStatus == RestaurantStatus.locked || 
                        newStatus == RestaurantStatus.suspended) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonController,
                        decoration: const InputDecoration(
                          labelText: 'Lý do *',
                          border: OutlineInputBorder(),
                          helperText: 'Nhập lý do khóa hoặc tạm ngưng',
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    reasonController.dispose();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (newStatus == null) {
                      Navigator.of(context).pop();
                      reasonController.dispose();
                      return;
                    }
                    
                    if ((newStatus == RestaurantStatus.locked || 
                         newStatus == RestaurantStatus.suspended) &&
                        reasonController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng nhập lý do'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    await _dbRef.child('restaurants/$restaurantId/status').set(newStatus);
                    if (reasonController.text.trim().isNotEmpty) {
                      await _dbRef.child('restaurants/$restaurantId/lockReason')
                          .set(reasonController.text.trim());
                    }
                    await _dbRef.child('restaurants/$restaurantId/updatedAt')
                        .set(DateTime.now().toIso8601String());
                    
                    reasonController.dispose();
                    Navigator.of(context).pop();
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã cập nhật trạng thái thành ${RestaurantStatus.getDisplayName(newStatus)}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                  ),
                  child: const Text('Xác Nhận'),
                ),
              ],
            );
          },
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
    final statusColor = RestaurantStatus.getStatusColor(status);
    final restaurantType = restaurant['restaurantType'];
    final subscriptionPlan = restaurant['subscriptionPlan'] ?? SubscriptionPlan.free;
    
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
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            RestaurantStatus.getStatusIcon(status),
            color: statusColor,
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
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        RestaurantStatus.getStatusIcon(status),
                        color: statusColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        RestaurantStatus.getDisplayName(status),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (restaurantType != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      RestaurantType.getDisplayName(restaurantType),
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    SubscriptionPlan.getDisplayName(subscriptionPlan),
                    style: TextStyle(
                      color: Colors.purple.shade700,
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
              icon: const Icon(Icons.people, color: Colors.green),
              onPressed: () => _showManageUsersDialog(restaurantId, restaurant['name'] ?? 'Nhà hàng'),
              tooltip: 'Quản lý nhân viên',
            ),
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
                RestaurantStatus.getStatusIcon(status),
                color: RestaurantStatus.getStatusColor(status),
              ),
              onPressed: () => _showStatusChangeDialog(restaurantId, status),
              tooltip: 'Thay đổi trạng thái',
            ),
          ],
        ),
      ),
    );
  }

  // Quản lý user cho nhà hàng
  Future<void> _showManageUsersDialog(String restaurantId, String restaurantName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(dialogContext).size.width * 0.8,
            height: MediaQuery.of(dialogContext).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quản Lý Nhân Viên',
                            style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            restaurantName,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _showAddUserDialog(dialogContext, restaurantId),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Thêm Nhân Viên'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildUsersList(dialogContext, restaurantId),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersList(BuildContext dialogContext, String restaurantId) {
    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('users').onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.snapshot.exists) {
          return const Center(
            child: Text('Không có nhân viên nào'),
          );
        }

        final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        final users = data.entries
            .where((entry) {
              final user = entry.value as Map<dynamic, dynamic>;
              return user['resID'] == restaurantId;
            })
            .toList();

        if (users.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Chưa có nhân viên nào',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userId = users[index].key as String;
            final user = users[index].value as Map<dynamic, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    (user['fullName'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  user['fullName'] ?? 'Không có tên',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['email'] ?? ''),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            UserRole.getDisplayName(user['role']),
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (user['phoneNumber'] != null && user['phoneNumber'].toString().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            user['phoneNumber'],
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  onPressed: () => _removeUserFromRestaurant(dialogContext, userId, user['fullName'] ?? 'user'),
                  tooltip: 'Xóa khỏi nhà hàng',
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddUserDialog(BuildContext parentContext, String restaurantId) async {
    final TextEditingController emailController = TextEditingController();
    
    return showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Thêm Nhân Viên Vào Nhà Hàng'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Nhân Viên *',
                  border: OutlineInputBorder(),
                  helperText: 'Nhập email của nhân viên cần thêm',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nhân viên phải đã có tài khoản trong hệ thống',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập email'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                Navigator.of(dialogContext).pop();
                await _addUserToRestaurant(restaurantId, email);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      emailController.dispose();
    });
  }

  Future<void> _addUserToRestaurant(String restaurantId, String email) async {
    try {
      // Tìm user theo email
      final usersSnapshot = await _dbRef.child('users').get();
      
      if (!usersSnapshot.exists) {
        throw Exception('Không tìm thấy user nào trong hệ thống');
      }
      
      final usersData = usersSnapshot.value as Map<dynamic, dynamic>;
      String? userId;
      Map<dynamic, dynamic>? userData;
      
      for (var entry in usersData.entries) {
        final user = entry.value as Map<dynamic, dynamic>;
        if (user['email']?.toString().toLowerCase() == email.toLowerCase()) {
          userId = entry.key as String;
          userData = user;
          break;
        }
      }
      
      if (userId == null || userData == null) {
        throw Exception('Không tìm thấy user với email: $email');
      }
      
      // Kiểm tra xem user đã thuộc nhà hàng khác chưa
      if (userData['resID'] != null && userData['resID'] != restaurantId) {
        throw Exception('User này đã thuộc nhà hàng khác');
      }
      
      if (userData['resID'] == restaurantId) {
        throw Exception('User này đã thuộc nhà hàng này rồi');
      }
      
      // Cập nhật resID cho user
      await _dbRef.child('users/$userId/resID').set(restaurantId);
      await _dbRef.child('users/$userId/updatedAt').set(DateTime.now().toIso8601String());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm ${userData['fullName'] ?? email} vào nhà hàng'),
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

  Future<void> _removeUserFromRestaurant(BuildContext parentContext, String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: parentContext,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác Nhận'),
          content: Text('Bạn có chắc muốn xóa $userName khỏi nhà hàng này?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
    
    if (confirm != true) return;
    
    try {
      // Set resID về null
      await _dbRef.child('users/$userId/resID').set(null);
      await _dbRef.child('users/$userId/updatedAt').set(DateTime.now().toIso8601String());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa $userName khỏi nhà hàng'),
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
}
