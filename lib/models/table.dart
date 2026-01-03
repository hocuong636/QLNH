enum TableStatus { empty, occupied, reserved }

class TableModel {
  final String id;
  final String restaurantID;
  final int number;
  final int capacity;
  final TableStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? reservedAt;
  final String? reservedBy;
  final String? reservedPhone;

  TableModel({
    required this.id,
    required this.restaurantID,
    required this.number,
    required this.capacity,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.reservedAt,
    this.reservedBy,
    this.reservedPhone,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['id'] ?? '',
      restaurantID: json['restaurantID'] ?? json['ownerId'] ?? '',
      number: json['number'] ?? 0,
      capacity: json['capacity'] ?? 0,
      status: _parseTableStatus(json['status']),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      reservedAt: json['reservedAt'] != null
          ? DateTime.parse(json['reservedAt'])
          : null,
      reservedBy: json['reservedBy'],
      reservedPhone: json['reservedPhone'],
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
      'restaurantID': restaurantID,
      'number': number,
      'capacity': capacity,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'reservedAt': reservedAt?.toIso8601String(),
      'reservedBy': reservedBy,
      'reservedPhone': reservedPhone,
    };
  }

  TableModel copyWith({
    String? id,
    String? restaurantID,
    int? number,
    int? capacity,
    TableStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? reservedAt,
    String? reservedBy,
    String? reservedPhone,
  }) {
    return TableModel(
      id: id ?? this.id,
      restaurantID: restaurantID ?? this.restaurantID,
      number: number ?? this.number,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reservedAt: reservedAt ?? this.reservedAt,
      reservedBy: reservedBy ?? this.reservedBy,
      reservedPhone: reservedPhone ?? this.reservedPhone,
    );
  }
}
