import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:quanlynhahang/models/order.dart';

class OrderService {
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

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
            Map<String, dynamic> orderMap = Map<String, dynamic>.from(value);
            orderMap['id'] = key;
            Order order = Order.fromJson(orderMap);
            print(
              'OrderService: Order ${order.id} has restaurantId: ${order.restaurantId}, status: ${order.status}',
            );
            // Filter by restaurantId
            if (restaurantId.isEmpty || order.restaurantId == restaurantId) {
              orders.add(order);
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
      DatabaseReference ref = _database.ref('restaurants');
      DataSnapshot snapshot = await ref
          .orderByChild('ownerId')
          .equalTo(ownerId)
          .get();

      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> restaurants =
            snapshot.value as Map<dynamic, dynamic>;
        // Return the first restaurant ID found for this owner
        return restaurants.keys.first;
      }
      return null;
    } catch (e) {
      print('Error getting restaurant ID by owner ID: $e');
      return null;
    }
  }
}
