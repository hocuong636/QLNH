import 'package:flutter/material.dart';

/// Trạng thái nhà hàng
class RestaurantStatus {
  static const String active = 'active';
  static const String suspended = 'suspended';
  static const String locked = 'locked';
  
  static const List<String> allStatuses = [
    active,
    suspended,
    locked,
  ];
  
  static String getDisplayName(String? status) {
    switch (status) {
      case active:
        return 'Hoạt động';
      case suspended:
        return 'Tạm ngưng';
      case locked:
        return 'Bị khóa';
      default:
        return 'Không xác định';
    }
  }
  
  static Color getStatusColor(String? status) {
    switch (status) {
      case active:
        return Colors.green;
      case suspended:
        return Colors.orange;
      case locked:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  static IconData getStatusIcon(String? status) {
    switch (status) {
      case active:
        return Icons.check_circle;
      case suspended:
        return Icons.pause_circle;
      case locked:
        return Icons.lock;
      default:
        return Icons.help;
    }
  }
}

