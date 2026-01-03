class InventoryHistory {
  final String id;
  final String inventoryItemId;
  final String restaurantId;
  final String action; // 'add', 'subtract', 'update'
  final double quantityChange;
  final double newQuantity;
  final String notes;
  final DateTime timestamp;

  InventoryHistory({
    required this.id,
    required this.inventoryItemId,
    required this.restaurantId,
    required this.action,
    required this.quantityChange,
    required this.newQuantity,
    required this.notes,
    required this.timestamp,
  });

  factory InventoryHistory.fromJson(Map<String, dynamic> json) {
    return InventoryHistory(
      id: json['id'] ?? '',
      inventoryItemId: json['inventoryItemId'] ?? '',
      restaurantId: json['restaurantID'] ?? json['restaurantId'] ?? '',
      action: json['action'] ?? '',
      quantityChange: (json['quantityChange'] ?? 0).toDouble(),
      newQuantity: (json['newQuantity'] ?? 0).toDouble(),
      notes: json['notes'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inventoryItemId': inventoryItemId,
      'restaurantID': restaurantId,
      'action': action,
      'quantityChange': quantityChange,
      'newQuantity': newQuantity,
      'notes': notes,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
