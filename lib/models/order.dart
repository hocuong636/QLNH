enum OrderStatus { new_, cooking, done, paid }

class OrderItem {
  final String name;
  final int quantity;
  final double price;

  OrderItem({required this.name, required this.quantity, required this.price});

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'quantity': quantity, 'price': price};
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
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order({
    required this.id,
    required this.restaurantId,
    required this.tableId,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
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
            return OrderItem(name: '', quantity: 0, price: 0);
          }).toList() ??
          [],
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      status: _parseOrderStatus(json['status']),
      notes: json['notes'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
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
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
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
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
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
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
