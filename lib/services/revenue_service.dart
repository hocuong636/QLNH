import 'package:firebase_database/firebase_database.dart';
import 'package:quanlynhahang/models/revenue.dart';
import 'package:quanlynhahang/models/restaurant.dart';
import 'package:quanlynhahang/models/order.dart';

/// Service quản lý doanh thu và phí platform
class RevenueService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  
  /// Phí platform mặc định (2%)
  static const double defaultPlatformFeePercent = 2.0;

  /// Lấy phí platform của nhà hàng
  Future<double> getRestaurantPlatformFee(String restaurantId) async {
    try {
      final snapshot = await _database
          .child('restaurants')
          .child(restaurantId)
          .child('platformFeePercent')
          .get();
      
      if (snapshot.exists) {
        return (snapshot.value as num).toDouble();
      }
      return defaultPlatformFeePercent;
    } catch (e) {
      print('Error getting platform fee: $e');
      return defaultPlatformFeePercent;
    }
  }

  /// Tính toán phí platform
  PlatformFeeCalculation calculatePlatformFee(double totalAmount, double feePercent) {
    final platformFee = totalAmount * (feePercent / 100);
    final restaurantAmount = totalAmount - platformFee;
    
    return PlatformFeeCalculation(
      totalAmount: totalAmount,
      platformFeePercent: feePercent,
      platformFee: platformFee,
      restaurantAmount: restaurantAmount,
    );
  }

  /// Ghi nhận doanh thu khi thanh toán thành công
  /// Nếu paymentMethod là 'cash' thì không tính phí platform
  Future<RevenueRecord?> recordRevenue({
    required Order order,
    required String transactionId,
    required String paymentMethod,
  }) async {
    try {
      // Thanh toán tiền mặt không tính phí platform
      double feePercent;
      if (paymentMethod == 'cash') {
        feePercent = 0.0;
      } else {
        // Lấy phí platform của nhà hàng
        feePercent = await getRestaurantPlatformFee(order.restaurantId);
      }
      
      // Tính toán
      final calculation = calculatePlatformFee(order.totalAmount, feePercent);
      
      // Tạo ID cho bản ghi
      final recordRef = _database.child('revenue_records').push();
      final recordId = recordRef.key!;
      
      final record = RevenueRecord(
        id: recordId,
        restaurantId: order.restaurantId,
        orderId: order.id,
        transactionId: transactionId,
        totalAmount: calculation.totalAmount,
        platformFeePercent: calculation.platformFeePercent,
        platformFee: calculation.platformFee,
        restaurantAmount: calculation.restaurantAmount,
        paymentMethod: paymentMethod,
        status: 'pending', // Chưa chuyển cho nhà hàng
        createdAt: DateTime.now(),
      );
      
      // Lưu vào Firebase
      await recordRef.set(record.toJson());
      
      // Cập nhật tổng hợp doanh thu của nhà hàng
      await _updateRestaurantRevenueSummary(order.restaurantId, record);
      
      // Cập nhật tổng doanh thu platform
      await _updatePlatformRevenueSummary(record);
      
      print('Revenue recorded: ${record.id} - Restaurant: ${record.restaurantAmount}đ, Platform: ${record.platformFee}đ');
      
      return record;
    } catch (e) {
      print('Error recording revenue: $e');
      return null;
    }
  }

  /// Cập nhật tổng hợp doanh thu nhà hàng
  Future<void> _updateRestaurantRevenueSummary(String restaurantId, RevenueRecord record) async {
    try {
      final summaryRef = _database.child('revenue_summary').child(restaurantId);
      
      await summaryRef.runTransaction((Object? current) {
        if (current == null) {
          // Tạo mới summary
          return Transaction.success({
            'totalRevenue': record.totalAmount,
            'totalPlatformFee': record.platformFee,
            'totalRestaurantAmount': record.restaurantAmount,
            'pendingSettlement': record.restaurantAmount,
            'settledAmount': 0,
            'totalTransactions': 1,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }
        
        final data = Map<String, dynamic>.from(current as Map);
        data['totalRevenue'] = (data['totalRevenue'] ?? 0) + record.totalAmount;
        data['totalPlatformFee'] = (data['totalPlatformFee'] ?? 0) + record.platformFee;
        data['totalRestaurantAmount'] = (data['totalRestaurantAmount'] ?? 0) + record.restaurantAmount;
        data['pendingSettlement'] = (data['pendingSettlement'] ?? 0) + record.restaurantAmount;
        data['totalTransactions'] = (data['totalTransactions'] ?? 0) + 1;
        data['updatedAt'] = DateTime.now().toIso8601String();
        
        return Transaction.success(data);
      });
    } catch (e) {
      print('Error updating restaurant revenue summary: $e');
    }
  }

  /// Cập nhật tổng doanh thu platform
  Future<void> _updatePlatformRevenueSummary(RevenueRecord record) async {
    try {
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final monthKey = '${today.year}-${today.month.toString().padLeft(2, '0')}';
      
      // Cập nhật theo ngày
      await _database.child('platform_revenue').child('daily').child(dateKey).runTransaction((Object? current) {
        if (current == null) {
          return Transaction.success({
            'totalRevenue': record.totalAmount,
            'totalPlatformFee': record.platformFee,
            'totalTransactions': 1,
          });
        }
        
        final data = Map<String, dynamic>.from(current as Map);
        data['totalRevenue'] = (data['totalRevenue'] ?? 0) + record.totalAmount;
        data['totalPlatformFee'] = (data['totalPlatformFee'] ?? 0) + record.platformFee;
        data['totalTransactions'] = (data['totalTransactions'] ?? 0) + 1;
        
        return Transaction.success(data);
      });
      
      // Cập nhật theo tháng
      await _database.child('platform_revenue').child('monthly').child(monthKey).runTransaction((Object? current) {
        if (current == null) {
          return Transaction.success({
            'totalRevenue': record.totalAmount,
            'totalPlatformFee': record.platformFee,
            'totalTransactions': 1,
          });
        }
        
        final data = Map<String, dynamic>.from(current as Map);
        data['totalRevenue'] = (data['totalRevenue'] ?? 0) + record.totalAmount;
        data['totalPlatformFee'] = (data['totalPlatformFee'] ?? 0) + record.platformFee;
        data['totalTransactions'] = (data['totalTransactions'] ?? 0) + 1;
        
        return Transaction.success(data);
      });
    } catch (e) {
      print('Error updating platform revenue summary: $e');
    }
  }

  /// Lấy tổng hợp doanh thu của nhà hàng
  Future<RestaurantRevenueSummary?> getRestaurantRevenueSummary(String restaurantId, String restaurantName) async {
    try {
      final snapshot = await _database.child('revenue_summary').child(restaurantId).get();
      
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        data['restaurantId'] = restaurantId;
        data['restaurantName'] = restaurantName;
        return RestaurantRevenueSummary.fromJson(data);
      }
      
      return RestaurantRevenueSummary.empty(restaurantId, restaurantName);
    } catch (e) {
      print('Error getting restaurant revenue summary: $e');
      return null;
    }
  }

  /// Lấy danh sách bản ghi doanh thu của nhà hàng
  Future<List<RevenueRecord>> getRestaurantRevenueRecords(
    String restaurantId, {
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
  }) async {
    try {
      Query query = _database
          .child('revenue_records')
          .orderByChild('restaurantId')
          .equalTo(restaurantId);
      
      final snapshot = await query.limitToLast(limit).get();
      
      if (!snapshot.exists) return [];
      
      final records = <RevenueRecord>[];
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      
      data.forEach((key, value) {
        final record = RevenueRecord.fromJson(Map<String, dynamic>.from(value));
        
        // Filter by status
        if (status != null && record.status != status) return;
        
        // Filter by date
        if (fromDate != null && record.createdAt.isBefore(fromDate)) return;
        if (toDate != null && record.createdAt.isAfter(toDate)) return;
        
        records.add(record);
      });
      
      // Sort by createdAt descending
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return records;
    } catch (e) {
      print('Error getting revenue records: $e');
      return [];
    }
  }

  /// Lấy tổng hợp doanh thu tất cả nhà hàng (cho Admin)
  Future<List<RestaurantRevenueSummary>> getAllRestaurantRevenueSummaries() async {
    try {
      // Lấy danh sách nhà hàng
      final restaurantsSnapshot = await _database.child('restaurants').get();
      if (!restaurantsSnapshot.exists) return [];
      
      final restaurantsData = Map<String, dynamic>.from(restaurantsSnapshot.value as Map);
      final summaries = <RestaurantRevenueSummary>[];
      
      for (final entry in restaurantsData.entries) {
        final restaurantData = Map<String, dynamic>.from(entry.value);
        final restaurantId = entry.key;
        final restaurantName = restaurantData['name'] ?? 'Unknown';
        
        final summary = await getRestaurantRevenueSummary(restaurantId, restaurantName);
        if (summary != null) {
          summaries.add(summary);
        }
      }
      
      // Sort by pending settlement descending
      summaries.sort((a, b) => b.pendingSettlement.compareTo(a.pendingSettlement));
      
      return summaries;
    } catch (e) {
      print('Error getting all revenue summaries: $e');
      return [];
    }
  }

  /// Lấy tổng doanh thu platform theo ngày
  Future<Map<String, dynamic>?> getPlatformDailyRevenue(DateTime date) async {
    try {
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final snapshot = await _database.child('platform_revenue').child('daily').child(dateKey).get();
      
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      print('Error getting platform daily revenue: $e');
      return null;
    }
  }

  /// Lấy tổng doanh thu platform theo tháng
  Future<Map<String, dynamic>?> getPlatformMonthlyRevenue(int year, int month) async {
    try {
      final monthKey = '$year-${month.toString().padLeft(2, '0')}';
      final snapshot = await _database.child('platform_revenue').child('monthly').child(monthKey).get();
      
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      print('Error getting platform monthly revenue: $e');
      return null;
    }
  }

  /// Cập nhật phí platform cho nhà hàng (Admin only)
  Future<bool> updateRestaurantPlatformFee(String restaurantId, double newFeePercent) async {
    try {
      if (newFeePercent < 0 || newFeePercent > 100) {
        print('Invalid fee percent: $newFeePercent');
        return false;
      }
      
      await _database.child('restaurants').child(restaurantId).update({
        'platformFeePercent': newFeePercent,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      return true;
    } catch (e) {
      print('Error updating platform fee: $e');
      return false;
    }
  }

  /// Đánh dấu settlement (chuyển tiền cho nhà hàng)
  Future<SettlementRecord?> createSettlement({
    required String restaurantId,
    required double amount,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
    required List<String> revenueRecordIds,
    String? note,
  }) async {
    try {
      final settlementRef = _database.child('settlements').push();
      final settlementId = settlementRef.key!;
      
      final settlement = SettlementRecord(
        id: settlementId,
        restaurantId: restaurantId,
        amount: amount,
        bankName: bankName,
        bankAccountNumber: bankAccountNumber,
        bankAccountName: bankAccountName,
        status: 'pending',
        note: note,
        createdAt: DateTime.now(),
        revenueRecordIds: revenueRecordIds,
      );
      
      await settlementRef.set(settlement.toJson());
      
      return settlement;
    } catch (e) {
      print('Error creating settlement: $e');
      return null;
    }
  }

  /// Xác nhận settlement đã hoàn thành
  Future<bool> completeSettlement(String settlementId, String restaurantId) async {
    try {
      // Lấy thông tin settlement
      final settlementSnapshot = await _database.child('settlements').child(settlementId).get();
      if (!settlementSnapshot.exists) return false;
      
      final settlementData = Map<String, dynamic>.from(settlementSnapshot.value as Map);
      final amount = (settlementData['amount'] ?? 0).toDouble();
      final revenueRecordIds = List<String>.from(settlementData['revenueRecordIds'] ?? []);
      
      // Cập nhật settlement status
      await _database.child('settlements').child(settlementId).update({
        'status': 'completed',
        'completedAt': DateTime.now().toIso8601String(),
      });
      
      // Cập nhật các revenue record thành settled
      for (final recordId in revenueRecordIds) {
        await _database.child('revenue_records').child(recordId).update({
          'status': 'settled',
          'settledAt': DateTime.now().toIso8601String(),
        });
      }
      
      // Cập nhật summary của nhà hàng
      await _database.child('revenue_summary').child(restaurantId).runTransaction((Object? current) {
        if (current == null) return Transaction.abort();
        
        final data = Map<String, dynamic>.from(current as Map);
        data['pendingSettlement'] = (data['pendingSettlement'] ?? 0) - amount;
        data['settledAmount'] = (data['settledAmount'] ?? 0) + amount;
        data['lastSettledAt'] = DateTime.now().toIso8601String();
        
        return Transaction.success(data);
      });
      
      return true;
    } catch (e) {
      print('Error completing settlement: $e');
      return false;
    }
  }
}

/// Kết quả tính toán phí platform
class PlatformFeeCalculation {
  final double totalAmount;
  final double platformFeePercent;
  final double platformFee;
  final double restaurantAmount;

  PlatformFeeCalculation({
    required this.totalAmount,
    required this.platformFeePercent,
    required this.platformFee,
    required this.restaurantAmount,
  });
  
  @override
  String toString() {
    return 'Total: $totalAmount, Fee: $platformFee ($platformFeePercent%), Restaurant: $restaurantAmount';
  }
}
