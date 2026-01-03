import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/inventory_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/models/inventory_item.dart';
import 'package:quanlynhahang/models/inventory_history.dart';

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
  List<InventoryHistory> _inventoryHistory = [];
  bool _isLoading = true;
  bool _showHistory = false;

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
          if (_showHistory) {
            _inventoryHistory = await _inventoryService.getInventoryHistory(
              restaurantId,
            );
          }
        } else {
          _showSnackBar('Không tìm thấy nhà hàng. Vui lòng đăng nhập lại.');
        }
      } else {
        _showSnackBar('Bạn chưa đăng nhập. Vui lòng đăng nhập lại.');
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
                      isActive: true,
                      lastUpdated: DateTime.now(),
                    );

                    if (item == null) {
                      String? result = await _inventoryService
                          .createInventoryItem(newItem);
                      if (result != null) {
                        _showSnackBar('Thêm nguyên liệu thành công');
                      } else {
                        _showSnackBar('Lỗi khi thêm nguyên liệu');
                        return;
                      }
                    } else {
                      bool success = await _inventoryService
                          .updateInventoryItem(newItem);
                      if (success) {
                        _showSnackBar('Cập nhật nguyên liệu thành công');
                      } else {
                        _showSnackBar('Lỗi khi cập nhật nguyên liệu');
                        return;
                      }
                    }

                    Navigator.of(context).pop();
                    _loadInventoryItems();
                  } else {
                    _showSnackBar(
                      'Không tìm thấy nhà hàng. Vui lòng đăng nhập lại.',
                    );
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

  void _showDeactivateDialog(InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ngừng sử dụng nguyên liệu'),
        content: Text(
          'Bạn có chắc chắn muốn ngừng sử dụng "${item.name}"? Nguyên liệu sẽ bị ẩn khỏi danh sách nhưng vẫn có thể khôi phục.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                bool success = await _inventoryService.deactivateInventoryItem(
                  item.id,
                );
                if (success) {
                  _showSnackBar('Ngừng sử dụng nguyên liệu thành công');
                  Navigator.of(context).pop();
                  _loadInventoryItems();
                } else {
                  _showSnackBar('Lỗi khi ngừng sử dụng');
                }
              } catch (e) {
                _showSnackBar('Lỗi: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Ngừng sử dụng'),
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
                double newQuantity = double.parse(quantityController.text);
                String action = newQuantity > item.quantity
                    ? 'add'
                    : 'subtract';
                String notes = 'Cập nhật thủ công';

                bool success = await _inventoryService.updateInventoryQuantity(
                  item.id,
                  newQuantity,
                  action,
                  notes,
                );

                if (success) {
                  _showSnackBar('Cập nhật số lượng thành công');
                  Navigator.of(context).pop();
                  _loadInventoryItems();
                } else {
                  _showSnackBar('Lỗi khi cập nhật');
                }
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

  void _showSubtractQuantityDialog(InventoryItem item) {
    final quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xuất kho - ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Số lượng hiện tại: ${item.quantity} ${item.unit}'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: InputDecoration(
                labelText: 'Số lượng xuất (${item.unit})',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            const Text(
              'Lưu ý: Xuất kho sẽ giảm số lượng trong kho',
              style: TextStyle(fontSize: 12, color: Colors.red),
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
                _showSnackBar('Vui lòng nhập số lượng xuất');
                return;
              }

              try {
                double subtractQuantity = double.parse(quantityController.text);
                if (subtractQuantity <= 0) {
                  _showSnackBar('Số lượng phải lớn hơn 0');
                  return;
                }
                if (subtractQuantity > item.quantity) {
                  _showSnackBar('Không đủ số lượng trong kho');
                  return;
                }

                double newQuantity = item.quantity - subtractQuantity;
                bool success = await _inventoryService.updateInventoryQuantity(
                  item.id,
                  newQuantity,
                  'subtract',
                  'Xuất kho thủ công',
                );

                if (success) {
                  _showSnackBar('Xuất kho thành công');
                  Navigator.of(context).pop();
                  _loadInventoryItems();
                } else {
                  _showSnackBar('Lỗi khi xuất kho');
                }
              } catch (e) {
                _showSnackBar('Lỗi: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Xuất kho'),
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
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _showHistory = !_showHistory);
              _loadInventoryItems();
            },
            child: Text(
              _showHistory ? 'Xem kho' : 'Xem lịch sử',
              style: const TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _showHistory
          ? _buildHistoryView()
          : _inventoryItems.isEmpty
          ? _buildEmptyState()
          : _buildInventoryList(),
      floatingActionButton: !_showHistory
          ? FloatingActionButton(
              onPressed: () => _showAddEditDialog(),
              backgroundColor: Colors.blue.shade700,
              child: const Icon(Icons.add),
            )
          : null,
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
                  case 'subtract_quantity':
                    _showSubtractQuantityDialog(item);
                    break;
                  case 'edit':
                    _showAddEditDialog(item);
                    break;
                  case 'deactivate':
                    _showDeactivateDialog(item);
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
                  value: 'subtract_quantity',
                  child: Row(
                    children: [
                      Icon(Icons.remove_circle, size: 20),
                      SizedBox(width: 8),
                      Text('Xuất kho'),
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
                  value: 'deactivate',
                  child: Row(
                    children: [
                      Icon(Icons.pause, size: 20),
                      SizedBox(width: 8),
                      Text('Ngừng sử dụng'),
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

  Widget _buildHistoryView() {
    if (_inventoryHistory.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có lịch sử nào',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _inventoryHistory.length,
      itemBuilder: (context, index) {
        final history = _inventoryHistory[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              history.action == 'add'
                  ? Icons.add_circle
                  : history.action == 'subtract'
                  ? Icons.remove_circle
                  : Icons.edit,
              color: history.action == 'add'
                  ? Colors.green
                  : history.action == 'subtract'
                  ? Colors.red
                  : Colors.blue,
            ),
            title: Text(
              history.action == 'add'
                  ? 'Nhập kho'
                  : history.action == 'subtract'
                  ? 'Xuất kho'
                  : 'Cập nhật',
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Số lượng: ${history.quantityChange > 0 ? '+' : ''}${history.quantityChange} → ${history.newQuantity}',
                ),
                Text(
                  history.timestamp.toString().substring(0, 19),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (history.notes.isNotEmpty)
                  Text(
                    history.notes,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
