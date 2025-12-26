import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:quanlynhahang/services/menu_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/services/cloudinary_service.dart';
import 'package:quanlynhahang/models/menu_item.dart';
import 'package:quanlynhahang/constants/cloudinary_config.dart';

class MenuManagementPage extends StatefulWidget {
  const MenuManagementPage({super.key});

  @override
  State<MenuManagementPage> createState() => _MenuManagementPageState();
}

class _MenuManagementPageState extends State<MenuManagementPage> {
  final MenuService _menuService = MenuService();
  final LocalStorageService _localStorageService = LocalStorageService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final TextEditingController _searchController = TextEditingController();
  List<MenuItem> _menuItems = [];
  List<MenuItem> _filteredMenuItems = [];
  bool _isLoading = true;
  String _selectedCategory = 'Tất cả';
  final List<String> _categories = [
    'Tất cả',
    'Khai vị',
    'Món chính',
    'Món phụ',
    'Tráng miệng',
    'Đồ uống',
    'Khác'
  ];

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
    _searchController.addListener(_filterMenuItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMenuItems() async {
    setState(() => _isLoading = true);
    try {
      _menuItems = await _menuService.getMenuItems();
      _filterMenuItems();
    } catch (e) {
      _showSnackBar('Lỗi khi tải danh sách món ăn: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterMenuItems() {
    setState(() {
      _filteredMenuItems = _menuItems.where((item) {
        final matchesSearch = item.name
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            item.description
                .toLowerCase()
                .contains(_searchController.text.toLowerCase());
        final matchesCategory = _selectedCategory == 'Tất cả' ||
            item.category == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAddEditDialog([MenuItem? item]) {
    final nameController = TextEditingController(text: item?.name ?? '');
    final descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    final priceController = TextEditingController(
      text: item?.price.toString() ?? '',
    );
    String selectedCategory = item?.category ?? 'Món chính';
    String imageUrl = item?.imageUrl ?? '';
    bool isAvailable = item?.isAvailable ?? true;
    bool isUploading = false;
    File? selectedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Thêm món ăn' : 'Sửa món ăn'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hiển thị hình ảnh
                GestureDetector(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1024,
                      maxHeight: 1024,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      setDialogState(() {
                        selectedImage = File(image.path);
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      _buildImagePlaceholder(),
                                ),
                              )
                            : _buildImagePlaceholder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nhấn để chọn hình ảnh',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên món ăn *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.restaurant),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Giá (VND) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Danh mục',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _categories
                      .where((cat) => cat != 'Tất cả')
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Món ăn có sẵn:',
                      style: TextStyle(fontSize: 16),
                    ),
                    Switch(
                      value: isAvailable,
                      onChanged: (value) =>
                          setDialogState(() => isAvailable = value),
                    ),
                  ],
                ),
                if (isUploading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Đang tải hình ảnh...'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (nameController.text.isEmpty ||
                          priceController.text.isEmpty) {
                        _showSnackBar('Vui lòng nhập tên và giá');
                        return;
                      }

                      setDialogState(() => isUploading = true);

                      try {
                        // Get restaurant ID from local storage (single restaurant app)
                        String restaurantId = _localStorageService.getRestaurantId();

                        // Upload hình ảnh nếu có
                        String finalImageUrl = imageUrl;
                        if (selectedImage != null) {
                          finalImageUrl = await _uploadImage(
                            selectedImage!,
                            restaurantId,
                          );
                        }

                        MenuItem newItem = MenuItem(
                          id: item?.id ?? '',
                          restaurantId: restaurantId,
                          name: nameController.text,
                          description: descriptionController.text,
                          price: double.parse(priceController.text),
                          category: selectedCategory,
                          imageUrl: finalImageUrl,
                          isAvailable: isAvailable,
                          createdAt: item?.createdAt ?? DateTime.now(),
                          updatedAt: DateTime.now(),
                        );

                        if (item == null) {
                          await _menuService.createMenuItem(newItem);
                        } else {
                          await _menuService.updateMenuItem(newItem);
                        }

                        // Đóng dialog trước
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }

                        // Hiển thị thông báo và reload
                        _showSnackBar(
                          item == null
                              ? 'Thêm món ăn thành công'
                              : 'Cập nhật món ăn thành công',
                        );
                        await _loadMenuItems();
                      } catch (e) {
                        // Đảm bảo tắt loading
                        setDialogState(() => isUploading = false);
                        
                        // Hiển thị lỗi
                        if (context.mounted) {
                          _showSnackBar('Lỗi: $e');
                        }
                      }
                    },
              child: Text(item == null ? 'Thêm' : 'Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate,
          size: 60,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 8),
        Text(
          'Thêm hình ảnh',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Future<String> _uploadImage(File image, String restaurantId) async {
    try {
      // Kiểm tra file có tồn tại không
      if (!await image.exists()) {
        throw Exception('File không tồn tại');
      }

      // Upload lên Cloudinary
      final imageUrl = await _cloudinaryService.uploadImage(
        file: image,
        folder: CloudinaryConfig.menuImagesFolder,
      );

      return imageUrl;
    } catch (e) {
      throw Exception('Lỗi khi tải hình ảnh: $e');
    }
  }

  void _showDeleteDialog(MenuItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa món ăn'),
        content: Text('Bạn có chắc chắn muốn xóa "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _menuService.deleteMenuItem(item.id);
                _showSnackBar('Xóa món ăn thành công');
                Navigator.of(context).pop();
                _loadMenuItems();
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

  void _showDetailDialog(MenuItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hình ảnh
              if (item.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 250,
                      color: Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 250,
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.restaurant,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              // Thông tin chi tiết
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        item.category,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.attach_money, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '${item.price.toStringAsFixed(0)} VND',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Mô tả:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.description.isNotEmpty
                          ? item.description
                          : 'Chưa có mô tả',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text(
                          'Trạng thái: ',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: item.isAvailable
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.isAvailable ? 'Có sẵn' : 'Hết hàng',
                            style: TextStyle(
                              color: item.isAvailable
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.w500,
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _showAddEditDialog(item);
            },
            icon: const Icon(Icons.edit),
            label: const Text('Sửa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý thực đơn'),
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
                    hintText: 'Tìm kiếm món ăn...',
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
                ),
              ),
              const SizedBox(height: 8),
              // Bộ lọc danh mục
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = category == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = category;
                            _filterMenuItems();
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
          : _filteredMenuItems.isEmpty
              ? _buildEmptyState()
              : _buildMenuGrid(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Colors.blue.shade700,
        icon: const Icon(Icons.add),
        label: const Text('Thêm món'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 100, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty ||
                    _selectedCategory != 'Tất cả'
                ? 'Không tìm thấy món ăn'
                : 'Chưa có món ăn nào',
            style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty ||
                    _selectedCategory != 'Tất cả'
                ? 'Thử thay đổi bộ lọc hoặc tìm kiếm'
                : 'Nhấn nút "Thêm món" để bắt đầu',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredMenuItems.length,
      itemBuilder: (context, index) {
        final item = _filteredMenuItems[index];
        return _buildMenuCard(item);
      },
    );
  }

  Widget _buildMenuCard(MenuItem item) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showDetailDialog(item),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hình ảnh
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      color: Colors.grey.shade200,
                    ),
                    child: item.imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: item.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (context, url, error) => Icon(
                                Icons.restaurant,
                                size: 50,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.restaurant,
                            size: 50,
                            color: Colors.grey.shade400,
                          ),
                  ),
                  // Badge trạng thái
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item.isAvailable
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.isAvailable ? 'Có sẵn' : 'Hết',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Menu options
                  Positioned(
                    top: 8,
                    left: 8,
                    child: PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _showAddEditDialog(item);
                            break;
                          case 'delete':
                            _showDeleteDialog(item);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Sửa'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
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
            // Thông tin
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.category,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      '${item.price.toStringAsFixed(0)} đ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
