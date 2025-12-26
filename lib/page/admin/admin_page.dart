import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:quanlynhahang/services/auth_service.dart';
import 'package:quanlynhahang/constants/restaurant_status.dart';
import 'owner_management_page.dart';
import 'restaurant_management_page.dart';
import '../shared/profile_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();

  // Sử dụng cùng database instance như AuthService
  FirebaseDatabase get _database {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
    );
  }

  DatabaseReference get _dbRef => _database.ref();

  int _selectedIndex = 0;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

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
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Đăng Xuất',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          content: const Text(
            'Bạn có chắc chắn muốn đăng xuất?',
            style: TextStyle(color: Color(0xFF666666), fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF666666),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                _authService.signOut();
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC3545),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Đăng Xuất'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    List<Widget> pages = [
      _buildDashboardPage(),
      const OwnerManagementPage(),
      const RestaurantManagementPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.restaurant_menu,
                color: colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Quản Lý Nhà Hàng',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF666666)),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _selectedIndex == 0 ? _buildQuickActionFAB() : null,
    );
  }

  Widget _buildDashboardPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          // Container(
          //   padding: const EdgeInsets.all(20),
          //   decoration: BoxDecoration(
          //     gradient: const LinearGradient(
          //       colors: [Colors.blue, Colors.indigo],
          //       begin: Alignment.topLeft,
          //       end: Alignment.bottomRight,
          //     ),
          //     borderRadius: BorderRadius.circular(16),
          //     boxShadow: [
          //       BoxShadow(
          //         color: Colors.blue.withOpacity(0.3),
          //         blurRadius: 12,
          //         offset: const Offset(0, 6),
          //       ),
          //     ],
          //   ),
          //   child: const Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: [
          //       Text(
          //         'Dashboard',
          //         style: TextStyle(
          //           fontSize: 32,
          //           fontWeight: FontWeight.bold,
          //           color: Colors.white,
          //           letterSpacing: 1.2,
          //         ),
          //       ),
          //       SizedBox(height: 8),
          //       Text(
          //         'Tổng quan hệ thống quản lý nhà hàng',
          //         style: TextStyle(
          //           fontSize: 16,
          //           color: Colors.white70,
          //           fontWeight: FontWeight.w400,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          const SizedBox(height: 32),

          // Stats Grid
          const Text(
            'Thống Kê Hệ Thống',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 20),

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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Card(
        elevation: 8,
        shadowColor: color.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Colors.white, color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 36),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<DatabaseEvent>(
                      stream: stream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Container(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          print('StatCard [$title]: Error - ${snapshot.error}');
                          return const Text(
                            '0',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          );
                        }

                        if (snapshot.hasData &&
                            snapshot.data!.snapshot.exists) {
                          final data = snapshot.data!.snapshot.value;
                          int count = 0;
                          if (data != null) {
                            if (filter != null) {
                              count = filter(data);
                            } else if (data is Map) {
                              count = data.length;
                              print(
                                'StatCard [$title]: Found $count items (Map)',
                              );
                              if (count > 0) {
                                final keys = data.keys.take(3).toList();
                                print('StatCard [$title]: Sample keys: $keys');
                              }
                            } else if (data is List) {
                              count = data.length;
                              print(
                                'StatCard [$title]: Found $count items (List)',
                              );
                            } else {
                              print(
                                'StatCard [$title]: Data type is ${data.runtimeType}, value: $data',
                              );
                              count = 1;
                            }
                          } else {
                            print('StatCard [$title]: Data is null');
                          }
                          return TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: count),
                            duration: const Duration(milliseconds: 800),
                            builder: (context, value, child) {
                              return Text(
                                '$value',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                  shadows: [
                                    Shadow(
                                      color: color.withOpacity(0.3),
                                      offset: const Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }

                        print(
                          'StatCard [$title]: No data or snapshot does not exist',
                        );
                        print(
                          'StatCard [$title]: hasData=${snapshot.hasData}, exists=${snapshot.data?.snapshot.exists}',
                        );
                        return const Text(
                          '0',
                          style: TextStyle(
                            fontSize: 32,
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
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: Colors.grey.shade500,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          elevation: 0,
          backgroundColor: Colors.white,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined, size: 24),
              activeIcon: Icon(Icons.dashboard, size: 26),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, size: 24),
              activeIcon: Icon(Icons.person, size: 26),
              label: 'Owner',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_outlined, size: 24),
              activeIcon: Icon(Icons.restaurant, size: 26),
              label: 'Nhà Hàng',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle_outlined, size: 24),
              activeIcon: Icon(Icons.account_circle, size: 26),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionFAB() {
    final colorScheme = Theme.of(context).colorScheme;

    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton.extended(
        onPressed: () {
          // Quick action - navigate to restaurant management
          setState(() {
            _selectedIndex = 2;
          });
        },
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'Thêm Nhà Hàng',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ),
    );
  }
}
