import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:quanlynhahang/models/revenue.dart';
import 'package:quanlynhahang/services/revenue_service.dart';

/// Trang quản lý thanh toán cho Owner (chỉ Admin)
/// Hiển thị các giao dịch PayOS cần trả tiền cho nhà hàng
class SettlementManagementPage extends StatefulWidget {
  const SettlementManagementPage({super.key});

  @override
  State<SettlementManagementPage> createState() => _SettlementManagementPageState();
}

class _SettlementManagementPageState extends State<SettlementManagementPage>
    with SingleTickerProviderStateMixin {
  final RevenueService _revenueService = RevenueService();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  late TabController _tabController;
  bool _isLoading = true;

  // Data
  List<RestaurantRevenueSummary> _allSummaries = [];
  List<RestaurantRevenueSummary> _pendingSummaries = []; // Có tiền cần trả
  List<SettlementRecord> _settlementHistory = [];
  Map<String, Map<String, dynamic>> _restaurantBankInfo = {};

  // Total stats
  double _totalPendingAmount = 0;
  double _totalSettledAmount = 0;
  int _totalPendingRestaurants = 0;

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
      // Load all restaurant revenue summaries
      _allSummaries = await _revenueService.getAllRestaurantRevenueSummaries();

      // Filter restaurants with pending payment (PayOS only)
      _pendingSummaries = _allSummaries
          .where((s) => s.pendingSettlement > 0)
          .toList();

      // Load bank info for each restaurant
      await _loadRestaurantBankInfo();

      // Load settlement history
      await _loadSettlementHistory();

      // Calculate totals
      _totalPendingAmount = _pendingSummaries.fold(
        0.0,
        (sum, s) => sum + s.pendingSettlement,
      );
      _totalSettledAmount = _allSummaries.fold(
        0.0,
        (sum, s) => sum + s.settledAmount,
      );
      _totalPendingRestaurants = _pendingSummaries.length;
    } catch (e) {
      print('Error loading settlement data: $e');
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

  Future<void> _loadRestaurantBankInfo() async {
    try {
      for (final summary in _allSummaries) {
        final snapshot = await _database
            .child('restaurants')
            .child(summary.restaurantId)
            .get();

        if (snapshot.exists) {
          final data = Map<String, dynamic>.from(snapshot.value as Map);
          _restaurantBankInfo[summary.restaurantId] = {
            'bankName': data['bankName'] ?? '',
            'bankAccountNumber': data['bankAccountNumber'] ?? '',
            'bankAccountName': data['bankAccountName'] ?? '',
            'ownerName': data['ownerName'] ?? '',
            'phone': data['phone'] ?? '',
          };
        }
      }
    } catch (e) {
      print('Error loading bank info: $e');
    }
  }

  Future<void> _loadSettlementHistory() async {
    try {
      final snapshot = await _database
          .child('settlements')
          .orderByChild('createdAt')
          .limitToLast(50)
          .get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        _settlementHistory = data.entries.map((e) {
          return SettlementRecord.fromJson(
            Map<String, dynamic>.from(e.value),
          );
        }).toList();

        // Sort by createdAt descending
        _settlementHistory.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (e) {
      print('Error loading settlement history: $e');
    }
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
          'Thanh toán cho Owner',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4CAF50),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4CAF50),
          tabs: const [
            Tab(text: 'Chờ thanh toán'),
            Tab(text: 'Lịch sử'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPendingTab(),
                      _buildHistoryTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
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
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Tổng quan thanh toán',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Chờ thanh toán',
                  _currencyFormat.format(_totalPendingAmount),
                  Icons.pending_actions,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryItem(
                  'Đã thanh toán',
                  _currencyFormat.format(_totalSettledAmount),
                  Icons.check_circle,
                  Colors.green.shade300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.store, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$_totalPendingRestaurants nhà hàng cần thanh toán',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    if (_pendingSummaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade300),
            const SizedBox(height: 16),
            const Text(
              'Không có khoản nào cần thanh toán',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tất cả các giao dịch PayOS đã được thanh toán',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _pendingSummaries.length,
        itemBuilder: (context, index) {
          final summary = _pendingSummaries[index];
          return _buildRestaurantPendingCard(summary);
        },
      ),
    );
  }

  Widget _buildRestaurantPendingCard(RestaurantRevenueSummary summary) {
    final bankInfo = _restaurantBankInfo[summary.restaurantId] ?? {};
    final hasBankInfo = (bankInfo['bankAccountNumber'] ?? '').isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    color: Color(0xFF4CAF50),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.restaurantName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${summary.totalTransactions} giao dịch',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    'Chờ TT',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Amount info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Số tiền cần trả:',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(summary.pendingSettlement),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Bank info
                if (hasBankInfo) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance, 
                                size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            const Text(
                              'Thông tin ngân hàng',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        _buildBankInfoRow('Ngân hàng', bankInfo['bankName'] ?? '-'),
                        const SizedBox(height: 4),
                        _buildBankInfoRow('Số TK', bankInfo['bankAccountNumber'] ?? '-'),
                        const SizedBox(height: 4),
                        _buildBankInfoRow('Chủ TK', bankInfo['bankAccountName'] ?? '-'),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.red.shade400),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Nhà hàng chưa cập nhật thông tin ngân hàng',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showTransactionDetails(summary),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('Chi tiết'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4CAF50),
                          side: const BorderSide(color: Color(0xFF4CAF50)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasBankInfo
                            ? () => _showConfirmSettlementDialog(summary, bankInfo)
                            : null,
                        icon: const Icon(Icons.payment, size: 18),
                        label: const Text('Thanh toán'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showTransactionDetails(RestaurantRevenueSummary summary) async {
    // Load pending revenue records for this restaurant
    final records = await _revenueService.getRestaurantRevenueRecords(
      summary.restaurantId,
      status: 'pending',
    );

    // Filter only PayOS transactions
    final payosRecords = records.where((r) => r.paymentMethod == 'payos').toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Color(0xFF4CAF50)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.restaurantName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${payosRecords.length} giao dịch PayOS chờ thanh toán',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: payosRecords.isEmpty
                  ? const Center(
                      child: Text('Không có giao dịch PayOS nào'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: payosRecords.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final record = payosRecords[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.qr_code,
                              color: Colors.blue.shade400,
                            ),
                          ),
                          title: Text(
                            'Đơn #${record.orderId.substring(record.orderId.length - 6)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(record.createdAt),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _currencyFormat.format(record.restaurantAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                              Text(
                                'Phí: ${_currencyFormat.format(record.platformFee)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showConfirmSettlementDialog(
    RestaurantRevenueSummary summary,
    Map<String, dynamic> bankInfo,
  ) async {
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.payment, color: Color(0xFF4CAF50)),
            SizedBox(width: 8),
            Text('Xác nhận thanh toán'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bạn xác nhận đã chuyển tiền cho nhà hàng "${summary.restaurantName}"?',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Số tiền:'),
                        Text(
                          _currencyFormat.format(summary.pendingSettlement),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    _buildBankInfoRow('Ngân hàng', bankInfo['bankName'] ?? '-'),
                    const SizedBox(height: 4),
                    _buildBankInfoRow('Số TK', bankInfo['bankAccountNumber'] ?? '-'),
                    const SizedBox(height: 4),
                    _buildBankInfoRow('Chủ TK', bankInfo['bankAccountName'] ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (tùy chọn)',
                  hintText: 'VD: Mã giao dịch ngân hàng...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
            label: const Text('Xác nhận đã thanh toán'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _processSettlement(summary, bankInfo, noteController.text);
    }

    noteController.dispose();
  }

  Future<void> _processSettlement(
    RestaurantRevenueSummary summary,
    Map<String, dynamic> bankInfo,
    String note,
  ) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Get all pending PayOS revenue records for this restaurant
      final records = await _revenueService.getRestaurantRevenueRecords(
        summary.restaurantId,
        status: 'pending',
      );

      final payosRecords = records.where((r) => r.paymentMethod == 'payos').toList();
      final recordIds = payosRecords.map((r) => r.id).toList();

      // Create settlement record
      final settlement = await _revenueService.createSettlement(
        restaurantId: summary.restaurantId,
        amount: summary.pendingSettlement,
        bankName: bankInfo['bankName'] ?? '',
        bankAccountNumber: bankInfo['bankAccountNumber'] ?? '',
        bankAccountName: bankInfo['bankAccountName'] ?? '',
        revenueRecordIds: recordIds,
        note: note.isEmpty ? null : note,
      );

      if (settlement != null) {
        // Complete the settlement
        final success = await _revenueService.completeSettlement(
          settlement.id,
          summary.restaurantId,
        );

        if (mounted) Navigator.pop(context); // Close loading

        if (success) {
          // Reload data
          await _loadData();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Đã thanh toán ${_currencyFormat.format(summary.pendingSettlement)} cho ${summary.restaurantName}',
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Failed to complete settlement');
        }
      } else {
        if (mounted) Navigator.pop(context);
        throw Exception('Failed to create settlement');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildHistoryTab() {
    if (_settlementHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Chưa có lịch sử thanh toán',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _settlementHistory.length,
        itemBuilder: (context, index) {
          final settlement = _settlementHistory[index];
          return _buildSettlementHistoryCard(settlement);
        },
      ),
    );
  }

  Widget _buildSettlementHistoryCard(SettlementRecord settlement) {
    // Find restaurant name
    final restaurantSummary = _allSummaries.firstWhere(
      (s) => s.restaurantId == settlement.restaurantId,
      orElse: () => RestaurantRevenueSummary.empty(settlement.restaurantId, 'Unknown'),
    );

    final isCompleted = settlement.status == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted ? Colors.green.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle : Icons.pending,
                  color: isCompleted ? Colors.green : Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurantSummary.restaurantName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(settlement.createdAt),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFormat.format(settlement.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isCompleted ? Colors.green : Colors.grey,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isCompleted ? 'Đã TT' : 'Đang xử lý',
                      style: TextStyle(
                        fontSize: 11,
                        color: isCompleted ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (settlement.note != null && settlement.note!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.note, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      settlement.note!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${settlement.bankName} - ${settlement.bankAccountNumber}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
