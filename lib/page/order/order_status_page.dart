import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/order_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/models/order.dart';

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

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
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
        _orders = await _orderService.getOrders(restaurantId);
        // Lọc chỉ lấy đơn hàng đang active (chưa thanh toán)
        _orders = _orders
            .where((order) => order.status != OrderStatus.paid)
            .toList();
      } else {
        _orders = [];
      }
    } catch (e) {
      _showSnackBar('Lỗi khi tải đơn hàng: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.new_:
        return 'Mới';
      case OrderStatus.cooking:
        return 'Đang chế biến';
      case OrderStatus.done:
        return 'Hoàn thành';
      case OrderStatus.paid:
        return 'Đã thanh toán';
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.new_:
        return Colors.blue;
      case OrderStatus.cooking:
        return Colors.orange;
      case OrderStatus.done:
        return Colors.green;
      case OrderStatus.paid:
        return Colors.grey;
    }
  }

  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    try {
      Order updatedOrder = order.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      bool success = await _orderService.updateOrder(updatedOrder);
      if (success) {
        _showSnackBar('Cập nhật trạng thái thành công');
        _loadOrders(); // Reload để cập nhật UI
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
    ).then((_) => _loadOrders()); // Reload after returning
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
              onRefresh: _loadOrders,
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
                              Text(
                                'Đơn hàng #${order.id.substring(0, 8)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(order.status),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getStatusText(order.status),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
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
