import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:quanlynhahang/models/user.dart';
import 'package:quanlynhahang/models/service_package.dart';
import 'package:quanlynhahang/constants/user_roles.dart';

class OwnerPackageManagementPage extends StatefulWidget {
  const OwnerPackageManagementPage({super.key});

  @override
  State<OwnerPackageManagementPage> createState() => _OwnerPackageManagementPageState();
}

class _OwnerPackageManagementPageState extends State<OwnerPackageManagementPage> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  List<UserModel> _owners = [];
  List<ServicePackage> _packages = [];
  List<UserModel> _filteredOwners = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedPackageFilter;
  String? _selectedStatusFilter; // 'active', 'expired', 'no_package'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadOwners(),
        _loadPackages(),
      ]);
      _checkExpiredPackages();
      _applyFilters();
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    }
  }

  Future<void> _loadOwners() async {
    try {
      final snapshot = await _database.ref('users').get();
      final owners = <UserModel>[];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final user = UserModel.fromJson({
                'uid': key,
                ...Map<String, dynamic>.from(value),
              });
              if (user.role == UserRole.owner) {
                owners.add(user);
              }
            } catch (e) {
              print('Error parsing user $key: $e');
            }
          }
        });
      }

      setState(() {
        _owners = owners;
      });
    } catch (e) {
      print('Error loading owners: $e');
      rethrow;
    }
  }

  Future<void> _loadPackages() async {
    try {
      final snapshot = await _database.ref('service_packages').get();
      final packages = <ServicePackage>[];

      if (snapshot.exists) {
        final data = snapshot.value;
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
      }

      setState(() {
        _packages = packages;
      });
    } catch (e) {
      print('Error loading packages: $e');
      rethrow;
    }
  }

  Future<void> _checkExpiredPackages() async {
    final now = DateTime.now();
    final expiredOwners = <String>[];

    for (var owner in _owners) {
      if (owner.packageExpiryDate != null && owner.packageExpiryDate!.isBefore(now)) {
        if (owner.isActive) {
          // Vô hiệu hóa tài khoản và gửi thông báo
          expiredOwners.add(owner.uid);
          await _deactivateOwner(owner);
          await _sendExpiryNotification(owner);
        }
      }
    }

    if (expiredOwners.isNotEmpty) {
      await _loadOwners();
    }
  }

  Future<void> _deactivateOwner(UserModel owner) async {
    try {
      await _database.ref('users/${owner.uid}').update({
        'isActive': false,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error deactivating owner: $e');
    }
  }

  Future<void> _sendExpiryNotification(UserModel owner) async {
    try {
      final notification = {
        'userId': owner.uid,
        'title': 'Gói dịch vụ đã hết hạn',
        'message': 'Gói dịch vụ của bạn đã hết hạn. Vui lòng gia hạn để tiếp tục sử dụng dịch vụ.',
        'type': 'package_expired',
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      };

      await _database.ref('notifications').push().set(notification);
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  Future<void> _assignPackage(UserModel owner, ServicePackage package) async {
    try {
      final expiryDate = DateTime.now().add(Duration(days: package.durationMonths * 30));

      await _database.ref('users/${owner.uid}').update({
        'packageId': package.id,
        'packageExpiryDate': expiryDate.toIso8601String(),
        'isActive': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await _loadOwners();
      _applyFilters();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gán gói ${package.name} cho ${owner.fullName}')),
        );
      }
    } catch (e) {
      print('Error assigning package: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gán gói dịch vụ: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    List<UserModel> filtered = List.from(_owners);

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((owner) {
        final query = _searchQuery.toLowerCase();
        return owner.email.toLowerCase().contains(query) ||
            owner.fullName.toLowerCase().contains(query) ||
            owner.phoneNumber.contains(query);
      }).toList();
    }

    // Filter by package
    if (_selectedPackageFilter != null && _selectedPackageFilter!.isNotEmpty) {
      filtered = filtered.where((owner) => owner.packageId == _selectedPackageFilter).toList();
    }

    // Filter by status
    if (_selectedStatusFilter != null && _selectedStatusFilter!.isNotEmpty) {
      final now = DateTime.now();
      if (_selectedStatusFilter == 'active') {
        filtered = filtered.where((owner) {
          return owner.isActive &&
              owner.packageExpiryDate != null &&
              owner.packageExpiryDate!.isAfter(now);
        }).toList();
      } else if (_selectedStatusFilter == 'expired') {
        filtered = filtered.where((owner) {
          return owner.packageExpiryDate != null &&
              owner.packageExpiryDate!.isBefore(now);
        }).toList();
      } else if (_selectedStatusFilter == 'no_package') {
        filtered = filtered.where((owner) => owner.packageId == null).toList();
      }
    }

    setState(() {
      _filteredOwners = filtered;
    });
  }

  String? _getPackageName(String? packageId) {
    if (packageId == null) return null;
    final package = _packages.firstWhere(
      (p) => p.id == packageId,
      orElse: () => ServicePackage(
        id: '',
        name: 'Unknown',
        description: '',
        durationMonths: 0,
        price: 0,
        level: 'basic',
        createdAt: DateTime.now(),
      ),
    );
    return package.name;
  }

  String _getStatusText(UserModel owner) {
    if (owner.packageId == null) return 'Chưa có gói';
    if (owner.packageExpiryDate == null) return 'Không xác định';
    
    final now = DateTime.now();
    if (owner.packageExpiryDate!.isBefore(now)) {
      return 'Đã hết hạn';
    } else {
      final daysLeft = owner.packageExpiryDate!.difference(now).inDays;
      return 'Còn $daysLeft ngày';
    }
  }

  Color _getStatusColor(UserModel owner) {
    if (owner.packageId == null) return Colors.grey;
    if (owner.packageExpiryDate == null) return Colors.grey;
    
    final now = DateTime.now();
    if (owner.packageExpiryDate!.isBefore(now)) {
      return Colors.red;
    } else {
      final daysLeft = owner.packageExpiryDate!.difference(now).inDays;
      if (daysLeft <= 7) return Colors.orange;
      return Colors.green;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAssignPackageDialog(UserModel owner) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Gán gói dịch vụ cho ${owner.fullName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _packages.length,
            itemBuilder: (context, index) {
              final package = _packages[index];
              return ListTile(
                title: Text(package.name),
                subtitle: Text('${package.durationMonths} tháng - ${_formatCurrency(package.price)}'),
                trailing: package.isActive
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.block, color: Colors.red),
                onTap: package.isActive
                    ? () {
                        Navigator.of(context).pop();
                        _assignPackage(owner, package);
                      }
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
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
        title: const Text('Quản lý Owner & Gói Dịch vụ'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Làm mới',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilters();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm theo tên, email, SĐT...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedPackageFilter,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Tất cả gói',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Tất cả gói', overflow: TextOverflow.ellipsis)),
                          ..._packages.map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name, overflow: TextOverflow.ellipsis),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedPackageFilter = value;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatusFilter,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Tất cả trạng thái',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Tất cả trạng thái', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'active', child: Text('Đang hoạt động', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'expired', child: Text('Đã hết hạn', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'no_package', child: Text('Chưa có gói', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatusFilter = value;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredOwners.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Chưa có owner nào'
                            : 'Không tìm thấy owner',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredOwners.length,
                  itemBuilder: (context, index) {
                    final owner = _filteredOwners[index];
                    final statusColor = _getStatusColor(owner);
                    final statusText = _getStatusText(owner);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.1),
                          child: Icon(
                            Icons.person,
                            color: statusColor,
                          ),
                        ),
                        title: Text(
                          owner.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(owner.email),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (owner.packageId != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _getPackageName(owner.packageId) ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: statusColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (owner.packageExpiryDate != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Hết hạn: ${_formatDate(owner.packageExpiryDate)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _showAssignPackageDialog(owner),
                          tooltip: 'Gán gói dịch vụ',
                        ),
                        onTap: () => _showAssignPackageDialog(owner),
                      ),
                    );
                  },
                ),
    );
  }
}

