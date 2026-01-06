import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:quanlynhahang/services/auth_service.dart';
import 'package:quanlynhahang/constants/restaurant_status.dart';
import 'owner_management_page.dart';
import 'restaurant_management_page.dart';
import 'user_management_page.dart';
import 'audit_log_page.dart';
import 'service_package_management_page.dart';
import 'owner_package_management_page.dart';
import 'request_management_page.dart';
import 'settlement_management_page.dart';
import 'package_revenue_page.dart';
import '../shared/profile_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final AuthService _authService = AuthService();

  // Sử dụng cùng database instance như AuthService
  FirebaseDatabase get _database {
    return FirebaseDatabase.instance;
  }

  DatabaseReference get _dbRef => _database.ref();

  int _selectedIndex = 0;

  // Package Revenue Stats
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  double _totalPackageRevenue = 0;
  double _todayPackageRevenue = 0;
  double _monthPackageRevenue = 0;
  int _totalPackageTransactions = 0;
  int _pendingPackagePayments = 0;
  bool _isLoadingPackageStats = false;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadPackageRevenueStats();
  }

  Future<void> _loadPackageRevenueStats() async {
    setState(() => _isLoadingPackageStats = true);
    
    try {
      List<Map<String, dynamic>> allPayments = [];
      
      // Load owner registration payments from 'requests'
      final requestsSnapshot = await _dbRef.child('requests').get();
      if (requestsSnapshot.exists && requestsSnapshot.value is Map) {
        final data = Map<String, dynamic>.from(requestsSnapshot.value as Map);
        for (final entry in data.entries) {
          if (entry.value is! Map) continue;
          final request = Map<String, dynamic>.from(entry.value as Map);
          final type = request['type'];
          final status = request['status'];
          final packagePrice = request['packagePrice'];
          
          if (type == 'owner' && status == 'approved' && packagePrice != null) {
            final payment = <String, dynamic>{
              'price': (packagePrice is num) ? packagePrice.toDouble() : 0.0,
              'status': (request['paymentStatus'] == 'paid') ? 'completed' : 'pending',
            };
            
            if (request['createdAt'] != null) {
              payment['createdAtDate'] = DateTime.tryParse(request['createdAt'].toString()) ?? DateTime.now();
            } else {
              payment['createdAtDate'] = DateTime.now();
            }
            
            allPayments.add(payment);
          }
        }
      }
      
      // Load renewal history from 'renewal_history'
      final renewalSnapshot = await _dbRef.child('renewal_history').get();
      if (renewalSnapshot.exists && renewalSnapshot.value is Map) {
        final data = Map<String, dynamic>.from(renewalSnapshot.value as Map);
        for (final entry in data.entries) {
          if (entry.value is! Map) continue;
          final renewal = Map<String, dynamic>.from(entry.value as Map);
          
          final payment = <String, dynamic>{
            'price': (renewal['packagePrice'] is num) 
                ? (renewal['packagePrice'] as num).toDouble() 
                : 0.0,
            'status': 'completed',
          };
          
          if (renewal['createdAt'] != null) {
            payment['createdAtDate'] = DateTime.tryParse(renewal['createdAt'].toString()) ?? DateTime.now();
          } else {
            payment['createdAtDate'] = DateTime.now();
          }
          
          allPayments.add(payment);
        }
      }
      
      // Calculate stats
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final monthStart = DateTime(now.year, now.month, 1);
      
      _totalPackageRevenue = 0;
      _todayPackageRevenue = 0;
      _monthPackageRevenue = 0;
      _totalPackageTransactions = 0;
      _pendingPackagePayments = 0;
      
      for (final payment in allPayments) {
        final status = payment['status'];
        final price = (payment['price'] ?? 0).toDouble();
        final createdAt = payment['createdAtDate'] as DateTime;
        
        if (status == 'completed') {
          _totalPackageRevenue += price;
          _totalPackageTransactions++;
          
          if (createdAt.isAfter(todayStart)) {
            _todayPackageRevenue += price;
          }
          
          if (createdAt.isAfter(monthStart)) {
            _monthPackageRevenue += price;
          }
        } else if (status == 'pending') {
          _pendingPackagePayments++;
        }
      }
    } catch (e) {
      print('Error loading package revenue stats: $e');
    }
    
    if (mounted) {
      setState(() => _isLoadingPackageStats = false);
    }
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
      const UserManagementPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _selectedIndex == 0 ? AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        centerTitle: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Color(0xFF4CAF50),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, Admin 👋',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tổng quan hệ thống hôm nay',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () {
                // TODO: mở trang thông báo hệ thống
              },
              icon: const Icon(Icons.notifications_none_rounded,
                  color: Color(0xFF4CAF50), size: 22),
              tooltip: 'Thông báo',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout_rounded, 
                  color: Color(0xFFEF4444), size: 22),
              tooltip: 'Đăng xuất',
            ),
          ),
        ],
      ) : null,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildDashboardPage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF5F7FA), Color(0xFFFFFFFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Package Revenue Card
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PackageRevenuePage(),
                    ),
                  ).then((_) => _loadPackageRevenueStats());
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF4CAF50),
                        const Color(0xFF4CAF50).withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isLoadingPackageStats
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.card_giftcard,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Doanh thu dịch vụ',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'Từ gói dịch vụ & gia hạn',
                                            style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _currencyFormat.format(_totalPackageRevenue),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$_totalPackageTransactions giao dịch thành công',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: _loadPackageRevenueStats,
                                tooltip: 'Làm mới',
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Quick Stats Cards
            Row(
              children: [
                Expanded(
                  child: _buildQuickStatCard(
                    'Hôm nay',
                    _currencyFormat.format(_todayPackageRevenue),
                    Icons.today,
                    Colors.blue.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickStatCard(
                    'Tháng này',
                    _currencyFormat.format(_monthPackageRevenue),
                    Icons.calendar_month,
                    Colors.purple.shade600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildQuickStatCard(
                    'Đang chờ',
                    '$_pendingPackagePayments',
                    Icons.pending_actions,
                    Colors.orange.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickStatCard(
                    'Hoàn thành',
                    '$_totalPackageTransactions',
                    Icons.check_circle,
                    const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // System Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Tổng Người Dùng',
                    subtitle: 'Tất cả tài khoản trong hệ thống',
                    icon: Icons.people_rounded,
                    color: Colors.teal,
                    stream: _dbRef.child('users').onValue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Tổng Nhà Hàng',
                    subtitle: 'Bao gồm mọi trạng thái',
                    icon: Icons.restaurant_rounded,
                    color: Colors.deepOrange,
                    stream: _dbRef.child('restaurants').onValue,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Chức năng Quản lý',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    title: 'Quản lý Người dùng',
                    icon: Icons.people_rounded,
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      setState(() {
                        _selectedIndex = 1;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    title: 'Quản lý Nhà hàng',
                    icon: Icons.restaurant_rounded,
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RestaurantManagementPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    title: 'Owner & Gói',
                    icon: Icons.business_center_rounded,
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OwnerPackageManagementPage(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    title: 'Yêu cầu',
                    icon: Icons.request_quote_rounded,
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RequestManagementPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    title: 'Gói dịch vụ',
                    icon: Icons.card_giftcard_rounded,
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ServicePackageManagementPage(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    title: 'Thanh toán Owner',
                    icon: Icons.account_balance_wallet_rounded,
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettlementManagementPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    title: 'Thống kê',
                    icon: Icons.analytics_rounded,
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PackageRevenuePage(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    title: 'Nhật ký hoạt động',
                    icon: Icons.history_rounded,
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AuditLogPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 160,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF4CAF50), size: 28),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Stream<DatabaseEvent> stream,
    int Function(dynamic)? filter,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<DatabaseEvent>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SizedBox(
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
                return Text(
                  '0',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
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
                return TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: count),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    );
                  },
                );
              }

              print('StatCard [$title]: No data or snapshot does not exist');
              print('StatCard [$title]: hasData=${snapshot.hasData}, exists=${snapshot.data?.snapshot.exists}');
              return Text(
                '0',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              );
            },
          ),
        ],
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
          selectedItemColor: const Color(0xFF4CAF50),
          unselectedItemColor: const Color(0xFF9CA3AF),
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
              icon: Icon(Icons.people_outline, size: 24),
              activeIcon: Icon(Icons.people, size: 26),
              label: 'Người dùng',
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

}
