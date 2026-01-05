import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/auth_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/services/table_service.dart';
import 'package:quanlynhahang/services/order_service.dart';
import 'package:quanlynhahang/models/table.dart';
import 'package:quanlynhahang/models/order.dart';
import 'package:quanlynhahang/page/order/order_table_detail_page.dart';
import '../shared/profile_page.dart';
import '../shared/chat_badge_button.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final AuthService _authService = AuthService();
  final LocalStorageService _localStorageService = LocalStorageService();
  final TableService _tableService = TableService();
  final OrderService _orderService = OrderService();
  int _selectedIndex = 0;
  List<TableModel> _tables = [];
  Map<String, Order?> _tableOrders = {}; // Map tableId -> active order
  bool _isLoadingTables = true;

  @override
  void initState() {
    super.initState();
    String? restaurantId = _localStorageService.getRestaurantId();
    String? userId = _localStorageService.getUserId();
    String? userRole = _localStorageService.getUserRole();
    print(
      'Order Page - UserId: $userId, Role: $userRole, RestaurantId: $restaurantId',
    );
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() => _isLoadingTables = true);
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
        
        // Load active orders for each table
        _tableOrders.clear();
        for (var table in _tables) {
          if (table.status == TableStatus.occupied) {
            final order = await _orderService.getActiveOrderByTable(restaurantId, table.id);
            _tableOrders[table.id] = order;
          }
        }
      }
    } catch (e) {
      _showSnackBar('Lỗi khi tải danh sách bàn: $e');
    } finally {
      setState(() => _isLoadingTables = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
        return 'Đang phục vụ';
      case TableStatus.reserved:
        return 'Đã đặt';
    }
  }

  Future<void> _handleTableTap(TableModel table) async {
    if (table.status == TableStatus.occupied) {
      // Bàn đang mở, chuyển đến trang chi tiết đơn hàng
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderTableDetailPage(table: table),
        ),
      );
      if (result == true) {
        _loadTables();
      }
    } else {
      // Bàn chưa mở, hiển thị dialog hỏi có muốn mở không
      bool? shouldOpen = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Mở bàn ${table.number}'),
          content: const Text('Bàn này chưa được mở. Bạn có muốn mở bàn này để tạo đơn hàng không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Không'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('Có, mở bàn'),
            ),
          ],
        ),
      );

      if (shouldOpen == true && mounted) {
        await _openTableAndNavigate(table);
      }
    }
  }

  Future<void> _openTableAndNavigate(TableModel table) async {
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
        await _loadTables();
        if (mounted) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderTableDetailPage(table: updatedTable),
            ),
          );
          if (result == true) {
            _loadTables();
          }
        }
      } else {
        _showSnackBar('Lỗi khi mở bàn');
      }
    } catch (e) {
      _showSnackBar('Lỗi: $e');
    }
  }

  Future<void> _updateTableStatus(TableModel table, TableStatus newStatus) async {
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

  void _showTableStatusMenu(TableModel table) {
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
            const Text(
              'Đổi trạng thái bàn',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            if (table.status != TableStatus.empty)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.green),
                ),
                title: const Text('Đặt về trống', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _updateTableStatus(table, TableStatus.empty);
                },
              ),
            if (table.status != TableStatus.occupied)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.restaurant, color: Colors.orange),
                ),
                title: const Text('Mở bàn (Đang phục vụ)', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _updateTableStatus(table, TableStatus.occupied);
                },
              ),
            if (table.status != TableStatus.reserved)
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
            const SizedBox(height: 16),
            // Nút thanh toán
            if (table.status == TableStatus.occupied)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _handlePayment(table);
                    },
                    icon: const Icon(Icons.payment),
                    label: const Text('Thanh toán'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Đăng Xuất'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                _authService.signOut();
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              },
              child: const Text('Đăng Xuất'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String? userName = _localStorageService.getUserName();

    List<Widget> pages = [_buildTableGridPage(userName), const ProfilePage()];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Xin chào, ${userName ?? 'Nhân Viên'}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          const ChatBadgeButton(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadTables,
            tooltip: 'Làm mới',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: _handleLogout,
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: Container(color: Colors.grey.shade50, child: pages[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey.shade600,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.table_restaurant_outlined),
            activeIcon: Icon(Icons.table_restaurant),
            label: 'Bàn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Hồ Sơ',
          ),
        ],
      ),
    );
  }

  Widget _buildTableGridPage(String? userName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quản lý đặt hàng',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Chọn bàn để tạo đơn hàng',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              // Status Legend
              Row(
                children: [
                  _buildStatusLegend(Colors.green, 'Trống'),
                  const SizedBox(width: 16),
                  _buildStatusLegend(Colors.orange, 'Đang phục vụ'),
                  const SizedBox(width: 16),
                  _buildStatusLegend(Colors.red, 'Đã đặt'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingTables
              ? const Center(child: CircularProgressIndicator())
              : _tables.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.table_restaurant, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có bàn nào',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _loadTables,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tải lại'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadTables,
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: _tables.length,
                        itemBuilder: (context, index) {
                          final table = _tables[index];
                          return _buildTableCard(table);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildStatusLegend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildTableCard(TableModel table) {
    final order = _tableOrders[table.id];
    final hasOrder = order != null;
    final itemCount = hasOrder ? order.items.length : 0;
    final totalAmount = hasOrder ? order.totalAmount : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor(table.status).withOpacity(0.5),
          width: 2,
        ),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: () => _handleTableTap(table),
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(table.status).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.table_restaurant,
                        size: 20,
                        color: _getStatusColor(table.status),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Bàn ${table.number}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(table.status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStatusText(table.status),
                        style: TextStyle(
                          fontSize: 9,
                          color: _getStatusColor(table.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Hiển thị thông tin đơn hàng nếu có
                    if (hasOrder && table.status == TableStatus.occupied) ...[
                      const SizedBox(height: 3),
                      Text(
                        '$itemCount món • ${_formatCurrency(totalAmount)}',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[
                      const SizedBox(height: 3),
                      Text(
                        '${table.capacity} người',
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // 3-dot menu button
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showTableStatusMenu(table),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.more_vert,
                      size: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ),
            // Nút thanh toán nhanh cho bàn đang phục vụ có đơn hàng
            if (hasOrder && table.status == TableStatus.occupied)
              Positioned(
                bottom: 2,
                right: 2,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handlePayment(table),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade500,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.payment,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handlePayment(TableModel table) {
    final order = _tableOrders[table.id];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.payment, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            Text('Thanh toán Bàn ${table.number}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (order != null) ...[
              _buildPaymentInfoRow('Số món:', '${order.items.length} món'),
              const SizedBox(height: 8),
              _buildPaymentInfoRow('Tổng tiền:', _formatCurrency(order.totalAmount)),
              const Divider(height: 24),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tính năng thanh toán sẽ được phát triển trong phiên bản tiếp theo.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('Tính năng thanh toán sẽ được phát triển sau!');
            },
            icon: const Icon(Icons.check),
            label: const Text('Xác nhận thanh toán'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return '${amount.toStringAsFixed(0)}đ';
  }
}
