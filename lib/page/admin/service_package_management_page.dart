import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:quanlynhahang/models/service_package.dart';

class ServicePackageManagementPage extends StatefulWidget {
  const ServicePackageManagementPage({super.key});

  @override
  State<ServicePackageManagementPage> createState() => _ServicePackageManagementPageState();
}

class _ServicePackageManagementPageState extends State<ServicePackageManagementPage> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  List<ServicePackage> _packages = [];
  bool _isLoading = true;

  // Controllers for add/edit form
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String _selectedLevel = 'basic';
  bool _isActive = true;
  ServicePackage? _editingPackage;

  @override
  void initState() {
    super.initState();
    _loadPackages();
    _initializeDefaultPackages();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _initializeDefaultPackages() async {
    try {
      final snapshot = await _database.ref('service_packages').get();
      bool shouldInitialize = false;
      
      if (!snapshot.exists) {
        shouldInitialize = true;
      } else {
        final data = snapshot.value;
        if (data is Map) {
          shouldInitialize = data.isEmpty;
        } else {
          // Nếu data không phải Map, có thể là lỗi cấu trúc, nên khởi tạo lại
          shouldInitialize = true;
        }
      }

      if (shouldInitialize) {
        // Tạo 3 gói mặc định nếu chưa có
        final defaultPackages = [
          {
            'id': 'basic',
            'name': 'Gói Cơ Bản',
            'description': 'Gói dịch vụ cơ bản cho nhà hàng nhỏ',
            'durationMonths': 3,
            'price': 500000.0,
            'level': 'basic',
            'isActive': true,
            'createdAt': DateTime.now().toIso8601String(),
          },
          {
            'id': 'standard',
            'name': 'Gói Tiêu Chuẩn',
            'description': 'Gói dịch vụ tiêu chuẩn cho nhà hàng vừa',
            'durationMonths': 6,
            'price': 900000.0,
            'level': 'standard',
            'isActive': true,
            'createdAt': DateTime.now().toIso8601String(),
          },
          {
            'id': 'premium',
            'name': 'Gói Cao Cấp',
            'description': 'Gói dịch vụ cao cấp cho nhà hàng lớn',
            'durationMonths': 12,
            'price': 1500000.0,
            'level': 'premium',
            'isActive': true,
            'createdAt': DateTime.now().toIso8601String(),
          },
        ];

        for (var packageData in defaultPackages) {
          await _database.ref('service_packages/${packageData['id']}').set(packageData);
        }
      }
    } catch (e) {
      print('Error initializing default packages: $e');
    }
  }

  Future<void> _loadPackages() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await _database.ref('service_packages').get();

      if (snapshot.exists) {
        final data = snapshot.value;
        final packages = <ServicePackage>[];

        if (data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              try {
                final package = ServicePackage.fromJson({
                  'id': key.toString(),
                  ...Map<String, dynamic>.from(value),
                });
                packages.add(package);
              } catch (e) {
                print('Error parsing package $key: $e');
              }
            } else {
              print('Warning: package $key is not a Map, skipping');
            }
          });
        } else {
          print('Warning: service_packages data is not a Map');
        }

        // Sắp xếp theo level
        packages.sort((a, b) {
          final order = {'basic': 1, 'standard': 2, 'premium': 3};
          return (order[a.level] ?? 0).compareTo(order[b.level] ?? 0);
        });

        setState(() {
          _packages = packages;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading packages: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải danh sách gói dịch vụ: $e')),
        );
      }
    }
  }

  Future<void> _togglePackageStatus(ServicePackage package) async {
    try {
      await _database.ref('service_packages/${package.id}').update({
        'isActive': !package.isActive,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await _loadPackages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              package.isActive
                  ? 'Đã vô hiệu hóa gói ${package.name}'
                  : 'Đã kích hoạt gói ${package.name}',
            ),
          ),
        );
      }
    } catch (e) {
      print('Error toggling package status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật trạng thái: $e')),
        );
      }
    }
  }

  Future<void> _savePackage() async {
    if (_nameController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _durationController.text.isEmpty ||
        _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
      );
      return;
    }

    final duration = int.tryParse(_durationController.text);
    final price = double.tryParse(_priceController.text);

    if (duration == null || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thời gian phải là số nguyên dương')),
      );
      return;
    }

    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giá phải là số dương')),
      );
      return;
    }

    try {
      final packageId = _editingPackage?.id ?? 
          _selectedLevel.toLowerCase().replaceAll(' ', '_') + '_${DateTime.now().millisecondsSinceEpoch}';

      final packageData = {
        'id': packageId,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'durationMonths': duration,
        'price': price,
        'level': _selectedLevel,
        'isActive': _isActive,
        'createdAt': _editingPackage?.createdAt.toIso8601String() ?? DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _database.ref('service_packages/$packageId').set(packageData);
      await _loadPackages();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingPackage == null 
                ? 'Đã thêm gói dịch vụ thành công'
                : 'Đã cập nhật gói dịch vụ thành công'),
          ),
        );
      }
    } catch (e) {
      print('Error saving package: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu gói dịch vụ: $e')),
        );
      }
    }
  }

  Future<void> _deletePackage(ServicePackage package) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa gói "${package.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _database.ref('service_packages/${package.id}').remove();
        await _loadPackages();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã xóa gói ${package.name}')),
          );
        }
      } catch (e) {
        print('Error deleting package: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi xóa gói dịch vụ: $e')),
          );
        }
      }
    }
  }

  void _showAddEditPackageDialog({ServicePackage? package}) {
    _editingPackage = package;
    
    if (package != null) {
      // Edit mode
      _nameController.text = package.name;
      _descriptionController.text = package.description;
      _durationController.text = package.durationMonths.toString();
      _priceController.text = package.price.toString();
      _selectedLevel = package.level;
      _isActive = package.isActive;
    } else {
      // Add mode
      _nameController.clear();
      _descriptionController.clear();
      _durationController.clear();
      _priceController.clear();
      _selectedLevel = 'basic';
      _isActive = true;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(package == null ? 'Thêm gói dịch vụ' : 'Sửa gói dịch vụ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên gói *',
                    hintText: 'Gói Cơ Bản',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả *',
                    hintText: 'Mô tả về gói dịch vụ',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _durationController,
                        decoration: const InputDecoration(
                          labelText: 'Thời gian (tháng) *',
                          hintText: '3',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Giá (VND) *',
                          hintText: '500000',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedLevel,
                  decoration: const InputDecoration(
                    labelText: 'Cấp độ',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'basic', child: Text('Cơ Bản')),
                    DropdownMenuItem(value: 'standard', child: Text('Tiêu Chuẩn')),
                    DropdownMenuItem(value: 'premium', child: Text('Cao Cấp')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedLevel = value ?? 'basic';
                    });
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Kích hoạt'),
                  value: _isActive,
                  onChanged: (value) {
                    setDialogState(() {
                      _isActive = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _editingPackage = null;
              },
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: _savePackage,
              child: Text(package == null ? 'Thêm' : 'Lưu'),
            ),
          ],
        ),
      ),
    ).then((_) {
      _editingPackage = null;
    });
  }

  void _showPackageDetails(ServicePackage package) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(package.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Mô tả', package.description),
              _buildDetailRow('Thời gian', '${package.durationMonths} tháng'),
              _buildDetailRow('Giá', _formatCurrency(package.price)),
              _buildDetailRow('Cấp độ', _getLevelDisplayName(package.level)),
              _buildDetailRow('Trạng thái', package.isActive ? 'Hoạt động' : 'Đã vô hiệu hóa'),
              _buildDetailRow('Ngày tạo', _formatDate(package.createdAt)),
              if (package.updatedAt != null)
                _buildDetailRow('Cập nhật lần cuối', _formatDate(package.updatedAt!)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )} VND';
  }

  String _getLevelDisplayName(String level) {
    switch (level) {
      case 'basic':
        return 'Cơ Bản';
      case 'standard':
        return 'Tiêu Chuẩn';
      case 'premium':
        return 'Cao Cấp';
      default:
        return level;
    }
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'basic':
        return Colors.blue;
      case 'standard':
        return Colors.green;
      case 'premium':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: color.withOpacity(0.7),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      appBar: AppBar(
        title: const Text('Quản lý Gói Dịch vụ'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditPackageDialog(),
            tooltip: 'Thêm gói mới',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPackages,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _packages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.card_giftcard_outlined,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có gói dịch vụ nào',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _packages.length,
                  itemBuilder: (context, index) {
                    final package = _packages[index];
                    final levelColor = _getLevelColor(package.level);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white,
                              levelColor.withOpacity(0.02),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: levelColor.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row with icon and title
                              Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          levelColor.withOpacity(0.2),
                                          levelColor.withOpacity(0.1),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: levelColor.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.card_giftcard_rounded,
                                      color: levelColor,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          package.name,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1A1A1A),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          package.description,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                            height: 1.4,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Badges row
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: levelColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: levelColor.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          size: 14,
                                          color: levelColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _getLevelDisplayName(package.level),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: levelColor,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: (package.isActive ? Colors.green : Colors.red).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: (package.isActive ? Colors.green : Colors.red).withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          package.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                          size: 14,
                                          color: package.isActive ? Colors.green : Colors.red,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          package.isActive ? 'Hoạt động' : 'Đã vô hiệu hóa',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: package.isActive ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Divider
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: Colors.grey.shade200,
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Info row with duration and price
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInfoItem(
                                      icon: Icons.calendar_today_rounded,
                                      label: 'Thời gian',
                                      value: '${package.durationMonths} tháng',
                                      color: Colors.blue,
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.grey.shade200,
                                  ),
                                  Expanded(
                                    child: _buildInfoItem(
                                      icon: Icons.attach_money_rounded,
                                      label: 'Giá',
                                      value: _formatCurrency(package.price),
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Action buttons row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _buildActionButton(
                                    icon: Icons.info_outline_rounded,
                                    tooltip: 'Chi tiết',
                                    color: Colors.blue,
                                    onPressed: () => _showPackageDetails(package),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildActionButton(
                                    icon: Icons.edit_rounded,
                                    tooltip: 'Sửa',
                                    color: Colors.orange,
                                    onPressed: () => _showAddEditPackageDialog(package: package),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildActionButton(
                                    icon: Icons.delete_rounded,
                                    tooltip: 'Xóa',
                                    color: Colors.red,
                                    onPressed: () => _deletePackage(package),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildActionButton(
                                    icon: package.isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                                    tooltip: package.isActive ? 'Vô hiệu hóa' : 'Kích hoạt',
                                    color: package.isActive ? Colors.red : Colors.green,
                                    onPressed: () => _togglePackageStatus(package),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

