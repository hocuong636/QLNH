import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/order_service.dart';
import 'package:quanlynhahang/services/table_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/models/order.dart';
import 'package:quanlynhahang/models/table.dart';

class OrderPaymentPage extends StatefulWidget {
  const OrderPaymentPage({super.key});

  @override
  State<OrderPaymentPage> createState() => _OrderPaymentPageState();
}

class _OrderPaymentPageState extends State<OrderPaymentPage> {
  final OrderService _orderService = OrderService();
  final TableService _tableService = TableService();
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
          restaurantId = await _orderService.getRestaurantIdByOwnerId(userId);
        }
      }

      if (restaurantId != null && restaurantId.isNotEmpty) {
        _orders = await _orderService.getOrders(restaurantId);
        // Chỉ hiển thị đơn đã hoàn thành
        _orders = _orders
            .where((order) => order.status == OrderStatus.done)
            .toList();
        _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        _orders = [];
      }
    } catch (e) {
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

  void _showPaymentDialog(Order order) {
    String paymentMethod = 'cash'; // cash or transfer

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Thanh toán đơn #${order.id.substring(0, 8)}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chi tiết đơn hàng:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('${item.name} x${item.quantity}')),
                        Text(
                          '${(item.price * item.quantity).toStringAsFixed(0)} VND',
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
                const Text(
                  'Phương thức thanh toán:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                RadioListTile<String>(
                  title: const Text('Tiền mặt'),
                  value: 'cash',
                  groupValue: paymentMethod,
                  onChanged: (value) => setState(() => paymentMethod = value!),
                ),
                RadioListTile<String>(
                  title: const Text('Chuyển khoản'),
                  value: 'transfer',
                  groupValue: paymentMethod,
                  onChanged: (value) => setState(() => paymentMethod = value!),
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
              onPressed: () => _processPayment(order, paymentMethod),
              child: const Text('Xác nhận thanh toán'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment(Order order, String paymentMethod) async {
    try {
      // Cập nhật trạng thái đơn hàng thành paid
      Order updatedOrder = Order(
        id: order.id,
        restaurantId: order.restaurantId,
        tableId: order.tableId,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        items: order.items,
        totalAmount: order.totalAmount,
        status: OrderStatus.paid,
        notes: order.notes,
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
      );

      await _orderService.updateOrder(updatedOrder);

      // Giải phóng bàn
      String? restaurantId = _localStorageService.getRestaurantId();

      // If restaurantId is null, try to get it from userId
      if (restaurantId == null || restaurantId.isEmpty) {
        String? userId = _localStorageService.getUserId();
        if (userId != null) {
          restaurantId = await _orderService.getRestaurantIdByOwnerId(userId);
        }
      }

      if (restaurantId != null && restaurantId.isNotEmpty) {
        List<TableModel> tables = await _tableService.getTables(restaurantId);
        TableModel? table = tables.firstWhere(
          (t) => t.number.toString() == order.tableId,
        );

        TableModel updatedTable = TableModel(
          id: table.id,
          restaurantID: table.restaurantID,
          number: table.number,
          capacity: table.capacity,
          status: TableStatus.empty,
          createdAt: table.createdAt,
          updatedAt: DateTime.now(),
        );
        await _tableService.updateTable(updatedTable);
            }

      Navigator.of(context).pop();
      _showSnackBar('Thanh toán thành công');
      _loadOrders();
    } catch (e) {
      _showSnackBar('Lỗi khi thanh toán: $e');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán đơn hàng'),
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
          Icon(Icons.payment, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Không có đơn hàng nào cần thanh toán',
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
            onTap: () => _showPaymentDialog(order),
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
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Sẵn sàng thanh toán',
                          style: TextStyle(
                            color: Colors.green,
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
