import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:quanlynhahang/models/menu_item.dart';

class MenuService {
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  // Get all menu items (for single restaurant app)
  Future<List<MenuItem>> getMenuItems([String? restaurantId]) async {
    try {
      DatabaseReference ref = _database.ref('menu');
      DataSnapshot snapshot = await ref.get();

      List<MenuItem> menuItems = [];
      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> items = snapshot.value as Map<dynamic, dynamic>;
        items.forEach((key, value) {
          if (value is Map) {
            // Cast to Map<dynamic, dynamic> first
            Map<dynamic, dynamic> rawMap = value as Map<dynamic, dynamic>;
            // Convert to Map<String, dynamic>
            Map<String, dynamic> itemData = {};
            rawMap.forEach((k, v) {
              itemData[k.toString()] = v;
            });
            itemData['id'] = key.toString();
            menuItems.add(MenuItem.fromJson(itemData));
          }
        });
      }
      return menuItems;
    } catch (e) {
      print('Error getting menu items: $e');
      return [];
    }
  }

  // Create menu item
  Future<String?> createMenuItem(MenuItem menuItem) async {
    try {
      DatabaseReference ref = _database.ref('menu').push();
      await ref.set(menuItem.toJson());
      return ref.key;
    } catch (e) {
      print('Error creating menu item: $e');
      return null;
    }
  }

  // Update menu item
  Future<bool> updateMenuItem(MenuItem menuItem) async {
    try {
      DatabaseReference ref = _database.ref('menu/${menuItem.id}');
      await ref.update(menuItem.toJson());
      return true;
    } catch (e) {
      print('Error updating menu item: $e');
      return false;
    }
  }

  // Delete menu item
  Future<bool> deleteMenuItem(String menuItemId) async {
    try {
      DatabaseReference ref = _database.ref('menu/$menuItemId');
      await ref.remove();
      return true;
    } catch (e) {
      print('Error deleting menu item: $e');
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
}
