import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:quanlynhahang/services/auth_service.dart';
import 'package:quanlynhahang/constants/user_roles.dart';
import 'package:quanlynhahang/constants/restaurant_status.dart';
import '../owner/owner_management_page.dart';
import '../owner/restaurant_management_page.dart';
import '../owner/subscription_management_page.dart';
import '../owner/system_settings_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final AuthService _authService = AuthService();
  
  // Sử dụng cùng database instance như AuthService
  FirebaseDatabase get _database {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
    );
  }
  
  DatabaseReference get _dbRef => _database.ref();
  
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
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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
    List<Widget> pages = [
      _buildDashboardPage(),
      const OwnerManagementPage(),
      const RestaurantManagementPage(),
      const SubscriptionManagementPage(),
      const SystemSettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản Lý Nhà Hàng',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
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
      body: Container(
        color: Colors.grey.shade50,
        child: pages[_selectedIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey.shade600,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 8,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Owner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_outlined),
            activeIcon: Icon(Icons.restaurant),
            label: 'Nhà Hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_membership_outlined),
            activeIcon: Icon(Icons.card_membership),
            label: 'Gói DV',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Cài Đặt',
          ),
        ],
      ),
    );
  }

Widget _buildDashboardPage() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(20.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tổng quan hệ thống',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 30),

        /// Tổng người dùng
        _buildStatCard(
          title: 'Tổng Người Dùng',
          icon: Icons.people_outline,
          color: Colors.blue,
          stream: _dbRef.child('users').onValue,
        ),

        const SizedBox(height: 16),

        /// Nhà hàng đang hoạt động
        _buildStatCard(
          title: 'Nhà Hàng Đang Hoạt Động',
          icon: Icons.restaurant,
          color: Colors.green,
          stream: _dbRef.child('restaurants').onValue,
          filter: (data) {
            if (data is! Map) return 0;
            int count = 0;
            data.forEach((key, value) {
              if (value is Map) {
                final status = value['status']?.toString();
                if (status == RestaurantStatus.active) {
                  count++;
                }
              }
            });
            return count;
          },
        ),

        const SizedBox(height: 16),

        /// Tổng nhà hàng
        _buildStatCard(
          title: 'Tổng Nhà Hàng',
          icon: Icons.restaurant_outlined,
          color: Colors.blue,
          stream: _dbRef.child('restaurants').onValue,
        ),

        const SizedBox(height: 16),

        /// Tổng đơn hàng
        _buildStatCard(
          title: 'Tổng Đơn Hàng',
          icon: Icons.shopping_cart_outlined,
          color: Colors.orange,
          stream: _dbRef.child('orders').onValue,
        ),
      ],
    ),
  );
}


  Widget _buildStatCard({
    required String title,
    required IconData icon,
    required Color color,
    required Stream<DatabaseEvent> stream,
    int Function(dynamic)? filter,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
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
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<DatabaseEvent>(
                    stream: stream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text(
                          '...',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        print('StatCard [$title]: Error - ${snapshot.error}');
                        return const Text(
                          '0',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        );
                      }
                      
                      if (snapshot.hasData && snapshot.data!.snapshot.exists) {
                        final data = snapshot.data!.snapshot.value;
                        int count = 0;
                        if (data != null) {
                          if (filter != null) {
                            count = filter(data);
                          } else if (data is Map) {
                            count = data.length;
                            print('StatCard [$title]: Found $count items (Map)');
                            if (count > 0) {
                              final keys = data.keys.take(3).toList();
                              print('StatCard [$title]: Sample keys: $keys');
                            }
                          } else if (data is List) {
                            count = data.length;
                            print('StatCard [$title]: Found $count items (List)');
                          } else {
                            print('StatCard [$title]: Data type is ${data.runtimeType}, value: $data');
                            count = 1;
                          }
                        } else {
                          print('StatCard [$title]: Data is null');
                        }
                        return Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        );
                      }
                      
                      print('StatCard [$title]: No data or snapshot does not exist');
                      print('StatCard [$title]: hasData=${snapshot.hasData}, exists=${snapshot.data?.snapshot.exists}');
                      return const Text(
                        '0',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
