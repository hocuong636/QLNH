class Restaurant {
  final String id;
  final String ownerId;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String description;
  final String openingHours;
  final int capacity;
  final bool isOpen;
  final DateTime createdAt;
  final DateTime updatedAt;

  Restaurant({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.description,
    required this.openingHours,
    required this.capacity,
    required this.isOpen,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] ?? '',
      ownerId: json['ownerId'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      description: json['description'] ?? '',
      openingHours: json['openingHours'] ?? '',
      capacity: json['capacity'] ?? 0,
      isOpen: json['isOpen'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'description': description,
      'openingHours': openingHours,
      'capacity': capacity,
      'isOpen': isOpen,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Restaurant copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? address,
    String? phone,
    String? email,
    String? description,
    String? openingHours,
    int? capacity,
    bool? isOpen,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Restaurant(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      description: description ?? this.description,
      openingHours: openingHours ?? this.openingHours,
      capacity: capacity ?? this.capacity,
      isOpen: isOpen ?? this.isOpen,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
