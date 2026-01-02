import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/table_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/models/table.dart';
import 'package:quanlynhahang/page/order/order_cart_page.dart';

class OrderTableSelectionPage extends StatefulWidget {
  const OrderTableSelectionPage({super.key});

  @override
  State<OrderTableSelectionPage> createState() => _OrderTableSelectionPageState();
}

class _OrderTableSelectionPageState extends State<OrderTableSelectionPage> {
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
      
      if (restaurantId == null || restaurantId.isEmpty) {
        String? userId = _localStorageService.getUserId();
        if (userId != null) {
          restaurantId = await _tableService.getRestaurantIdByOwnerId(userId);
        }
      }

      if (restaurantId != null && restaurantId.isNotEmpty) {
        _tables = await _tableService.getTables(restaurantId);
      }
    } catch (e) {
      _showSnackBar('Lỗi khi tải danh sách bàn: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleTableSelection(TableModel table) async {
    if (table.status == TableStatus.occupied) {
      // Bàn đang mở, chuyển thẳng đến trang menu
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderCartPage(table: table),
        ),
      );
    } else {
      // Bàn chưa mở, hiển thị dialog hỏi có muốn mở không
      bool? shouldOpen = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Mở bàn ${table.number}'),
          content: const Text('Bàn này chưa được mở. Bạn có muốn mở bàn này không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Không'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Có'),
            ),
          ],
        ),
      );

      if (shouldOpen == true && mounted) {
        // Mở bàn và chuyển đến trang menu
        await _openTable(table);
      }
    }
  }

  Future<void> _openTable(TableModel table) async {
    try {
      TableModel updatedTable = TableModel(
        id: table.id,
        restaurantID: table.restaurantID,
        number: table.number,
        capacity: table.capacity,
        status: TableStatus.occupied,
        createdAt: table.createdAt,
        updatedAt: DateTime.now(),
      );

      bool success = await _tableService.updateTable(updatedTable);
      if (success) {
        _showSnackBar('Đã mở bàn ${table.number}');
        // Chuyển đến trang menu
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderCartPage(table: updatedTable),
            ),
          );
        }
      } else {
        _showSnackBar('Lỗi khi mở bàn');
      }
    } catch (e) {
      _showSnackBar('Lỗi: $e');
    }
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
        title: const Text('Chọn bàn'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tables.isEmpty
              ? const Center(
                  child: Text(
                    'Không có bàn nào',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTables,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.8,
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
                          onTap: () => _handleTableSelection(table),
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
                  ),
                ),
    );
  }
}
