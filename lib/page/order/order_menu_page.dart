import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/constants/user_roles.dart';

class OrderMenuPage extends StatefulWidget {
  final String tableId;
  final String tableNumber;
  final String capacity;

  const OrderMenuPage({
    Key? key,
    required this.tableId,
    required this.tableNumber,
    required this.capacity,
  }) : super(key: key);

  @override
  State<OrderMenuPage> createState() => _OrderMenuPageState();
}

class _OrderMenuPageState extends State<OrderMenuPage> {
  final _dbRef = FirebaseDatabase.instance.ref();
  final _localStorageService = LocalStorageService();
  
  Map<String, Map<String, dynamic>> _cart = {};
  bool _isSubmitting = false;

  void _addToCart(String menuId, String name, num price) {
    setState(() {
      if (_cart.containsKey(menuId)) {
        _cart[menuId]!['quantity'] += 1;
      } else {
        _cart[menuId] = {
          'name': name,
          'price': price,
          'quantity': 1,
        };
      }
    });
  }

  void _updateCartQuantity(String menuId, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _cart.remove(menuId);
      } else {
        _cart[menuId]!['quantity'] = quantity;
      }
    });
  }

  void _removeFromCart(String menuId) {
    setState(() {
      _cart.remove(menuId);
    });
  }

  double _calculateTotal() {
    double total = 0;
    _cart.forEach((key, item) {
      total += (item['price'] as num) * item['quantity'];
    });
    return total;
  }

  Future<void> _submitOrder() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất một món')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? resID = _localStorageService.getUserResId();
      String? staffId = await _localStorageService.getUserId();
      String? staffName = await _localStorageService.getUserName();

      final items = _cart.entries.map((e) {
        return {
          'menuId': e.key,
          'name': e.value['name'],
          'price': e.value['price'],
          'quantity': e.value['quantity'],
          'total': (e.value['price'] as num) * e.value['quantity'],
        };
      }).toList();

      final orderData = {
        'restaurantId': resID,
        'tableId': widget.tableId,
        'staffId': staffId,
        'staffName': staffName ?? 'N/A',
        'items': items,
        'totalPrice': _calculateTotal(),
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      };

      final ordersRef = _dbRef.child('orders').push();
      await ordersRef.set(orderData);

      // Cập nhật trạng thái bàn thành "occupied"
      await _dbRef.child('tables/${widget.tableId}').update({
        'status': 'occupied',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gửi đơn hàng thành công!'),
          backgroundColor: Colors.green,
        ),
      );

      // Quay lại trang chọn bàn
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_cart.isNotEmpty) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Hủy đơn hàng?'),
              content: const Text('Giỏ hàng của bạn sẽ bị xóa'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Tiếp tục'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Hủy'),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue.shade700,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bàn ${widget.tableNumber}'),
              Text(
                'Sức chứa: ${widget.capacity} người',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          elevation: 0,
        ),
        body: Row(
          children: [
            // Menu
            Expanded(
              flex: 2,
              child: _buildMenuSection(),
            ),
            
            // Divider
            VerticalDivider(
              width: 1,
              color: Colors.grey.shade300,
            ),
            
            // Giỏ hàng
            Expanded(
              flex: 1,
              child: _buildCartSection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    String? resID = _localStorageService.getUserResId();
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade100,
          child: const Text(
            'Menu',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: _dbRef.child('menus').orderByChild('restaurantId').equalTo(resID).onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || !snapshot.data!.snapshot.exists) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text(
                        'Không có menu',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
              final menus = data.entries
                  .map((e) => MapEntry(e.key as String, e.value as Map<dynamic, dynamic>))
                  .toList();

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: menus.length,
                itemBuilder: (context, index) {
                  final menuId = menus[index].key;
                  final menu = menus[index].value;
                  final price = menu['price'] is num ? menu['price'] : 0;
                  final name = menu['name']?.toString() ?? 'Không có tên';

                  return GestureDetector(
                    onTap: () => _addToCart(menuId, name, price as num),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  topRight: Radius.circular(10),
                                ),
                              ),
                              child: menu['image'] != null
                                  ? Image.network(
                                      menu['image'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Icon(
                                          Icons.fastfood,
                                          size: 40,
                                          color: Colors.blue.shade700,
                                        );
                                      },
                                    )
                                  : Icon(
                                      Icons.fastfood,
                                      size: 40,
                                      color: Colors.blue.shade700,
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
                                    name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '₫${price.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade700,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCartSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade100,
          child: const Text(
            'Giỏ Hàng',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: _cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text(
                        'Giỏ trống',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _cart.length,
                  itemBuilder: (context, index) {
                    final menuId = _cart.keys.toList()[index];
                    final item = _cart[menuId];
                    
                    if (item == null) return const SizedBox();
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item['name'] as String? ?? 'Không có tên',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _removeFromCart(menuId),
                                  child: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '₫${((item['price'] as num?) ?? 0).toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _updateCartQuantity(menuId, (item['quantity'] as int? ?? 0) - 1),
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Icon(
                                            Icons.remove,
                                            size: 14,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 24,
                                        child: Center(
                                          child: Text(
                                            '${item['quantity'] as int? ?? 0}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _updateCartQuantity(menuId, (item['quantity'] as int? ?? 0) + 1),
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Icon(
                                            Icons.add,
                                            size: 14,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
            color: Colors.grey.shade50,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    '₫${_calculateTotal().toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitOrder,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(_isSubmitting ? 'Đang gửi...' : 'Đặt Hàng'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
