enum OrderStatus { new_, cooking, done, paid }

enum OrderItemStatus { pending, cooking, ready, served }

enum PaymentMethod { cash, payos, pending }

class OrderItem {
  final String menuItemId;  // ID của món ăn trong menu
  final String name;
  final int quantity;
  final double price;
  final OrderItemStatus itemStatus;
  final String? note;

  OrderItem({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.price,
    this.itemStatus = OrderItemStatus.pending,
    this.note,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      menuItemId: json['menuItemId'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
      itemStatus: _parseItemStatus(json['itemStatus']),
      note: json['note'],
    );
  }

  static OrderItemStatus _parseItemStatus(String? status) {
    switch (status) {
      case 'pending':
        return OrderItemStatus.pending;
      case 'cooking':
        return OrderItemStatus.cooking;
      case 'ready':
        return OrderItemStatus.ready;
      case 'served':
        return OrderItemStatus.served;
      default:
        return OrderItemStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'menuItemId': menuItemId,
      'name': name,
      'quantity': quantity,
      'price': price,
      'itemStatus': itemStatus.toString().split('.').last,
      'note': note,
    };
  }

  OrderItem copyWith({
    String? menuItemId,
    String? name,
    int? quantity,
    double? price,
    OrderItemStatus? itemStatus,
    String? note,
  }) {
    return OrderItem(
      menuItemId: menuItemId ?? this.menuItemId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      itemStatus: itemStatus ?? this.itemStatus,
      note: note ?? this.note,
    );
  }
}

class Order {
  final String id;
  final String restaurantId;
  final String tableId;
  final String customerName;
  final String customerPhone;
  final List<OrderItem> items;
  final double totalAmount;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final String? transactionId; // MoMo transaction ID
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? paidAt;

  Order({
    required this.id,
    required this.restaurantId,
    required this.tableId,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.totalAmount,
    required this.status,
    this.paymentMethod = PaymentMethod.pending,
    this.transactionId,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.paidAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      restaurantId: json['restaurantId'] ?? '',
      tableId: json['tableId'] ?? '',
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      items:
          (json['items'] as List<dynamic>?)?.map((item) {
            if (item is Map) {
              Map<dynamic, dynamic> rawItem = item as Map<dynamic, dynamic>;
              Map<String, dynamic> itemMap = {};
              rawItem.forEach((k, v) {
                itemMap[k.toString()] = v;
              });
              return OrderItem.fromJson(itemMap);
            }
            return OrderItem(name: '', quantity: 0, price: 0, menuItemId: '');
          }).toList() ??
          [],
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      status: _parseOrderStatus(json['status']),
      paymentMethod: _parsePaymentMethod(json['paymentMethod']),
      transactionId: json['transactionId'],
      notes: json['notes'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
    );
  }

  static PaymentMethod _parsePaymentMethod(String? method) {
    switch (method) {
      case 'cash':
        return PaymentMethod.cash;
      case 'payos':
      case 'momo': // backward compatibility
        return PaymentMethod.payos;
      default:
        return PaymentMethod.pending;
    }
  }

  static OrderStatus _parseOrderStatus(String? status) {
    switch (status) {
      case 'new':
        return OrderStatus.new_;
      case 'cooking':
        return OrderStatus.cooking;
      case 'done':
        return OrderStatus.done;
      case 'paid':
        return OrderStatus.paid;
      default:
        return OrderStatus.new_;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'tableId': tableId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'items': items.map((item) => item.toJson()).toList(),
      'totalAmount': totalAmount,
      'status': status.toString().split('.').last,
      'paymentMethod': paymentMethod.toString().split('.').last,
      'transactionId': transactionId,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
    };
  }

  Order copyWith({
    String? id,
    String? restaurantId,
    String? tableId,
    String? customerName,
    String? customerPhone,
    List<OrderItem>? items,
    double? totalAmount,
    OrderStatus? status,
    PaymentMethod? paymentMethod,
    String? transactionId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? paidAt,
  }) {
    return Order(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      tableId: tableId ?? this.tableId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionId: transactionId ?? this.transactionId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}
