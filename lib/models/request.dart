enum RequestType { owner, staff }

enum RequestStatus { pending, approved, rejected }

class Request {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final RequestType type;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Cho Owner request
  final String? packageId;
  final String? packageName;
  final double? packagePrice;
  final int? packageDurationMonths;
  final String? paymentMethod;
  final String? paymentStatus; // 'pending', 'paid', 'failed'
  
  // Cho Staff request
  final String? restaurantId;
  final String? restaurantName;
  final String? requestedRole; // 'order' hoặc 'kitchen'
  final String? ownerId;

  Request({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.type,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.packageId,
    this.packageName,
    this.packagePrice,
    this.packageDurationMonths,
    this.paymentMethod,
    this.paymentStatus,
    this.restaurantId,
    this.restaurantName,
    this.requestedRole,
    this.ownerId,
  });

  factory Request.fromJson(Map<String, dynamic> json) {
    return Request(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userEmail: json['userEmail'] ?? '',
      userName: json['userName'] ?? '',
      type: _parseRequestType(json['type']),
      status: _parseRequestStatus(json['status']),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      packageId: json['packageId'],
      packageName: json['packageName'],
      packagePrice: json['packagePrice'] is double 
          ? json['packagePrice'] 
          : (json['packagePrice'] is int 
              ? (json['packagePrice'] as int).toDouble() 
              : null),
      packageDurationMonths: json['packageDurationMonths'] is int 
          ? json['packageDurationMonths'] 
          : (json['packageDurationMonths'] is double 
              ? (json['packageDurationMonths'] as double).toInt() 
              : null),
      paymentMethod: json['paymentMethod'],
      paymentStatus: json['paymentStatus'],
      restaurantId: json['restaurantId'],
      restaurantName: json['restaurantName'],
      requestedRole: json['requestedRole'],
      ownerId: json['ownerId'],
    );
  }

  static RequestType _parseRequestType(String? type) {
    switch (type) {
      case 'owner':
        return RequestType.owner;
      case 'staff':
        return RequestType.staff;
      default:
        return RequestType.owner;
    }
  }

  static RequestStatus _parseRequestStatus(String? status) {
    switch (status) {
      case 'pending':
        return RequestStatus.pending;
      case 'approved':
        return RequestStatus.approved;
      case 'rejected':
        return RequestStatus.rejected;
      default:
        return RequestStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'packageId': packageId,
      'packageName': packageName,
      'packagePrice': packagePrice,
      'packageDurationMonths': packageDurationMonths,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'requestedRole': requestedRole,
      'ownerId': ownerId,
    };
  }

  Request copyWith({
    String? id,
    String? userId,
    String? userEmail,
    String? userName,
    RequestType? type,
    RequestStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? packageId,
    String? packageName,
    double? packagePrice,
    int? packageDurationMonths,
    String? paymentMethod,
    String? paymentStatus,
    String? restaurantId,
    String? restaurantName,
    String? requestedRole,
    String? ownerId,
  }) {
    return Request(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      packagePrice: packagePrice ?? this.packagePrice,
      packageDurationMonths: packageDurationMonths ?? this.packageDurationMonths,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      requestedRole: requestedRole ?? this.requestedRole,
      ownerId: ownerId ?? this.ownerId,
    );
  }
}

