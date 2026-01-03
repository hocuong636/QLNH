class InventoryCheck {
  final String id;
  final String inventoryItemId;
  final String restaurantId;
  final String checkedBy; // user ID of kitchen staff
  final double systemQuantity;
  final double actualQuantity;
  final double difference; // actual - system
  final String notes;
  final DateTime checkedAt;

  InventoryCheck({
    required this.id,
    required this.inventoryItemId,
    required this.restaurantId,
    required this.checkedBy,
    required this.systemQuantity,
    required this.actualQuantity,
    required this.difference,
    required this.notes,
    required this.checkedAt,
  });

  factory InventoryCheck.fromJson(Map<String, dynamic> json) {
    return InventoryCheck(
      id: json['id'] ?? '',
      inventoryItemId: json['inventoryItemId'] ?? '',
      restaurantId: json['restaurantID'] ?? json['restaurantId'] ?? '',
      checkedBy: json['checkedBy'] ?? '',
      systemQuantity: (json['systemQuantity'] ?? 0).toDouble(),
      actualQuantity: (json['actualQuantity'] ?? 0).toDouble(),
      difference: (json['difference'] ?? 0).toDouble(),
      notes: json['notes'] ?? '',
      checkedAt: json['checkedAt'] != null
          ? DateTime.parse(json['checkedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inventoryItemId': inventoryItemId,
      'restaurantID': restaurantId,
      'checkedBy': checkedBy,
      'systemQuantity': systemQuantity,
      'actualQuantity': actualQuantity,
      'difference': difference,
      'notes': notes,
      'checkedAt': checkedAt.toIso8601String(),
    };
  }
}
