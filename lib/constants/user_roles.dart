/// Các role người dùng trong hệ thống
class UserRole {
  // Role hiện tại
  static const String admin = 'admin';
  static const String order = 'order';
  
  // Role mới
  static const String owner = 'OWNER';
  static const String manager = 'MANAGER';
  static const String kitchen = 'KITCHEN';
  static const String cashier = 'CASHIER';
  static const String customer = 'KHÁCH HÀNG';
  
  // Danh sách tất cả các role
  static const List<String> allRoles = [
    admin,
    order,
    owner,
    manager,
    kitchen,
    cashier,
    customer,
  ];
  
  // Kiểm tra xem role có phải là admin hoặc có quyền admin không
  static bool isAdminRole(String? role) {
    if (role == null) return false;
    return role == admin || role == owner || role == manager;
  }
  
  // Kiểm tra xem role có phải là nhân viên không
  static bool isStaffRole(String? role) {
    if (role == null) return false;
    return role == kitchen || role == cashier || role == order;
  }
  
  // Lấy tên hiển thị của role
  static String getDisplayName(String? role) {
    switch (role) {
      case admin:
        return 'Quản trị viên';
      case owner:
        return 'Chủ nhà hàng';
      case manager:
        return 'Quản lý';
      case kitchen:
        return 'Bếp';
      case cashier:
        return 'Thu ngân';
      case order:
        return 'Nhân viên đặt hàng';
      case customer:
        return 'Khách hàng';
      default:
        return 'Không xác định';
    }
  }

  // Lấy route điều hướng dựa trên role
  static String getRouteForRole(String? role) {
    switch (role) {
      case admin:
        return '/admin';
      case owner:
        return '/owner';
      case manager:
        return '/manager';
      case kitchen:
        return '/kitchen';
      case cashier:
        return '/cashier';
      case order:
        return '/order';
      case customer:
        return '/home';
      default:
        return '/home'; // Mặc định về home
    }
  }
}

