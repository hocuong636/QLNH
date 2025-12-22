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
}

