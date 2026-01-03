/// Các gói dịch vụ
class SubscriptionPlan {
  static const String free = 'free';
  static const String basic = 'basic';
  static const String pro = 'pro';
  static const String enterprise = 'enterprise';
  
  static const List<String> allPlans = [
    free,
    basic,
    pro,
    enterprise,
  ];
  
  static String getDisplayName(String? plan) {
    switch (plan) {
      case free:
        return 'Free';
      case basic:
        return 'Basic';
      case pro:
        return 'Pro';
      case enterprise:
        return 'Enterprise';
      default:
        return 'Không xác định';
    }
  }
  
  // Giới hạn của từng gói
  static Map<String, dynamic> getLimits(String plan) {
    switch (plan) {
      case free:
        return {
          'maxBranches': 1,
          'maxUsers': 3,
          'maxOrdersPerDay': 50,
          'features': ['basic_ordering', 'basic_reports'],
        };
      case basic:
        return {
          'maxBranches': 3,
          'maxUsers': 10,
          'maxOrdersPerDay': 200,
          'features': ['basic_ordering', 'basic_reports', 'inventory'],
        };
      case pro:
        return {
          'maxBranches': 10,
          'maxUsers': 50,
          'maxOrdersPerDay': 1000,
          'features': ['basic_ordering', 'basic_reports', 'inventory', 'advanced_reports', 'analytics'],
        };
      case enterprise:
        return {
          'maxBranches': -1, // Unlimited
          'maxUsers': -1, // Unlimited
          'maxOrdersPerDay': -1, // Unlimited
          'features': ['all'],
        };
      default:
        return {
          'maxBranches': 1,
          'maxUsers': 3,
          'maxOrdersPerDay': 50,
          'features': [],
        };
    }
  }
}

