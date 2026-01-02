import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:quanlynhahang/models/order.dart';

class OrderService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Get orders by restaurant ID
  Future<List<Order>> getOrders(String restaurantId) async {
    try {
      print('OrderService: Getting orders for restaurantId: $restaurantId');
      DatabaseReference ref = _database.ref('orders');

      // Temporarily get all orders and filter in code to debug
      DataSnapshot snapshot = await ref.get();

      print('OrderService: Full snapshot exists: ${snapshot.exists}');
      List<Order> orders = [];
      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> orderData =
            snapshot.value as Map<dynamic, dynamic>;
        print('OrderService: Total orders in DB: ${orderData.length}');
        orderData.forEach((key, value) {
          if (value is Map) {
            // Cast to Map<dynamic, dynamic> first
            Map<dynamic, dynamic> rawMap = value as Map<dynamic, dynamic>;
            // Convert to Map<String, dynamic>
            Map<String, dynamic> orderMap = {};
            rawMap.forEach((k, v) {
              orderMap[k.toString()] = v;
            });
            orderMap['id'] = key.toString();
            try {
              Order order = Order.fromJson(orderMap);
              // Filter by restaurantId
              if (restaurantId.isEmpty || order.restaurantId == restaurantId) {
                orders.add(order);
              }
            } catch (e) {
              print('OrderService: Error parsing order $key: $e');
            }
          }
        });
      }

      print(
        'OrderService: Filtered to ${orders.length} orders for restaurantId: $restaurantId',
      );
      // Sort by createdAt descending (newest first)
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    } catch (e) {
      print('Error getting orders: $e');
      return [];
    }
  }

  // Create order
  Future<String?> createOrder(Order order) async {
    try {
      DatabaseReference ref = _database.ref('orders').push();
      await ref.set(order.toJson());
      return ref.key;
    } catch (e) {
      print('Error creating order: $e');
      return null;
    }
  }

  // Update order
  Future<bool> updateOrder(Order order) async {
    try {
      DatabaseReference ref = _database.ref('orders/${order.id}');
      await ref.update(order.toJson());
      return true;
    } catch (e) {
      print('Error updating order: $e');
      return false;
    }
  }

  // Delete order
  Future<bool> deleteOrder(String orderId) async {
    try {
      DatabaseReference ref = _database.ref('orders/$orderId');
      await ref.remove();
      return true;
    } catch (e) {
      print('Error deleting order: $e');
      return false;
    }
  }

  // Get restaurant ID by owner ID
  Future<String?> getRestaurantIdByOwnerId(String ownerId) async {
    try {
      DatabaseReference ref = _database.ref('users/$ownerId');
      DataSnapshot snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> userData =
            snapshot.value as Map<dynamic, dynamic>;
        return userData['restaurantID'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting restaurant ID by owner ID: $e');
      return null;
    }
  }

  // Get restaurant ID by user ID (for both owner and staff)
  Future<String?> getRestaurantIdByUserId(String userId) async {
    try {
      DatabaseReference ref = _database.ref('users/$userId');
      DataSnapshot snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> userData =
            snapshot.value as Map<dynamic, dynamic>;
        String? restaurantId = userData['restaurantID'];

        // If restaurantId is set in user data, return it
        if (restaurantId != null && restaurantId.isNotEmpty) {
          return restaurantId;
        }

        // If not set, try to find restaurant where this user is the owner
        DatabaseReference restaurantRef = _database.ref('restaurants');
        DataSnapshot restaurantSnapshot = await restaurantRef
            .orderByChild('ownerId')
            .equalTo(userId)
            .get();

        if (restaurantSnapshot.exists && restaurantSnapshot.value != null) {
          Map<dynamic, dynamic> restaurants =
              restaurantSnapshot.value as Map<dynamic, dynamic>;
          return restaurants.keys.first;
        }
      }
      return null;
    } catch (e) {
      print('Error getting restaurant ID by user ID: $e');
      return null;
    }
  }

  // Get active order for a specific table (not paid)
  Future<Order?> getActiveOrderByTable(String restaurantId, String tableId) async {
    try {
      DatabaseReference ref = _database.ref('orders');
      DataSnapshot snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> orderData = snapshot.value as Map<dynamic, dynamic>;
        
        for (var entry in orderData.entries) {
          if (entry.value is Map) {
            Map<dynamic, dynamic> rawMap = entry.value as Map<dynamic, dynamic>;
            Map<String, dynamic> orderMap = {};
            rawMap.forEach((k, v) {
              orderMap[k.toString()] = v;
            });
            orderMap['id'] = entry.key.toString();
            
            try {
              Order order = Order.fromJson(orderMap);
              // Check if this order belongs to the table and is not paid
              if (order.restaurantId == restaurantId && 
                  order.tableId == tableId && 
                  order.status != OrderStatus.paid) {
                return order;
              }
            } catch (e) {
              print('Error parsing order: $e');
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('Error getting active order by table: $e');
      return null;
    }
  }

  // Get orders by table ID
  Future<List<Order>> getOrdersByTable(String restaurantId, String tableId) async {
    try {
      DatabaseReference ref = _database.ref('orders');
      DataSnapshot snapshot = await ref.get();

      List<Order> orders = [];
      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> orderData = snapshot.value as Map<dynamic, dynamic>;
        
        orderData.forEach((key, value) {
          if (value is Map) {
            Map<dynamic, dynamic> rawMap = value as Map<dynamic, dynamic>;
            Map<String, dynamic> orderMap = {};
            rawMap.forEach((k, v) {
              orderMap[k.toString()] = v;
            });
            orderMap['id'] = key.toString();
            
            try {
              Order order = Order.fromJson(orderMap);
              if (order.restaurantId == restaurantId && order.tableId == tableId) {
                orders.add(order);
              }
            } catch (e) {
              print('Error parsing order: $e');
            }
          }
        });
      }
      
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    } catch (e) {
      print('Error getting orders by table: $e');
      return [];
    }
  }
}
