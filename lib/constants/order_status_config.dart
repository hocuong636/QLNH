import 'package:flutter/material.dart';
import 'package:quanlynhahang/models/order.dart';

class OrderStatusConfig {
  static String getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.new_:
        return 'Đơn mới';
      case OrderStatus.cooking:
        return 'Đang chế biến';
      case OrderStatus.done:
        return 'Hoàn thành';
      case OrderStatus.paid:
        return 'Đã thanh toán';
    }
  }

  static Color getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.new_:
        return Colors.orange;
      case OrderStatus.cooking:
        return Colors.blue;
      case OrderStatus.done:
        return Colors.green;
      case OrderStatus.paid:
        return Colors.grey;
    }
  }

  static Color getStatusBackgroundColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.new_:
        return Colors.orange.shade100;
      case OrderStatus.cooking:
        return Colors.blue.shade100;
      case OrderStatus.done:
        return Colors.green.shade100;
      case OrderStatus.paid:
        return Colors.grey.shade100;
    }
  }

  static IconData getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.new_:
        return Icons.new_releases;
      case OrderStatus.cooking:
        return Icons.restaurant;
      case OrderStatus.done:
        return Icons.check_circle;
      case OrderStatus.paid:
        return Icons.payment;
    }
  }

  // Get next status for workflow
  static OrderStatus? getNextStatus(OrderStatus currentStatus) {
    switch (currentStatus) {
      case OrderStatus.new_:
        return OrderStatus.cooking;
      case OrderStatus.cooking:
        return OrderStatus.done;
      case OrderStatus.done:
        return OrderStatus.paid;
      case OrderStatus.paid:
        return null; // Final status
    }
  }

  // Get previous status for workflow
  static OrderStatus? getPreviousStatus(OrderStatus currentStatus) {
    switch (currentStatus) {
      case OrderStatus.new_:
        return null; // Initial status
      case OrderStatus.cooking:
        return OrderStatus.new_;
      case OrderStatus.done:
        return OrderStatus.cooking;
      case OrderStatus.paid:
        return OrderStatus.done;
    }
  }

  // Check if status can be updated by specific role
  static bool canUpdateStatus(OrderStatus currentStatus, String userRole) {
    switch (userRole) {
      case 'ORDER':
        // Order staff can update from new_ to cooking
        return currentStatus == OrderStatus.new_;
      case 'KITCHEN':
        // Kitchen can update from new_ to cooking, and cooking to done
        return currentStatus == OrderStatus.new_ ||
            currentStatus == OrderStatus.cooking;
      case 'OWNER':
        // Owner can update any status
        return true;
      default:
        return false;
    }
  }

  // Get available next statuses for specific role
  static List<OrderStatus> getAvailableStatuses(
    OrderStatus currentStatus,
    String userRole,
  ) {
    List<OrderStatus> available = [];

    switch (userRole) {
      case 'ORDER':
        if (currentStatus == OrderStatus.new_) {
          available.add(OrderStatus.cooking);
        }
        break;
      case 'KITCHEN':
        if (currentStatus == OrderStatus.new_) {
          available.add(OrderStatus.cooking);
        } else if (currentStatus == OrderStatus.cooking) {
          available.add(OrderStatus.done);
        }
        break;
      case 'OWNER':
        OrderStatus? next = getNextStatus(currentStatus);
        if (next != null) {
          available.add(next);
        }
        break;
    }

    return available;
  }
}
