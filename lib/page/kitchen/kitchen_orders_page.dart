import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/order_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/services/table_service.dart';
import 'package:quanlynhahang/models/order.dart';
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

      _tableNames = {for (var table in tables) table.id: 'Bàn ${table.number}'};

      // Active orders: có ít nhất 1 món chưa served (pending, cooking, ready)
      _activeOrders = allOrders.where((order) {
        if (order.status == OrderStatus.paid) return false;
        return order.items.any((item) => 
          item.itemStatus != OrderItemStatus.served
        );
      }).toList();

      // Completed orders: tất cả món đã served hoặc order đã done
      _completedOrders = allOrders.where((order) {
        if (order.status == OrderStatus.paid) return false;
        if (order.status == OrderStatus.done) return true;
        return order.items.every((item) => 
          item.itemStatus == OrderItemStatus.served
        );
      }).toList();

      // Sort by time - oldest first for active orders (FIFO)
      _activeOrders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _completedOrders.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

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

  Future<void> _updateItemStatus(Order order, int itemIndex, OrderItemStatus newStatus) async {
    try {
      List<OrderItem> updatedItems = List.from(order.items);
      updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(itemStatus: newStatus);

      // Check if all items are ready or served -> update order status
      OrderStatus newOrderStatus = order.status;
      bool allReady = updatedItems.every((item) => 
        item.itemStatus == OrderItemStatus.ready || 
        item.itemStatus == OrderItemStatus.served
      );
      bool allServed = updatedItems.every((item) => 
        item.itemStatus == OrderItemStatus.served
      );

      if (allServed) {
        newOrderStatus = OrderStatus.done;
      } else if (allReady) {
        newOrderStatus = OrderStatus.done;
      } else if (updatedItems.any((item) => item.itemStatus == OrderItemStatus.cooking)) {
        newOrderStatus = OrderStatus.cooking;
      }

      final updatedOrder = order.copyWith(
        items: updatedItems,
        status: newOrderStatus,
        updatedAt: DateTime.now(),
      );

      final success = await _orderService.updateOrder(updatedOrder);
      if (success) {
        _showSnackBar('Đã cập nhật trạng thái món');
      } else {
        _showSnackBar('Lỗi khi cập nhật');
      }
    } catch (e) {
      print('Error updating item status: $e');
      _showSnackBar('Lỗi: $e');
    }
  }

  Future<void> _markAllItemsAsStatus(Order order, OrderItemStatus newStatus) async {
    try {
      List<OrderItem> updatedItems = order.items.map((item) {
        // Only update items that are not already served
        if (item.itemStatus != OrderItemStatus.served) {
          return item.copyWith(itemStatus: newStatus);
        }
        return item;
      }).toList();

      OrderStatus newOrderStatus = order.status;
      if (newStatus == OrderItemStatus.ready) {
        newOrderStatus = OrderStatus.done;
      } else if (newStatus == OrderItemStatus.cooking) {
        newOrderStatus = OrderStatus.cooking;
      }

      final updatedOrder = order.copyWith(
        items: updatedItems,
        status: newOrderStatus,
        updatedAt: DateTime.now(),
      );

      final success = await _orderService.updateOrder(updatedOrder);
      if (success) {
        _showSnackBar('Đã cập nhật tất cả món');
      } else {
        _showSnackBar('Lỗi khi cập nhật');
      }
    } catch (e) {
      print('Error updating all items: $e');
      _showSnackBar('Lỗi: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Color _getItemStatusColor(OrderItemStatus status) {
    switch (status) {
      case OrderItemStatus.pending:
        return Colors.grey;
      case OrderItemStatus.cooking:
        return Colors.orange;
      case OrderItemStatus.ready:
        return Colors.green;
      case OrderItemStatus.served:
        return Colors.blue;
    }
  }

  String _getItemStatusText(OrderItemStatus status) {
    switch (status) {
      case OrderItemStatus.pending:
        return 'Chờ';
      case OrderItemStatus.cooking:
        return 'Đang nấu';
      case OrderItemStatus.ready:
        return 'Xong';
      case OrderItemStatus.served:
        return 'Đã phục vụ';
    }
  }

  IconData _getItemStatusIcon(OrderItemStatus status) {
    switch (status) {
      case OrderItemStatus.pending:
        return Icons.hourglass_empty;
      case OrderItemStatus.cooking:
        return Icons.local_fire_department;
      case OrderItemStatus.ready:
        return Icons.check_circle;
      case OrderItemStatus.served:
        return Icons.done_all;
    }
  }

  int _getPendingItemsCount(Order order) {
    return order.items.where((item) => 
      item.itemStatus == OrderItemStatus.pending || 
      item.itemStatus == OrderItemStatus.cooking
    ).length;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Đang Xử Lý'),
                    if (_activeOrders.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_activeOrders.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'Đã Hoàn Thành'),
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
              _buildActiveOrdersList(),
              _buildCompletedOrdersList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveOrdersList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activeOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Không có đơn hàng nào đang xử lý',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Các đơn mới sẽ hiển thị ở đây',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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
        padding: const EdgeInsets.all(12),
        itemCount: _activeOrders.length,
        itemBuilder: (context, index) {
          final order = _activeOrders[index];
          return _buildOrderCard(order, isActive: true);
        },
      ),
    );
  }

  Widget _buildCompletedOrdersList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_completedOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Chưa có đơn hàng hoàn thành',
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
        padding: const EdgeInsets.all(12),
        itemCount: _completedOrders.length,
        itemBuilder: (context, index) {
          final order = _completedOrders[index];
          return _buildOrderCard(order, isActive: false);
        },
      ),
    );
  }

  Widget _buildOrderCard(Order order, {required bool isActive}) {
    final pendingCount = _getPendingItemsCount(order);
    final timeSinceOrder = DateTime.now().difference(order.createdAt);
    final isUrgent = timeSinceOrder.inMinutes > 15 && isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isUrgent 
          ? const BorderSide(color: Colors.red, width: 2)
          : BorderSide.none,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUrgent ? Colors.red.shade50 : Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                // Table number - prominent display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _tableNames[order.tableId] ?? 'Bàn ${order.tableId}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${order.id.substring(0, 8)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        _formatTime(order.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isUrgent ? Colors.red : Colors.grey.shade600,
                          fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive && pendingCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$pendingCount món chờ',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (!isActive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Xong',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Items list
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ...order.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return _buildItemRow(order, index, item, isActive);
                }),
              ],
            ),
          ),

          // Quick actions for active orders
          if (isActive && pendingCount > 0) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _markAllItemsAsStatus(order, OrderItemStatus.cooking),
                      icon: const Icon(Icons.local_fire_department, size: 18),
                      label: const Text('Nấu tất cả'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAllItemsAsStatus(order, OrderItemStatus.ready),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Xong tất cả'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Notes
          if (order.notes.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.note, size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.notes,
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemRow(Order order, int index, OrderItem item, bool isActive) {
    final bool canUpdate = isActive && item.itemStatus != OrderItemStatus.served;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _getItemStatusColor(item.itemStatus).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getItemStatusColor(item.itemStatus).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getItemStatusColor(item.itemStatus).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getItemStatusIcon(item.itemStatus),
              color: _getItemStatusColor(item.itemStatus),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          
          // Item info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'x${item.quantity}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getItemStatusColor(item.itemStatus).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getItemStatusText(item.itemStatus),
                        style: TextStyle(
                          fontSize: 11,
                          color: _getItemStatusColor(item.itemStatus),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.note != null && item.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Ghi chú: ${item.note}',
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
          
          // Action buttons
          if (canUpdate) ...[
            _buildItemActionButton(order, index, item),
          ],
        ],
      ),
    );
  }

  Widget _buildItemActionButton(Order order, int index, OrderItem item) {
    switch (item.itemStatus) {
      case OrderItemStatus.pending:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _updateItemStatus(order, index, OrderItemStatus.cooking),
              icon: const Icon(Icons.local_fire_department),
              color: Colors.orange,
              tooltip: 'Bắt đầu nấu',
              style: IconButton.styleFrom(
                backgroundColor: Colors.orange.shade50,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => _updateItemStatus(order, index, OrderItemStatus.ready),
              icon: const Icon(Icons.check_circle),
              color: Colors.green,
              tooltip: 'Đánh dấu xong',
              style: IconButton.styleFrom(
                backgroundColor: Colors.green.shade50,
              ),
            ),
          ],
        );
      case OrderItemStatus.cooking:
        return IconButton(
          onPressed: () => _updateItemStatus(order, index, OrderItemStatus.ready),
          icon: const Icon(Icons.check_circle),
          color: Colors.green,
          tooltip: 'Hoàn thành',
          style: IconButton.styleFrom(
            backgroundColor: Colors.green.shade50,
          ),
        );
      case OrderItemStatus.ready:
        return IconButton(
          onPressed: () => _updateItemStatus(order, index, OrderItemStatus.served),
          icon: const Icon(Icons.done_all),
          color: Colors.blue,
          tooltip: 'Đã phục vụ',
          style: IconButton.styleFrom(
            backgroundColor: Colors.blue.shade50,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 1) {
      return 'Vừa xong';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    } else {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.day}/${dateTime.month}';
    }
  }
}
