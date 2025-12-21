import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'page/signup_page.dart';
import 'page/login_page.dart';
import 'page/home_page.dart';
import 'page/admin_page.dart';
import 'page/owner_page.dart';
import 'page/manager_page.dart';
import 'page/kitchen_page.dart';
import 'page/cashier_page.dart';
import 'page/order_page.dart';
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
        '/manager': (context) => const ManagerPage(),
        '/kitchen': (context) => const KitchenPage(),
        '/cashier': (context) => const CashierPage(),
        '/order': (context) => const OrderPage(),
      },
    );
  }
}
