/// Model theo dõi doanh thu của từng nhà hàng
class RevenueRecord {
  final String id;
  final String restaurantId;
  final String orderId;
  final String transactionId;
  final double totalAmount;          // Tổng tiền khách trả
  final double platformFeePercent;   // % phí platform
  final double platformFee;          // Số tiền phí platform
  final double restaurantAmount;     // Số tiền nhà hàng nhận
  final String paymentMethod;        // cash, payos
  final String status;               // pending, settled (đã chuyển cho nhà hàng)
  final DateTime createdAt;
  final DateTime? settledAt;         // Ngày chuyển tiền cho nhà hàng

  RevenueRecord({
    required this.id,
    required this.restaurantId,
    required this.orderId,
    required this.transactionId,
    required this.totalAmount,
    required this.platformFeePercent,
    required this.platformFee,
    required this.restaurantAmount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.settledAt,
  });

  factory RevenueRecord.fromJson(Map<String, dynamic> json) {
    return RevenueRecord(
      id: json['id'] ?? '',
      restaurantId: json['restaurantId'] ?? '',
      orderId: json['orderId'] ?? '',
      transactionId: json['transactionId'] ?? '',
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      platformFeePercent: (json['platformFeePercent'] ?? 2.0).toDouble(),
      platformFee: (json['platformFee'] ?? 0).toDouble(),
      restaurantAmount: (json['restaurantAmount'] ?? 0).toDouble(),
      paymentMethod: json['paymentMethod'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      settledAt: json['settledAt'] != null
          ? DateTime.parse(json['settledAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'orderId': orderId,
      'transactionId': transactionId,
      'totalAmount': totalAmount,
      'platformFeePercent': platformFeePercent,
      'platformFee': platformFee,
      'restaurantAmount': restaurantAmount,
      'paymentMethod': paymentMethod,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'settledAt': settledAt?.toIso8601String(),
    };
  }
}

/// Tổng hợp doanh thu theo nhà hàng
class RestaurantRevenueSummary {
  final String restaurantId;
  final String restaurantName;
  final double totalRevenue;           // Tổng doanh thu
  final double totalPlatformFee;       // Tổng phí platform
  final double totalRestaurantAmount;  // Tổng tiền nhà hàng nhận
  final double pendingSettlement;      // Số tiền chưa chuyển
  final double settledAmount;          // Số tiền đã chuyển
  final int totalTransactions;         // Số giao dịch
  final DateTime? lastSettledAt;       // Lần chuyển tiền gần nhất

  RestaurantRevenueSummary({
    required this.restaurantId,
    required this.restaurantName,
    required this.totalRevenue,
    required this.totalPlatformFee,
    required this.totalRestaurantAmount,
    required this.pendingSettlement,
    required this.settledAmount,
    required this.totalTransactions,
    this.lastSettledAt,
  });

  factory RestaurantRevenueSummary.empty(String restaurantId, String restaurantName) {
    return RestaurantRevenueSummary(
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      totalRevenue: 0,
      totalPlatformFee: 0,
      totalRestaurantAmount: 0,
      pendingSettlement: 0,
      settledAmount: 0,
      totalTransactions: 0,
    );
  }

  factory RestaurantRevenueSummary.fromJson(Map<String, dynamic> json) {
    return RestaurantRevenueSummary(
      restaurantId: json['restaurantId'] ?? '',
      restaurantName: json['restaurantName'] ?? '',
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      totalPlatformFee: (json['totalPlatformFee'] ?? 0).toDouble(),
      totalRestaurantAmount: (json['totalRestaurantAmount'] ?? 0).toDouble(),
      pendingSettlement: (json['pendingSettlement'] ?? 0).toDouble(),
      settledAmount: (json['settledAmount'] ?? 0).toDouble(),
      totalTransactions: json['totalTransactions'] ?? 0,
      lastSettledAt: json['lastSettledAt'] != null
          ? DateTime.parse(json['lastSettledAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'totalRevenue': totalRevenue,
      'totalPlatformFee': totalPlatformFee,
      'totalRestaurantAmount': totalRestaurantAmount,
      'pendingSettlement': pendingSettlement,
      'settledAmount': settledAmount,
      'totalTransactions': totalTransactions,
      'lastSettledAt': lastSettledAt?.toIso8601String(),
    };
  }
}

/// Thông tin settlement (chuyển tiền cho nhà hàng)
class SettlementRecord {
  final String id;
  final String restaurantId;
  final double amount;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountName;
  final String status;  // pending, processing, completed, failed
  final String? note;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<String> revenueRecordIds;  // Các bản ghi doanh thu đã settle

  SettlementRecord({
    required this.id,
    required this.restaurantId,
    required this.amount,
    required this.bankName,
    required this.bankAccountNumber,
    required this.bankAccountName,
    required this.status,
    this.note,
    required this.createdAt,
    this.completedAt,
    required this.revenueRecordIds,
  });

  factory SettlementRecord.fromJson(Map<String, dynamic> json) {
    return SettlementRecord(
      id: json['id'] ?? '',
      restaurantId: json['restaurantId'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      bankName: json['bankName'] ?? '',
      bankAccountNumber: json['bankAccountNumber'] ?? '',
      bankAccountName: json['bankAccountName'] ?? '',
      status: json['status'] ?? 'pending',
      note: json['note'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      revenueRecordIds: json['revenueRecordIds'] != null
          ? List<String>.from(json['revenueRecordIds'])
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'amount': amount,
      'bankName': bankName,
      'bankAccountNumber': bankAccountNumber,
      'bankAccountName': bankAccountName,
      'status': status,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'revenueRecordIds': revenueRecordIds,
    };
  }
}
