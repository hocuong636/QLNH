import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/auth_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/services/dashboard_service.dart';
import 'package:quanlynhahang/constants/user_roles.dart';
import '../shared/profile_page.dart';
import 'menu_management_page.dart';
import 'table_management_page.dart';
import 'order_management_page.dart';
import 'inventory_management_page.dart';
import 'owner_restaurant_management_page.dart';
import 'staff_management_page.dart';

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
            leading: const Icon(Icons.inventory),
            title: const Text('Quản lý kho'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const InventoryManagementPage(),
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
    return RefreshIndicator(
      onRefresh: _loadDashboardStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              'Dashboard',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Quản lý nhà hàng của bạn',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 30),

            // Statistics Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Tổng đơn hàng',
                    _isLoadingStats ? '...' : _totalOrders.toString(),
                    Icons.receipt_long,
                    Colors.blue,
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const OrderManagementPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Doanh thu',
                    _isLoadingStats
                        ? '...'
                        : '${(_totalRevenue / 1000000).toStringAsFixed(1)}M VND',
                    Icons.attach_money,
                    Colors.green,
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const OrderManagementPage(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Món bán chạy',
                    _bestSellingItem,
                    Icons.trending_up,
                    Colors.orange,
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const MenuManagementPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Trạng thái',
                    _restaurantStatus,
                    Icons.store,
                    Colors.purple,
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const OwnerRestaurantManagementPage(),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Management Cards
            Text(
              'Quản lý',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            _buildManagementCard(
              'Quản lý thực đơn',
              'Thêm, sửa, xóa món ăn',
              Icons.restaurant_menu,
              Colors.green,
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MenuManagementPage(),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildManagementCard(
              'Quản lý bàn',
              'Theo dõi trạng thái bàn',
              Icons.table_restaurant,
              Colors.orange,
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TableManagementPage(),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildManagementCard(
              'Quản lý đơn hàng',
              'Xem và cập nhật đơn hàng',
              Icons.receipt_long,
              Colors.purple,
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const OrderManagementPage(),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildManagementCard(
              'Quản lý kho',
              'Theo dõi nguyên liệu',
              Icons.inventory,
              Colors.teal,
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const InventoryManagementPage(),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildManagementCard(
              'Quản lý nhân viên',
              'Thêm và quản lý nhân viên nhà hàng',
              Icons.people,
              Colors.indigo,
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const StaffManagementPage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
