import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

/// Trang thống kê doanh thu từ gói dịch vụ cho Admin
class PackageRevenuePage extends StatefulWidget {
  const PackageRevenuePage({super.key});

  @override
  State<PackageRevenuePage> createState() => _PackageRevenuePageState();
}

class _PackageRevenuePageState extends State<PackageRevenuePage>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  late TabController _tabController;
  bool _isLoading = true;

  // Data
  List<Map<String, dynamic>> _allPayments = [];
  List<Map<String, dynamic>> _completedPayments = [];
  List<Map<String, dynamic>> _pendingPayments = [];
  Map<String, Map<String, dynamic>> _packageStats = {}; // Stats by package

  // Summary
  double _totalRevenue = 0;
  double _todayRevenue = 0;
  double _monthRevenue = 0;
  int _totalTransactions = 0;

  // Filter
  String _selectedPeriod = 'all'; // all, today, week, month
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _allPayments.clear();

    try {
      // Load owner registration payments from 'requests'
      await _loadOwnerRegistrationPayments();

      // Load renewal history from 'renewal_history'
      await _loadRenewalHistory();

      // Calculate stats
      _calculateStats();
    } catch (e) {
      print('Error loading package revenue data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Load đăng ký Owner từ 'requests' (type='owner', status='approved')
  Future<void> _loadOwnerRegistrationPayments() async {
    try {
      final snapshot = await _database.child('requests').get();

      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        
        for (final entry in data.entries) {
          // Skip if entry value is not a Map
          if (entry.value is! Map) continue;
          
          final request = Map<String, dynamic>.from(entry.value as Map);
          
          // Chỉ lấy Owner request đã approved và có thông tin gói
          final type = request['type'];
          final status = request['status'];
          final packagePrice = request['packagePrice'];
          
          if (type == 'owner' && status == 'approved' && packagePrice != null) {
            final payment = <String, dynamic>{
              'id': entry.key,
              'source': 'registration', // Đăng ký mới
              'packageId': request['packageId'],
              'packageName': request['packageName'] ?? 'Unknown',
              'price': (packagePrice is num) ? packagePrice.toDouble() : 0.0,
              'durationMonths': request['packageDurationMonths'] ?? 0,
              'userEmail': request['userEmail'] ?? '',
              'userName': request['userName'] ?? '',
              'paymentMethod': request['paymentMethod'] ?? '',
              'paymentStatus': request['paymentStatus'] ?? 'pending',
            };
            
            // Set status based on paymentStatus
            payment['status'] = (request['paymentStatus'] == 'paid') ? 'completed' : 'pending';
            
            // Parse createdAt
            if (request['createdAt'] != null) {
              payment['createdAtDate'] = DateTime.tryParse(request['createdAt'].toString()) ?? DateTime.now();
            } else {
              payment['createdAtDate'] = DateTime.now();
            }

            // Parse updatedAt as completedAt
            if (request['updatedAt'] != null) {
              payment['completedAtDate'] = DateTime.tryParse(request['updatedAt'].toString());
            }

            _allPayments.add(payment);
          }
        }
      }
    } catch (e) {
      print('Error loading owner registration payments: $e');
    }
  }

  /// Load lịch sử gia hạn từ 'renewal_history'
  Future<void> _loadRenewalHistory() async {
    try {
      final snapshot = await _database.child('renewal_history').get();

      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        
        for (final entry in data.entries) {
          // Skip if entry value is not a Map
          if (entry.value is! Map) continue;
          
          final renewal = Map<String, dynamic>.from(entry.value as Map);
          
          final payment = <String, dynamic>{
            'id': entry.key,
            'source': 'renewal', // Gia hạn
            'packageId': renewal['packageId'],
            'packageName': renewal['packageName'] ?? 'Unknown',
            'price': (renewal['packagePrice'] is num) 
                ? (renewal['packagePrice'] as num).toDouble() 
                : 0.0,
            'durationMonths': renewal['durationMonths'] ?? 0,
            'userId': renewal['userId'] ?? '',
            'paymentMethod': renewal['paymentMethod'] ?? '',
            'transactionId': renewal['transactionId'],
            'status': 'completed', // Renewal history chỉ chứa các gia hạn đã hoàn thành
          };
          
          // Parse createdAt
          if (renewal['createdAt'] != null) {
            payment['createdAtDate'] = DateTime.tryParse(renewal['createdAt'].toString()) ?? DateTime.now();
            payment['completedAtDate'] = payment['createdAtDate'];
          } else {
            payment['createdAtDate'] = DateTime.now();
            payment['completedAtDate'] = DateTime.now();
          }

          _allPayments.add(payment);
        }
      }
    } catch (e) {
      print('Error loading renewal history: $e');
    }
  }

  void _calculateStats() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    _totalRevenue = 0;
    _todayRevenue = 0;
    _monthRevenue = 0;
    _totalTransactions = 0;
    _completedPayments.clear();
    _pendingPayments.clear();
    _packageStats.clear();

    for (final payment in _allPayments) {
      final status = payment['status'];
      final price = (payment['price'] ?? 0).toDouble();
      final createdAt = payment['createdAtDate'] as DateTime;
      final packageName = payment['packageName'] ?? 'Unknown';

      if (status == 'completed') {
        _completedPayments.add(payment);
        _totalRevenue += price;
        _totalTransactions++;

        // Today revenue
        if (createdAt.isAfter(todayStart)) {
          _todayRevenue += price;
        }

        // Month revenue
        if (createdAt.isAfter(monthStart)) {
          _monthRevenue += price;
        }

        // Stats by package
        if (!_packageStats.containsKey(packageName)) {
          _packageStats[packageName] = {
            'name': packageName,
            'count': 0,
            'revenue': 0.0,
          };
        }
        _packageStats[packageName]!['count'] = (_packageStats[packageName]!['count'] as int) + 1;
        _packageStats[packageName]!['revenue'] = (_packageStats[packageName]!['revenue'] as double) + price;
      } else if (status == 'pending') {
        _pendingPayments.add(payment);
      }
    }

    // Sort by date descending
    _completedPayments.sort((a, b) => 
        (b['createdAtDate'] as DateTime).compareTo(a['createdAtDate'] as DateTime));
    _pendingPayments.sort((a, b) => 
        (b['createdAtDate'] as DateTime).compareTo(a['createdAtDate'] as DateTime));
  }

  List<Map<String, dynamic>> _getFilteredPayments() {
    final now = DateTime.now();
    DateTime filterStart;

    switch (_selectedPeriod) {
      case 'today':
        filterStart = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        filterStart = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        filterStart = DateTime(now.year, now.month, 1);
        break;
      default:
        return _completedPayments;
    }

    return _completedPayments.where((p) {
      final date = p['createdAtDate'] as DateTime;
      return date.isAfter(filterStart);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thống kê thu tiền Package',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, color: Color(0xFF4CAF50)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4CAF50),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4CAF50),
          tabs: const [
            Tab(text: 'Tổng quan'),
            Tab(text: 'Lịch sử'),
            Tab(text: 'Theo gói'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildHistoryTab(),
                _buildByPackageTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main revenue card
          Container(
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
            child: Column(
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
                            'Tổng doanh thu Package',
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
                  _currencyFormat.format(_totalRevenue),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_totalTransactions giao dịch thành công',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Quick stats
          Row(
            children: [
              Expanded(
                child: _buildQuickStatCard(
                  'Hôm nay',
                  _currencyFormat.format(_todayRevenue),
                  Icons.today,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickStatCard(
                  'Tháng này',
                  _currencyFormat.format(_monthRevenue),
                  Icons.calendar_month,
                  Colors.purple,
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
                  '${_pendingPayments.length}',
                  Icons.pending_actions,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickStatCard(
                  'Hoàn thành',
                  '$_totalTransactions',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Recent transactions
          const Text(
            'Giao dịch gần đây',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (_completedPayments.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text(
                      'Chưa có giao dịch nào',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            ...(_completedPayments.take(5).map((payment) => 
                _buildTransactionCard(payment))),
        ],
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
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
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

  Widget _buildHistoryTab() {
    final filteredPayments = _getFilteredPayments();

    return Column(
      children: [
        // Filter
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Text('Lọc: ', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Tất cả', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Hôm nay', 'today'),
                      const SizedBox(width: 8),
                      _buildFilterChip('7 ngày', 'week'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Tháng này', 'month'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Stats for filtered
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFF4CAF50).withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredPayments.length} giao dịch',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                _currencyFormat.format(
                  filteredPayments.fold(0.0, (sum, p) => sum + ((p['price'] ?? 0) as num).toDouble()),
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: filteredPayments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text(
                        'Không có giao dịch nào',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredPayments.length,
                    itemBuilder: (context, index) {
                      return _buildTransactionCard(filteredPayments[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedPeriod = value;
        });
      },
      selectedColor: const Color(0xFF4CAF50).withOpacity(0.2),
      checkmarkColor: const Color(0xFF4CAF50),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> payment) {
    final packageName = payment['packageName'] ?? 'Unknown';
    final price = (payment['price'] ?? 0).toDouble();
    final userEmail = payment['userEmail'] ?? '';
    final createdAt = payment['createdAtDate'] as DateTime;
    final source = payment['source'] ?? 'package_payment';
    final isRenewal = source == 'renewal';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isRenewal 
                  ? Colors.purple.withOpacity(0.1)
                  : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isRenewal ? Icons.autorenew : Icons.card_giftcard,
              color: isRenewal ? Colors.purple : Colors.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        packageName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isRenewal 
                            ? Colors.purple.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isRenewal ? 'Gia hạn' : 'Đăng ký',
                        style: TextStyle(
                          fontSize: 11,
                          color: isRenewal ? Colors.purple : Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  userEmail,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currencyFormat.format(price),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 12, color: Colors.green.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Thành công',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildByPackageTab() {
    final packageList = _packageStats.values.toList();
    packageList.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

    return packageList.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  'Chưa có dữ liệu thống kê',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: packageList.length,
              itemBuilder: (context, index) {
                final pkg = packageList[index];
                final name = pkg['name'] as String;
                final count = pkg['count'] as int;
                final revenue = pkg['revenue'] as double;
                final percentage = _totalRevenue > 0 ? (revenue / _totalRevenue * 100) : 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
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
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _getPackageColor(index).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.card_giftcard,
                              color: _getPackageColor(index),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '$count lần mua',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _currencyFormat.format(revenue),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _getPackageColor(index),
                                ),
                              ),
                              Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(_getPackageColor(index)),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
  }

  Color _getPackageColor(int index) {
    final colors = [
      const Color(0xFF4CAF50),
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }
}
