import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../services/local_storage_service.dart';
import '../chat/chat_list_page.dart';

/// Widget hiển thị icon chat với badge số tin nhắn chưa đọc
class ChatBadgeButton extends StatefulWidget {
  final Color? iconColor;
  
  const ChatBadgeButton({super.key, this.iconColor});

  @override
  State<ChatBadgeButton> createState() => _ChatBadgeButtonState();
}

class _ChatBadgeButtonState extends State<ChatBadgeButton> {
  final ChatService _chatService = ChatService();
  final LocalStorageService _localStorageService = LocalStorageService();
  
  String? _userId;
  String? _restaurantId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    _userId = _localStorageService.getUserId();
    _restaurantId = _localStorageService.getRestaurantId();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null || _restaurantId == null) {
      return IconButton(
        icon: Icon(Icons.chat_bubble_outline, color: widget.iconColor ?? Colors.black87),
        onPressed: () => _openChat(context),
        tooltip: 'Chat nội bộ',
      );
    }

    return StreamBuilder<int>(
      stream: _chatService.getTotalUnreadCount(_userId!, _restaurantId!),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                unreadCount > 0 ? Icons.chat_bubble : Icons.chat_bubble_outline,
                color: widget.iconColor ?? Colors.black87,
              ),
              onPressed: () => _openChat(context),
              tooltip: 'Chat nội bộ',
            ),
            if (unreadCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _openChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatListPage()),
    );
  }
}

/// Widget hiển thị tile chat trong drawer với badge
class ChatDrawerTile extends StatefulWidget {
  const ChatDrawerTile({super.key});

  @override
  State<ChatDrawerTile> createState() => _ChatDrawerTileState();
}

class _ChatDrawerTileState extends State<ChatDrawerTile> {
  final ChatService _chatService = ChatService();
  final LocalStorageService _localStorageService = LocalStorageService();
  
  String? _userId;
  String? _restaurantId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    _userId = _localStorageService.getUserId();
    _restaurantId = _localStorageService.getRestaurantId();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null || _restaurantId == null) {
      return ListTile(
        leading: Icon(Icons.chat_bubble_outline, color: Colors.deepPurple.shade600),
        title: const Text('Chat nội bộ'),
        subtitle: const Text('Nhắn tin với nhân viên', style: TextStyle(fontSize: 12)),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatListPage()),
          );
        },
      );
    }

    return StreamBuilder<int>(
      stream: _chatService.getTotalUnreadCount(_userId!, _restaurantId!),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        
        return ListTile(
          leading: Icon(Icons.chat_bubble_outline, color: Colors.deepPurple.shade600),
          title: Row(
            children: [
              const Text('Chat nội bộ'),
              if (unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
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
          subtitle: const Text('Nhắn tin với nhân viên', style: TextStyle(fontSize: 12)),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatListPage()),
            );
          },
        );
      },
    );
  }
}
