/// Các loại hình nhà hàng
class RestaurantType {
  static const String fastFood = 'fast_food';
  static const String restaurant = 'restaurant';
  static const String cafe = 'cafe';
  static const String bar = 'bar';
  static const String bakery = 'bakery';
  static const String buffet = 'buffet';
  
  static const List<String> allTypes = [
    fastFood,
    restaurant,
    cafe,
    bar,
    bakery,
    buffet,
  ];
  
  static String getDisplayName(String? type) {
    switch (type) {
      case fastFood:
        return 'Ăn Nhanh';
      case restaurant:
        return 'Nhà Hàng';
      case cafe:
        return 'Café';
      case bar:
        return 'Bar';
      case bakery:
        return 'Tiệm Bánh';
      case buffet:
        return 'Buffet';
      default:
        return 'Không xác định';
    }
  }
}

