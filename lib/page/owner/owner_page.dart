import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/auth_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/services/dashboard_service.dart';
import 'package:quanlynhahang/constants/user_roles.dart';
import '../shared/profile_page.dart';
import '../revenue/revenue_page.dart';
import 'menu_management_page.dart';
import 'table_management_page.dart';
import 'order_management_page.dart';
import 'owner_restaurant_management_page.dart';
import 'staff_management_page.dart';
import 'staff_request_management_page.dart';
import 'reports_page.dart';
import 'package_renewal_page.dart';

class OwnerPage extends StatefulWidget {
  const OwnerPage({super.key});

  @override
  State<OwnerPage> createState() => _OwnerPageState();
}

class _OwnerPageState extends State<OwnerPage> {
  final AuthService _authService = AuthService();
  final LocalStorageService _localStorageService = LocalStorageService();
  final DashboardService _dashboardService = DashboardService();
  int _selectedIndex = 0;

  // Dashboard stats
  bool _isLoadingStats = true;
  int _totalOrders = 0;
  double _totalRevenue = 0.0;
  String _bestSellingItem = 'Đang tải...';
  String _restaurantStatus = 'Đang tải...';

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      String? restaurantId = _localStorageService.getRestaurantId();
      if (restaurantId != null) {
        final stats = await _dashboardService.getDashboardStats(restaurantId);
        setState(() {
          _totalOrders = stats['totalOrders'];
          _totalRevenue = stats['totalRevenue'];
          _bestSellingItem = stats['bestSellingItem'];
          _restaurantStatus = stats['restaurantStatus'];
          _isLoadingStats = false;
        });
      } else {
        setState(() {
          _bestSellingItem = 'Chưa thiết lập';
          _restaurantStatus = 'Chưa thiết lập';
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('Error loading dashboard stats: $e');
      setState(() {
        _bestSellingItem = 'Lỗi tải dữ liệu';
        _restaurantStatus = 'Lỗi tải dữ liệu';
        _isLoadingStats = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Refresh dashboard data when switching to dashboard tab
    if (index == 0) {
      _loadDashboardStats();
    }
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Đăng Xuất'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                _authService.signOut();
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              },
              child: const Text('Đăng Xuất'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue.shade700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.restaurant, size: 30, color: Colors.blue),
                ),
                const SizedBox(height: 10),
                Text(
                  _localStorageService.getUserName() ?? 'Owner',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  UserRole.getDisplayName(_localStorageService.getUserRole()),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Trang chủ'),
            onTap: () {
              Navigator.of(context).pop();
              setState(() => _selectedIndex = 0);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.restaurant_menu),
            title: const Text('Quản lý thực đơn'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MenuManagementPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_restaurant),
            title: const Text('Quản lý bàn'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TableManagementPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Quản lý đơn hàng'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const OrderManagementPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Quản lý nhân viên'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const StaffManagementPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.account_balance_wallet, color: Colors.orange.shade600),
            title: const Text('Doanh thu'),
            subtitle: const Text('Xem doanh thu nhà hàng', style: TextStyle(fontSize: 12)),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const RevenuePage(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.card_membership, color: Colors.purple.shade600),
            title: const Text('Gia hạn gói dịch vụ'),
            subtitle: const Text('Gia hạn hoặc nâng cấp gói', style: TextStyle(fontSize: 12)),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PackageRenewalPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? userName = _localStorageService.getUserName();
    String? userRole = _localStorageService.getUserRole();

    List<Widget> pages = [_buildDashboardPage(userName), const ProfilePage()];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Xin chào, ${userName ?? 'Owner'}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: _handleLogout,
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Container(color: Colors.grey.shade50, child: pages[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey.shade600,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Trang Chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Hồ Sơ',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardPage(String? userName) {
    return const OwnerReportsPage();
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagementCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
