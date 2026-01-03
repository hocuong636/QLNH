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
      } else {
        // Try to get restaurantId from userId for staff
        String? userId = _localStorageService.getUserId();
        if (userId != null) {
          restaurantId = await _tableService.getRestaurantIdByOwnerId(userId);
          if (restaurantId != null) {
            _tables = await _tableService.getTables(restaurantId);
          }
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Bàn ${table.number}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(table.status).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusText(table.status),
                style: TextStyle(
                  color: _getStatusColor(table.status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (table.status == TableStatus.empty) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.green),
                ),
                title: const Text('Mở bàn', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _updateTableStatus(table, TableStatus.occupied);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.book_online, color: Colors.red),
                ),
                title: const Text('Đặt trước', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _updateTableStatus(table, TableStatus.reserved);
                },
              ),
            ],
            if (table.status == TableStatus.occupied)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stop, color: Colors.orange),
                ),
                title: const Text('Kết thúc bàn', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _updateTableStatus(table, TableStatus.empty);
                },
              ),
            if (table.status == TableStatus.reserved) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.green),
                ),
                title: const Text('Bắt đầu phục vụ', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _updateTableStatus(table, TableStatus.occupied);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.cancel, color: Colors.grey.shade700),
                ),
                title: const Text('Hủy đặt bàn', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _updateTableStatus(table, TableStatus.empty);
                },
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Đóng'),
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
        return Colors.orange;
      case TableStatus.reserved:
        return Colors.red;
    }
  }

  String _getStatusText(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return 'Trống';
      case TableStatus.occupied:
        return 'Phục vụ';
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
        childAspectRatio: 0.8,
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                border: Border.all(
                  color: _getStatusColor(table.status).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: _getStatusColor(table.status).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.table_restaurant,
                      size: 22,
                      color: _getStatusColor(table.status),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Flexible(
                    child: Text(
                      'Bàn ${table.number}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(table.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(table.status),
                      style: TextStyle(
                        fontSize: 10,
                        color: _getStatusColor(table.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Flexible(
                    child: Text(
                      '${table.capacity} người',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
