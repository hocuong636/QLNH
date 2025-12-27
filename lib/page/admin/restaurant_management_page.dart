import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quanlynhahang/models/restaurant.dart';
import 'package:quanlynhahang/constants/user_roles.dart';

class RestaurantManagementPage extends StatefulWidget {
  const RestaurantManagementPage({super.key});

  @override
  State<RestaurantManagementPage> createState() =>
      _RestaurantManagementPageState();
}

class _RestaurantManagementPageState extends State<RestaurantManagementPage> {
  List<Restaurant> _restaurants = [];
  bool _isLoading = true;
  String _searchQuery = '';

  List<Map<String, dynamic>> _owners = [];
  String? _selectedOwnerId;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _openingHoursController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
    _loadOwners();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    _openingHoursController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurants() async {
    setState(() => _isLoading = true);

    try {
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL:
            'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

      final snapshot = await database.ref('restaurants').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final restaurants = <Restaurant>[];

        data.forEach((key, value) {
          if (value is Map) {
            try {
              final restaurant = Restaurant.fromJson({
                'id': key,
                ...Map<String, dynamic>.from(value),
              });
              restaurants.add(restaurant);
            } catch (e) {
              print('Error parsing restaurant $key: $e');
            }
          }
        });

        setState(() {
          _restaurants = restaurants;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading restaurants: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải danh sách nhà hàng: $e')),
        );
      }
    }
  }

  Future<void> _loadOwners() async {
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
            owners.add({
              'id': key,
              'email': value['email'] ?? '',
              'name': value['name'] ?? '',
            });
          }
        });

        setState(() {
          _owners = owners;
        });
        print('Loaded ${owners.length} owners: $owners');
      } else {
        print('No users snapshot exists');
      }
    } catch (e) {
      print('Error loading owners: $e');
    }
  }

  Future<void> _createRestaurant() async {
    if (_nameController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _selectedOwnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng điền đầy đủ tên, địa chỉ và chọn chủ sở hữu'),
        ),
      );
      return;
    }

    try {
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL:
            'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

      final newRestaurantRef = database.ref('restaurants').push();
      final restaurantId = newRestaurantRef.key!;

      final restaurant = Restaurant(
        id: restaurantId,
        ownerId: _selectedOwnerId!,
        name: _nameController.text,
        address: _addressController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        description: _descriptionController.text,
        openingHours: _openingHoursController.text,
        capacity: int.tryParse(_capacityController.text) ?? 0,
        isOpen: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await newRestaurantRef.set(restaurant.toJson());

      // Cập nhật restaurantID cho owner
      await database.ref('users/$_selectedOwnerId').update({
        'restaurantID': restaurantId,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Clear form
      _clearForm();

      // Reload restaurants
      await _loadRestaurants();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo nhà hàng thành công')),
        );
        Navigator.of(context).pop(); // Close dialog
      }
    } catch (e) {
      print('Error creating restaurant: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tạo nhà hàng: $e')));
      }
    }
  }

  Future<void> _toggleRestaurantStatus(
    String restaurantId,
    bool currentStatus,
  ) async {
    try {
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL:
            'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

      await database.ref('restaurants/$restaurantId').update({
        'isOpen': !currentStatus,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await _loadRestaurants();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentStatus ? 'Đã đóng cửa nhà hàng' : 'Đã mở cửa nhà hàng',
            ),
          ),
        );
      }
    } catch (e) {
      print('Error updating restaurant status: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi cập nhật trạng thái: $e')));
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _addressController.clear();
    _phoneController.clear();
    _emailController.clear();
    _descriptionController.clear();
    _openingHoursController.clear();
    _capacityController.clear();
    _selectedOwnerId = null;
  }

  void _showCreateRestaurantDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo nhà hàng mới'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedOwnerId,
                decoration: const InputDecoration(
                  labelText: 'Chủ sở hữu *',
                  hintText: 'Chọn chủ sở hữu',
                ),
                items: _owners.map((owner) {
                  print('Owner: ${owner['name']} (${owner['id']})');
                  final displayName = owner['name']?.isNotEmpty == true
                      ? owner['name']
                      : owner['email'] ?? owner['id'];
                  return DropdownMenuItem<String>(
                    value: owner['id'],
                    child: Text(displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedOwnerId = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng chọn chủ sở hữu';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên nhà hàng *',
                  hintText: 'Nhà hàng ABC',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ *',
                  hintText: '123 Đường ABC, Quận 1, TP.HCM',
                ),
                maxLines: 2,
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
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'contact@restaurant.com',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _capacityController,
                decoration: const InputDecoration(
                  labelText: 'Sức chứa',
                  hintText: '50',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _openingHoursController,
                decoration: const InputDecoration(
                  labelText: 'Giờ mở cửa',
                  hintText: '08:00 - 22:00',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  hintText: 'Mô tả về nhà hàng...',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _clearForm();
              Navigator.of(context).pop();
            },
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: _createRestaurant,
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  List<Restaurant> get _filteredRestaurants {
    if (_searchQuery.isEmpty) return _restaurants;
    return _restaurants
        .where(
          (restaurant) =>
              restaurant.name.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              restaurant.address.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ),
        )
        .toList();
  }

  Color _getStatusColor(bool isOpen) {
    return isOpen ? Colors.green : Colors.red;
  }

  String _getStatusText(bool isOpen) {
    return isOpen ? 'Đang mở cửa' : 'Đã đóng cửa';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Nhà hàng'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateRestaurantDialog,
            tooltip: 'Tạo nhà hàng mới',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRestaurants,
            tooltip: 'Làm mới',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm nhà hàng...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredRestaurants.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restaurant_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'Chưa có nhà hàng nào'
                        : 'Không tìm thấy nhà hàng',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  if (_searchQuery.isEmpty) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showCreateRestaurantDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Tạo nhà hàng đầu tiên'),
                    ),
                  ],
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredRestaurants.length,
              itemBuilder: (context, index) {
                final restaurant = _filteredRestaurants[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(
                        restaurant.isOpen,
                      ).withOpacity(0.1),
                      child: Icon(
                        Icons.restaurant,
                        color: _getStatusColor(restaurant.isOpen),
                      ),
                    ),
                    title: Text(
                      restaurant.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(restaurant.address),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  restaurant.isOpen,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getStatusText(restaurant.isOpen),
                                style: TextStyle(
                                  color: _getStatusColor(restaurant.isOpen),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Sức chứa: ${restaurant.capacity}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (restaurant.phone.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(restaurant.phone),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (restaurant.email.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(
                                    Icons.email,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(restaurant.email),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (restaurant.openingHours.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(restaurant.openingHours),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (restaurant.isOpen)
                                  TextButton.icon(
                                    onPressed: () => _toggleRestaurantStatus(
                                      restaurant.id,
                                      restaurant.isOpen,
                                    ),
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                    ),
                                    label: const Text(
                                      'Đóng cửa',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  )
                                else
                                  TextButton.icon(
                                    onPressed: () => _toggleRestaurantStatus(
                                      restaurant.id,
                                      restaurant.isOpen,
                                    ),
                                    icon: const Icon(
                                      Icons.play_arrow,
                                      color: Colors.green,
                                    ),
                                    label: const Text(
                                      'Mở cửa',
                                      style: TextStyle(color: Colors.green),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
