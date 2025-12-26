# Hướng dẫn sử dụng Chức năng Quản lý Thực đơn

## Tổng quan
Chức năng quản lý thực đơn cho phép chủ nhà hàng thực hiện đầy đủ các thao tác CRUD (Create, Read, Update, Delete) trên các món ăn trong thực đơn của nhà hàng.

## Các tính năng chính

### 1. **Xem danh sách món ăn**
- Hiển thị tất cả món ăn dưới dạng lưới (grid) với hình ảnh
- Thông tin hiển thị: Tên món, giá, danh mục, trạng thái (có sẵn/hết hàng)
- Giao diện trực quan với hình ảnh món ăn

### 2. **Thêm món ăn mới**
- Nhấn nút "Thêm món" (floating action button)
- Nhập thông tin:
  - **Tên món ăn** (*bắt buộc)
  - **Mô tả**: Mô tả chi tiết về món ăn
  - **Giá tiền** (VND) (*bắt buộc)
  - **Danh mục**: Khai vị, Món chính, Món phụ, Tráng miệng, Đồ uống, Khác
  - **Hình ảnh**: Upload từ thư viện ảnh hoặc nhập URL
  - **Trạng thái**: Có sẵn / Hết hàng

### 3. **Chỉnh sửa món ăn**
- Nhấn vào icon menu (3 chấm) trên thẻ món ăn
- Chọn "Sửa"
- Cập nhật thông tin cần thay đổi
- Nhấn "Cập nhật" để lưu

### 4. **Xóa món ăn**
- Nhấn vào icon menu (3 chấm) trên thẻ món ăn
- Chọn "Xóa"
- Xác nhận xóa trong hộp thoại

### 5. **Xem chi tiết món ăn**
- Nhấn vào thẻ món ăn
- Xem đầy đủ thông tin: hình ảnh lớn, tên, giá, mô tả, danh mục, trạng thái
- Có thể chỉnh sửa trực tiếp từ màn hình chi tiết

### 6. **Tìm kiếm món ăn**
- Sử dụng thanh tìm kiếm ở đầu trang
- Tìm theo tên món hoặc mô tả
- Kết quả hiển thị ngay lập tức

### 7. **Lọc theo danh mục**
- Sử dụng các chip lọc bên dưới thanh tìm kiếm
- Các danh mục: Tất cả, Khai vị, Món chính, Món phụ, Tráng miệng, Đồ uống, Khác
- Kết hợp được với tìm kiếm

## Cấu trúc dữ liệu

### Model MenuItem
```dart
class MenuItem {
  final String id;              // ID tự động sinh
  final String restaurantId;    // ID nhà hàng
  final String name;            // Tên món ăn
  final String description;     // Mô tả
  final double price;           // Giá (VND)
  final String category;        // Danh mục
  final String imageUrl;        // URL hình ảnh
  final bool isAvailable;       // Trạng thái
  final DateTime createdAt;     // Ngày tạo
  final DateTime updatedAt;     // Ngày cập nhật
}
```

## Services được sử dụng

### MenuService
Xử lý tất cả các thao tác với Firebase Realtime Database:
- `getMenuItems(restaurantId)`: Lấy danh sách món ăn
- `createMenuItem(menuItem)`: Tạo món ăn mới
- `updateMenuItem(menuItem)`: Cập nhật món ăn
- `deleteMenuItem(menuItemId)`: Xóa món ăn
- `getRestaurantIdByOwnerId(ownerId)`: Lấy ID nhà hàng theo owner

### Firebase Storage
- Upload hình ảnh món ăn lên Firebase Storage
- Tự động tạo URL công khai để hiển thị
- Tên file: `menu_[restaurantId]_[timestamp].jpg`

## Giao diện người dùng

### Layout
- **AppBar**: Tiêu đề, thanh tìm kiếm, bộ lọc danh mục
- **Body**: Lưới 2 cột hiển thị các món ăn
- **FloatingActionButton**: Nút thêm món ăn mới

### Màu sắc
- **Xanh dương** (`Colors.blue.shade700`): Nút chính, filter được chọn
- **Xanh lá** (`Colors.green.shade700`): Giá tiền, trạng thái "Có sẵn"
- **Đỏ** (`Colors.red.shade700`): Nút xóa, trạng thái "Hết hàng"
- **Xám** (`Colors.grey`): Nền, placeholder

## Xử lý lỗi và thông báo

- SnackBar hiển thị thông báo cho mọi thao tác
- Loading indicator khi đang tải dữ liệu
- Placeholder khi không có hình ảnh
- Xác nhận trước khi xóa

## Các packages được sử dụng

```yaml
dependencies:
  firebase_core: ^4.2.1
  firebase_database: ^12.1.0
  firebase_storage: ^13.0.4
  image_picker: ^1.0.7          # Chọn ảnh từ thiết bị
  cached_network_image: ^3.3.1  # Cache và hiển thị ảnh từ network
```

## Cách truy cập

Từ Owner Page:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const MenuManagementPage(),
  ),
);
```

## Lưu ý khi sử dụng

1. **Quyền truy cập**: Chỉ owner của nhà hàng mới có thể quản lý thực đơn
2. **Kết nối Internet**: Cần kết nối để upload ảnh và sync dữ liệu
3. **Kích thước ảnh**: Ảnh được tự động resize về tối đa 1024x1024px
4. **Định dạng giá**: Nhập số nguyên (VD: 50000 cho 50.000 VND)
5. **Xóa món**: Không thể khôi phục sau khi xóa

## Cải tiến trong tương lai

- [ ] Hỗ trợ nhiều ảnh cho mỗi món
- [ ] Quản lý combo/set menu
- [ ] Thêm đánh giá và rating
- [ ] Export/Import menu từ file
- [ ] Sao chép món ăn
- [ ] Lịch sử thay đổi giá
- [ ] Thống kê món bán chạy

## Hỗ trợ

Nếu gặp vấn đề, vui lòng kiểm tra:
1. Firebase được cấu hình đúng
2. Rules của Realtime Database cho phép read/write
3. Rules của Storage cho phép upload
4. User đã đăng nhập và có quyền owner
