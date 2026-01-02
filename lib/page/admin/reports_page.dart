import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:quanlynhahang/models/order.dart';
import 'package:quanlynhahang/models/restaurant.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  String _selectedPeriod = 'today'; // today, week, month
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  
  Map<String, dynamic> _revenueData = {};
  List<Map<String, dynamic>> _topRestaurants = [];
  Map<String, int> _orderStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadRevenueData(),
        _loadTopRestaurants(),
        _loadOrderStats(),
      ]);

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading reports: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải báo cáo: $e')),
        );
      }
    }
  }

  Future<void> _loadRevenueData() async {
    try {
      final ordersSnapshot = await _database.ref('orders').get();
      double totalRevenue = 0;
      int totalOrders = 0;

      if (ordersSnapshot.exists) {
        final ordersData = ordersSnapshot.value as Map<dynamic, dynamic>?;
        if (ordersData != null) {
          ordersData.forEach((key, value) {
            if (value is Map) {
              final orderDate = value['createdAt'] != null
                  ? DateTime.parse(value['createdAt'])
                  : null;
              
              if (orderDate != null && _isDateInRange(orderDate)) {
                final status = value['status']?.toString();
                if (status == 'paid') {
                  final totalAmount = value['totalAmount'];
                  final total = totalAmount is int 
                      ? totalAmount.toDouble() 
                      : (totalAmount is double ? totalAmount : 0.0);
                  totalRevenue += total;
                  totalOrders++;
                }
              }
            }
          });
        }
      }

      setState(() {
        _revenueData = {
          'totalRevenue': totalRevenue,
          'totalOrders': totalOrders,
          'averageOrderValue': totalOrders > 0 ? totalRevenue / totalOrders : 0.0,
        };
      });
    } catch (e) {
      print('Error loading revenue data: $e');
    }
  }

  Future<void> _loadTopRestaurants() async {
    try {
      final restaurantsSnapshot = await _database.ref('restaurants').get();
      final ordersSnapshot = await _database.ref('orders').get();
      
      Map<String, double> restaurantRevenue = {};
      Map<String, String> restaurantNames = {};

      if (restaurantsSnapshot.exists) {
        final restaurantsData = restaurantsSnapshot.value as Map<dynamic, dynamic>?;
        if (restaurantsData != null) {
          restaurantsData.forEach((key, value) {
            if (value is Map) {
              restaurantNames[key] = value['name'] ?? 'Unknown';
              restaurantRevenue[key] = 0.0;
            }
          });
        }
      }

      if (ordersSnapshot.exists) {
        final ordersData = ordersSnapshot.value as Map<dynamic, dynamic>?;
        if (ordersData != null) {
          ordersData.forEach((key, value) {
            if (value is Map) {
              final orderDate = value['createdAt'] != null
                  ? DateTime.parse(value['createdAt'])
                  : null;
              
              if (orderDate != null && _isDateInRange(orderDate)) {
                final status = value['status']?.toString();
                if (status == 'paid') {
                  final restaurantId = value['restaurantId']?.toString();
                  final totalAmount = value['totalAmount'];
                  final total = totalAmount is int 
                      ? totalAmount.toDouble() 
                      : (totalAmount is double ? totalAmount : 0.0);
                  
                  if (restaurantId != null && restaurantRevenue.containsKey(restaurantId)) {
                    restaurantRevenue[restaurantId] = 
                        (restaurantRevenue[restaurantId] ?? 0.0) + total;
                  }
                }
              }
            }
          });
        }
      }

      final topList = restaurantRevenue.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _topRestaurants = topList.take(5).map((entry) {
          return {
            'id': entry.key,
            'name': restaurantNames[entry.key] ?? 'Unknown',
            'revenue': entry.value,
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading top restaurants: $e');
    }
  }

  Future<void> _loadOrderStats() async {
    try {
      final ordersSnapshot = await _database.ref('orders').get();
      Map<String, int> stats = {
        'new': 0,
        'cooking': 0,
        'done': 0,
        'paid': 0,
      };

      if (ordersSnapshot.exists) {
        final ordersData = ordersSnapshot.value as Map<dynamic, dynamic>?;
        if (ordersData != null) {
          ordersData.forEach((key, value) {
            if (value is Map) {
              final orderDate = value['createdAt'] != null
                  ? DateTime.parse(value['createdAt'])
                  : null;
              
              if (orderDate != null && _isDateInRange(orderDate)) {
                final status = value['status']?.toString();
                if (status != null) {
                  final statusKey = status.replaceAll('_', '');
                  if (stats.containsKey(statusKey)) {
                    stats[statusKey] = (stats[statusKey] ?? 0) + 1;
                  }
                }
              }
            }
          });
        }
      }

      setState(() {
        _orderStats = stats;
      });
    } catch (e) {
      print('Error loading order stats: $e');
    }
  }

  bool _isDateInRange(DateTime date) {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'today':
        return date.year == now.year && 
               date.month == now.month && 
               date.day == now.day;
      case 'week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
               date.isBefore(now.add(const Duration(days: 1)));
      case 'month':
        return date.year == now.year && date.month == now.month;
      default:
        return true;
    }
  }

  double _getDoubleValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )} VND';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      appBar: AppBar(
        title: const Text('Báo cáo & Thống kê'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Làm mới',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'today', label: Text('Hôm nay')),
                      ButtonSegment(value: 'week', label: Text('Tuần này')),
                      ButtonSegment(value: 'month', label: Text('Tháng này')),
                    ],
                    selected: {_selectedPeriod},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedPeriod = newSelection.first;
                        _loadReports();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Revenue Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Tổng Doanh Thu',
                          value: _formatCurrency(_getDoubleValue(_revenueData['totalRevenue'])),
                          icon: Icons.attach_money,
                          color: const Color(0xFF2ECC71),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Tổng Đơn Hàng',
                          value: '${_revenueData['totalOrders'] ?? 0}',
                          icon: Icons.receipt_long,
                          color: const Color(0xFF3498DB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    title: 'Giá Trị Đơn Hàng Trung Bình',
                    value: _formatCurrency(_getDoubleValue(_revenueData['averageOrderValue'])),
                    icon: Icons.trending_up,
                    color: const Color(0xFF9B59B6),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Order Status Stats
                  const Text(
                    'Thống kê Đơn hàng',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildOrderStatRow('Đơn mới', _orderStats['new'] ?? 0, Colors.orange),
                          const Divider(),
                          _buildOrderStatRow('Đang chế biến', _orderStats['cooking'] ?? 0, Colors.blue),
                          const Divider(),
                          _buildOrderStatRow('Hoàn thành', _orderStats['done'] ?? 0, Colors.green),
                          const Divider(),
                          _buildOrderStatRow('Đã thanh toán', _orderStats['paid'] ?? 0, Colors.purple),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Top Restaurants
                  const Text(
                    'Top Nhà Hàng Doanh Thu Cao',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_topRestaurants.isEmpty)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'Chưa có dữ liệu',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    )
                  else
                    ..._topRestaurants.asMap().entries.map((entry) {
                      final index = entry.key;
                      final restaurant = entry.value;
                      return Card(
                        margin: EdgeInsets.only(bottom: index < _topRestaurants.length - 1 ? 8 : 0),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF2ECC71).withOpacity(0.1),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Color(0xFF2ECC71),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            restaurant['name'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: Text(
                            _formatCurrency(_getDoubleValue(restaurant['revenue'])),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2ECC71),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, color.withOpacity(0.03)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Text(
            '$count',
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
}

