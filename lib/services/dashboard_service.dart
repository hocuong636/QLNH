import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class DashboardService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Get total orders count for restaurant
  Future<int> getTotalOrders(String restaurantId) async {
    try {
      DatabaseReference ref = _database.ref('orders');
      DataSnapshot snapshot = await ref
          .orderByChild('restaurantID')
          .equalTo(restaurantId)
          .get();

      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> orders = snapshot.value as Map<dynamic, dynamic>;
        int paidOrders = 0;
        orders.forEach((key, value) {
          if (value is Map) {
            String? status = value['status'] as String?;
            if (status == 'paid') {
              paidOrders++;
            }
          }
        });
        return paidOrders;
      }
      return 0;
    } catch (e) {
      print('Error getting total orders: $e');
      return 0;
    }
  }

  // Get total revenue for restaurant
  Future<double> getTotalRevenue(String restaurantId) async {
    try {
      DatabaseReference ref = _database.ref('orders');
      DataSnapshot snapshot = await ref
          .orderByChild('restaurantID')
          .equalTo(restaurantId)
          .get();

      double totalRevenue = 0;
      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> orders = snapshot.value as Map<dynamic, dynamic>;
        orders.forEach((key, value) {
          if (value is Map) {
            String? status = value['status'] as String?;
            // Only include orders that are paid
            if (status == 'paid') {
              double? totalAmount = (value['totalAmount'] as num?)?.toDouble();
              if (totalAmount != null) {
                totalRevenue += totalAmount;
              }
            }
          }
        });
      }
      return totalRevenue;
    } catch (e) {
      print('Error getting total revenue: $e');
      return 0;
    }
  }

  // Get best selling menu item
  Future<String> getBestSellingItem(String restaurantId) async {
    try {
      // Get all completed orders for this restaurant
      DatabaseReference ordersRef = _database.ref('orders');
      DataSnapshot ordersSnapshot = await ordersRef
          .orderByChild('restaurantID')
          .equalTo(restaurantId)
          .get();

      if (!ordersSnapshot.exists || ordersSnapshot.value == null) {
        return 'Chưa có đơn hàng';
      }

      // Count order frequency for each menu item (number of orders containing this item)
      Map<String, int> itemOrderCount = {};
      Map<dynamic, dynamic> orders =
          ordersSnapshot.value as Map<dynamic, dynamic>;

      for (var order in orders.values) {
        if (order is Map) {
          String? status = order['status'] as String?;
          // Only include orders that are paid
          if (status == 'paid') {
            var orderItems = order['items'];
            if (orderItems is List) {
              // Track items in this order to avoid double counting
              Set<String> itemsInOrder = {};
              for (var item in orderItems) {
                if (item is Map && item['menuItemId'] != null) {
                  String itemId = item['menuItemId'].toString();
                  if (!itemsInOrder.contains(itemId)) {
                    itemsInOrder.add(itemId);
                    itemOrderCount[itemId] = (itemOrderCount[itemId] ?? 0) + 1;
                  }
                }
              }
            }
          }
        }
      }

      if (itemOrderCount.isEmpty) {
        return 'Chưa có dữ liệu bán hàng';
      }

      // Find the most frequently ordered item
      String bestItemId = itemOrderCount.keys.reduce(
        (a, b) => itemOrderCount[a]! > itemOrderCount[b]! ? a : b,
      );

      // Get the item name from menu
      DatabaseReference menuRef = _database.ref('menu/$bestItemId');
      DataSnapshot menuSnapshot = await menuRef.get();

      if (menuSnapshot.exists && menuSnapshot.value != null) {
        Map<dynamic, dynamic> menuItem =
            menuSnapshot.value as Map<dynamic, dynamic>;
        return menuItem['name'] ?? 'Món không xác định';
      }

      return 'Món bán chạy nhất';
    } catch (e) {
      print('Error getting best selling item: $e');
      return 'Lỗi tải dữ liệu';
    }
  }

  // Get restaurant status
  Future<String> getRestaurantStatus(String restaurantId) async {
    try {
      DatabaseReference ref = _database.ref('restaurants/$restaurantId');
      DataSnapshot snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> restaurant =
            snapshot.value as Map<dynamic, dynamic>;
        bool? isOpen = restaurant['isOpen'] as bool?;
        return isOpen == true ? 'Đang mở' : 'Đã đóng';
      }
      return 'Chưa thiết lập';
    } catch (e) {
      print('Error getting restaurant status: $e');
      return 'Lỗi tải dữ liệu';
    }
  }

  // Get all dashboard stats at once
  Future<Map<String, dynamic>> getDashboardStats(String restaurantId) async {
    try {
      final results = await Future.wait([
        getTotalOrders(restaurantId),
        getTotalRevenue(restaurantId),
        getBestSellingItem(restaurantId),
        getRestaurantStatus(restaurantId),
      ]);

      return {
        'totalOrders': results[0] as int,
        'totalRevenue': results[1] as double,
        'bestSellingItem': results[2] as String,
        'restaurantStatus': results[3] as String,
      };
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return {
        'totalOrders': 0,
        'totalRevenue': 0.0,
        'bestSellingItem': 'Lỗi tải dữ liệu',
        'restaurantStatus': 'Lỗi tải dữ liệu',
      };
    }
  }
}
