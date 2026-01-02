class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String phoneNumber;
  final String role;
  final String? restaurantID; // null khi chưa thuộc nhà hàng nào
  final bool isActive;
  final String? packageId; // ID của gói dịch vụ (chỉ cho owner)
  final DateTime? packageExpiryDate; // Ngày hết hạn gói dịch vụ
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    this.restaurantID,
    this.isActive = true,
    this.packageId,
    this.packageExpiryDate,
    required this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? json['phone'] ?? '',
      role: json['role'] ?? '',
      restaurantID: json['restaurantID'],
      isActive: json['isActive'] ?? true,
      packageId: json['packageId'],
      packageExpiryDate: json['packageExpiryDate'] != null
          ? DateTime.parse(json['packageExpiryDate'])
          : null,
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
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'role': role,
      'restaurantID': restaurantID,
      'isActive': isActive,
      'packageId': packageId,
      'packageExpiryDate': packageExpiryDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? phoneNumber,
    String? role,
    String? restaurantID,
    bool? isActive,
    String? packageId,
    DateTime? packageExpiryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      restaurantID: restaurantID ?? this.restaurantID,
      isActive: isActive ?? this.isActive,
      packageId: packageId ?? this.packageId,
      packageExpiryDate: packageExpiryDate ?? this.packageExpiryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
