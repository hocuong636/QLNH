import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:quanlynhahang/models/menu_item.dart';

class MenuService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Get all menu items (for single restaurant app)
  Future<List<MenuItem>> getMenuItems([String? restaurantId]) async {
    try {
      DatabaseReference ref = _database.ref('menu');
      DataSnapshot snapshot;
      
      // Nếu có restaurantId, chỉ lấy menu của nhà hàng đó
      if (restaurantId != null && restaurantId.isNotEmpty) {
        snapshot = await ref
            .orderByChild('restaurantId')  // Sử dụng 'restaurantId' như trong Firebase
            .equalTo(restaurantId)
            .get();
      } else {
        // Không có restaurantId thì lấy tất cả (dùng cho admin)
        snapshot = await ref.get();
      }

      List<MenuItem> menuItems = [];
      if (snapshot.exists && snapshot.value != null) {
        final value = snapshot.value;
        
        // Kiểm tra kiểu dữ liệu trả về
        if (value is Map) {
          Map<dynamic, dynamic> items = value as Map<dynamic, dynamic>;
          items.forEach((key, itemValue) {
            if (itemValue is Map) {
              try {
                // Cast to Map<dynamic, dynamic> first
                Map<dynamic, dynamic> rawMap = itemValue as Map<dynamic, dynamic>;
                // Convert to Map<String, dynamic>
                Map<String, dynamic> itemData = {};
                rawMap.forEach((k, v) {
                  itemData[k.toString()] = v;
                });
                itemData['id'] = key.toString();
                menuItems.add(MenuItem.fromJson(itemData));
              } catch (e) {
                print('Error parsing menu item $key: $e');
              }
            }
          });
        } else {
          print('Unexpected data type from Firebase: ${value.runtimeType}');
        }
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
