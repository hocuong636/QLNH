class InventoryItem {
  final String id;
  final String restaurantId;
  final String name;
  final double quantity;
  final String unit;
  final double minThreshold;
  final String supplier;
  final String notes;
  final DateTime lastUpdated;

  InventoryItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.minThreshold,
    required this.supplier,
    required this.notes,
    required this.lastUpdated,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] ?? '',
      restaurantId: json['restaurantId'] ?? '',
      name: json['name'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      minThreshold: (json['minThreshold'] ?? 0).toDouble(),
      supplier: json['supplier'] ?? '',
      notes: json['notes'] ?? '',
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'minThreshold': minThreshold,
      'supplier': supplier,
      'notes': notes,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  InventoryItem copyWith({
    String? id,
    String? restaurantId,
    String? name,
    double? quantity,
    String? unit,
    double? minThreshold,
    String? supplier,
    String? notes,
    DateTime? lastUpdated,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      minThreshold: minThreshold ?? this.minThreshold,
      supplier: supplier ?? this.supplier,
      notes: notes ?? this.notes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
