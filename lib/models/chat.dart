/// Model cho tin nhắn chat
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final String? imageUrl;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.imageUrl,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, String id) {
    return ChatMessage(
      id: id,
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'imageUrl': imageUrl,
    };
  }
}

/// Model cho phòng chat
class ChatRoom {
  final String id;
  final String name;
  final String type; // 'private' hoặc 'group'
  final List<String> memberIds;
  final Map<String, String> memberNames; // userId -> userName
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final String restaurantId;
  final DateTime createdAt;
  final Map<String, int> unreadCount; // userId -> unread count

  ChatRoom({
    required this.id,
    required this.name,
    required this.type,
    required this.memberIds,
    required this.memberNames,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    required this.restaurantId,
    required this.createdAt,
    this.unreadCount = const {},
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json, String id) {
    Map<String, String> memberNames = {};
    if (json['memberNames'] != null) {
      (json['memberNames'] as Map<dynamic, dynamic>).forEach((key, value) {
        memberNames[key.toString()] = value.toString();
      });
    }

    List<String> memberIds = [];
    if (json['memberIds'] != null) {
      memberIds = (json['memberIds'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();
    }

    Map<String, int> unreadCount = {};
    if (json['unreadCount'] != null) {
      (json['unreadCount'] as Map<dynamic, dynamic>).forEach((key, value) {
        unreadCount[key.toString()] = (value as num?)?.toInt() ?? 0;
      });
    }

    return ChatRoom(
      id: id,
      name: json['name'] ?? '',
      type: json['type'] ?? 'private',
      memberIds: memberIds,
      memberNames: memberNames,
      lastMessage: json['lastMessage'],
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.parse(json['lastMessageTime'])
          : null,
      lastMessageSenderId: json['lastMessageSenderId'],
      restaurantId: json['restaurantId'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      unreadCount: unreadCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'memberIds': memberIds,
      'memberNames': memberNames,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'lastMessageSenderId': lastMessageSenderId,
      'restaurantId': restaurantId,
      'createdAt': createdAt.toIso8601String(),
      'unreadCount': unreadCount,
    };
  }

  ChatRoom copyWith({
    String? id,
    String? name,
    String? type,
    List<String>? memberIds,
    Map<String, String>? memberNames,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    String? restaurantId,
    DateTime? createdAt,
    Map<String, int>? unreadCount,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      memberIds: memberIds ?? this.memberIds,
      memberNames: memberNames ?? this.memberNames,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      restaurantId: restaurantId ?? this.restaurantId,
      createdAt: createdAt ?? this.createdAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  /// Lấy tên hiển thị cho phòng chat (với chat private, hiển thị tên người kia)
  String getDisplayName(String currentUserId) {
    if (type == 'group') {
      return name;
    }
    // Với chat private, hiển thị tên của người còn lại
    for (var entry in memberNames.entries) {
      if (entry.key != currentUserId) {
        return entry.value;
      }
    }
    return name;
  }

  /// Lấy số tin nhắn chưa đọc của user
  int getUnreadCount(String userId) {
    return unreadCount[userId] ?? 0;
  }
}
