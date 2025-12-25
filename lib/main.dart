import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'page/auth/signup_page.dart';
import 'page/auth/login_page.dart';
import 'page/shared/home_page.dart';
import 'page/admin/admin_page.dart';
import 'page/owner/owner_page.dart';
import 'page/kitchen/kitchen_page.dart';
import 'page/order/order_page.dart';
import 'services/local_storage_service.dart';

Future<void>main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Khởi tạo LocalStorageService
  await LocalStorageService.init();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Bật logging để debug
  FirebaseDatabase.instance.setLoggingEnabled(true);
  
  print('✓ Firebase App initialized successfully');
  print('Database URL: ${DefaultFirebaseOptions.currentPlatform.databaseURL}');
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản Lý Nhà Hàng',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const HomePage(),
        '/admin': (context) => const AdminPage(),
        '/owner': (context) => const OwnerPage(),
        '/kitchen': (context) => const KitchenPage(),
        '/order': (context) => const OrderPage(),
      },
    );
  }
}
