enum TableStatus { empty, occupied, reserved }

class TableModel {
  final String id;
  final String restaurantId;
  final int number;
  final int capacity;
  final TableStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  TableModel({
    required this.id,
    required this.restaurantId,
    required this.number,
    required this.capacity,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['id'] ?? '',
      restaurantId: json['restaurantId'] ?? '',
      number: json['number'] ?? 0,
      capacity: json['capacity'] ?? 0,
      status: _parseTableStatus(json['status']),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  static TableStatus _parseTableStatus(String? status) {
    switch (status) {
      case 'empty':
        return TableStatus.empty;
      case 'occupied':
        return TableStatus.occupied;
      case 'reserved':
        return TableStatus.reserved;
      default:
        return TableStatus.empty;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'number': number,
      'capacity': capacity,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  TableModel copyWith({
    String? id,
    String? restaurantId,
    int? number,
    int? capacity,
    TableStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TableModel(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      number: number ?? this.number,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
