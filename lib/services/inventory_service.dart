import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:quanlynhahang/models/inventory_item.dart';
import 'package:quanlynhahang/models/inventory_history.dart';
import 'package:quanlynhahang/models/inventory_check.dart';

class InventoryService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Get inventory items by restaurant ID
  Future<List<InventoryItem>> getInventoryItems(String restaurantId) async {
    try {
      DatabaseReference ref = _database.ref('inventory');
      DataSnapshot snapshot = await ref
          .orderByChild('restaurantID')
          .equalTo(restaurantId)
          .get();

      List<InventoryItem> items = [];
      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> itemData =
            snapshot.value as Map<dynamic, dynamic>;
        itemData.forEach((key, value) {
          if (value is Map) {
            // Cast to Map<dynamic, dynamic> first
            Map<dynamic, dynamic> rawMap = value as Map<dynamic, dynamic>;
            // Convert to Map<String, dynamic>
            Map<String, dynamic> itemMap = {};
            rawMap.forEach((k, v) {
              itemMap[k.toString()] = v;
            });
            itemMap['id'] = key.toString();
            InventoryItem item = InventoryItem.fromJson(itemMap);
            if (item.isActive) {
              items.add(item);
            }
          }
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

  // Deactivate inventory item
  Future<bool> deactivateInventoryItem(String itemId) async {
    try {
      DatabaseReference ref = _database.ref('inventory/$itemId');
      await ref.update({'isActive': false});
      return true;
    } catch (e) {
      print('Error deactivating inventory item: $e');
      return false;
    }
  }

  // Update inventory quantity and log history
  Future<bool> updateInventoryQuantity(
    String itemId,
    double newQuantity,
    String action,
    String notes,
  ) async {
    try {
      // Get current item
      DatabaseReference itemRef = _database.ref('inventory/$itemId');
      DataSnapshot snapshot = await itemRef.get();
      if (!snapshot.exists) return false;

      Map<dynamic, dynamic> rawMap = snapshot.value as Map<dynamic, dynamic>;
      Map<String, dynamic> itemMap = {};
      rawMap.forEach((k, v) {
        itemMap[k.toString()] = v;
      });
      itemMap['id'] = itemId;
      InventoryItem currentItem = InventoryItem.fromJson(itemMap);

      double quantityChange = newQuantity - currentItem.quantity;

      // Update item
      await itemRef.update({
        'quantity': newQuantity,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      // Log history
      DatabaseReference historyRef = _database.ref('inventory_history').push();
      InventoryHistory history = InventoryHistory(
        id: '',
        inventoryItemId: itemId,
        restaurantId: currentItem.restaurantId,
        action: action,
        quantityChange: quantityChange,
        newQuantity: newQuantity,
        notes: notes,
        timestamp: DateTime.now(),
      );
      await historyRef.set(history.toJson());

      return true;
    } catch (e) {
      print('Error updating inventory quantity: $e');
      return false;
    }
  }

  // Get inventory history
  Future<List<InventoryHistory>> getInventoryHistory(
    String restaurantId,
  ) async {
    try {
      DatabaseReference ref = _database.ref('inventory_history');
      DataSnapshot snapshot = await ref
          .orderByChild('restaurantID')
          .equalTo(restaurantId)
          .get();

      List<InventoryHistory> history = [];
      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> historyData =
            snapshot.value as Map<dynamic, dynamic>;
        historyData.forEach((key, value) {
          if (value is Map) {
            Map<dynamic, dynamic> rawMap = value as Map<dynamic, dynamic>;
            Map<String, dynamic> historyMap = {};
            rawMap.forEach((k, v) {
              historyMap[k.toString()] = v;
            });
            historyMap['id'] = key.toString();
            history.add(InventoryHistory.fromJson(historyMap));
          }
        });
      }
      history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return history;
    } catch (e) {
      print('Error getting inventory history: $e');
      return [];
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

  // Create inventory check
  Future<String?> createInventoryCheck(InventoryCheck check) async {
    try {
      DatabaseReference ref = _database.ref('inventory_checks').push();
      await ref.set(check.toJson());
      return ref.key;
    } catch (e) {
      print('Error creating inventory check: $e');
      return null;
    }
  }

  // Get inventory checks by restaurant ID
  Future<List<InventoryCheck>> getInventoryChecks(String restaurantId) async {
    try {
      DatabaseReference ref = _database.ref('inventory_checks');
      DataSnapshot snapshot = await ref
          .orderByChild('restaurantID')
          .equalTo(restaurantId)
          .get();

      List<InventoryCheck> checks = [];
      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> checkData =
            snapshot.value as Map<dynamic, dynamic>;
        checkData.forEach((key, value) {
          if (value is Map) {
            Map<dynamic, dynamic> rawMap = value as Map<dynamic, dynamic>;
            Map<String, dynamic> checkMap = {};
            rawMap.forEach((k, v) {
              checkMap[k.toString()] = v;
            });
            checkMap['id'] = key.toString();
            checks.add(InventoryCheck.fromJson(checkMap));
          }
        });
      }
      checks.sort((a, b) => b.checkedAt.compareTo(a.checkedAt));
      return checks;
    } catch (e) {
      print('Error getting inventory checks: $e');
      return [];
    }
  }

  // Get inventory checks by item ID
  Future<List<InventoryCheck>> getInventoryChecksByItem(String itemId) async {
    try {
      DatabaseReference ref = _database.ref('inventory_checks');
      DataSnapshot snapshot = await ref
          .orderByChild('inventoryItemId')
          .equalTo(itemId)
          .get();

      List<InventoryCheck> checks = [];
      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> checkData =
            snapshot.value as Map<dynamic, dynamic>;
        checkData.forEach((key, value) {
          if (value is Map) {
            Map<dynamic, dynamic> rawMap = value as Map<dynamic, dynamic>;
            Map<String, dynamic> checkMap = {};
            rawMap.forEach((k, v) {
              checkMap[k.toString()] = v;
            });
            checkMap['id'] = key.toString();
            checks.add(InventoryCheck.fromJson(checkMap));
          }
        });
      }
      checks.sort((a, b) => b.checkedAt.compareTo(a.checkedAt));
      return checks;
    } catch (e) {
      print('Error getting inventory checks by item: $e');
      return [];
    }
  }
}
