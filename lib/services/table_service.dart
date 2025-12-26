import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:quanlynhahang/models/table.dart';

class TableService {
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  // Get tables by owner ID
  Future<List<TableModel>> getTables([String? ownerId]) async {
    try {
      DatabaseReference ref = _database.ref('tables');
      DataSnapshot snapshot = await ref.get();

      List<TableModel> tables = [];
      if (snapshot.exists && snapshot.value != null) {
        final value = snapshot.value;
        
        // Kiểm tra kiểu dữ liệu
        if (value is Map) {
          Map<dynamic, dynamic> tableData = value as Map<dynamic, dynamic>;
          tableData.forEach((key, value) {
            if (value is Map) {
              Map<String, dynamic> tableMap = Map<String, dynamic>.from(value);
              tableMap['id'] = key;
              
              // Lọc theo ownerId nếu được cung cấp
              if (ownerId != null && ownerId.isNotEmpty) {
                if (tableMap['ownerId'] == ownerId) {
                  tables.add(TableModel.fromJson(tableMap));
                }
              } else {
                tables.add(TableModel.fromJson(tableMap));
              }
            }
          });
        }
      }
      
      // Sort by table number
      tables.sort((a, b) => a.number.compareTo(b.number));
      return tables;
    } catch (e) {
      print('Error getting tables: $e');
      return [];
    }
  }

  // Create table
  Future<String?> createTable(TableModel table) async {
    try {
      DatabaseReference ref = _database.ref('tables').push();
      await ref.set(table.toJson());
      return ref.key;
    } catch (e) {
      print('Error creating table: $e');
      return null;
    }
  }

  // Update table
  Future<bool> updateTable(TableModel table) async {
    try {
      DatabaseReference ref = _database.ref('tables/${table.id}');
      await ref.update(table.toJson());
      return true;
    } catch (e) {
      print('Error updating table: $e');
      return false;
    }
  }

  // Delete table
  Future<bool> deleteTable(String tableId) async {
    try {
      DatabaseReference ref = _database.ref('tables/$tableId');
      await ref.remove();
      return true;
    } catch (e) {
      print('Error deleting table: $e');
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
