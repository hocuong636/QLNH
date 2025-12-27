import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/table_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/models/table.dart';

class OrderTableManagementPage extends StatefulWidget {
  const OrderTableManagementPage({super.key});

  @override
  State<OrderTableManagementPage> createState() =>
      _OrderTableManagementPageState();
}

class _OrderTableManagementPageState extends State<OrderTableManagementPage> {
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
      String? restaurantId = _localStorageService.getRestaurantId();
      if (restaurantId != null) {
        _tables = await _tableService.getTables(restaurantId);
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

  Future<void> _updateTableStatus(
    TableModel table,
    TableStatus newStatus,
  ) async {
    try {
      TableModel updatedTable = TableModel(
        id: table.id,
        restaurantID: table.restaurantID,
        number: table.number,
        capacity: table.capacity,
        status: newStatus,
        createdAt: table.createdAt,
        updatedAt: DateTime.now(),
      );

      bool success = await _tableService.updateTable(updatedTable);
      if (success) {
        _showSnackBar('Cập nhật trạng thái bàn thành công');
        _loadTables();
      } else {
        _showSnackBar('Lỗi khi cập nhật trạng thái bàn');
      }
    } catch (e) {
      _showSnackBar('Lỗi khi cập nhật trạng thái: $e');
    }
  }

  void _showTableActions(TableModel table) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bàn ${table.number}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (table.status == TableStatus.empty)
              ListTile(
                leading: const Icon(Icons.play_arrow, color: Colors.green),
                title: const Text('Mở bàn'),
                onTap: () {
                  Navigator.pop(context);
                  _updateTableStatus(table, TableStatus.occupied);
                },
              ),
            if (table.status == TableStatus.occupied)
              ListTile(
                leading: const Icon(Icons.stop, color: Colors.red),
                title: const Text('Kết thúc bàn'),
                onTap: () {
                  Navigator.pop(context);
                  _updateTableStatus(table, TableStatus.empty);
                },
              ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Hủy'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
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

  String _getStatusText(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return 'Trống';
      case TableStatus.occupied:
        return 'Đang phục vụ';
      case TableStatus.reserved:
        return 'Đã đặt';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý bàn ăn'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tables.isEmpty
          ? _buildEmptyState()
          : _buildTableGrid(),
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
        ],
      ),
    );
  }

  Widget _buildTableGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _tables.length,
      itemBuilder: (context, index) {
        final table = _tables[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showTableActions(table),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.table_restaurant,
                    size: 32,
                    color: _getStatusColor(table.status),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bàn ${table.number}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getStatusText(table.status),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getStatusColor(table.status),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${table.capacity} người',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
