import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/table_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/models/table.dart';

class TableManagementPage extends StatefulWidget {
  const TableManagementPage({super.key});

  @override
  State<TableManagementPage> createState() => _TableManagementPageState();
}

class _TableManagementPageState extends State<TableManagementPage> {
  final TableService _tableService = TableService();
  final LocalStorageService _localStorageService = LocalStorageService();
  List<TableModel> _tables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() => _isLoading = true);
    try {
      String? ownerId = _localStorageService.getUserId();
      if (ownerId != null) {
        String? restaurantId = await _tableService.getRestaurantIdByOwnerId(
          ownerId,
        );
        if (restaurantId != null) {
          _tables = await _tableService.getTables(restaurantId);
        }
      }
    } catch (e) {
      _showSnackBar('Lỗi khi tải danh sách bàn: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAddEditDialog([TableModel? table]) {
    final numberController = TextEditingController(
      text: table?.number.toString() ?? '',
    );
    final capacityController = TextEditingController(
      text: table?.capacity.toString() ?? '',
    );
    TableStatus status = table?.status ?? TableStatus.empty;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(table == null ? 'Thêm bàn' : 'Sửa bàn'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numberController,
                  decoration: const InputDecoration(labelText: 'Số bàn'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: capacityController,
                  decoration: const InputDecoration(
                    labelText: 'Sức chứa (người)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<TableStatus>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                  items: TableStatus.values.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(_getStatusDisplayName(status)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => status = value!),
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
                if (numberController.text.isEmpty ||
                    capacityController.text.isEmpty) {
                  _showSnackBar('Vui lòng nhập số bàn và sức chứa');
                  return;
                }

                try {
                  String? ownerId = _localStorageService.getUserId();
                  if (ownerId != null) {
                    String? restaurantId = await _tableService
                        .getRestaurantIdByOwnerId(ownerId);
                    if (restaurantId != null) {
                      TableModel newTable = TableModel(
                        id: table?.id ?? '',
                        restaurantId: restaurantId,
                        number: int.parse(numberController.text),
                        capacity: int.parse(capacityController.text),
                        status: status,
                        createdAt: table?.createdAt ?? DateTime.now(),
                        updatedAt: DateTime.now(),
                      );

                      if (table == null) {
                        await _tableService.createTable(newTable);
                        _showSnackBar('Thêm bàn thành công');
                      } else {
                        await _tableService.updateTable(newTable);
                        _showSnackBar('Cập nhật bàn thành công');
                      }

                      Navigator.of(context).pop();
                      _loadTables();
                    }
                  }
                } catch (e) {
                  _showSnackBar('Lỗi: $e');
                }
              },
              child: Text(table == null ? 'Thêm' : 'Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(TableModel table) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bàn'),
        content: Text('Bạn có chắc chắn muốn xóa bàn ${table.number}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _tableService.deleteTable(table.id);
                _showSnackBar('Xóa bàn thành công');
                Navigator.of(context).pop();
                _loadTables();
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

  String _getStatusDisplayName(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return 'Trống';
      case TableStatus.occupied:
        return 'Đang sử dụng';
      case TableStatus.reserved:
        return 'Đã đặt';
    }
  }

  Color _getStatusColor(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return Colors.green;
      case TableStatus.occupied:
        return Colors.red;
      case TableStatus.reserved:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý bàn'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tables.isEmpty
          ? _buildEmptyState()
          : _buildTableList(),
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
          Icon(Icons.table_restaurant, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Chưa có bàn nào',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn + để thêm bàn đầu tiên',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildTableList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tables.length,
      itemBuilder: (context, index) {
        final table = _tables[index];
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
                color: _getStatusColor(table.status).withOpacity(0.1),
              ),
              child: Icon(
                Icons.table_restaurant,
                color: _getStatusColor(table.status),
                size: 24,
              ),
            ),
            title: Text(
              'Bàn ${table.number}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${table.capacity} người',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(table.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusDisplayName(table.status),
                    style: TextStyle(
                      color: _getStatusColor(table.status),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showAddEditDialog(table);
                    break;
                  case 'delete':
                    _showDeleteDialog(table);
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
