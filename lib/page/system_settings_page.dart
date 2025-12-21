import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  FirebaseDatabase get _database {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
    );
  }
  
  DatabaseReference get _dbRef => _database.ref();
  
  final TextEditingController _currencyController = TextEditingController();
  final TextEditingController _timezoneController = TextEditingController();
  final TextEditingController _vatController = TextEditingController();
  String? _selectedCurrency;
  String? _selectedTimezone;
  double? _vatRate;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _currencyController.dispose();
    _timezoneController.dispose();
    _vatController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final snapshot = await _dbRef.child('systemSettings').get();
      if (snapshot.exists) {
        final settings = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _selectedCurrency = settings['currency'] ?? 'VND';
          _selectedTimezone = settings['timezone'] ?? 'Asia/Ho_Chi_Minh';
          _vatRate = settings['vatRate']?.toDouble() ?? 10.0;
          _currencyController.text = _selectedCurrency ?? 'VND';
          _timezoneController.text = _selectedTimezone ?? 'Asia/Ho_Chi_Minh';
          _vatController.text = _vatRate?.toString() ?? '10';
        });
      } else {
        // Set defaults
        setState(() {
          _selectedCurrency = 'VND';
          _selectedTimezone = 'Asia/Ho_Chi_Minh';
          _vatRate = 10.0;
          _currencyController.text = 'VND';
          _timezoneController.text = 'Asia/Ho_Chi_Minh';
          _vatController.text = '10';
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _dbRef.child('systemSettings').set({
        'currency': _selectedCurrency ?? 'VND',
        'timezone': _selectedTimezone ?? 'Asia/Ho_Chi_Minh',
        'vatRate': _vatRate ?? 10.0,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu cấu hình hệ thống!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showNotificationDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Gửi Thông Báo Hệ Thống'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Nội dung',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                titleController.dispose();
                messageController.dispose();
                Navigator.of(context).pop();
              },
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty || messageController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng điền đầy đủ thông tin'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  await _dbRef.child('systemNotifications').push().set({
                    'title': titleController.text.trim(),
                    'message': messageController.text.trim(),
                    'type': 'system',
                    'createdAt': DateTime.now().toIso8601String(),
                    'readBy': {},
                  });

                  titleController.dispose();
                  messageController.dispose();
                  Navigator.of(context).pop();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã gửi thông báo hệ thống!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Lỗi: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
              ),
              child: const Text('Gửi'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Text(
            'Cấu Hình Hệ Thống',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cấu hình toàn cục cho hệ thống',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 30),
          // Cấu hình chung
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cấu Hình Chung',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Tiền tệ mặc định',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'VND', child: Text('VND (Việt Nam Đồng)')),
                      DropdownMenuItem(value: 'USD', child: Text('USD (Đô la Mỹ)')),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR (Euro)')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCurrency = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedTimezone,
                    decoration: const InputDecoration(
                      labelText: 'Múi giờ',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Asia/Ho_Chi_Minh', child: Text('Asia/Ho_Chi_Minh (GMT+7)')),
                      DropdownMenuItem(value: 'UTC', child: Text('UTC (GMT+0)')),
                      DropdownMenuItem(value: 'Asia/Bangkok', child: Text('Asia/Bangkok (GMT+7)')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedTimezone = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _vatController,
                    decoration: const InputDecoration(
                      labelText: 'Thuế VAT (%)',
                      border: OutlineInputBorder(),
                      helperText: 'Nhập phần trăm VAT (ví dụ: 10)',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _vatRate = double.tryParse(value);
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Lưu Cấu Hình'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Thông báo hệ thống
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông Báo Hệ Thống',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Gửi thông báo đến tất cả người dùng trong hệ thống',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showNotificationDialog,
                      icon: const Icon(Icons.notifications),
                      label: const Text('Gửi Thông Báo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

