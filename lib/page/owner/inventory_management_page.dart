import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/inventory_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/models/inventory_item.dart';

class InventoryManagementPage extends StatefulWidget {
  const InventoryManagementPage({super.key});

  @override
  State<InventoryManagementPage> createState() =>
      _InventoryManagementPageState();
}

class _InventoryManagementPageState extends State<InventoryManagementPage> {
  final InventoryService _inventoryService = InventoryService();
  final LocalStorageService _localStorageService = LocalStorageService();
  List<InventoryItem> _inventoryItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInventoryItems();
  }

  Future<void> _loadInventoryItems() async {
    setState(() => _isLoading = true);
    try {
      String? ownerId = _localStorageService.getUserId();
      if (ownerId != null) {
        String? restaurantId = await _inventoryService.getRestaurantIdByOwnerId(
          ownerId,
        );
        if (restaurantId != null) {
          _inventoryItems = await _inventoryService.getInventoryItems(
            restaurantId,
          );
        }
      }
    } catch (e) {
      _showSnackBar('Lỗi khi tải danh sách kho: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAddEditDialog([InventoryItem? item]) {
    final nameController = TextEditingController(text: item?.name ?? '');
    final quantityController = TextEditingController(
      text: item?.quantity.toString() ?? '',
    );
    final unitController = TextEditingController(text: item?.unit ?? '');
    final minThresholdController = TextEditingController(
      text: item?.minThreshold.toString() ?? '',
    );
    final supplierController = TextEditingController(
      text: item?.supplier ?? '',
    );
    final notesController = TextEditingController(text: item?.notes ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Thêm nguyên liệu' : 'Sửa nguyên liệu'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tên nguyên liệu'),
              ),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Số lượng'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: 'Đơn vị (kg, lít, cái...)',
                ),
              ),
              TextField(
                controller: minThresholdController,
                decoration: const InputDecoration(
                  labelText: 'Ngưỡng tối thiểu',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: supplierController,
                decoration: const InputDecoration(labelText: 'Nhà cung cấp'),
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Ghi chú'),
                maxLines: 2,
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
                  quantityController.text.isEmpty) {
                _showSnackBar('Vui lòng nhập tên và số lượng');
                return;
              }

              try {
                String? ownerId = _localStorageService.getUserId();
                if (ownerId != null) {
                  String? restaurantId = await _inventoryService
                      .getRestaurantIdByOwnerId(ownerId);
                  if (restaurantId != null) {
                    InventoryItem newItem = InventoryItem(
                      id: item?.id ?? '',
                      restaurantId: restaurantId,
                      name: nameController.text,
                      quantity: double.parse(quantityController.text),
                      unit: unitController.text,
                      minThreshold:
                          double.tryParse(minThresholdController.text) ?? 0,
                      supplier: supplierController.text,
                      notes: notesController.text,
                      lastUpdated: DateTime.now(),
                    );

                    if (item == null) {
                      await _inventoryService.createInventoryItem(newItem);
                      _showSnackBar('Thêm nguyên liệu thành công');
                    } else {
                      await _inventoryService.updateInventoryItem(newItem);
                      _showSnackBar('Cập nhật nguyên liệu thành công');
                    }

                    Navigator.of(context).pop();
                    _loadInventoryItems();
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
    );
  }

  void _showDeleteDialog(InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa nguyên liệu'),
        content: Text('Bạn có chắc chắn muốn xóa "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _inventoryService.deleteInventoryItem(item.id);
                _showSnackBar('Xóa nguyên liệu thành công');
                Navigator.of(context).pop();
                _loadInventoryItems();
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

  void _showUpdateQuantityDialog(InventoryItem item) {
    final quantityController = TextEditingController(
      text: item.quantity.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cập nhật số lượng - ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              decoration: InputDecoration(
                labelText: 'Số lượng mới (${item.unit})',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (quantityController.text.isEmpty) {
                _showSnackBar('Vui lòng nhập số lượng');
                return;
              }

              try {
                InventoryItem updatedItem = InventoryItem(
                  id: item.id,
                  restaurantId: item.restaurantId,
                  name: item.name,
                  quantity: double.parse(quantityController.text),
                  unit: item.unit,
                  minThreshold: item.minThreshold,
                  supplier: item.supplier,
                  notes: item.notes,
                  lastUpdated: DateTime.now(),
                );

                await _inventoryService.updateInventoryItem(updatedItem);
                _showSnackBar('Cập nhật số lượng thành công');
                Navigator.of(context).pop();
                _loadInventoryItems();
              } catch (e) {
                _showSnackBar('Lỗi khi cập nhật: $e');
              }
            },
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
  }

  Color _getQuantityColor(double quantity, double minThreshold) {
    if (quantity <= minThreshold) {
      return Colors.red;
    } else if (quantity <= minThreshold * 1.5) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  String _getQuantityStatus(double quantity, double minThreshold) {
    if (quantity <= minThreshold) {
      return 'Cần nhập thêm';
    } else if (quantity <= minThreshold * 1.5) {
      return 'Sắp hết';
    } else {
      return 'Đủ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý kho'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _inventoryItems.isEmpty
          ? _buildEmptyState()
          : _buildInventoryList(),
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
          Icon(Icons.inventory, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Kho trống',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn + để thêm nguyên liệu đầu tiên',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _inventoryItems.length,
      itemBuilder: (context, index) {
        final item = _inventoryItems[index];
        return Card(
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
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade200,
              ),
              child: Icon(
                Icons.inventory_2,
                color: Colors.grey.shade600,
                size: 24,
              ),
            ),
            title: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${item.quantity} ${item.unit}',
                      style: TextStyle(
                        color: _getQuantityColor(
                          item.quantity,
                          item.minThreshold,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getQuantityColor(
                          item.quantity,
                          item.minThreshold,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getQuantityStatus(item.quantity, item.minThreshold),
                        style: TextStyle(
                          color: _getQuantityColor(
                            item.quantity,
                            item.minThreshold,
                          ),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.supplier.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'NCC: ${item.supplier}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
                if (item.notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.notes,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'update_quantity':
                    _showUpdateQuantityDialog(item);
                    break;
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
                  value: 'update_quantity',
                  child: Row(
                    children: [
                      Icon(Icons.edit_note, size: 20),
                      SizedBox(width: 8),
                      Text('Cập nhật số lượng'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Sửa thông tin'),
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
