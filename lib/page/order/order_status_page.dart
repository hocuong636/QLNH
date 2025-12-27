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
      print('Loading orders for restaurantId: $restaurantId');

      // If restaurantId is null, try to get it from userId (assuming order is linked to owner)
      if (restaurantId == null || restaurantId.isEmpty) {
        String? userId = _localStorageService.getUserId();
        if (userId != null) {
          restaurantId = await _orderService.getRestaurantIdByOwnerId(userId);
          print('Got restaurantId from userId: $restaurantId');
        }
      }

      if (restaurantId != null && restaurantId.isNotEmpty) {
        print('About to call getOrders with restaurantId: $restaurantId');
        _orders = await _orderService.getOrders(restaurantId);
        print('Loaded ${_orders.length} orders from database');
        // Chỉ hiển thị đơn đang phục vụ (chưa thanh toán)
        _orders = _orders
            .where((order) => order.status != OrderStatus.paid)
            .toList();
        print('Filtered to ${_orders.length} orders for display');
        _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        print(
          'RestaurantId is still null or empty - trying to load all orders for debugging',
        );
        // Temporarily load all orders to debug
        _orders = await _orderService.getOrders(
          '',
        ); // This will load all and filter in service
        print('Loaded all ${_orders.length} orders for debugging');
      }
    } catch (e) {
      print('Error loading orders: $e');
      _showSnackBar('Lỗi khi tải danh sách đơn hàng: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showOrderDetails(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Đơn hàng #${order.id.substring(0, 8)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Khách hàng:', order.customerName),
              _buildDetailRow('Số điện thoại:', order.customerPhone),
              _buildDetailRow('Bàn:', order.tableId),
              _buildDetailRow('Thời gian:', _formatDateTime(order.createdAt)),
              const SizedBox(height: 16),
              const Text(
                'Món ăn:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...order.items.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${entry.value.name} x${entry.value.quantity}',
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${(entry.value.price * entry.value.quantity).toStringAsFixed(0)} VND',
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16),
                            onPressed: () =>
                                _editItemQuantity(order, entry.key),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              size: 16,
                              color: Colors.red,
                            ),
                            onPressed: () => _removeItem(order, entry.key),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng cộng:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${order.totalAmount.toStringAsFixed(0)} VND',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                'Ghi chú:',
                order.notes.isEmpty ? 'Không có' : order.notes,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _updateOrderStatus(order, OrderStatus.cooking);
              Navigator.of(context).pop();
            },
            child: const Text('Gửi bếp'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _editItemQuantity(Order order, int itemIndex) async {
    final item = order.items[itemIndex];
    final quantityController = TextEditingController(
      text: item.quantity.toString(),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sửa số lượng ${item.name}'),
        content: TextField(
          controller: quantityController,
          decoration: const InputDecoration(labelText: 'Số lượng'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newQuantity =
                  int.tryParse(quantityController.text) ?? item.quantity;
              if (newQuantity > 0) {
                await _updateItemQuantity(order, itemIndex, newQuantity);
                Navigator.pop(context);
              }
            },
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateItemQuantity(
    Order order,
    int itemIndex,
    int newQuantity,
  ) async {
    try {
      List<OrderItem> updatedItems = List.from(order.items);
      updatedItems[itemIndex] = OrderItem(
        name: updatedItems[itemIndex].name,
        quantity: newQuantity,
        price: updatedItems[itemIndex].price,
      );

      double newTotal = updatedItems.fold(
        0,
        (sum, item) => sum + (item.price * item.quantity),
      );

      Order updatedOrder = Order(
        id: order.id,
        restaurantId: order.restaurantId,
        tableId: order.tableId,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        items: updatedItems,
        totalAmount: newTotal,
        status: order.status,
        notes: order.notes,
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
      );

      await _orderService.updateOrder(updatedOrder);
      _showSnackBar('Cập nhật số lượng thành công');
      _loadOrders();
    } catch (e) {
      _showSnackBar('Lỗi khi cập nhật: $e');
    }
  }

  Future<void> _removeItem(Order order, int itemIndex) async {
    try {
      List<OrderItem> updatedItems = List.from(order.items);
      updatedItems.removeAt(itemIndex);

      double newTotal = updatedItems.fold(
        0,
        (sum, item) => sum + (item.price * item.quantity),
      );

      Order updatedOrder = Order(
        id: order.id,
        restaurantId: order.restaurantId,
        tableId: order.tableId,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        items: updatedItems,
        totalAmount: newTotal,
        status: order.status,
        notes: order.notes,
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
      );

      await _orderService.updateOrder(updatedOrder);
      _showSnackBar('Xóa món thành công');
      _loadOrders();
    } catch (e) {
      _showSnackBar('Lỗi khi xóa: $e');
    }
  }

  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    try {
      Order updatedOrder = Order(
        id: order.id,
        restaurantId: order.restaurantId,
        tableId: order.tableId,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        items: order.items,
        totalAmount: order.totalAmount,
        status: newStatus,
        notes: order.notes,
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
      );

      await _orderService.updateOrder(updatedOrder);
      _showSnackBar('Cập nhật trạng thái thành công');
      _loadOrders();
    } catch (e) {
      _showSnackBar('Lỗi khi cập nhật trạng thái: $e');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
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
        return Colors.purple;
    }
  }

  String _getStatusDisplayName(OrderStatus status) {
    switch (status) {
      case OrderStatus.new_:
        return 'Mới';
      case OrderStatus.cooking:
        return 'Đang nấu';
      case OrderStatus.done:
        return 'Hoàn thành';
      case OrderStatus.paid:
        return 'Đã thanh toán';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trạng thái đơn hàng'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? _buildEmptyState()
          : _buildOrderList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Không có đơn hàng nào',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showOrderDetails(order),
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
                        '#${order.id.substring(0, 8)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusDisplayName(order.status),
                          style: TextStyle(
                            color: _getStatusColor(order.status),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    order.customerName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bàn ${order.tableId}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${order.totalAmount.toStringAsFixed(0)} VND',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(order.createdAt),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${order.items.length} món',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
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
