/// Các role người dùng trong hệ thống
class UserRole {
  // Role hiện tại
  static const String admin = 'admin';
  static const String order = 'order';
  // Role mới
  static const String owner = 'OWNER';
  static const String kitchen = 'KITCHEN';
  static const String customer = 'customer'; // Khách hàng
  
  // Danh sách tất cả các role
  static const List<String> allRoles = [
    admin,
    order,
    owner,
    kitchen,
    customer,
  ];
  
  // Kiểm tra xem role có phải là admin hoặc có quyền admin không
  static bool isAdminRole(String? role) {
    if (role == null) return false;
    return role == admin || role == owner;
  }
  
  // Kiểm tra xem role có phải là nhân viên không
  static bool isStaffRole(String? role) {
    if (role == null) return false;
    return role == kitchen || role == order;
  }
  
  // Lấy tên hiển thị của role
  static String getDisplayName(String? role) {
    switch (role) {
      case admin:
        return 'Quản trị toàn bộ hệ thống';
      case owner:
        return 'Quản lý và vận hành nhà hàng';
      case kitchen:
        return 'Xử lý và chế biến món ăn';
      case order:
        return 'Nhận order & thanh toán';
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
      case kitchen:
        return '/kitchen';
      case order:
        return '/order';
      case customer:
        return '/customer';
      default:
        return '/customer'; // Mặc định là customer
    }
  }
}

