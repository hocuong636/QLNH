import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:quanlynhahang/constants/cloudinary_config.dart';

class CloudinaryService {
  late CloudinaryPublic _cloudinary;

  CloudinaryService() {
    _cloudinary = CloudinaryPublic(
      CloudinaryConfig.cloudName,
      CloudinaryConfig.uploadPreset,
      cache: false,
    );
  }

  /// Upload hình ảnh lên Cloudinary
  /// 
  /// [file] - File ảnh cần upload
  /// [folder] - Thư mục trên Cloudinary (ví dụ: 'menu_images')
  /// [resourceType] - Loại resource (mặc định: image)
  /// 
  /// Returns: URL của ảnh đã upload
  Future<String> uploadImage({
    required File file,
    String folder = 'menu_images',
    CloudinaryResourceType resourceType = CloudinaryResourceType.Image,
  }) async {
    try {
      // Kiểm tra file tồn tại
      if (!await file.exists()) {
        throw Exception('File không tồn tại');
      }

      // Tạo tên file unique
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}';

      // Upload lên Cloudinary
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          folder: folder,
          publicId: fileName,
          resourceType: resourceType,
        ),
      );

      return response.secureUrl;
    } on CloudinaryException catch (e) {
      throw Exception('Lỗi Cloudinary: ${e.message}');
    } catch (e) {
      throw Exception('Lỗi khi upload ảnh: $e');
    }
  }

  /// Upload nhiều ảnh cùng lúc
  Future<List<String>> uploadMultipleImages({
    required List<File> files,
    String folder = 'menu_images',
  }) async {
    List<String> urls = [];
    
    for (File file in files) {
      try {
        String url = await uploadImage(file: file, folder: folder);
        urls.add(url);
      } catch (e) {
        // Bỏ qua ảnh lỗi và tiếp tục
        print('Lỗi upload ảnh: $e');
      }
    }
    
    return urls;
  }

  /// Xóa ảnh từ Cloudinary (cần API Key và Secret)
  /// Note: Cần sử dụng cloudinary SDK khác hoặc gọi API trực tiếp
  Future<void> deleteImage(String publicId) async {
    // Để xóa ảnh, bạn cần sử dụng Admin API với API Secret
    // Package cloudinary_public không hỗ trợ xóa
    // Bạn có thể để ảnh trên Cloudinary hoặc implement Admin API
    print('Delete image với public ID: $publicId');
  }
}
