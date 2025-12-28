import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/inventory_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/models/inventory_item.dart';
import 'package:quanlynhahang/models/inventory_check.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class KitchenInventoryPage extends StatefulWidget {
  const KitchenInventoryPage({super.key});

  @override
  State<KitchenInventoryPage> createState() => _KitchenInventoryPageState();
}

class _KitchenInventoryPageState extends State<KitchenInventoryPage>
    with SingleTickerProviderStateMixin {
  final InventoryService _inventoryService = InventoryService();
  final LocalStorageService _localStorageService = LocalStorageService();

  late TabController _tabController;
  List<InventoryItem> _inventoryItems = [];
  List<InventoryCheck> _inventoryChecks = [];
  bool _isLoading = true;
  DatabaseReference? _inventoryRef;
  DatabaseReference? _inventoryChecksRef;
  StreamSubscription<DatabaseEvent>? _inventorySubscription;
  StreamSubscription<DatabaseEvent>? _inventoryChecksSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupRealtimeUpdates();
  }

  @override
  void dispose() {
    _inventorySubscription?.cancel();
    _inventoryChecksSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _setupRealtimeUpdates() async {
    setState(() => _isLoading = true);

    try {
      final restaurantId = await _inventoryService.getRestaurantIdByOwnerId(
        _localStorageService.getUserId() ?? '',
      );

      if (restaurantId != null) {
        final database = FirebaseDatabase.instance;

        // Setup realtime listeners
        _inventoryRef = database.ref('inventory');
        _inventoryChecksRef = database.ref('inventory_checks');

        _inventorySubscription = _inventoryRef!.onValue.listen((event) {
          _loadInventoryRealtime(restaurantId);
        });

        _inventoryChecksSubscription = _inventoryChecksRef!.onValue.listen((
          event,
        ) {
          _loadInventoryChecksRealtime(restaurantId);
        });

        // Initial load
        await Future.wait([
          _loadInventoryRealtime(restaurantId),
          _loadInventoryChecksRealtime(restaurantId),
        ]);
      }
    } catch (e) {
      print('Error setting up realtime updates: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadInventoryRealtime(String restaurantId) async {
    try {
      _inventoryItems = await _inventoryService.getInventoryItems(restaurantId);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading inventory realtime: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadInventoryChecksRealtime(String restaurantId) async {
    try {
      _inventoryChecks = await _inventoryService.getInventoryChecks(
        restaurantId,
      );

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading inventory checks realtime: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _performInventoryCheck(InventoryItem item) async {
    final TextEditingController actualQuantityController =
        TextEditingController();
    final TextEditingController notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kiểm kho: ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Số lượng hệ thống: ${item.quantity} ${item.unit}'),
            const SizedBox(height: 16),
            TextField(
              controller: actualQuantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số lượng thực tế',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (tùy chọn)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (result == true) {
      final actualQuantity =
          double.tryParse(actualQuantityController.text) ?? 0;
      final difference = actualQuantity - item.quantity;

      try {
        final check = InventoryCheck(
          id: '',
          inventoryItemId: item.id,
          restaurantId: item.restaurantId,
          checkedBy: _localStorageService.getUserId() ?? '',
          systemQuantity: item.quantity,
          actualQuantity: actualQuantity,
          difference: difference,
          notes: notesController.text,
          checkedAt: DateTime.now(),
        );

        final checkId = await _inventoryService.createInventoryCheck(check);
        if (checkId != null) {
          // No need to reload - realtime listeners will update automatically
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                difference == 0
                    ? 'Kiểm kho thành công - Số lượng khớp'
                    : 'Kiểm kho thành công - Chênh lệch: ${difference > 0 ? '+' : ''}${difference} ${item.unit}',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lỗi khi lưu kết quả kiểm kho')),
          );
        }
      } catch (e) {
        print('Error saving inventory check: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi khi lưu kết quả kiểm kho')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Danh sách nguyên liệu'),
              Tab(text: 'Lịch sử kiểm kho'),
            ],
            labelColor: Colors.blue.shade700,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.blue.shade700,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildInventoryList(), _buildInventoryChecksList()],
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_inventoryItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có nguyên liệu nào',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final restaurantId = await _inventoryService.getRestaurantIdByOwnerId(
          _localStorageService.getUserId() ?? '',
        );
        if (restaurantId != null) {
          await _loadInventoryRealtime(restaurantId);
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _inventoryItems.length,
        itemBuilder: (context, index) {
          final item = _inventoryItems[index];
          final isLowStock = item.quantity <= item.minThreshold;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isLowStock
                              ? Colors.red.shade100
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isLowStock ? 'Sắp hết' : 'Còn đủ',
                          style: TextStyle(
                            color: isLowStock
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Số lượng: ${item.quantity} ${item.unit}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  Text(
                    'Ngưỡng tối thiểu: ${item.minThreshold} ${item.unit}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  if (item.notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Ghi chú: ${item.notes}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _performInventoryCheck(item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Kiểm kho'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInventoryChecksList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_inventoryChecks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Chưa có lịch sử kiểm kho',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // Group checks by item
    final groupedChecks = <String, List<InventoryCheck>>{};
    for (final check in _inventoryChecks) {
      if (!groupedChecks.containsKey(check.inventoryItemId)) {
        groupedChecks[check.inventoryItemId] = [];
      }
      groupedChecks[check.inventoryItemId]!.add(check);
    }

    return RefreshIndicator(
      onRefresh: () async {
        final restaurantId = await _inventoryService.getRestaurantIdByOwnerId(
          _localStorageService.getUserId() ?? '',
        );
        if (restaurantId != null) {
          await _loadInventoryChecksRealtime(restaurantId);
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupedChecks.length,
        itemBuilder: (context, index) {
          final itemId = groupedChecks.keys.elementAt(index);
          final checks = groupedChecks[itemId]!;
          final item = _inventoryItems.firstWhere(
            (item) => item.id == itemId,
            orElse: () => InventoryItem(
              id: itemId,
              restaurantId: '',
              name: 'Nguyên liệu không xác định',
              quantity: 0,
              unit: '',
              minThreshold: 0,
              supplier: '',
              notes: '',
              isActive: true,
              lastUpdated: DateTime.now(),
            ),
          );

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              title: Text(
                item.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text('${checks.length} lần kiểm kho'),
              children: checks.map((check) {
                final isDiscrepancy = check.difference != 0;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDateTime(check.checkedAt),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDiscrepancy
                                  ? Colors.orange.shade100
                                  : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isDiscrepancy ? 'Có chênh lệch' : 'Khớp',
                              style: TextStyle(
                                color: isDiscrepancy
                                    ? Colors.orange.shade700
                                    : Colors.green.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hệ thống: ${check.systemQuantity} ${item.unit} | Thực tế: ${check.actualQuantity} ${item.unit}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (isDiscrepancy)
                        Text(
                          'Chênh lệch: ${check.difference > 0 ? '+' : ''}${check.difference} ${item.unit}',
                          style: TextStyle(
                            fontSize: 14,
                            color: check.difference > 0
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (check.notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Ghi chú: ${check.notes}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
