import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AvatarService {
  static const String _avatarDir = 'assets/avatars';

  // Tải avatar từ URL và lưu vào assets
  static Future<String?> downloadAndSaveAvatar({
    required String avatarUrl,
    required String userId,
  }) async {
    try {
      if (avatarUrl.isEmpty) return null;

      // Tạo thư mục nếu chưa tồn tại
      final appDir = await getApplicationDocumentsDirectory();
      final avatarDir = Directory('${appDir.path}/$_avatarDir');
      
      if (!await avatarDir.exists()) {
        await avatarDir.create(recursive: true);
      }

      // Tải ảnh từ URL
      final response = await http.get(Uri.parse(avatarUrl));
      
      if (response.statusCode == 200) {
        // Lấy phần mở rộng từ URL
        String fileName = '$userId.jpg';
        final file = File('${avatarDir.path}/$fileName');
        
        // Lưu ảnh vào file
        await file.writeAsBytes(response.bodyBytes);
        
        print('✓ Avatar saved: ${file.path}');
        return file.path;
      } else {
        print('✗ Failed to download avatar: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error downloading avatar: $e');
      return null;
    }
  }

  // Lấy đường dẫn avatar của user
  static Future<String?> getAvatarPath(String userId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$_avatarDir/$userId.jpg');
      
      if (await file.exists()) {
        return file.path;
      }
      return null;
    } catch (e) {
      print('Error getting avatar path: $e');
      return null;
    }
  }

  // Xóa avatar
  static Future<void> deleteAvatar(String userId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$_avatarDir/$userId.jpg');
      
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting avatar: $e');
    }
  }
}
