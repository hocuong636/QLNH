import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:quanlynhahang/services/auth_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/models/restaurant.dart';
import 'package:quanlynhahang/models/service_package.dart';
import 'package:quanlynhahang/models/request.dart';
import 'package:quanlynhahang/constants/user_roles.dart';

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  final AuthService _authService = AuthService();
  final LocalStorageService _localStorageService = LocalStorageService();
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  List<Restaurant> _restaurants = [];
  bool _isLoading = true;
  String _searchQuery = '';
  ServicePackage? _selectedPackage;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await _database.ref('restaurants').get();
      final restaurants = <Restaurant>[];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          data.forEach((key, value) {
            if (value is Map) {
              try {
                final restaurant = Restaurant.fromJson({
                  'id': key.toString(),
                  ...Map<String, dynamic>.from(value),
                });
                // Chỉ hiển thị nhà hàng đang hoạt động
                if (restaurant.isOpen) {
                  restaurants.add(restaurant);
                }
              } catch (e) {
                print('Error parsing restaurant $key: $e');
              }
            }
          });
        }
      }

      setState(() {
        _restaurants = restaurants;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading restaurants: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải danh sách nhà hàng: $e')),
        );
      }
    }
  }

  List<Restaurant> get _filteredRestaurants {
    if (_searchQuery.isEmpty) return _restaurants;
    
    final query = _searchQuery.toLowerCase();
    return _restaurants.where((restaurant) {
      return restaurant.name.toLowerCase().contains(query) ||
          restaurant.address.toLowerCase().contains(query) ||
          restaurant.description.toLowerCase().contains(query);
    }).toList();
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
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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
    final userName = _localStorageService.getUserName() ?? 'Khách hàng';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Icon(
                Icons.person_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xin chào, $userName 👋',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const Text(
                    'Khám phá nhà hàng',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: mở trang thông báo
            },
            icon: const Icon(Icons.notifications_none_rounded,
                color: Color(0xFF666666)),
            tooltip: 'Thông báo',
          ),
          IconButton(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF666666)),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Hero section - Giới thiệu
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF004F4F), Color(0xFF00796B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF004F4F).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white.withOpacity(0.15),
                          ),
                          child: const Icon(
                            Icons.restaurant_menu_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Hệ Thống Quản Lý Nhà Hàng',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Giải pháp quản lý nhà hàng toàn diện, giúp bạn quản lý menu, đơn hàng, nhân viên và doanh thu một cách hiệu quả.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _showRegistrationOptions,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF004F4F),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          icon: const Icon(Icons.app_registration_rounded, size: 24),
                          label: const Text(
                            'Đăng Ký Ngay',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Features section
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tính năng nổi bật',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureCard(
                          icon: Icons.restaurant_menu_rounded,
                          title: 'Quản lý Menu',
                          description: 'Quản lý món ăn, giá cả và danh mục một cách dễ dàng',
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureCard(
                          icon: Icons.receipt_long_rounded,
                          title: 'Quản lý Đơn hàng',
                          description: 'Theo dõi và xử lý đơn hàng theo thời gian thực',
                          color: Colors.green,
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureCard(
                          icon: Icons.people_rounded,
                          title: 'Quản lý Nhân viên',
                          description: 'Phân quyền và quản lý nhân viên hiệu quả',
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureCard(
                          icon: Icons.analytics_rounded,
                          title: 'Báo cáo & Thống kê',
                          description: 'Theo dõi doanh thu và hiệu suất kinh doanh',
                          color: Colors.purple,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showRegistrationOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chọn loại đăng ký',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn muốn đăng ký làm gì?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            _buildRegistrationOption(
              icon: Icons.business_center_rounded,
              title: 'Đăng ký làm Owner',
              description: 'Quản lý nhà hàng của riêng bạn',
              color: Colors.blue,
              onTap: () {
                Navigator.of(context).pop();
                _showOwnerRegistrationDialog();
              },
            ),
            const SizedBox(height: 16),
            _buildRegistrationOption(
              icon: Icons.work_outline_rounded,
              title: 'Đăng ký làm Nhân viên',
              description: 'Làm việc tại một nhà hàng',
              color: Colors.green,
              onTap: () {
                Navigator.of(context).pop();
                _showStaffRegistrationDialog();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationOption({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showOwnerRegistrationDialog() async {
    List<ServicePackage> packages = [];
    bool isLoadingPackages = true;

    // Load packages
    try {
      final snapshot = await _database.ref('service_packages').get();
      print('Service packages snapshot exists: ${snapshot.exists}');
      
      if (snapshot.exists) {
        final data = snapshot.value;
        print('Service packages data type: ${data.runtimeType}');
        
        if (data is Map) {
          print('Service packages count: ${data.length}');
          data.forEach((key, value) {
            print('Processing package key: $key, value type: ${value.runtimeType}');
            if (value is Map) {
              try {
                final packageData = {
                  'id': key.toString(),
                  ...Map<String, dynamic>.from(value),
                };
                print('Package data: $packageData');
                
                final package = ServicePackage.fromJson(packageData);
                print('Parsed package: ${package.name}, isActive: ${package.isActive}');
                
                // Chỉ hiển thị các gói đang active (mặc định là true nếu không có field)
                if (package.isActive) {
                  packages.add(package);
                  print('Added package: ${package.name}');
                } else {
                  print('Skipped package ${package.name} because isActive is false');
                }
              } catch (e) {
                print('Error parsing package $key: $e');
                print('Stack trace: ${StackTrace.current}');
              }
            } else {
              print('Value is not a Map for key $key: $value');
            }
          });
        } else {
          print('Data is not a Map: $data');
        }
      } else {
        print('Service packages snapshot does not exist');
      }
      
      print('Total packages loaded: ${packages.length}');
      isLoadingPackages = false;
    } catch (e) {
      print('Error loading packages: $e');
      print('Stack trace: ${StackTrace.current}');
      isLoadingPackages = false;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Đăng ký làm Owner'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin về Owner:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Quản lý nhà hàng của riêng bạn\n'
                    '• Tạo và quản lý menu\n'
                    '• Theo dõi đơn hàng và doanh thu\n'
                    '• Quản lý nhân viên\n'
                    '• Xem báo cáo chi tiết',
                    style: TextStyle(fontSize: 14, height: 1.6),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Chọn gói dịch vụ:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isLoadingPackages)
                    const Center(child: CircularProgressIndicator())
                  else if (packages.isEmpty)
                    const Text('Chưa có gói dịch vụ nào')
                  else
                    ...packages.map((package) {
                      return RadioListTile<ServicePackage>(
                        title: Text(package.name),
                        subtitle: Text(
                          '${package.durationMonths} tháng - ${_formatCurrency(package.price)}',
                        ),
                        value: package,
                        groupValue: _selectedPackage,
                        onChanged: (value) {
                          setDialogState(() {
                            _selectedPackage = value;
                          });
                        },
                      );
                    }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: _selectedPackage == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _submitOwnerRequest();
                    },
              child: const Text('Gửi yêu cầu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStaffRegistrationDialog() async {
    // Load restaurants
    List<Restaurant> restaurants = [];
    bool isLoading = true;

    try {
      final snapshot = await _database.ref('restaurants').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          data.forEach((key, value) {
            if (value is Map) {
              try {
                final restaurant = Restaurant.fromJson({
                  'id': key.toString(),
                  ...Map<String, dynamic>.from(value),
                });
                if (restaurant.isOpen) {
                  restaurants.add(restaurant);
                }
              } catch (e) {
                print('Error parsing restaurant: $e');
              }
            }
          });
        }
      }
      isLoading = false;
    } catch (e) {
      print('Error loading restaurants: $e');
      isLoading = false;
    }

    if (!mounted) return;

    String? selectedRestaurantId;
    String? selectedRole;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Đăng ký làm Nhân viên'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chọn nhà hàng:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (restaurants.isEmpty)
                    const Text('Chưa có nhà hàng nào')
                  else
                    ...restaurants.map((restaurant) {
                      return RadioListTile<String>(
                        title: Text(restaurant.name),
                        subtitle: Text(restaurant.address),
                        value: restaurant.id,
                        groupValue: selectedRestaurantId,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedRestaurantId = value;
                            selectedRole = null; // Reset role khi đổi nhà hàng
                          });
                        },
                      );
                    }),
                  if (selectedRestaurantId != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Chọn vai trò:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<String>(
                      title: const Text('Nhân viên Order'),
                      subtitle: const Text('Nhận order & thanh toán'),
                      value: UserRole.order,
                      groupValue: selectedRole,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedRole = value;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Nhân viên Bếp'),
                      subtitle: const Text('Xử lý và chế biến món ăn'),
                      value: UserRole.kitchen,
                      groupValue: selectedRole,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedRole = value;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: selectedRestaurantId == null || selectedRole == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _submitStaffRequest(selectedRestaurantId!, selectedRole!);
                    },
              child: const Text('Gửi yêu cầu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitOwnerRequest() async {
    if (_selectedPackage == null) return;

    try {
      final userId = _localStorageService.getUserId() ?? '';
      final userEmail = _localStorageService.getUserEmail() ?? '';
      final userName = _localStorageService.getUserName() ?? '';

      final request = Request(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        userEmail: userEmail,
        userName: userName,
        type: RequestType.owner,
        status: RequestStatus.pending,
        createdAt: DateTime.now(),
        packageId: _selectedPackage!.id,
        packageName: _selectedPackage!.name,
        packagePrice: _selectedPackage!.price,
        packageDurationMonths: _selectedPackage!.durationMonths,
        paymentMethod: 'Chưa thanh toán', // TODO: Implement payment
      );

      await _database.ref('requests/${request.id}').set(request.toJson());

      // Gửi thông báo cho admin (tất cả admin sẽ thấy)
      // Tìm tất cả admin users
      try {
        final usersSnapshot = await _database.ref('users').get();
        if (usersSnapshot.exists) {
          final usersData = usersSnapshot.value as Map<dynamic, dynamic>?;
          if (usersData != null) {
            usersData.forEach((key, value) {
              if (value is Map) {
                final role = value['role'];
                if (role == UserRole.admin) {
                  // Gửi thông báo cho từng admin
                  _database.ref('notifications').push().set({
                    'userId': key.toString(),
                    'title': 'Yêu cầu đăng ký Owner mới',
                    'message': '$userName muốn đăng ký làm Owner với gói ${_selectedPackage!.name}',
                    'type': 'owner_request',
                    'requestId': request.id,
                    'timestamp': DateTime.now().toIso8601String(),
                    'read': false,
                  });
                }
              }
            });
          }
        }
      } catch (e) {
        print('Error sending notification to admin: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi yêu cầu đăng ký Owner. Vui lòng chờ Admin phê duyệt.'),
          ),
        );
        _selectedPackage = null;
      }
    } catch (e) {
      print('Error submitting owner request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi yêu cầu: $e')),
        );
      }
    }
  }

  Future<void> _submitStaffRequest(String restaurantId, String role) async {
    try {
      // Lấy thông tin nhà hàng và owner
      final restaurantSnapshot = await _database.ref('restaurants/$restaurantId').get();
      if (!restaurantSnapshot.exists) {
        throw Exception('Không tìm thấy nhà hàng');
      }

      final restaurantData = restaurantSnapshot.value as Map<dynamic, dynamic>;
      final restaurantName = restaurantData['name'] ?? 'Unknown';
      final ownerId = restaurantData['ownerId'] ?? '';

      final userId = _localStorageService.getUserId() ?? '';
      final userEmail = _localStorageService.getUserEmail() ?? '';
      final userName = _localStorageService.getUserName() ?? '';

      final request = Request(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        userEmail: userEmail,
        userName: userName,
        type: RequestType.staff,
        status: RequestStatus.pending,
        createdAt: DateTime.now(),
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        requestedRole: role,
        ownerId: ownerId,
      );

      await _database.ref('requests/${request.id}').set(request.toJson());

      // Gửi thông báo cho owner
      await _database.ref('notifications').push().set({
        'userId': ownerId,
        'title': 'Yêu cầu đăng ký Nhân viên mới',
        'message': '$userName muốn đăng ký làm ${role == UserRole.order ? "Nhân viên Order" : "Nhân viên Bếp"} tại $restaurantName',
        'type': 'staff_request',
        'requestId': request.id,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã gửi yêu cầu đến Owner của $restaurantName. Vui lòng chờ phê duyệt.'),
          ),
        );
      }
    } catch (e) {
      print('Error submitting staff request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi yêu cầu: $e')),
        );
      }
    }
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )} VND';
  }
}

