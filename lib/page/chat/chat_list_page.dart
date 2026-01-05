import 'package:flutter/material.dart';
import '../../models/chat.dart';
import '../../models/user.dart';
import '../../services/chat_service.dart';
import '../../services/local_storage_service.dart';
import 'chat_detail_page.dart';

/// Trang danh sách chat - hiển thị tất cả các cuộc trò chuyện
class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatService _chatService = ChatService();
  final LocalStorageService _localStorageService = LocalStorageService();
  
  String? _currentUserId;
  String? _currentUserName;
  String? _restaurantId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userId = _localStorageService.getUserId();
    final userName = _localStorageService.getUserName();
    final restaurantId = _localStorageService.getRestaurantId();

    setState(() {
      _currentUserId = userId;
      _currentUserName = userName;
      _restaurantId = restaurantId;
      _isLoading = false;
    });

    // Tạo/cập nhật nhóm chat mặc định của nhà hàng
    if (restaurantId != null) {
      await _chatService.getOrCreateRestaurantGroupChat(restaurantId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat nội bộ'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'Bắt đầu chat mới',
            onPressed: _showNewChatDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _restaurantId == null
              ? _buildNoRestaurantView()
              : _buildChatList(),
    );
  }

  Widget _buildNoRestaurantView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Bạn chưa thuộc nhà hàng nào',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vui lòng liên hệ quản lý để được thêm vào nhà hàng',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return StreamBuilder<List<ChatRoom>>(
      stream: _chatService.getChatRoomsStream(_currentUserId!, _restaurantId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Đã xảy ra lỗi: ${snapshot.error}'),
              ],
            ),
          );
        }

        final chatRooms = snapshot.data ?? [];

        if (chatRooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Chưa có cuộc trò chuyện nào',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _showNewChatDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Bắt đầu chat mới'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadUserData,
          child: ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              final room = chatRooms[index];
              return _buildChatRoomTile(room);
            },
          ),
        );
      },
    );
  }

  Widget _buildChatRoomTile(ChatRoom room) {
    final displayName = room.getDisplayName(_currentUserId!);
    final unreadCount = room.getUnreadCount(_currentUserId!);
    final isGroup = room.type == 'group';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isGroup ? Colors.deepPurple : Colors.blue,
        child: Icon(
          isGroup ? Icons.group : Icons.person,
          color: Colors.white,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              style: TextStyle(
                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isGroup)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.deepPurple[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Nhóm',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.deepPurple[700],
                ),
              ),
            ),
        ],
      ),
      subtitle: room.lastMessage != null
          ? Text(
              room.lastMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
              ),
            )
          : Text(
              'Chưa có tin nhắn',
              style: TextStyle(
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (room.lastMessageTime != null)
            Text(
              _formatTime(room.lastMessageTime!),
              style: TextStyle(
                fontSize: 12,
                color: unreadCount > 0 ? Colors.deepPurple : Colors.grey[500],
              ),
            ),
          const SizedBox(height: 4),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () => _openChatDetail(room),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Hôm qua';
    } else if (diff.inDays < 7) {
      const days = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
      return days[time.weekday % 7];
    } else {
      return '${time.day}/${time.month}';
    }
  }

  void _openChatDetail(ChatRoom room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailPage(
          chatRoom: room,
          currentUserId: _currentUserId!,
          currentUserName: _currentUserName ?? 'Người dùng',
        ),
      ),
    );
  }

  void _showNewChatDialog() async {
    if (_restaurantId == null) return;

    final staffList = await _chatService.getRestaurantStaff(_restaurantId!);
    
    // Lọc bỏ user hiện tại
    final otherStaff = staffList.where((u) => u.uid != _currentUserId).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bắt đầu cuộc trò chuyện mới',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: otherStaff.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 60, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Không có nhân viên khác trong nhà hàng',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: otherStaff.length,
                      itemBuilder: (context, index) {
                        final user = otherStaff[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getRoleColor(user.role),
                            child: Text(
                              user.fullName.isNotEmpty 
                                  ? user.fullName[0].toUpperCase() 
                                  : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(user.fullName),
                          subtitle: Text(_getRoleDisplayName(user.role)),
                          onTap: () => _startPrivateChat(user),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return Colors.purple;
      case 'KITCHEN':
        return Colors.orange;
      case 'ORDER':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return 'Chủ nhà hàng';
      case 'KITCHEN':
        return 'Nhân viên bếp';
      case 'ORDER':
        return 'Nhân viên order';
      case 'ADMIN':
        return 'Quản trị viên';
      default:
        return role;
    }
  }

  Future<void> _startPrivateChat(UserModel otherUser) async {
    Navigator.pop(context); // Đóng bottom sheet

    final chatRoom = await _chatService.getOrCreatePrivateChat(
      _currentUserId!,
      _currentUserName ?? 'Người dùng',
      otherUser.uid,
      otherUser.fullName,
      _restaurantId!,
    );

    if (chatRoom != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(
            chatRoom: chatRoom,
            currentUserId: _currentUserId!,
            currentUserName: _currentUserName ?? 'Người dùng',
          ),
        ),
      );
    }
  }
}
