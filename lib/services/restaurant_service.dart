import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:quanlynhahang/models/restaurant.dart';

class RestaurantService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Get restaurant by owner ID
  Future<Restaurant?> getRestaurantByOwnerId(String ownerId) async {
    try {
      DatabaseReference ref = _database.ref('restaurants');
      DataSnapshot snapshot = await ref
          .orderByChild('ownerId')
          .equalTo(ownerId)
          .get();

      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> restaurants =
            snapshot.value as Map<dynamic, dynamic>;
        String restaurantId = restaurants.keys.first;
        Map<String, dynamic> restaurantMap = Map<String, dynamic>.from(
          restaurants[restaurantId],
        );
        restaurantMap['id'] = restaurantId;
        return Restaurant.fromJson(restaurantMap);
      }
      return null;
    } catch (e) {
      print('Error getting restaurant: $e');
      return null;
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
      print('Error getting restaurant ID: $e');
      return null;
    }
  }

  // Update restaurant
  Future<bool> updateRestaurant(Restaurant restaurant) async {
    try {
      DatabaseReference ref = _database.ref('restaurants/${restaurant.id}');
      await ref.update(restaurant.toJson());
      return true;
    } catch (e) {
      print('Error updating restaurant: $e');
      return false;
    }
  }

  // Create restaurant
  Future<String?> createRestaurant(Map<String, dynamic> restaurantData) async {
    try {
      DatabaseReference ref = _database.ref('restaurants').push();
      await ref.set(restaurantData);
      return ref.key;
    } catch (e) {
      print('Error creating restaurant: $e');
      return null;
    }
  }
}
