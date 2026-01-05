import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/chat.dart';
import '../models/user.dart';
import 'local_storage_service.dart';

class ChatService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final LocalStorageService _localStorageService = LocalStorageService();

  // Singleton pattern
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  /// Lấy danh sách tất cả nhân viên trong nhà hàng
  Future<List<UserModel>> getRestaurantStaff(String restaurantId) async {
    try {
      final snapshot = await _database.ref('users').once();
      if (snapshot.snapshot.value == null) return [];

      final usersMap = snapshot.snapshot.value as Map<dynamic, dynamic>;
      List<UserModel> staffList = [];

      usersMap.forEach((key, value) {
        final userData = Map<String, dynamic>.from(value as Map);
        if (userData['restaurantID'] == restaurantId && 
            userData['isActive'] == true) {
          staffList.add(UserModel.fromJson({...userData, 'uid': key}));
        }
      });

      return staffList;
    } catch (e) {
      print('Lỗi khi lấy danh sách nhân viên: $e');
      return [];
    }
  }

  /// Tạo hoặc lấy phòng chat private giữa 2 người
  Future<ChatRoom?> getOrCreatePrivateChat(
    String currentUserId,
    String currentUserName,
    String otherUserId,
    String otherUserName,
    String restaurantId,
  ) async {
    try {
      // Tạo ID phòng chat bằng cách sắp xếp 2 userId
      List<String> userIds = [currentUserId, otherUserId]..sort();
      String chatRoomId = 'private_${userIds[0]}_${userIds[1]}';

      // Kiểm tra xem phòng chat đã tồn tại chưa
      final snapshot = await _database.ref('chatRooms/$chatRoomId').once();
      
      if (snapshot.snapshot.value != null) {
        // Phòng chat đã tồn tại
        final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        return ChatRoom.fromJson(data, chatRoomId);
      }

      // Tạo phòng chat mới
      final chatRoom = ChatRoom(
        id: chatRoomId,
        name: '$currentUserName - $otherUserName',
        type: 'private',
        memberIds: [currentUserId, otherUserId],
        memberNames: {
          currentUserId: currentUserName,
          otherUserId: otherUserName,
        },
        restaurantId: restaurantId,
        createdAt: DateTime.now(),
        unreadCount: {currentUserId: 0, otherUserId: 0},
      );

      await _database.ref('chatRooms/$chatRoomId').set(chatRoom.toJson());
      
      return chatRoom;
    } catch (e) {
      print('Lỗi khi tạo/lấy phòng chat private: $e');
      return null;
    }
  }

  /// Tạo hoặc lấy nhóm chat mặc định của nhà hàng (tất cả nhân viên)
  Future<ChatRoom?> getOrCreateRestaurantGroupChat(String restaurantId) async {
    try {
      String groupChatId = 'group_$restaurantId';

      // Lấy danh sách nhân viên
      final staffList = await getRestaurantStaff(restaurantId);
      
      List<String> memberIds = staffList.map((u) => u.uid).toList();
      Map<String, String> memberNames = {};
      Map<String, int> unreadCount = {};
      
      for (var user in staffList) {
        memberNames[user.uid] = user.fullName;
        unreadCount[user.uid] = 0;
      }

      // Kiểm tra xem nhóm chat đã tồn tại chưa
      final snapshot = await _database.ref('chatRooms/$groupChatId').once();
      
      if (snapshot.snapshot.value != null) {
        // Cập nhật danh sách thành viên nếu có thay đổi
        final existingData = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        final existingRoom = ChatRoom.fromJson(existingData, groupChatId);
        
        // Cập nhật thành viên mới
        await _database.ref('chatRooms/$groupChatId').update({
          'memberIds': memberIds,
          'memberNames': memberNames,
        });
        
        return existingRoom.copyWith(
          memberIds: memberIds,
          memberNames: memberNames,
        );
      }

      // Tạo nhóm chat mới
      final chatRoom = ChatRoom(
        id: groupChatId,
        name: 'Nhóm nhà hàng',
        type: 'group',
        memberIds: memberIds,
        memberNames: memberNames,
        restaurantId: restaurantId,
        createdAt: DateTime.now(),
        unreadCount: unreadCount,
      );

      await _database.ref('chatRooms/$groupChatId').set(chatRoom.toJson());
      
      return chatRoom;
    } catch (e) {
      print('Lỗi khi tạo/lấy nhóm chat nhà hàng: $e');
      return null;
    }
  }

  /// Lấy danh sách các phòng chat của user
  Stream<List<ChatRoom>> getChatRoomsStream(String userId, String restaurantId) {
    return _database
        .ref('chatRooms')
        .orderByChild('restaurantId')
        .equalTo(restaurantId)
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return [];

      final roomsMap = event.snapshot.value as Map<dynamic, dynamic>;
      List<ChatRoom> rooms = [];

      roomsMap.forEach((key, value) {
        final roomData = Map<String, dynamic>.from(value as Map);
        final room = ChatRoom.fromJson(roomData, key.toString());
        
        // Chỉ lấy các phòng mà user là thành viên
        if (room.memberIds.contains(userId)) {
          rooms.add(room);
        }
      });

      // Sắp xếp theo tin nhắn mới nhất
      rooms.sort((a, b) {
        if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });

      return rooms;
    });
  }

  /// Gửi tin nhắn
  Future<bool> sendMessage(
    String chatRoomId,
    String senderId,
    String senderName,
    String content, {
    String? imageUrl,
  }) async {
    try {
      final messageRef = _database.ref('messages/$chatRoomId').push();
      final messageId = messageRef.key!;

      final message = ChatMessage(
        id: messageId,
        senderId: senderId,
        senderName: senderName,
        content: content,
        timestamp: DateTime.now(),
        imageUrl: imageUrl,
      );

      await messageRef.set(message.toJson());

      // Cập nhật thông tin tin nhắn cuối trong phòng chat
      await _database.ref('chatRooms/$chatRoomId').update({
        'lastMessage': content,
        'lastMessageTime': DateTime.now().toIso8601String(),
        'lastMessageSenderId': senderId,
      });

      // Tăng unread count cho các thành viên khác
      final roomSnapshot = await _database.ref('chatRooms/$chatRoomId').once();
      if (roomSnapshot.snapshot.value != null) {
        final roomData = Map<String, dynamic>.from(roomSnapshot.snapshot.value as Map);
        final room = ChatRoom.fromJson(roomData, chatRoomId);
        
        Map<String, int> newUnreadCount = Map.from(room.unreadCount);
        for (var memberId in room.memberIds) {
          if (memberId != senderId) {
            newUnreadCount[memberId] = (newUnreadCount[memberId] ?? 0) + 1;
          }
        }
        
        await _database.ref('chatRooms/$chatRoomId/unreadCount').set(newUnreadCount);
      }

      return true;
    } catch (e) {
      print('Lỗi khi gửi tin nhắn: $e');
      return false;
    }
  }

  /// Lấy stream tin nhắn của một phòng chat
  Stream<List<ChatMessage>> getMessagesStream(String chatRoomId) {
    return _database
        .ref('messages/$chatRoomId')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return [];

      final messagesMap = event.snapshot.value as Map<dynamic, dynamic>;
      List<ChatMessage> messages = [];

      messagesMap.forEach((key, value) {
        final messageData = Map<String, dynamic>.from(value as Map);
        messages.add(ChatMessage.fromJson(messageData, key.toString()));
      });

      // Sắp xếp theo thời gian
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return messages;
    });
  }

  /// Đánh dấu đã đọc tin nhắn
  Future<void> markAsRead(String chatRoomId, String userId) async {
    try {
      await _database.ref('chatRooms/$chatRoomId/unreadCount/$userId').set(0);
    } catch (e) {
      print('Lỗi khi đánh dấu đã đọc: $e');
    }
  }

  /// Lấy tổng số tin nhắn chưa đọc của user
  Stream<int> getTotalUnreadCount(String userId, String restaurantId) {
    return getChatRoomsStream(userId, restaurantId).map((rooms) {
      int total = 0;
      for (var room in rooms) {
        total += room.getUnreadCount(userId);
      }
      return total;
    });
  }

  /// Xóa tin nhắn (chỉ cho phép xóa tin nhắn của chính mình)
  Future<bool> deleteMessage(String chatRoomId, String messageId, String userId) async {
    try {
      final messageSnapshot = await _database
          .ref('messages/$chatRoomId/$messageId')
          .once();
      
      if (messageSnapshot.snapshot.value == null) return false;
      
      final messageData = Map<String, dynamic>.from(messageSnapshot.snapshot.value as Map);
      if (messageData['senderId'] != userId) {
        return false; // Không được xóa tin nhắn của người khác
      }

      await _database.ref('messages/$chatRoomId/$messageId').remove();
      return true;
    } catch (e) {
      print('Lỗi khi xóa tin nhắn: $e');
      return false;
    }
  }

  /// Lấy thông tin user theo ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final snapshot = await _database.ref('users/$userId').once();
      if (snapshot.snapshot.value == null) return null;

      final userData = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
      return UserModel.fromJson({...userData, 'uid': userId});
    } catch (e) {
      print('Lỗi khi lấy thông tin user: $e');
      return null;
    }
  }
}
