import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/restaurant_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/models/restaurant.dart';

class OwnerRestaurantManagementPage extends StatefulWidget {
  const OwnerRestaurantManagementPage({super.key});

  @override
  State<OwnerRestaurantManagementPage> createState() =>
      _OwnerRestaurantManagementPageState();
}

class _OwnerRestaurantManagementPageState
    extends State<OwnerRestaurantManagementPage> {
  final RestaurantService _restaurantService = RestaurantService();
  final LocalStorageService _localStorageService = LocalStorageService();
  Restaurant? _restaurant;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRestaurant();
  }

  Future<void> _loadRestaurant() async {
    setState(() => _isLoading = true);
    try {
      String? ownerId = _localStorageService.getUserId();
      if (ownerId != null) {
        _restaurant = await _restaurantService.getRestaurantByOwnerId(ownerId);
      }
    } catch (e) {
      _showSnackBar('Lỗi khi tải thông tin nhà hàng: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showEditDialog() {
    if (_restaurant == null) return;

    final nameController = TextEditingController(text: _restaurant!.name);
    final addressController = TextEditingController(text: _restaurant!.address);
    final phoneController = TextEditingController(text: _restaurant!.phone);
    final emailController = TextEditingController(text: _restaurant!.email);
    final descriptionController = TextEditingController(
      text: _restaurant!.description,
    );
    final openingHoursController = TextEditingController(
      text: _restaurant!.openingHours,
    );
    final capacityController = TextEditingController(
      text: _restaurant!.capacity.toString(),
    );
    bool isOpen = _restaurant!.isOpen;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Chỉnh sửa thông tin nhà hàng'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Tên nhà hàng'),
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Địa chỉ'),
                  maxLines: 2,
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Mô tả'),
                  maxLines: 3,
                ),
                TextField(
                  controller: openingHoursController,
                  decoration: const InputDecoration(labelText: 'Giờ mở cửa'),
                ),
                TextField(
                  controller: capacityController,
                  decoration: const InputDecoration(
                    labelText: 'Sức chứa (số bàn)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                Row(
                  children: [
                    const Text('Đang mở cửa:'),
                    Switch(
                      value: isOpen,
                      onChanged: (value) => setState(() => isOpen = value),
                    ),
                  ],
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
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    addressController.text.isEmpty) {
                  _showSnackBar('Vui lòng nhập tên và địa chỉ nhà hàng');
                  return;
                }

                try {
                  Restaurant updatedRestaurant = Restaurant(
                    id: _restaurant!.id,
                    ownerId: _restaurant!.ownerId,
                    name: nameController.text,
                    address: addressController.text,
                    phone: phoneController.text,
                    email: emailController.text,
                    description: descriptionController.text,
                    openingHours: openingHoursController.text,
                    capacity: int.parse(capacityController.text),
                    isOpen: isOpen,
                    createdAt: _restaurant!.createdAt,
                    updatedAt: DateTime.now(),
                  );

                  await _restaurantService.updateRestaurant(updatedRestaurant);
                  _showSnackBar('Cập nhật thông tin thành công');
                  Navigator.of(context).pop();
                  _loadRestaurant();
                } catch (e) {
                  _showSnackBar('Lỗi khi cập nhật: $e');
                }
              },
              child: const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý nhà hàng'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditDialog,
            tooltip: 'Chỉnh sửa',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _restaurant == null
          ? _buildEmptyState()
          : _buildRestaurantInfo(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Chưa có thông tin nhà hàng',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Vui lòng liên hệ quản trị viên',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.restaurant,
                        color: Colors.blue.shade700,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _restaurant!.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _restaurant!.isOpen
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _restaurant!.isOpen
                                  ? 'Đang mở cửa'
                                  : 'Đã đóng cửa',
                              style: TextStyle(
                                color: _restaurant!.isOpen
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
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

          const SizedBox(height: 24),

          // Information Cards
          _buildInfoCard('Thông tin liên hệ', [
            _buildInfoRow(Icons.phone, 'Điện thoại', _restaurant!.phone),
            _buildInfoRow(Icons.email, 'Email', _restaurant!.email),
          ]),

          const SizedBox(height: 16),

          _buildInfoCard('Địa chỉ & Giờ mở cửa', [
            _buildInfoRow(Icons.location_on, 'Địa chỉ', _restaurant!.address),
            _buildInfoRow(
              Icons.access_time,
              'Giờ mở cửa',
              _restaurant!.openingHours,
            ),
          ]),

          const SizedBox(height: 16),

          _buildInfoCard('Thông tin khác', [
            _buildInfoRow(
              Icons.people,
              'Sức chứa',
              '${_restaurant!.capacity} bàn',
            ),
            _buildInfoRow(
              Icons.calendar_today,
              'Ngày tạo',
              '${_restaurant!.createdAt.day}/${_restaurant!.createdAt.month}/${_restaurant!.createdAt.year}',
            ),
          ]),

          const SizedBox(height: 16),

          if (_restaurant!.description.isNotEmpty)
            _buildInfoCard('Mô tả', [
              _buildInfoRow(
                Icons.description,
                'Mô tả',
                _restaurant!.description,
              ),
            ]),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.grey.shade700, size: 20),
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
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
