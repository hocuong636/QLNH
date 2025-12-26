import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  final TextEditingController _taxRateController = TextEditingController();
  final TextEditingController _currencyController = TextEditingController();
  final TextEditingController _notificationTitleController =
      TextEditingController();
  final TextEditingController _notificationMessageController =
      TextEditingController();

  Map<String, dynamic> _settings = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _taxRateController.dispose();
    _currencyController.dispose();
    _notificationTitleController.dispose();
    _notificationMessageController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL:
            'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

      final snapshot = await database.ref('system_settings').get();

      if (snapshot.exists) {
        final data = snapshot.value;
        if (data is Map<dynamic, dynamic>) {
          setState(() {
            _settings = Map<String, dynamic>.from(data);
            _taxRateController.text = (_settings['taxRate'] ?? 0.0).toString();
            _currencyController.text = _settings['currency'] ?? 'VND';
          });
        } else {
          // Handle case where data is not a Map (e.g., it's a primitive value or null)
          print('Warning: system_settings data is not a Map, using defaults');
          setState(() {
            _settings = {
              'taxRate': 0.0,
              'currency': 'VND',
              'notifications': [],
            };
            _taxRateController.text = '0.0';
            _currencyController.text = 'VND';
          });
        }
      } else {
        // Default settings if no data exists
        setState(() {
          _settings = {'taxRate': 0.0, 'currency': 'VND', 'notifications': []};
          _taxRateController.text = '0.0';
          _currencyController.text = 'VND';
        });
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading settings: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải cài đặt hệ thống: $e')));
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL:
            'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

      final updatedSettings = {
        ..._settings,
        'taxRate': double.tryParse(_taxRateController.text) ?? 0.0,
        'currency': _currencyController.text,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await database.ref('system_settings').set(updatedSettings);

      setState(() {
        _settings = updatedSettings;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lưu cài đặt thành công')));
      }
    } catch (e) {
      print('Error saving settings: $e');
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi lưu cài đặt: $e')));
      }
    }
  }

  Future<void> _sendSystemNotification() async {
    if (_notificationTitleController.text.isEmpty ||
        _notificationMessageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng điền đầy đủ tiêu đề và nội dung thông báo'),
        ),
      );
      return;
    }

    try {
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL:
            'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

      final notification = {
        'title': _notificationTitleController.text,
        'message': _notificationMessageController.text,
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'system',
      };

      // Add to notifications list
      final notifications = List<Map<String, dynamic>>.from(
        _settings['notifications'] ?? [],
      );
      notifications.insert(0, notification); // Add to beginning

      // Keep only last 50 notifications
      if (notifications.length > 50) {
        notifications.removeRange(50, notifications.length);
      }

      await database.ref('system_settings/notifications').set(notifications);

      // Clear form
      _notificationTitleController.clear();
      _notificationMessageController.clear();

      setState(() {
        _settings['notifications'] = notifications;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gửi thông báo thành công')),
        );
        Navigator.of(context).pop(); // Close dialog
      }
    } catch (e) {
      print('Error sending notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi gửi thông báo: $e')));
      }
    }
  }

  void _showSendNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gửi thông báo hệ thống'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _notificationTitleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề thông báo *',
                  hintText: 'Cập nhật hệ thống',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notificationMessageController,
                decoration: const InputDecoration(
                  labelText: 'Nội dung thông báo *',
                  hintText: 'Thông báo về việc bảo trì hệ thống...',
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: _sendSystemNotification,
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt Hệ thống'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSettings,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tax and Currency Settings
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cấu hình Thuế & Tiền tệ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _taxRateController,
                            decoration: const InputDecoration(
                              labelText: 'Thuế suất (%)',
                              hintText: '10.0',
                              suffixText: '%',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _currencyController,
                            decoration: const InputDecoration(
                              labelText: 'Đơn vị tiền tệ',
                              hintText: 'VND',
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveSettings,
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Lưu cài đặt'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // System Notifications
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Thông báo Hệ thống',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _showSendNotificationDialog,
                                icon: const Icon(Icons.send),
                                label: const Text('Gửi thông báo'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if ((_settings['notifications'] as List?)?.isEmpty ??
                              true)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.notifications_none,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Chưa có thông báo nào',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount:
                                  (_settings['notifications'] as List).length,
                              itemBuilder: (context, index) {
                                final notification =
                                    (_settings['notifications'] as List)[index]
                                        as Map<String, dynamic>;
                                final timestamp = DateTime.parse(
                                  notification['timestamp'],
                                );

                                return ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.notifications),
                                  ),
                                  title: Text(notification['title'] ?? ''),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(notification['message'] ?? ''),
                                      Text(
                                        '${timestamp.toLocal().toString().split('.')[0]}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // System Information
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thông tin Hệ thống',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow('Phiên bản', '1.0.0'),
                          _buildInfoRow(
                            'Cập nhật cuối',
                            _settings['updatedAt'] != null
                                ? DateTime.parse(
                                    _settings['updatedAt'],
                                  ).toLocal().toString().split('.')[0]
                                : 'Chưa cập nhật',
                          ),
                          _buildInfoRow(
                            'Database URL',
                            'quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
