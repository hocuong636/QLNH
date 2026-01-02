import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final LocalStorageService _localStorageService = LocalStorageService();
  
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedActionFilter;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await _database.ref('audit_logs').get();
      final logs = <Map<String, dynamic>>[];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          data.forEach((key, value) {
            if (value is Map) {
              logs.add({
                'id': key,
                ...Map<String, dynamic>.from(value),
              });
            }
          });
        }
      }

      // Sort by timestamp descending (newest first)
      logs.sort((a, b) {
        final aTime = a['timestamp'] != null ? DateTime.parse(a['timestamp']) : DateTime(1970);
        final bTime = b['timestamp'] != null ? DateTime.parse(b['timestamp']) : DateTime(1970);
        return bTime.compareTo(aTime);
      });

      setState(() {
        _logs = logs;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading audit logs: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải nhật ký: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_logs);

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((log) {
        final query = _searchQuery.toLowerCase();
        return (log['userId']?.toString().toLowerCase().contains(query) ?? false) ||
            (log['userEmail']?.toString().toLowerCase().contains(query) ?? false) ||
            (log['action']?.toString().toLowerCase().contains(query) ?? false) ||
            (log['details']?.toString().toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Filter by action type
    if (_selectedActionFilter != null && _selectedActionFilter!.isNotEmpty) {
      filtered = filtered.where((log) => log['action'] == _selectedActionFilter).toList();
    }

    // Filter by date range
    if (_startDate != null) {
      filtered = filtered.where((log) {
        if (log['timestamp'] == null) return false;
        final logDate = DateTime.parse(log['timestamp']);
        return logDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
               (_endDate == null || logDate.isBefore(_endDate!.add(const Duration(days: 1))));
      }).toList();
    }

    setState(() {
      _filteredLogs = filtered;
    });
  }

  Future<void> _logAction(String action, String details, {String? targetId}) async {
    try {
      final userId = _localStorageService.getUserId() ?? 'system';
      final userEmail = _localStorageService.getUserEmail() ?? 'system@admin.com';
      
      final logEntry = {
        'userId': userId,
        'userEmail': userEmail,
        'action': action,
        'details': details,
        'targetId': targetId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _database.ref('audit_logs').push().set(logEntry);
    } catch (e) {
      print('Error logging action: $e');
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} ngày trước';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} giờ trước';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} phút trước';
      } else {
        return 'Vừa xong';
      }
    } catch (e) {
      return timestamp;
    }
  }

  Color _getActionColor(String? action) {
    switch (action) {
      case 'CREATE':
        return Colors.green;
      case 'UPDATE':
        return Colors.blue;
      case 'DELETE':
        return Colors.red;
      case 'LOGIN':
        return Colors.orange;
      case 'LOGOUT':
        return Colors.grey;
      default:
        return Colors.purple;
    }
  }

  IconData _getActionIcon(String? action) {
    switch (action) {
      case 'CREATE':
        return Icons.add_circle;
      case 'UPDATE':
        return Icons.edit;
      case 'DELETE':
        return Icons.delete;
      case 'LOGIN':
        return Icons.login;
      case 'LOGOUT':
        return Icons.logout;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      appBar: AppBar(
        title: const Text('Nhật ký Hệ thống'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAuditLogs,
            tooltip: 'Làm mới',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilters();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm theo user, action, details...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedActionFilter,
                  decoration: InputDecoration(
                    hintText: 'Tất cả hành động',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tất cả hành động')),
                    DropdownMenuItem(value: 'CREATE', child: Text('Tạo mới')),
                    DropdownMenuItem(value: 'UPDATE', child: Text('Cập nhật')),
                    DropdownMenuItem(value: 'DELETE', child: Text('Xóa')),
                    DropdownMenuItem(value: 'LOGIN', child: Text('Đăng nhập')),
                    DropdownMenuItem(value: 'LOGOUT', child: Text('Đăng xuất')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedActionFilter = value;
                      _applyFilters();
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredLogs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Chưa có nhật ký nào'
                            : 'Không tìm thấy nhật ký',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = _filteredLogs[index];
                    final action = log['action']?.toString() ?? 'UNKNOWN';
                    final actionColor = _getActionColor(action);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: actionColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getActionIcon(action),
                            color: actionColor,
                            size: 24,
                          ),
                        ),
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: actionColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                action,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: actionColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                log['details']?.toString() ?? 'No details',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text('User: ${log['userEmail'] ?? 'Unknown'}'),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(log['timestamp']?.toString()),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
}

