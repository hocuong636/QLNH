import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/menu_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/models/menu_item.dart';

class MenuManagementPage extends StatefulWidget {
  const MenuManagementPage({super.key});

  @override
  State<MenuManagementPage> createState() => _MenuManagementPageState();
}

class _MenuManagementPageState extends State<MenuManagementPage> {
  final MenuService _menuService = MenuService();
  final LocalStorageService _localStorageService = LocalStorageService();
  List<MenuItem> _menuItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
  }

  Future<void> _loadMenuItems() async {
    setState(() => _isLoading = true);
    try {
      String? ownerId = _localStorageService.getUserId();
      if (ownerId != null) {
        String? restaurantId = await _menuService.getRestaurantIdByOwnerId(
          ownerId,
        );
        if (restaurantId != null) {
          _menuItems = await _menuService.getMenuItems(restaurantId);
        }
      }
    } catch (e) {
      _showSnackBar('Lỗi khi tải danh sách món ăn: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAddEditDialog([MenuItem? item]) {
    final nameController = TextEditingController(text: item?.name ?? '');
    final descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    final priceController = TextEditingController(
      text: item?.price.toString() ?? '',
    );
    final categoryController = TextEditingController(
      text: item?.category ?? '',
    );
    final imageUrlController = TextEditingController(
      text: item?.imageUrl ?? '',
    );
    bool isAvailable = item?.isAvailable ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(item == null ? 'Thêm món ăn' : 'Sửa món ăn'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Tên món ăn'),
                ),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Mô tả'),
                  maxLines: 3,
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Giá (VND)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Danh mục'),
                ),
                TextField(
                  controller: imageUrlController,
                  decoration: const InputDecoration(labelText: 'URL hình ảnh'),
                ),
                Row(
                  children: [
                    const Text('Có sẵn:'),
                    Switch(
                      value: isAvailable,
                      onChanged: (value) => setState(() => isAvailable = value),
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
                    priceController.text.isEmpty) {
                  _showSnackBar('Vui lòng nhập tên và giá');
                  return;
                }

                try {
                  String? ownerId = _localStorageService.getUserId();
                  if (ownerId != null) {
                    String? restaurantId = await _menuService
                        .getRestaurantIdByOwnerId(ownerId);
                    if (restaurantId != null) {
                      MenuItem newItem = MenuItem(
                        id: item?.id ?? '',
                        restaurantId: restaurantId,
                        name: nameController.text,
                        description: descriptionController.text,
                        price: double.parse(priceController.text),
                        category: categoryController.text,
                        imageUrl: imageUrlController.text,
                        isAvailable: isAvailable,
                        createdAt: item?.createdAt ?? DateTime.now(),
                        updatedAt: DateTime.now(),
                      );

                      if (item == null) {
                        await _menuService.createMenuItem(newItem);
                        _showSnackBar('Thêm món ăn thành công');
                      } else {
                        await _menuService.updateMenuItem(newItem);
                        _showSnackBar('Cập nhật món ăn thành công');
                      }

                      Navigator.of(context).pop();
                      _loadMenuItems();
                    }
                  }
                } catch (e) {
                  _showSnackBar('Lỗi: $e');
                }
              },
              child: Text(item == null ? 'Thêm' : 'Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(MenuItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa món ăn'),
        content: Text('Bạn có chắc chắn muốn xóa "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _menuService.deleteMenuItem(item.id);
                _showSnackBar('Xóa món ăn thành công');
                Navigator.of(context).pop();
                _loadMenuItems();
              } catch (e) {
                _showSnackBar('Lỗi khi xóa: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý thực đơn'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _menuItems.isEmpty
          ? _buildEmptyState()
          : _buildMenuList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Chưa có món ăn nào',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn + để thêm món ăn đầu tiên',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _menuItems.length,
      itemBuilder: (context, index) {
        final item = _menuItems[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade200,
                image: item.imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(item.imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: item.imageUrl.isEmpty
                  ? Icon(
                      Icons.restaurant,
                      color: Colors.grey.shade400,
                      size: 30,
                    )
                  : null,
            ),
            title: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${item.price.toStringAsFixed(0)} VND',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: item.isAvailable
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.isAvailable ? 'Có sẵn' : 'Hết hàng',
                        style: TextStyle(
                          color: item.isAvailable
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showAddEditDialog(item);
                    break;
                  case 'delete':
                    _showDeleteDialog(item);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Sửa'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20),
                      SizedBox(width: 8),
                      Text('Xóa'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
