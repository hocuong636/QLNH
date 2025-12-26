import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';
import '../constants/user_roles.dart';
import 'local_storage_service.dart';
import 'avatar_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalStorageService _localStorageService = LocalStorageService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  // Getter để lấy database instance
  FirebaseDatabase get _database {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
    );
  }

  // Đăng ký user mới
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
  }) async {
    try {
      // Tạo account trên Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Lưu thông tin user vào Realtime Database
      await _database.ref('users/${userCredential.user!.uid}').set({
        'uid': userCredential.user!.uid,
        'email': email,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'role': UserRole.customer,
        'resID': null,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Lưu thông tin user vào Local Storage
      await _localStorageService.saveUserData(
        userId: userCredential.user!.uid,
        email: email,
        fullName: fullName,
        role: UserRole.customer,
        phoneNumber: phoneNumber,
        resID: null,
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw Exception('Mật khẩu quá yếu.');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('Email này đã được đăng ký.');
      }
      // Hiển thị rõ mã lỗi để dễ debug
      throw Exception('Đăng ký thất bại (${e.code}): ${e.message}');
    } catch (e) {
      print('Lỗi khi đăng ký: $e');
      throw Exception('Lỗi không xác định khi đăng ký: $e');
    }
  }

  // Đăng nhập
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('Bắt đầu đăng nhập với email: $email');
      
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('Đăng nhập thành công, user ID: ${userCredential.user?.uid}');

      // Lấy thông tin user từ database và lưu vào local storage
      if (userCredential.user != null) {
        try {
          DatabaseEvent event = await _database.ref('users/${userCredential.user!.uid}').once();
          Map<dynamic, dynamic> userData = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
          
          print('Lấy dữ liệu user thành công: $userData');
          
          await _localStorageService.saveUserData(
            userId: userCredential.user!.uid,
            email: email,
            fullName: userData['fullName'] ?? '',
            role: userData['role'] ?? UserRole.customer,
            phoneNumber: userData['phoneNumber'] ?? '',
            resID: userData['resID'],
          );
          
          // Lưu lịch sử đăng nhập
          try {
            await _database.ref('users/${userCredential.user!.uid}/loginHistory').push().set({
              'loginAt': DateTime.now().toIso8601String(),
              'method': 'email',
            });
          } catch (e) {
            print('Lỗi khi lưu lịch sử đăng nhập: $e');
          }
          
          print('Lưu dữ liệu vào local storage thành công');
        } catch (dbError) {
          print('Lỗi khi lấy dữ liệu từ database: $dbError');
          // Vẫn lưu email vào local storage nếu không lấy được dữ liệu
          await _localStorageService.saveUserData(
            userId: userCredential.user!.uid,
            email: email,
            fullName: '',
            role: UserRole.customer,
            phoneNumber: '',
            resID: null,
          );
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException code: ${e.code}');
      print('FirebaseAuthException message: ${e.message}');
      
      if (e.code == 'user-not-found') {
        throw Exception('User không tồn tại.');
      } else if (e.code == 'wrong-password') {
        throw Exception('Mật khẩu sai.');
      } else if (e.code == 'invalid-credential') {
        throw Exception('Email hoặc mật khẩu không chính xác.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Email không hợp lệ.');
      }
      throw Exception('Đăng nhập thất bại: ${e.message}');
    } catch (e) {
      print('Lỗi khi đăng nhập: $e');
      throw Exception('Lỗi không xác định khi đăng nhập: $e');
    }
  }

  // Đăng nhập bằng Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('Bắt đầu Google Sign-In');
      
      // Đăng xuất Google trước để chọn tài khoản mới
      await _googleSignIn.signOut();

      // Đăng nhập với Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Hủy đăng nhập Google');
      }

      print('Google Sign-In thành công: ${googleUser.email}');

      // Lấy authentication từ Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Tạo credential cho Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Đăng nhập vào Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        print('Firebase Sign-In thành công, user ID: ${user.uid}');
        
        // Kiểm tra xem user đã tồn tại trong database chưa
        DatabaseEvent event = await _database.ref('users/${user.uid}').once();
        bool userExists = event.snapshot.exists;
        
        String userRole = UserRole.customer; // Role mặc định là KHÁCH HÀNG
        String fullName = user.displayName ?? 'Google User';
        String phoneNumber = user.phoneNumber ?? '';
        String? resID;

        // Nếu user mới, lưu thông tin vào database
        if (!userExists) {
          print('User mới, lưu thông tin vào database');
          await _database.ref('users/${user.uid}').set({
            'uid': user.uid,
            'email': user.email,
            'fullName': fullName,
            'phoneNumber': phoneNumber,
            'photoUrl': user.photoURL ?? '',
            'role': userRole,
            'resID': null, // Mặc định null cho user mới
            'createdAt': DateTime.now().toIso8601String(),
          });
          resID = null;
        } else {
          // User đã tồn tại, lấy role từ database
          print('User đã tồn tại, lấy thông tin từ database');
          Map<dynamic, dynamic> userData = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
          userRole = userData['role'] ?? UserRole.customer;
          fullName = userData['fullName'] ?? fullName;
          phoneNumber = userData['phoneNumber'] ?? phoneNumber;
          resID = userData['resID'];
          print('Role của user: $userRole');
        }

        // Tải avatar từ Google
        if (user.photoURL != null && user.photoURL!.isNotEmpty) {
          print('Tải avatar từ Google');
          await AvatarService.downloadAndSaveAvatar(
            avatarUrl: user.photoURL!,
            userId: user.uid,
          );
        }

        // Lưu thông tin user vào local storage với role đúng
        await _localStorageService.saveUserData(
          userId: user.uid,
          email: user.email ?? '',
          fullName: fullName,
          role: userRole,
          phoneNumber: phoneNumber,
          resID: resID,
        );
        
        // Lưu lịch sử đăng nhập
        try {
          await _database.ref('users/${user.uid}/loginHistory').push().set({
            'loginAt': DateTime.now().toIso8601String(),
            'method': 'google',
          });
        } catch (e) {
          print('Lỗi khi lưu lịch sử đăng nhập: $e');
        }
        
        print('Lưu thông tin user vào local storage thành công với role: $userRole');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      if (e.code == 'invalid-credential') {
        throw Exception('Credential không hợp lệ. Vui lòng kiểm tra cấu hình Firebase.');
      }
      throw Exception('Đăng nhập Google thất bại: ${e.message}');
    } catch (e) {
      print('Error signing in with Google: $e');
      throw Exception('Lỗi khi đăng nhập Google: $e');
    }
  }

  // Đăng xuất
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      await _localStorageService.clearUserData();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // Lấy user hiện tại
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Stream để theo dõi trạng thái đăng nhập
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}