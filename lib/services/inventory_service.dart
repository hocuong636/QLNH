import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:quanlynhahang/models/inventory_item.dart';

class InventoryService {
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  // Get inventory items by restaurant ID
  Future<List<InventoryItem>> getInventoryItems(String restaurantId) async {
    try {
      DatabaseReference ref = _database.ref('inventory');
      DataSnapshot snapshot = await ref
          .orderByChild('restaurantId')
          .equalTo(restaurantId)
          .get();

      List<InventoryItem> items = [];
      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> itemData =
            snapshot.value as Map<dynamic, dynamic>;
        itemData.forEach((key, value) {
          Map<String, dynamic> itemMap = Map<String, dynamic>.from(value);
          itemMap['id'] = key;
          items.add(InventoryItem.fromJson(itemMap));
        });
      }
      return items;
    } catch (e) {
      print('Error getting inventory items: $e');
      return [];
    }
  }

  // Create inventory item
  Future<String?> createInventoryItem(InventoryItem item) async {
    try {
      DatabaseReference ref = _database.ref('inventory').push();
      await ref.set(item.toJson());
      return ref.key;
    } catch (e) {
      print('Error creating inventory item: $e');
      return null;
    }
  }

  // Update inventory item
  Future<bool> updateInventoryItem(InventoryItem item) async {
    try {
      DatabaseReference ref = _database.ref('inventory/${item.id}');
      await ref.update(item.toJson());
      return true;
    } catch (e) {
      print('Error updating inventory item: $e');
      return false;
    }
  }

  // Delete inventory item
  Future<bool> deleteInventoryItem(String itemId) async {
    try {
      DatabaseReference ref = _database.ref('inventory/$itemId');
      await ref.remove();
      return true;
    } catch (e) {
      print('Error deleting inventory item: $e');
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
