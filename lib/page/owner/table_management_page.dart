import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/table_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/models/table.dart';

class TableManagementPage extends StatefulWidget {
  const TableManagementPage({super.key});

  @override
  State<TableManagementPage> createState() => _TableManagementPageState();
}

class _TableManagementPageState extends State<TableManagementPage> {
  final TableService _tableService = TableService();
  final LocalStorageService _localStorageService = LocalStorageService();
  final TextEditingController _searchController = TextEditingController();
  List<TableModel> _tables = [];
  List<TableModel> _filteredTables = [];
  bool _isLoading = true;
  String _selectedStatus = 'Tất cả';
  final List<String> _statusOptions = ['Tất cả', 'Trống', 'Đang phục vụ', 'Đã đặt'];

  @override
  void initState() {
    super.initState();
    _loadTables();
    _searchController.addListener(_filterTables);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTables() async {
    setState(() => _isLoading = true);
    try {
      String ownerId = _localStorageService.getUserId() ?? '';
      _tables = await _tableService.getTables(ownerId);
      _filterTables();
    } catch (e) {
      _showSnackBar('Lỗi khi tải danh sách bàn: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterTables() {
    setState(() {
      _filteredTables = _tables.where((table) {
        final matchesSearch = table.number
            .toString()
            .contains(_searchController.text);
        final matchesStatus = _selectedStatus == 'Tất cả' ||
            _getStatusDisplayName(table.status) == _selectedStatus;
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAddEditDialog([TableModel? table]) {
    // Nếu đang edit, dùng form cũ
    if (table != null) {
      _showEditSingleTableDialog(table);
      return;
    }

    // Nếu thêm mới, dùng form thêm nhiều bàn
    _showAddMultipleTablesDialog();
  }

  void _showEditSingleTableDialog(TableModel table) {
    final numberController = TextEditingController(
      text: table.number.toString(),
    );
    final capacityController = TextEditingController(
      text: table.capacity.toString(),
    );
    String selectedStatus = _getStatusDisplayName(table.status);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Sửa thông tin bàn'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numberController,
                  decoration: const InputDecoration(
                    labelText: 'Số bàn *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.table_restaurant),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: capacityController,
                  decoration: const InputDecoration(
                    labelText: 'Số chỗ ngồi *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.people),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.info),
                  ),
                  items: _statusOptions
                      .where((status) => status != 'Tất cả')
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedStatus = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (numberController.text.isEmpty ||
                    capacityController.text.isEmpty) {
                  _showSnackBar('Vui lòng nhập đầy đủ thông tin');
                  return;
                }

                try {
                  String ownerId = _localStorageService.getUserId() ?? '';
                  TableStatus status = _parseStatusString(selectedStatus);

                  TableModel updatedTable = TableModel(
                    id: table.id,
                    ownerId: ownerId,
                    number: int.parse(numberController.text),
                    capacity: int.parse(capacityController.text),
                    status: status,
                    createdAt: table.createdAt,
                    updatedAt: DateTime.now(),
                  );

                  await _tableService.updateTable(updatedTable);

                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }

                  _showSnackBar('Cập nhật bàn thành công');
                  await _loadTables();
                } catch (e) {
                  if (context.mounted) {
                    _showSnackBar('Lỗi: $e');
                  }
                }
              },
              child: const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMultipleTablesDialog() {
    // Tìm số bàn lớn nhất hiện có
    int maxTableNumber = 0;
    if (_tables.isNotEmpty) {
      maxTableNumber = _tables.map((t) => t.number).reduce((a, b) => a > b ? a : b);
    }
    
    final startNumberController = TextEditingController(
      text: (maxTableNumber + 1).toString(),
    );
    final quantityController = TextEditingController(text: '10');
    final capacityController = TextEditingController(text: '4');
    bool isAdding = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm nhiều bàn'),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: startNumberController,
                    decoration: InputDecoration(
                      labelText: 'Số bàn bắt đầu *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.play_arrow),
                      helperText: _tables.isEmpty 
                        ? 'VD: 1'
                        : 'Số bàn lớn nhất hiện tại: $maxTableNumber',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Số lượng bàn *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.format_list_numbered),
                      helperText: 'VD: 10 sẽ tạo bàn 1-10',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: capacityController,
                    decoration: const InputDecoration(
                      labelText: 'Số chỗ ngồi (mỗi bàn) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.people),
                      helperText: 'Áp dụng cho tất cả',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, 
                          color: Colors.blue.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tất cả bàn sẽ có trạng thái "Trống"',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAdding)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Center(
                        child: Column(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Đang thêm bàn...',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isAdding ? null : () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: isAdding
                  ? null
                  : () async {
                      if (startNumberController.text.isEmpty ||
                          quantityController.text.isEmpty ||
                          capacityController.text.isEmpty) {
                        _showSnackBar('Vui lòng nhập đầy đủ thông tin');
                        return;
                      }

                      int startNumber = int.parse(startNumberController.text);
                      int quantity = int.parse(quantityController.text);
                      int capacity = int.parse(capacityController.text);

                      if (quantity <= 0 || quantity > 100) {
                        _showSnackBar('Số lượng bàn phải từ 1-100');
                        return;
                      }

                      setDialogState(() => isAdding = true);

                      try {
                        String ownerId =
                            _localStorageService.getUserId() ?? '';
                        int successCount = 0;
                        int failCount = 0;

                        for (int i = 0; i < quantity; i++) {
                          TableModel newTable = TableModel(
                            id: '',
                            ownerId: ownerId,
                            number: startNumber + i,
                            capacity: capacity,
                            status: TableStatus.empty,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          );

                          String? result =
                              await _tableService.createTable(newTable);
                          if (result != null) {
                            successCount++;
                          } else {
                            failCount++;
                          }
                        }

                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }

                        _showSnackBar(
                          'Thêm thành công $successCount bàn' +
                              (failCount > 0 ? ', thất bại $failCount' : ''),
                        );
                        await _loadTables();
                      } catch (e) {
                        setDialogState(() => isAdding = false);
                        if (context.mounted) {
                          _showSnackBar('Lỗi: $e');
                        }
                      }
                    },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  TableStatus _parseStatusString(String status) {
    switch (status) {
      case 'Trống':
        return TableStatus.empty;
      case 'Đang phục vụ':
        return TableStatus.occupied;
      case 'Đã đặt':
        return TableStatus.reserved;
      default:
        return TableStatus.empty;
    }
  }

  void _showDeleteDialog(TableModel table) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bàn'),
        content: Text('Bạn có chắc chắn muốn xóa "Bàn ${table.number}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _tableService.deleteTable(table.id);
                _showSnackBar('Xóa bàn thành công');
                Navigator.of(context).pop();
                _loadTables();
              } catch (e) {
                _showSnackBar('Lỗi khi xóa: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(TableModel table) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bàn ${table.number}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              Icons.table_restaurant,
              'Số bàn',
              table.number.toString(),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.people,
              'Số chỗ ngồi',
              '${table.capacity} người',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                const Text(
                  'Trạng thái:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(table.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusDisplayName(table.status),
                    style: TextStyle(
                      color: _getStatusColor(table.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _showAddEditDialog(table);
            },
            icon: const Icon(Icons.edit),
            label: const Text('Sửa'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Text(value),
      ],
    );
  }

  String _getStatusDisplayName(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return 'Trống';
      case TableStatus.occupied:
        return 'Đang phục vụ';
      case TableStatus.reserved:
        return 'Đã đặt';
    }
  }

  Color _getStatusColor(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return Colors.green;
      case TableStatus.occupied:
        return Colors.orange;
      case TableStatus.reserved:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý bàn'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Thanh tìm kiếm
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm số bàn...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 8),
              // Bộ lọc trạng thái
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _statusOptions.length,
                  itemBuilder: (context, index) {
                    final status = _statusOptions[index];
                    final isSelected = status == _selectedStatus;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(status),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedStatus = status;
                            _filterTables();
                          });
                        },
                        backgroundColor: Colors.grey.shade200,
                        selectedColor: Colors.blue.shade700,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredTables.isEmpty
              ? _buildEmptyState()
              : _buildTableGrid(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Colors.blue.shade700,
        icon: const Icon(Icons.add),
        label: const Text('Thêm bàn'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.table_restaurant, size: 100, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty || _selectedStatus != 'Tất cả'
                ? 'Không tìm thấy bàn'
                : 'Chưa có bàn nào',
            style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty || _selectedStatus != 'Tất cả'
                ? 'Thử thay đổi bộ lọc hoặc tìm kiếm'
                : 'Nhấn nút "Thêm bàn" để bắt đầu',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildTableGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredTables.length,
      itemBuilder: (context, index) {
        final table = _filteredTables[index];
        return _buildTableCard(table);
      },
    );
  }

  Widget _buildTableCard(TableModel table) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _getStatusColor(table.status).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => _showDetailDialog(table),
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.table_restaurant,
                  size: 40,
                  color: _getStatusColor(table.status),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bàn ${table.number}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${table.capacity} chỗ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(table.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusDisplayName(table.status),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(table.status),
                    ),
                  ),
                ),
              ],
            ),
            // Menu button
            Positioned(
              top: 4,
              right: 4,
              child: PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    size: 16,
                  ),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showAddEditDialog(table);
                      break;
                    case 'delete':
                      _showDeleteDialog(table);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Sửa'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Xóa', style: TextStyle(color: Colors.red)),
                      ],
                    ),
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
