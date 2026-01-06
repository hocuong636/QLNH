import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';

class OwnerReportsPage extends StatefulWidget {
  const OwnerReportsPage({super.key});

  @override
  State<OwnerReportsPage> createState() => _OwnerReportsPageState();
}

class _OwnerReportsPageState extends State<OwnerReportsPage> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final LocalStorageService _localStorageService = LocalStorageService();
  
  String _selectedPeriod = 'today'; // today, week, month
  String? _restaurantId;
  
  Map<String, dynamic> _revenueData = {};
  Map<String, int> _orderStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRestaurantId();
  }

  Future<void> _loadRestaurantId() async {
    final restaurantId = _localStorageService.getRestaurantId();
    if (restaurantId != null) {
      setState(() {
        _restaurantId = restaurantId;
      });
      _loadReports();
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy thông tin nhà hàng')),
        );
      }
    }
  }

  Future<void> _loadReports() async {
    if (_restaurantId == null) return;
    
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadRevenueData(),
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
    if (_restaurantId == null) return;
    
    try {
      final ordersSnapshot = await _database.ref('orders').get();
      double totalRevenue = 0;
      int totalOrders = 0;

      if (ordersSnapshot.exists) {
        final ordersData = ordersSnapshot.value as Map<dynamic, dynamic>?;
        if (ordersData != null) {
          ordersData.forEach((key, value) {
            if (value is Map) {
              // Chỉ lấy orders của nhà hàng này
              final orderRestaurantId = value['restaurantId']?.toString();
              if (orderRestaurantId != _restaurantId) return;
              
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

  Future<void> _loadOrderStats() async {
    if (_restaurantId == null) return;
    
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
              // Chỉ lấy orders của nhà hàng này
              final orderRestaurantId = value['restaurantId']?.toString();
              if (orderRestaurantId != _restaurantId) return;
              
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
    return Column(
      children: [
        // Header title
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          color: Colors.white,
          child: const Row(
            children: [
              Text(
                'Thống kê',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
        // Period selector - giống revenue page
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Khoảng thời gian',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF64B5F6)),
                    onPressed: _loadReports,
                    tooltip: 'Làm mới',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPeriodChip('Hôm nay', 'today'),
                    const SizedBox(width: 8),
                    _buildPeriodChip('Tuần này', 'week'),
                    const SizedBox(width: 8),
                    _buildPeriodChip('Tháng này', 'month'),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Body content
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF64B5F6)),
                  ),
                )
              : _restaurantId == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có thông tin nhà hàng',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReports,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main revenue card - giống revenue page
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [const Color(0xFF90CAF9), const Color(0xFF64B5F6)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFBBDEFB).withOpacity(0.6),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.attach_money, color: Colors.white, size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      const Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Tổng Doanh Thu',
                                            style: TextStyle(color: Colors.white70, fontSize: 14),
                                          ),
                                          Text(
                                            'Trong khoảng thời gian đã chọn',
                                            style: TextStyle(color: Colors.white54, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '${_formatCurrency(_getDoubleValue(_revenueData['totalRevenue']))} đ',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_revenueData['totalOrders'] ?? 0} đơn hàng',
                                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Stats row - giống revenue page
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    'Tổng Đơn Hàng',
                                    '${_revenueData['totalOrders'] ?? 0}',
                                    Icons.receipt_long,
                                    Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    'Giá trị TB/Đơn',
                                    _formatCurrency(_getDoubleValue(_revenueData['averageOrderValue'])),
                                    Icons.trending_up,
                                    Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // Order Status Stats - giống revenue page style
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade200,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.analytics, color: Color(0xFF64B5F6)),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Thống kê Đơn hàng',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildOrderStatRow('Đơn mới', _orderStats['new'] ?? 0, const Color(0xFFFFB74D)),
                                  const SizedBox(height: 12),
                                  _buildOrderStatRow('Đang chế biến', _orderStats['cooking'] ?? 0, Colors.blue),
                                  const SizedBox(height: 12),
                                  _buildOrderStatRow('Hoàn thành', _orderStats['done'] ?? 0, Colors.green),
                                  const SizedBox(height: 12),
                                  _buildOrderStatRow('Đã thanh toán', _orderStats['paid'] ?? 0, Colors.purple),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = value;
          _loadReports();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF64B5F6) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
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
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatRow(String label, int count, Color color) {
    final totalOrders = (_orderStats['new'] ?? 0) + 
                       (_orderStats['cooking'] ?? 0) + 
                       (_orderStats['done'] ?? 0) + 
                       (_orderStats['paid'] ?? 0);
    final percent = totalOrders > 0 ? (count / totalOrders * 100) : 0;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.circle, color: color, size: 12),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
            ),
            Text(
              '${percent.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

