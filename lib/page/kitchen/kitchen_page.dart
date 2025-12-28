import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/auth_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import '../shared/profile_page.dart';
import 'kitchen_orders_page.dart';
import 'kitchen_inventory_page.dart';

class KitchenPage extends StatefulWidget {
  const KitchenPage({super.key});

  @override
  State<KitchenPage> createState() => _KitchenPageState();
}

class _KitchenPageState extends State<KitchenPage> {
  final AuthService _authService = AuthService();
  final LocalStorageService _localStorageService = LocalStorageService();
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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

  @override
  Widget build(BuildContext context) {
    String? userName = _localStorageService.getUserName();

    List<Widget> pages = [
      KitchenOrdersPage(),
      KitchenInventoryPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Xin chào, ${userName ?? 'Bếp'}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: _handleLogout,
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: Container(color: Colors.grey.shade50, child: pages[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey.shade600,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_outlined),
            activeIcon: Icon(Icons.restaurant_menu),
            label: 'Đơn Hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_outlined),
            activeIcon: Icon(Icons.inventory),
            label: 'Kiểm Kho',
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
}
