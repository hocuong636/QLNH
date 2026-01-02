import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quanlynhahang/services/menu_service.dart';
import 'package:quanlynhahang/services/order_service.dart';
import 'package:quanlynhahang/services/table_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/services/payment_service.dart';
import 'package:quanlynhahang/models/menu_item.dart';
import 'package:quanlynhahang/models/table.dart';
import 'package:quanlynhahang/models/order.dart';

class OrderTableDetailPage extends StatefulWidget {
  final TableModel table;

  const OrderTableDetailPage({super.key, required this.table});

  @override
  State<OrderTableDetailPage> createState() => _OrderTableDetailPageState();
}

class _OrderTableDetailPageState extends State<OrderTableDetailPage>
    with SingleTickerProviderStateMixin {
  final MenuService _menuService = MenuService();
  final OrderService _orderService = OrderService();
  final TableService _tableService = TableService();
  final LocalStorageService _localStorageService = LocalStorageService();
  final PaymentService _paymentService = PaymentService();

  late TabController _tabController;
  
  Order? _currentOrder;
  List<MenuItem> _menuItems = [];
  List<OrderItem> _newItems = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _selectedCategory = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      String? restaurantId = _localStorageService.getRestaurantId();
      
      if (restaurantId == null || restaurantId.isEmpty) {
        String? userId = _localStorageService.getUserId();
        if (userId != null) {
          restaurantId = await _orderService.getRestaurantIdByUserId(userId);
        }
      }

      if (restaurantId != null && restaurantId.isNotEmpty) {
        // Load current order for this table
        _currentOrder = await _orderService.getActiveOrderByTable(
          restaurantId, 
          widget.table.number.toString()
        );
        
        // Load menu items
        _menuItems = await _menuService.getMenuItems(restaurantId);
        _menuItems = _menuItems.where((item) => item.isAvailable).toList();
      }
    } catch (e) {
      _showSnackBar('Lỗi khi tải dữ liệu: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
        return 'Sẵn sàng';
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

  List<String> _getCategories() {
    Set<String> categories = {'Tất cả'};
    for (var item in _menuItems) {
      categories.add(item.category);
    }
    return categories.toList();
  }

  List<MenuItem> _getFilteredItems() {
    if (_selectedCategory == 'Tất cả') {
      return _menuItems;
    }
    return _menuItems.where((item) => item.category == _selectedCategory).toList();
  }

  void _addToNewItems(MenuItem item) {
    int quantity = 1;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item.price.toStringAsFixed(0)} đ',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: quantity > 1 ? Colors.red.shade50 : Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: quantity > 1
                              ? () => setDialogState(() => quantity--)
                              : null,
                          icon: Icon(
                            Icons.remove,
                            color: quantity > 1 ? Colors.red : Colors.grey,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$quantity',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () => setDialogState(() => quantity++),
                          icon: const Icon(Icons.add, color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    int existingIndex = _newItems.indexWhere((i) => i.menuItemId == item.id);
                    if (existingIndex != -1) {
                      _newItems[existingIndex] = OrderItem(
                        menuItemId: _newItems[existingIndex].menuItemId,
                        name: _newItems[existingIndex].name,
                        quantity: _newItems[existingIndex].quantity + quantity,
                        price: _newItems[existingIndex].price,
                      );
                    } else {
                      _newItems.add(OrderItem(
                        menuItemId: item.id,
                        name: item.name,
                        quantity: quantity,
                        price: item.price,
                      ));
                    }
                    Navigator.pop(dialogContext);
                    setState(() {});
                    _showSnackBar('Đã thêm ${item.name} x$quantity');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Thêm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _removeNewItem(int index) {
    setState(() => _newItems.removeAt(index));
  }

  double _calculateNewItemsTotal() {
    return _newItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  Future<void> _removeOrderItem(int index) async {
    final item = _currentOrder!.items[index];
    
    // Chỉ cho phép xóa món chưa hoàn thành
    if (item.itemStatus == OrderItemStatus.served) {
      _showSnackBar('Không thể xóa món đã phục vụ');
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa món'),
        content: Text('Bạn có chắc muốn xóa "${item.name}" khỏi đơn hàng?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        List<OrderItem> updatedItems = List.from(_currentOrder!.items);
        updatedItems.removeAt(index);
        
        double newTotal = updatedItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
        
        Order updatedOrder = _currentOrder!.copyWith(
          items: updatedItems,
          totalAmount: newTotal,
          updatedAt: DateTime.now(),
        );

        bool success = await _orderService.updateOrder(updatedOrder);
        
        if (success) {
          _showSnackBar('Đã xóa ${item.name}');
          await _loadData();
        } else {
          _showSnackBar('Lỗi khi xóa món');
        }
      } catch (e) {
        _showSnackBar('Lỗi: $e');
      }
    }
  }

  void _handlePayment() {
    if (_currentOrder == null) {
      _showSnackBar('Chưa có đơn hàng để thanh toán');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildPaymentSheet(),
    );
  }

  Widget _buildPaymentSheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          Row(
            children: [
              Icon(Icons.payment, color: Colors.blue.shade600, size: 28),
              const SizedBox(width: 12),
              Text(
                'Thanh toán Bàn ${widget.table.number}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Order summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildPaymentRow('Số món:', '${_currentOrder!.items.length} món'),
                const Divider(height: 16),
                _buildPaymentRow(
                  'Tổng tiền:',
                  '${_formatCurrency(_currentOrder!.totalAmount)} đ',
                  isBold: true,
                  valueColor: Colors.orange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Payment methods title
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Chọn phương thức thanh toán',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          
          // Cash payment option
          _buildPaymentMethodCard(
            icon: Icons.money,
            iconColor: Colors.green,
            title: 'Tiền mặt',
            subtitle: 'Thanh toán trực tiếp tại quầy',
            onTap: () => _processPayment(PaymentMethod.cash),
          ),
          const SizedBox(height: 12),
          
          // PayOS payment option
          _buildPaymentMethodCard(
            icon: Icons.qr_code_scanner,
            iconColor: const Color(0xFF1E88E5), // PayOS blue
            title: 'PayOS',
            subtitle: 'QR Code - Ngân hàng - Ví điện tử',
            onTap: () => _processPayment(PaymentMethod.payos),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E88E5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PayOS',
                style: TextStyle(
                  color: Color(0xFF1E88E5),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Cancel button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment(PaymentMethod method) async {
    Navigator.pop(context); // Close bottom sheet
    
    if (method == PaymentMethod.cash) {
      // Show loading dialog for cash
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang xử lý thanh toán tiền mặt...'),
            ],
          ),
        ),
      );

      final result = await _paymentService.payWithCash(_currentOrder!);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (result.success) {
        await _updateOrderAsPaid(method, result.transactionId);
      } else {
        _showPaymentErrorDialog(result.message ?? 'Lỗi không xác định');
      }
    } else if (method == PaymentMethod.payos) {
      // PayOS payment - Show QR code
      _showPayOSQRCodeDialog();
    }
  }

  void _showPayOSQRCodeDialog() async {
    // Show loading first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF1E88E5)),
            SizedBox(height: 16),
            Text('Đang tạo mã thanh toán...'),
          ],
        ),
      ),
    );
    
    // Create pending payment in Firebase
    await _paymentService.createPendingPayment(_currentOrder!);
    
    // Create PayOS payment
    final payosResponse = await _paymentService.createPayOSPayment(_currentOrder!);
    
    // Close loading dialog
    if (mounted) Navigator.pop(context);
    
    if (!payosResponse.success) {
      // Nếu PayOS API lỗi, fallback sang QR thủ công
      final orderCode = 'ORD${DateTime.now().millisecondsSinceEpoch % 1000000}';
      final qrData = _paymentService.generatePayOSQRData(_currentOrder!, orderCode);
      
      _showPayOSQRDialog(
        qrData: qrData,
        orderCode: orderCode,
        paymentUrl: null,
        isFallback: true,
      );
    } else {
      _showPayOSQRDialog(
        qrData: payosResponse.qrCode ?? payosResponse.paymentUrl ?? '',
        orderCode: payosResponse.orderCode ?? '',
        paymentUrl: payosResponse.paymentUrl,
        isFallback: false,
      );
    }
  }
  
  void _showPayOSQRDialog({
    required String qrData,
    required String orderCode,
    String? paymentUrl,
    required bool isFallback,
  }) {
    final amount = _currentOrder!.totalAmount;
    final restaurantId = _currentOrder!.restaurantId;
    final orderId = _currentOrder!.id;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _PayOSQRDialog(
        qrData: qrData,
        orderCode: orderCode,
        paymentUrl: paymentUrl,
        amount: amount,
        tableNumber: widget.table.number,
        orderId: orderId,
        restaurantId: restaurantId,
        paymentService: _paymentService,
        isFallback: isFallback,
        onPaymentConfirmed: (transactionId) async {
          Navigator.pop(dialogContext);
          await _updateOrderAsPaid(PaymentMethod.payos, transactionId);
        },
        onCancel: () async {
          await _paymentService.cancelPendingPayment(restaurantId, orderId);
          Navigator.pop(dialogContext);
        },
      ),
    );
  }

  Future<void> _updateOrderAsPaid(PaymentMethod method, String? transactionId) async {
    try {
      final updatedOrder = _currentOrder!.copyWith(
        status: OrderStatus.paid,
        paymentMethod: method,
        transactionId: transactionId,
        paidAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await _orderService.updateOrder(updatedOrder);
      
      if (success) {
        // Cập nhật trạng thái bàn về trống
        await _resetTableStatus();
        
        if (mounted) {
          _showPaymentSuccessDialog(method, transactionId);
        }
      } else {
        _showSnackBar('Lỗi khi cập nhật đơn hàng');
      }
    } catch (e) {
      _showSnackBar('Lỗi: $e');
    }
  }

  Future<void> _resetTableStatus() async {
    try {
      final updatedTable = TableModel(
        id: widget.table.id,
        restaurantID: widget.table.restaurantID,
        number: widget.table.number,
        capacity: widget.table.capacity,
        status: TableStatus.empty,
        createdAt: widget.table.createdAt,
        updatedAt: DateTime.now(),
      );
      await _tableService.updateTable(updatedTable);
    } catch (e) {
      print('Error resetting table: $e');
    }
  }

  void _showPaymentSuccessDialog(PaymentMethod method, String? transactionId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Thanh toán thành công!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              method == PaymentMethod.cash ? 'Tiền mặt' : 'PayOS',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '${_formatCurrency(_currentOrder!.totalAmount)} đ',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            if (transactionId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Mã GD: ${transactionId.substring(0, transactionId.length > 12 ? 12 : transactionId.length)}...',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Close dialog safely
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close success dialog
                  if (context.mounted) {
                    Navigator.of(context).pop(true); // Return to order page with reload
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Hoàn tất'),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red.shade600,
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Thanh toán thất bại',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handlePayment(); // Try again
            },
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatter = amount.toStringAsFixed(0);
    final result = StringBuffer();
    int count = 0;
    for (int i = formatter.length - 1; i >= 0; i--) {
      result.write(formatter[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        result.write('.');
      }
    }
    return result.toString().split('').reversed.join();
  }

  Widget _buildPaymentRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
        Text(
          value, 
          style: TextStyle(
            fontSize: isBold ? 18 : 16, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Future<void> _submitNewItems() async {
    if (_newItems.isEmpty) {
      _showSnackBar('Vui lòng thêm món ăn');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? restaurantId = _localStorageService.getRestaurantId();

      if (restaurantId == null || restaurantId.isEmpty) {
        String? userId = _localStorageService.getUserId();
        if (userId != null) {
          restaurantId = await _orderService.getRestaurantIdByUserId(userId);
        }
      }

      if (restaurantId == null || restaurantId.isEmpty) {
        _showSnackBar('Không tìm thấy thông tin nhà hàng');
        return;
      }

      if (_currentOrder != null) {
        // Add items to existing order
        List<OrderItem> updatedItems = [..._currentOrder!.items, ..._newItems];
        double newTotal = updatedItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
        
        Order updatedOrder = _currentOrder!.copyWith(
          items: updatedItems,
          totalAmount: newTotal,
          updatedAt: DateTime.now(),
        );

        bool success = await _orderService.updateOrder(updatedOrder);
        
        if (success && mounted) {
          _showSnackBar('Đã thêm ${_newItems.length} món vào đơn hàng!');
          _newItems.clear();
          await _loadData();
          _tabController.animateTo(0); // Switch to order detail tab
        } else {
          _showSnackBar('Lỗi khi cập nhật đơn hàng');
        }
      } else {
        // Create new order
        Order newOrder = Order(
          id: '',
          restaurantId: restaurantId,
          tableId: widget.table.number.toString(),
          customerName: 'Khách',
          customerPhone: '',
          items: _newItems,
          totalAmount: _calculateNewItemsTotal(),
          status: OrderStatus.cooking,
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        String? orderId = await _orderService.createOrder(newOrder);
        
        if (orderId != null && mounted) {
          _showSnackBar('Đã tạo đơn hàng mới!');
          _newItems.clear();
          await _loadData();
          _tabController.animateTo(0);
        } else {
          _showSnackBar('Lỗi khi tạo đơn hàng');
        }
      }
    } catch (e) {
      _showSnackBar('Lỗi: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bàn ${widget.table.number}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_currentOrder != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: _handlePayment,
                icon: const Icon(Icons.payment, size: 18),
                label: const Text('Thanh toán'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue.shade700,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.blue.shade700,
          tabs: [
            Tab(
              icon: const Icon(Icons.receipt_long),
              text: 'Đơn hàng${_currentOrder != null ? ' (${_currentOrder!.items.length})' : ''}',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: _newItems.isNotEmpty,
                label: Text('${_newItems.length}'),
                child: const Icon(Icons.add_shopping_cart),
              ),
              text: 'Thêm món',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrderDetailTab(),
                _buildAddItemsTab(),
              ],
            ),
      bottomNavigationBar: _newItems.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Món mới: ${_newItems.length}',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                          Text(
                            '${_calculateNewItemsTotal().toStringAsFixed(0)} đ',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitNewItems,
                      icon: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(_currentOrder != null ? 'Gửi bếp' : 'Tạo đơn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildOrderDetailTab() {
    if (_currentOrder == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Chưa có đơn hàng',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Chuyển sang tab "Thêm món" để tạo đơn hàng mới',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.add),
              label: const Text('Thêm món'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Order info card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Đơn #${_currentOrder!.id.substring(0, 8)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getOrderStatusColor(_currentOrder!.status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getOrderStatusText(_currentOrder!.status),
                          style: TextStyle(
                            color: _getOrderStatusColor(_currentOrder!.status),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Khách: ${_currentOrder!.customerName}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  if (_currentOrder!.customerPhone.isNotEmpty)
                    Text(
                      'SĐT: ${_currentOrder!.customerPhone}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Items header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Các món đã đặt',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_currentOrder!.items.length} món',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Items list
          ..._currentOrder!.items.asMap().entries.map((entry) => 
            _buildOrderItemCard(entry.value, entry.key)
          ),
          
          const SizedBox(height: 16),
          
          // Total
          Card(
            color: Colors.orange.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng cộng',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_currentOrder!.totalAmount.toStringAsFixed(0)} đ',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemCard(OrderItem item, int index) {
    final bool canDelete = item.itemStatus != OrderItemStatus.served;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Status indicator
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getItemStatusColor(item.itemStatus).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getItemStatusIcon(item.itemStatus),
                color: _getItemStatusColor(item.itemStatus),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Item details
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getItemStatusColor(item.itemStatus).withOpacity(0.15),
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
                ],
              ),
            ),
            // Quantity and price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'x${item.quantity}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${(item.price * item.quantity).toStringAsFixed(0)} đ',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            // Delete button for incomplete items
            if (canDelete) ...[
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _removeOrderItem(index),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getOrderStatusColor(OrderStatus status) {
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

  String _getOrderStatusText(OrderStatus status) {
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

  Widget _buildAddItemsTab() {
    return Column(
      children: [
        // Category filter
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _getCategories().map((category) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(category),
                  selected: _selectedCategory == category,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = category);
                  },
                  backgroundColor: Colors.grey.shade100,
                  selectedColor: Colors.blue.shade100,
                  checkmarkColor: Colors.blue,
                  labelStyle: TextStyle(
                    color: _selectedCategory == category
                        ? Colors.blue.shade700
                        : Colors.grey.shade700,
                    fontWeight: _selectedCategory == category
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        
        // New items preview
        if (_newItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Món đã chọn:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _newItems.asMap().entries.map((entry) {
                    return Chip(
                      label: Text('${entry.value.name} x${entry.value.quantity}'),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeNewItem(entry.key),
                      backgroundColor: Colors.green.shade50,
                      deleteIconColor: Colors.red,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        
        // Menu grid
        Expanded(
          child: _getFilteredItems().isEmpty
              ? const Center(
                  child: Text(
                    'Không có món ăn nào',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: _getFilteredItems().length,
                  itemBuilder: (context, index) {
                    final item = _getFilteredItems()[index];
                    return _buildMenuItemCard(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMenuItemCard(MenuItem item) {
    int itemCount = _newItems
        .where((i) => i.menuItemId == item.id)
        .fold(0, (sum, i) => sum + i.quantity);
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _addToNewItems(item),
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: item.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.restaurant, size: 50, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.restaurant, size: 50, color: Colors.grey),
                          ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.price.toStringAsFixed(0)} đ',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add, color: Colors.green, size: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Badge showing item count
            if (itemCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$itemCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dialog hiển thị QR code PayOS với auto-update khi thanh toán thành công
class _PayOSQRDialog extends StatefulWidget {
  final String qrData;
  final String orderCode;
  final String? paymentUrl;
  final double amount;
  final int tableNumber;
  final String orderId;
  final String restaurantId;
  final PaymentService paymentService;
  final bool isFallback;
  final Function(String transactionId) onPaymentConfirmed;
  final VoidCallback onCancel;

  const _PayOSQRDialog({
    required this.qrData,
    required this.orderCode,
    this.paymentUrl,
    required this.amount,
    required this.tableNumber,
    required this.orderId,
    required this.restaurantId,
    required this.paymentService,
    required this.isFallback,
    required this.onPaymentConfirmed,
    required this.onCancel,
  });

  @override
  State<_PayOSQRDialog> createState() => _PayOSQRDialogState();
}

class _PayOSQRDialogState extends State<_PayOSQRDialog> {
  bool _isWaiting = true;
  String _statusText = 'Đang chờ thanh toán...';
  bool _isCheckingStatus = false;
  bool _isConfirmed = false; // Flag to prevent multiple calls
  StreamSubscription? _paymentListener;

  @override
  void initState() {
    super.initState();
    _listenPaymentStatus();
    // Nếu không phải fallback, poll PayOS API
    if (!widget.isFallback) {
      _startPollingPayOSStatus();
    }
  }
  
  @override
  void dispose() {
    _paymentListener?.cancel();
    super.dispose();
  }

  void _listenPaymentStatus() {
    _paymentListener = widget.paymentService
        .listenPaymentStatus(widget.restaurantId, widget.orderId)
        .listen((event) {
      if (!mounted || _isConfirmed) return;
      
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && data['status'] == 'completed') {
        if (!mounted || _isConfirmed) return;
        
        _isConfirmed = true; // Mark as confirmed to prevent duplicate calls
        
        setState(() {
          _isWaiting = false;
          _statusText = 'Thanh toán thành công!';
        });
        
        // Auto confirm - simplified approach
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && _isConfirmed) {
            final transactionId = data['transactionId'] ?? 'PAYOS_${DateTime.now().millisecondsSinceEpoch}';
            widget.onPaymentConfirmed(transactionId);
          }
        });
      }
    });
  }
  
  void _startPollingPayOSStatus() async {
    while (mounted && _isWaiting && !_isConfirmed) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted || !_isWaiting || _isConfirmed) break;
      
      final status = await widget.paymentService.checkPayOSPaymentStatus(widget.orderCode);
      if (status.isPaid && mounted && !_isConfirmed) {
        _isConfirmed = true; // Mark as confirmed
        
        setState(() {
          _isWaiting = false;
          _statusText = 'Thanh toán thành công!';
        });
        
        // Cập nhật Firebase
        await widget.paymentService.confirmPayment(
          widget.restaurantId, 
          widget.orderId, 
          status.transactionId ?? 'PAYOS_${widget.orderCode}'
        );
        
        // Wait and close dialog
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && _isConfirmed) {
            widget.onPaymentConfirmed(status.transactionId ?? 'PAYOS_${widget.orderCode}');
          }
        });
        break;
      }
    }
  }

  String _formatCurrency(double amount) {
    String result = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    int count = 0;
    for (int i = result.length - 1; i >= 0; i--) {
      buffer.write(result[i]);
      count++;
      if (count == 3 && i > 0) {
        buffer.write('.');
        count = 0;
      }
    }
    return buffer.toString().split('').reversed.join('');
  }
  
  Future<void> _openPaymentUrl() async {
    if (widget.paymentUrl != null) {
      final uri = Uri.parse(widget.paymentUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 350),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // PayOS logo
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E88E5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'PayOS',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E88E5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _isWaiting ? Colors.orange.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isWaiting)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _statusText,
                      style: TextStyle(
                        color: _isWaiting ? Colors.orange.shade700 : Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              const Text(
                'Quét mã QR để thanh toán',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              
              // QR Code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: CustomPaint(
                    size: const Size(200, 200),
                    painter: QrPainter(
                      data: widget.qrData,
                      version: QrVersions.auto,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      color: Colors.black,
                      emptyColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Amount
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Số tiền: ', style: TextStyle(fontSize: 16)),
                    Text(
                      '${_formatCurrency(widget.amount)} đ',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E88E5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Order info
              Text(
                'Bàn ${widget.tableNumber} - Mã: ${widget.orderCode}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              
              // Payment URL button (if available)
              if (widget.paymentUrl != null) ...[
                OutlinedButton.icon(
                  onPressed: _openPaymentUrl,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Mở trang thanh toán'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E88E5),
                    side: const BorderSide(color: Color(0xFF1E88E5)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              
              // Instructions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                        const SizedBox(width: 8),
                        const Text('Hướng dẫn', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Mở app Ngân hàng hoặc Ví điện tử\n'
                      '2. Chọn "Quét mã QR"\n'
                      '3. Quét mã QR bên trên\n'
                      '4. Xác nhận thanh toán',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Supported banks/wallets
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Hỗ trợ thanh toán qua',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'VietQR • Momo • ZaloPay • VNPay • Thẻ ATM',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isConfirmed ? null : () {
                        if (_isConfirmed) return;
                        _isConfirmed = true;
                        
                        // Manual confirm payment
                        final transactionId = 'PAYOS_${DateTime.now().millisecondsSinceEpoch}';
                        widget.onPaymentConfirmed(transactionId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Xác nhận đã nhận tiền'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
