class ServicePackage {
  final String id;
  final String name;
  final String description;
  final int durationMonths; // 3, 6, 12
  final double price;
  final String level; // 'basic', 'standard', 'premium'
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ServicePackage({
    required this.id,
    required this.name,
    required this.description,
    required this.durationMonths,
    required this.price,
    required this.level,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory ServicePackage.fromJson(Map<String, dynamic> json) {
    return ServicePackage(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      durationMonths: json['durationMonths'] is int 
          ? json['durationMonths'] 
          : (json['durationMonths'] is double 
              ? (json['durationMonths'] as double).toInt() 
              : 3),
      price: json['price'] is double 
          ? json['price'] 
          : (json['price'] is int 
              ? (json['price'] as int).toDouble() 
              : 0.0),
      level: json['level'] ?? 'basic',
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'durationMonths': durationMonths,
      'price': price,
      'level': level,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  ServicePackage copyWith({
    String? id,
    String? name,
    String? description,
    int? durationMonths,
    double? price,
    String? level,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServicePackage(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      durationMonths: durationMonths ?? this.durationMonths,
      price: price ?? this.price,
      level: level ?? this.level,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

