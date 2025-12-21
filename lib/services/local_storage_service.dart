import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static late SharedPreferences _prefs;
  
  // Keys for storing data
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _userRoleKey = 'user_role';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userPhoneKey = 'user_phone';

  // Initialize SharedPreferences
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Save user data
  Future<void> saveUserData({
    required String userId,
    required String email,
    required String fullName,
    required String role,
    required String phoneNumber,
  }) async {
    await Future.wait([
      _prefs.setString(_userIdKey, userId),
      _prefs.setString(_userEmailKey, email),
      _prefs.setString(_userNameKey, fullName),
      _prefs.setString(_userRoleKey, role),
      _prefs.setString(_userPhoneKey, phoneNumber),
      _prefs.setBool(_isLoggedInKey, true),
    ]);
  }

  // Get user ID
  String? getUserId() {
    return _prefs.getString(_userIdKey);
  }

  // Get user email
  String? getUserEmail() {
    return _prefs.getString(_userEmailKey);
  }

  // Get user name
  String? getUserName() {
    return _prefs.getString(_userNameKey);
  }

  // Get user role
  String? getUserRole() {
    return _prefs.getString(_userRoleKey);
  }

  // Get user phone
  String? getUserPhone() {
    return _prefs.getString(_userPhoneKey);
  }

  // Check if user is logged in
  bool isLoggedIn() {
    return _prefs.getBool(_isLoggedInKey) ?? false;
  }

  // Clear user data (logout)
  Future<void> clearUserData() async {
    await Future.wait([
      _prefs.remove(_userIdKey),
      _prefs.remove(_userEmailKey),
      _prefs.remove(_userNameKey),
      _prefs.remove(_userRoleKey),
      _prefs.remove(_userPhoneKey),
      _prefs.remove(_isLoggedInKey),
    ]);
  }

  // Save single preference
  Future<void> saveString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  // Get single preference
  String? getString(String key) {
    return _prefs.getString(key);
  }

  // Save boolean
  Future<void> saveBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  // Get boolean
  bool getBool(String key, {bool defaultValue = false}) {
    return _prefs.getBool(key) ?? defaultValue;
  }

  // Save int
  Future<void> saveInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  // Get int
  int getInt(String key, {int defaultValue = 0}) {
    return _prefs.getInt(key) ?? defaultValue;
  }

  // Clear all data
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
