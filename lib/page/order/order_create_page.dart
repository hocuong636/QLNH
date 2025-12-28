import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/table_service.dart';
import 'package:quanlynhahang/services/menu_service.dart';
import 'package:quanlynhahang/services/order_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/models/table.dart';
import 'package:quanlynhahang/models/menu_item.dart';
import 'package:quanlynhahang/models/order.dart';

class OrderCreatePage extends StatefulWidget {
  const OrderCreatePage({super.key});

  @override
  State<OrderCreatePage> createState() => _OrderCreatePageState();
}

class _OrderCreatePageState extends State<OrderCreatePage> {
  final TableService _tableService = TableService();
  final MenuService _menuService = MenuService();
  final OrderService _orderService = OrderService();
  final LocalStorageService _localStorageService = LocalStorageService();

  List<TableModel> _tables = [];
  List<MenuItem> _menuItems = [];
  final List<OrderItem> _cartItems = [];
  TableModel? _selectedTable;
  bool _isLoading = true;
  Order? _existingOrder; // For editing existing order

  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadExistingOrder();
  }

  Future<void> _loadExistingOrder() async {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Order && _existingOrder == null) {
      _existingOrder = arguments;
      _cartItems.addAll(_existingOrder!.items);
      _customerNameController.text = _existingOrder!.customerName;
      _customerPhoneController.text = _existingOrder!.customerPhone;
      _notesController.text = _existingOrder!.notes;

      // Set selected table
      if (_tables.isNotEmpty) {
        _selectedTable = _tables.firstWhere(
          (table) => table.number.toString() == _existingOrder!.tableId,
          orElse: () => _tables.first,
        );
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
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
        _tables = await _tableService.getTables(restaurantId);
        _tables = _tables
            .where((table) => table.status == TableStatus.occupied)
            .toList();
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectTable() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn bàn'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _tables.length,
            itemBuilder: (context, index) {
              final table = _tables[index];
              return ListTile(
                title: Text('Bàn ${table.number}'),
                subtitle: Text('${table.capacity} người'),
                onTap: () {
                  setState(() => _selectedTable = table);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }

  void _addToCart(MenuItem item) {
    showDialog(
      context: context,
      builder: (context) {
        final quantityController = TextEditingController(text: '1');
        final notesController = TextEditingController();

        return AlertDialog(
          title: Text('Thêm ${item.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Số lượng'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Ghi chú'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity = int.tryParse(quantityController.text) ?? 1;
                if (quantity > 0) {
                  setState(() {
                    _cartItems.add(
                      OrderItem(
                        name: item.name,
                        quantity: quantity,
                        price: item.price,
                      ),
                    );
                  });
                  Navigator.pop(context);
                  _showSnackBar('Đã thêm vào giỏ hàng');
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );
  }

  void _removeFromCart(int index) {
    setState(() => _cartItems.removeAt(index));
  }

  double _calculateTotal() {
    return _cartItems.fold(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );
  }

  Future<void> _createOrder() async {
    if (_selectedTable == null) {
      _showSnackBar('Vui lòng chọn bàn');
      return;
    }
    if (_cartItems.isEmpty) {
      _showSnackBar('Vui lòng thêm món ăn');
      return;
    }
    if (_customerNameController.text.isEmpty) {
      _showSnackBar('Vui lòng nhập tên khách hàng');
      return;
    }

    try {
      String? restaurantId = _localStorageService.getRestaurantId();

      // If restaurantId is null, try to get it from userId
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

      if (_existingOrder != null) {
        // Update existing order
        Order updatedOrder = _existingOrder!.copyWith(
          tableId: _selectedTable!.number.toString(),
          customerName: _customerNameController.text,
          customerPhone: _customerPhoneController.text,
          items: _cartItems,
          totalAmount: _calculateTotal(),
          notes: _notesController.text,
          updatedAt: DateTime.now(),
        );

        bool success = await _orderService.updateOrder(updatedOrder);
        if (success) {
          _showSnackBar('Cập nhật đơn hàng thành công');
          Navigator.pop(context);
        } else {
          _showSnackBar('Lỗi khi cập nhật đơn hàng');
        }
      } else {
        // Create new order
        Order newOrder = Order(
          id: '',
          restaurantId: restaurantId,
          tableId: _selectedTable!.number.toString(),
          customerName: _customerNameController.text,
          customerPhone: _customerPhoneController.text,
          items: _cartItems,
          totalAmount: _calculateTotal(),
          status: OrderStatus.new_,
          notes: _notesController.text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        print(
          'Creating order with restaurantId: $restaurantId, tableId: ${newOrder.tableId}',
        );
        String? orderId = await _orderService.createOrder(newOrder);
        print('Order created with ID: $orderId');
        if (orderId != null) {
          _showSnackBar('Tạo đơn hàng thành công');
          Navigator.pop(context);
        } else {
          _showSnackBar('Lỗi khi tạo đơn hàng');
        }
      }
    } catch (e) {
      _showSnackBar('Lỗi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _existingOrder != null ? 'Cập nhật đơn hàng' : 'Tạo đơn hàng',
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chọn bàn
                  Card(
                    child: ListTile(
                      title: const Text('Bàn'),
                      subtitle: Text(
                        _selectedTable != null
                            ? 'Bàn ${_selectedTable!.number}'
                            : 'Chọn bàn',
                      ),
                      trailing: const Icon(Icons.arrow_drop_down),
                      onTap: _selectTable,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Thông tin khách hàng
                  const Text(
                    'Thông tin khách hàng',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên khách hàng *',
                    ),
                  ),
                  TextField(
                    controller: _customerPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú đơn hàng',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Menu
                  const Text(
                    'Chọn món ăn',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: _menuItems.length,
                      itemBuilder: (context, index) {
                        final item = _menuItems[index];
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.price.toStringAsFixed(0)} VND',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => _addToCart(item),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Giỏ hàng
                  if (_cartItems.isNotEmpty) ...[
                    const Text(
                      'Giỏ hàng',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._cartItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Card(
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Text('Số lượng: ${item.quantity}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(item.price * item.quantity).toStringAsFixed(0)} VND',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeFromCart(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Text(
                      'Tổng cộng: ${_calculateTotal().toStringAsFixed(0)} VND',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: _cartItems.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _createOrder,
                child: Text(
                  _existingOrder != null ? 'Cập nhật đơn hàng' : 'Tạo đơn hàng',
                ),
              ),
            )
          : null,
    );
  }
}
