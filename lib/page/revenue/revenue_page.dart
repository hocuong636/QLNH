import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:quanlynhahang/models/revenue.dart';
import 'package:quanlynhahang/services/revenue_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';

class RevenuePage extends StatefulWidget {
  const RevenuePage({super.key});

  @override
  State<RevenuePage> createState() => _RevenuePageState();
}

class _RevenuePageState extends State<RevenuePage> with SingleTickerProviderStateMixin {
  final RevenueService _revenueService = RevenueService();
  final LocalStorageService _localStorageService = LocalStorageService();
  
  late TabController _tabController;
  
  bool _isLoading = true;
  String? _restaurantId;
  String _restaurantName = '';
  
  RestaurantRevenueSummary? _summary;
  List<RevenueRecord> _allRecords = [];
  List<RevenueRecord> _filteredRecords = [];
  
  // Filter
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedPeriod = 'month'; // today, week, month, custom
  String _selectedPaymentMethod = 'all'; // all, cash, payos

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      _restaurantId = _localStorageService.getRestaurantId();
      _restaurantName = _localStorageService.getRestaurantName() ?? '';
      
      // Lấy restaurant name từ Firebase nếu chưa có
      if (_restaurantId != null && _restaurantName.isEmpty) {
        try {
          final snapshot = await FirebaseDatabase.instance
              .ref('restaurants/$_restaurantId/name')
              .get();
          if (snapshot.exists) {
            _restaurantName = snapshot.value as String? ?? 'Nhà hàng';
            // Lưu lại vào local storage
            await _localStorageService.setRestaurantName(_restaurantName);
          } else {
            _restaurantName = 'Nhà hàng';
          }
        } catch (e) {
          _restaurantName = 'Nhà hàng';
        }
      }
      
      if (_restaurantId != null) {
        // Load summary
        _summary = await _revenueService.getRestaurantRevenueSummary(
          _restaurantId!,
          _restaurantName,
        );
        
        // Load records
        _allRecords = await _revenueService.getRestaurantRevenueRecords(
          _restaurantId!,
          limit: 100,
        );
        
        _applyFilters();
      }
    } catch (e) {
      print('Error loading revenue data: $e');
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    _filteredRecords = _allRecords.where((record) {
      // Filter by date
      if (record.createdAt.isBefore(_startDate) || 
          record.createdAt.isAfter(_endDate.add(const Duration(days: 1)))) {
        return false;
      }
      
      // Filter by payment method
      if (_selectedPaymentMethod != 'all' && 
          record.paymentMethod != _selectedPaymentMethod) {
        return false;
      }
      
      return true;
    }).toList();
    
    setState(() {});
  }

  void _selectPeriod(String period) {
    final now = DateTime.now();
    
    switch (period) {
      case 'today':
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = now;
        break;
      case 'week':
        _startDate = now.subtract(const Duration(days: 7));
        _endDate = now;
        break;
      case 'month':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
        break;
      case 'custom':
        _showDateRangePicker();
        return;
    }
    
    setState(() {
      _selectedPeriod = period;
    });
    _applyFilters();
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      locale: const Locale('vi', 'VN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange.shade600,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedPeriod = 'custom';
      });
      _applyFilters();
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  // Tính doanh thu theo khoảng thời gian đã filter
  double get _filteredTotalRevenue => 
      _filteredRecords.fold(0, (sum, r) => sum + r.totalAmount);
  
  double get _filteredPlatformFee => 
      _filteredRecords.fold(0, (sum, r) => sum + r.platformFee);
  
  double get _filteredRestaurantAmount => 
      _filteredRecords.fold(0, (sum, r) => sum + r.restaurantAmount);
  
  int get _filteredCashCount => 
      _filteredRecords.where((r) => r.paymentMethod == 'cash').length;
  
  int get _filteredPayOSCount => 
      _filteredRecords.where((r) => r.paymentMethod == 'payos').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Doanh thu'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Tổng quan', icon: Icon(Icons.dashboard)),
            Tab(text: 'Chi tiết', icon: Icon(Icons.list_alt)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildDetailTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period selector
            _buildPeriodSelector(),
            const SizedBox(height: 16),
            
            // Summary cards
            _buildSummaryCards(),
            const SizedBox(height: 20),
            
            // Payment method breakdown
            _buildPaymentMethodBreakdown(),
            const SizedBox(height: 20),
            
            // Total stats (all time)
            _buildAllTimeSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Khoảng thời gian',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPeriodChip('Hôm nay', 'today'),
                const SizedBox(width: 8),
                _buildPeriodChip('7 ngày', 'week'),
                const SizedBox(width: 8),
                _buildPeriodChip('Tháng này', 'month'),
                const SizedBox(width: 8),
                _buildPeriodChip('Tùy chọn', 'custom'),
              ],
            ),
          ),
          if (_selectedPeriod == 'custom') ...[
            const SizedBox(height: 8),
            Text(
              '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () => _selectPeriod(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.shade600 : Colors.grey.shade200,
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

  Widget _buildSummaryCards() {
    return Column(
      children: [
        // Main revenue card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade500, Colors.deepOrange.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.shade200,
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
                    child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doanh thu thực nhận',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        '(Sau trừ phí platform)',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${_formatCurrency(_filteredRestaurantAmount)} đ',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_filteredRecords.length} giao dịch',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Stats row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Tổng thu',
                _filteredTotalRevenue,
                Icons.payments,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Phí platform',
                _filteredPlatformFee,
                Icons.percent,
                Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, double amount, IconData icon, Color color) {
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
            '${_formatCurrency(amount)} đ',
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

  Widget _buildPaymentMethodBreakdown() {
    final cashAmount = _filteredRecords
        .where((r) => r.paymentMethod == 'cash')
        .fold(0.0, (sum, r) => sum + r.restaurantAmount);
    final payosAmount = _filteredRecords
        .where((r) => r.paymentMethod == 'payos')
        .fold(0.0, (sum, r) => sum + r.restaurantAmount);
    
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
          const Text(
            'Phương thức thanh toán',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          _buildPaymentMethodRow(
            'Tiền mặt',
            Icons.money,
            Colors.green,
            _filteredCashCount,
            cashAmount,
          ),
          const SizedBox(height: 12),
          _buildPaymentMethodRow(
            'PayOS (QR)',
            Icons.qr_code,
            Colors.blue,
            _filteredPayOSCount,
            payosAmount,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodRow(
    String name,
    IconData icon,
    Color color,
    int count,
    double amount,
  ) {
    final total = _filteredRestaurantAmount;
    final percent = total > 0 ? (amount / total * 100) : 0;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
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
              '${_formatCurrency(amount)} đ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '$count giao dịch',
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

  Widget _buildAllTimeSummary() {
    if (_summary == null) return const SizedBox.shrink();
    
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
              Icon(Icons.analytics, color: Colors.orange.shade600),
              const SizedBox(width: 8),
              const Text(
                'Tổng cộng (tất cả thời gian)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildSummaryRow('Tổng doanh thu', _summary!.totalRevenue),
          _buildSummaryRow('Phí platform đã trả', _summary!.totalPlatformFee, isNegative: true),
          _buildSummaryRow('Đã nhận', _summary!.settledAmount, color: Colors.green),
          _buildSummaryRow('Chờ thanh toán', _summary!.pendingSettlement, color: Colors.orange),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng giao dịch',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '${_summary!.totalTransactions} đơn',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isNegative = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(
            '${isNegative ? "-" : ""}${_formatCurrency(amount)} đ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color ?? (isNegative ? Colors.red : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTab() {
    return Column(
      children: [
        // Filter by payment method
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              const Text('Phương thức: ', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              _buildMethodChip('Tất cả', 'all'),
              const SizedBox(width: 8),
              _buildMethodChip('Tiền mặt', 'cash'),
              const SizedBox(width: 8),
              _buildMethodChip('PayOS', 'payos'),
            ],
          ),
        ),
        
        // List
        Expanded(
          child: _filteredRecords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có giao dịch',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredRecords.length,
                    itemBuilder: (context, index) {
                      final record = _filteredRecords[index];
                      return _buildRecordCard(record);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMethodChip(String label, String value) {
    final isSelected = _selectedPaymentMethod == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedPaymentMethod = value);
        _applyFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.shade600 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRecordCard(RevenueRecord record) {
    final isCash = record.paymentMethod == 'cash';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isCash ? Colors.green.shade50 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isCash ? Icons.money : Icons.qr_code,
            color: isCash ? Colors.green : Colors.blue,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Đơn #${record.orderId.length > 8 ? record.orderId.substring(0, 8) : record.orderId}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: record.status == 'settled' 
                    ? Colors.green.shade50 
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                record.status == 'settled' ? 'Đã chuyển' : 'Chờ xử lý',
                style: TextStyle(
                  fontSize: 11,
                  color: record.status == 'settled' 
                      ? Colors.green.shade700 
                      : Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatDate(record.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tổng: ${_formatCurrency(record.totalAmount)} đ',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        'Phí: -${_formatCurrency(record.platformFee)} đ (${record.platformFeePercent.toStringAsFixed(1)}%)',
                        style: TextStyle(fontSize: 12, color: Colors.red.shade400),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Thực nhận', style: TextStyle(fontSize: 11)),
                    Text(
                      '${_formatCurrency(record.restaurantAmount)} đ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
