import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/order_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/models/order.dart';
import 'package:quanlynhahang/constants/order_status_config.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class OrderStatusPage extends StatefulWidget {
  const OrderStatusPage({super.key});

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage> {
  final OrderService _orderService = OrderService();
  final LocalStorageService _localStorageService = LocalStorageService();
  List<Order> _orders = [];
  bool _isLoading = true;
  DatabaseReference? _ordersRef;
  StreamSubscription<DatabaseEvent>? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    _setupRealtimeUpdates();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _setupRealtimeUpdates() async {
    setState(() => _isLoading = true);

    try {
      String? restaurantId = _localStorageService.getRestaurantId();

      // If restaurantId is null, try to get it from userId
      if (restaurantId == null || restaurantId.isEmpty) {
        String? userId = _localStorageService.getUserId();
        if (userId != null) {
          restaurantId = await _orderService.getRestaurantIdByUserId(userId);
        }
      }

      if (restaurantId != null && restaurantId.isNotEmpty) {
        // Setup realtime listener
        _ordersRef = FirebaseDatabase.instance.ref('orders');

        _ordersSubscription = _ordersRef!.onValue.listen((event) {
          _loadOrdersRealtime(restaurantId!);
        });

        // Initial load
        await _loadOrdersRealtime(restaurantId);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('OrderStatusPage: Error setting up realtime updates: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOrdersRealtime(String restaurantId) async {
    try {
      _orders = await _orderService.getOrders(restaurantId);
      // Lọc chỉ lấy đơn hàng đang active (chưa thanh toán)
      _orders = _orders
          .where((order) => order.status != OrderStatus.paid)
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _getStatusText(OrderStatus status) {
    return OrderStatusConfig.getStatusText(status);
  }

  Color _getStatusColor(OrderStatus status) {
    return OrderStatusConfig.getStatusColor(status);
  }

  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    // Check if order staff can update this status
    if (!OrderStatusConfig.canUpdateStatus(order.status, 'ORDER')) {
      _showSnackBar('Bạn không có quyền cập nhật trạng thái này');
      return;
    }

    try {
      Order updatedOrder = order.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      bool success = await _orderService.updateOrder(updatedOrder);
      if (success) {
        _showSnackBar('Cập nhật trạng thái thành công');
        // No need to reload - realtime listener will update automatically
      } else {
        _showSnackBar('Lỗi khi cập nhật trạng thái');
      }
    } catch (e) {
      _showSnackBar('Lỗi: $e');
    }
  }

  void _updateOrder(Order order) {
    // Navigate to create order page with existing order data
    Navigator.pushNamed(
      context,
      '/order/create_order',
      arguments: order, // Pass order data for editing
    ).then((_) {
      // Reload after returning
      final restaurantId = _localStorageService.getRestaurantId();
      if (restaurantId != null) {
        _loadOrdersRealtime(restaurantId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theo dõi đơn hàng'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? const Center(
              child: Text(
                'Không có đơn hàng nào đang hoạt động',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                final restaurantId = _localStorageService.getRestaurantId();
                if (restaurantId != null) {
                  await _loadOrdersRealtime(restaurantId);
                }
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length,
                itemBuilder: (context, index) {
                  final order = _orders[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Đơn hàng #${order.id.substring(0, 8)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      OrderStatusConfig.getStatusBackgroundColor(
                                        order.status,
                                      ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _getStatusColor(order.status),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      OrderStatusConfig.getStatusIcon(
                                        order.status,
                                      ),
                                      color: _getStatusColor(order.status),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getStatusText(order.status),
                                      style: TextStyle(
                                        color: _getStatusColor(order.status),
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
                            'Bàn: ${order.tableId}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Khách: ${order.customerName}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Tổng tiền: ${order.totalAmount.toStringAsFixed(0)} VND',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Món ăn:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...order.items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.name} x${item.quantity}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    '${(item.price * item.quantity).toStringAsFixed(0)} VND',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (order.status == OrderStatus.new_)
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _updateOrderStatus(
                                      order,
                                      OrderStatus.cooking,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Gửi xuống bếp'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _updateOrder(order),
                                    child: const Text('Cập nhật đơn'),
                                  ),
                                ),
                              ],
                            )
                          else if (order.status == OrderStatus.cooking)
                            ElevatedButton(
                              onPressed: () =>
                                  _updateOrderStatus(order, OrderStatus.done),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Đã hoàn thành'),
                            )
                          else if (order.status == OrderStatus.done)
                            const Text(
                              'Đơn hàng đã sẵn sàng phục vụ',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
