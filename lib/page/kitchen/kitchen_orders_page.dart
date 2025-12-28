import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/order_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/services/table_service.dart';
import 'package:quanlynhahang/models/order.dart';
import 'package:quanlynhahang/constants/order_status_config.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class KitchenOrdersPage extends StatefulWidget {
  const KitchenOrdersPage({super.key});

  @override
  State<KitchenOrdersPage> createState() => _KitchenOrdersPageState();
}

class _KitchenOrdersPageState extends State<KitchenOrdersPage>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final LocalStorageService _localStorageService = LocalStorageService();
  final TableService _tableService = TableService();

  late TabController _tabController;
  List<Order> _activeOrders = [];
  List<Order> _completedOrders = [];
  Map<String, String> _tableNames = {};
  bool _isLoading = true;
  DatabaseReference? _ordersRef;
  StreamSubscription<DatabaseEvent>? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupRealtimeUpdates();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _setupRealtimeUpdates() async {
    setState(() => _isLoading = true);

    try {
      final restaurantId = await _orderService.getRestaurantIdByUserId(
        _localStorageService.getUserId() ?? '',
      );

      if (restaurantId != null) {
        _ordersRef = FirebaseDatabase.instance.ref('orders');

        _ordersSubscription = _ordersRef!.onValue.listen((event) {
          _loadOrdersRealtime(restaurantId);
        });

        // Initial load
        await _loadOrdersRealtime(restaurantId);
      }
    } catch (e) {
      print('Error setting up realtime updates: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOrdersRealtime(String restaurantId) async {
    try {
      final allOrders = await _orderService.getOrders(restaurantId);
      final tables = await _tableService.getTables(restaurantId);

      // Create table name map
      _tableNames = {for (var table in tables) table.id: 'Bàn ${table.number}'};

      // Filter orders for kitchen
      _activeOrders = allOrders
          .where(
            (order) =>
                order.status == OrderStatus.new_ ||
                order.status == OrderStatus.cooking,
          )
          .toList();

      _completedOrders = allOrders
          .where((order) => order.status == OrderStatus.done)
          .toList();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading orders realtime: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    // Check if kitchen can update this status
    if (!OrderStatusConfig.canUpdateStatus(order.status, 'KITCHEN')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không có quyền cập nhật trạng thái này'),
        ),
      );
      return;
    }

    try {
      final updatedOrder = order.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );

      final success = await _orderService.updateOrder(updatedOrder);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cập nhật trạng thái thành công')),
        );
        // No need to reload - realtime listener will update automatically
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi cập nhật trạng thái')));
      }
    } catch (e) {
      print('Error updating order status: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi cập nhật trạng thái')));
    }
  }

  String _getStatusText(OrderStatus status) {
    return OrderStatusConfig.getStatusText(status);
  }

  Color _getStatusColor(OrderStatus status) {
    return OrderStatusConfig.getStatusColor(status);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Đơn Đang Xử Lý'),
              Tab(text: 'Đơn Đã Hoàn Thành'),
            ],
            labelColor: Colors.blue.shade700,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.blue.shade700,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOrdersList(_activeOrders, true),
              _buildOrdersList(_completedOrders, false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersList(List<Order> orders, bool isActive) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.restaurant_menu : Icons.check_circle,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isActive
                  ? 'Không có đơn hàng nào đang xử lý'
                  : 'Chưa có đơn hàng hoàn thành',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final restaurantId = await _orderService.getRestaurantIdByUserId(
          _localStorageService.getUserId() ?? '',
        );
        if (restaurantId != null) {
          await _loadOrdersRealtime(restaurantId);
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () => _showOrderDetails(order, isActive),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Đơn #${order.id.substring(0, 8)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: OrderStatusConfig.getStatusBackgroundColor(
                              order.status,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getStatusColor(order.status),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                OrderStatusConfig.getStatusIcon(order.status),
                                color: _getStatusColor(order.status),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getStatusText(order.status),
                                style: TextStyle(
                                  color: _getStatusColor(order.status),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _tableNames[order.tableId] ?? 'Bàn ${order.tableId}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.items.length} món',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Thời gian: ${_formatDateTime(order.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    if (order.notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Ghi chú: ${order.notes}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showOrderDetails(Order order, bool isActive) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chi tiết đơn hàng',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildOrderInfo(order),
                    const SizedBox(height: 20),
                    const Text(
                      'Danh sách món ăn:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...order.items.map(
                      (item) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Số lượng: ${item.quantity}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive) ...[
                const SizedBox(height: 20),
                ..._buildStatusUpdateButtons(order),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderInfo(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Đơn #${order.id.substring(0, 8)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: OrderStatusConfig.getStatusBackgroundColor(order.status),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getStatusColor(order.status),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    OrderStatusConfig.getStatusIcon(order.status),
                    color: _getStatusColor(order.status),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getStatusText(order.status),
                    style: TextStyle(
                      color: _getStatusColor(order.status),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Bàn: ${_tableNames[order.tableId] ?? order.tableId}',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        Text(
          'Khách hàng: ${order.customerName}',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        Text(
          'Thời gian: ${_formatDateTime(order.createdAt)}',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        if (order.notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Ghi chú đơn hàng: ${order.notes}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.orange.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildStatusUpdateButtons(Order order) {
    final availableStatuses = OrderStatusConfig.getAvailableStatuses(
      order.status,
      'KITCHEN',
    );

    if (availableStatuses.isEmpty) {
      return [];
    }

    return [
      Row(
        children: availableStatuses.map((newStatus) {
          final buttonText = _getStatusButtonText(newStatus);
          final buttonColor = _getStatusColor(newStatus);

          return Expanded(
            child: Container(
              margin: EdgeInsets.only(
                right: availableStatuses.length > 1 ? 8 : 0,
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _updateOrderStatus(order, newStatus);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(buttonText),
              ),
            ),
          );
        }).toList(),
      ),
    ];
  }

  String _getStatusButtonText(OrderStatus status) {
    switch (status) {
      case OrderStatus.cooking:
        return 'Bắt đầu chế biến';
      case OrderStatus.done:
        return 'Hoàn thành';
      default:
        return 'Cập nhật';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
