import 'package:flutter/material.dart';
import 'package:quanlynhahang/services/auth_service.dart';
import 'package:quanlynhahang/services/local_storage_service.dart';
import 'package:quanlynhahang/constants/user_roles.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  final LocalStorageService _localStorageService = LocalStorageService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  // Color constants matching the design
  static const Color _lightGreen = Color(0xFFE8F5E9);
  static const Color _darkGreen = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Load remembered email when page initializes
  void _loadRememberedEmail() {
    String? rememberedEmail = _localStorageService.getRememberMeEmail();
    if (rememberedEmail != null && rememberedEmail.isNotEmpty) {
      _emailController.text = rememberedEmail;
      setState(() {
        _rememberMe = true;
      });
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signInWithUsernameOrEmail(
        usernameOrEmail: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        // Lấy email thực tế từ local storage (đã được lưu sau khi đăng nhập thành công)
        String? actualEmail = _localStorageService.getUserEmail();
        
        // Lưu email nếu remember me được chọn
        if (_rememberMe && actualEmail != null) {
          await _localStorageService.saveRememberMeEmail(actualEmail);
        } else {
          // Xóa email đã lưu nếu không chọn remember me
          await _localStorageService.clearRememberMe();
        }

        // Lấy role từ local storage và điều hướng theo role
        String? userRole = _localStorageService.getUserRole();
        String route = UserRole.getRouteForRole(userRole);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng nhập thành công!')),
        );
        
        Navigator.of(context).pushReplacementNamed(route);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightGreen,
      body: Stack(
        children: [
          // Decorative circles
          _buildDecorativeCircles(),
          // Leaf decoration at top
          _buildLeafDecoration(),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    // Title
                    const Text(
                      'Welcome Back',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _darkGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Login to your Account',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 16,
                        color: _darkGreen,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildEmailField(),
                          const SizedBox(height: 20),
                          _buildPasswordField(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Remember me and Forget password
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) async {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                                // Nếu uncheck, xóa email đã lưu ngay lập tức
                                if (!_rememberMe) {
                                  await _localStorageService.clearRememberMe();
                                }
                              },
                              activeColor: _darkGreen,
                              checkColor: Colors.white,
                            ),
                            const Text(
                              'Remember me',
                              style: TextStyle(
                                color: _darkGreen,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tính năng quên mật khẩu sắp có'),
                              ),
                            );
                          },
                          child: const Text(
                            'Forget password?',
                            style: TextStyle(
                              color: _darkGreen,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    _buildLoginButton(),
                    const SizedBox(height: 30),
                    _buildDivider(),
                    const SizedBox(height: 20),
                    _buildSocialLogin(),
                    const SizedBox(height: 30),
                    _buildSignUpNavigation(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: InputDecoration(
        hintText: 'User Name / Mail',
        prefixIcon: const Icon(Icons.person_outline, color: _darkGreen),
        filled: true,
        fillColor: _lightGreen,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkGreen, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      keyboardType: TextInputType.text,
      style: const TextStyle(color: _darkGreen),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Vui lòng nhập username hoặc email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: InputDecoration(
        hintText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline, color: _darkGreen),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: _darkGreen,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        filled: true,
        fillColor: _lightGreen,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkGreen, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      obscureText: _obscurePassword,
      style: const TextStyle(color: _darkGreen),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Vui lòng nhập mật khẩu';
        }
        return null;
      },
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleLogin,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: _darkGreen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text(
              'Login',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
    );
  }

  Widget _buildDecorativeCircles() {
    return Stack(
      children: [
        Positioned(
          top: 100,
          right: -50,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _darkGreen.withOpacity(0.1),
            ),
          ),
        ),
        Positioned(
          top: 200,
          left: -30,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _darkGreen.withOpacity(0.15),
            ),
          ),
        ),
        Positioned(
          bottom: 150,
          right: 20,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _darkGreen.withOpacity(0.1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeafDecoration() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: CustomPaint(
        size: Size(MediaQuery.of(context).size.width, 100),
        painter: LeafPainter(),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signInWithGoogle();

      if (mounted) {
        // Lấy role từ local storage và điều hướng theo role
        String? userRole = _localStorageService.getUserRole();
        String route = UserRole.getRouteForRole(userRole);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng nhập Google thành công!')),
        );
        
        Navigator.of(context).pushReplacementNamed(route);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: _darkGreen.withOpacity(0.3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Or Continue with',
            style: TextStyle(
              color: _darkGreen.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: _darkGreen.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLogin() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildGoogleButton(),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: _lightGreen,
        shape: BoxShape.circle,
        border: Border.all(color: _darkGreen.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: _handleGoogleSignIn,
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Image.asset(
              'assets/images/google_logo.png',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpNavigation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have account? ",
          style: TextStyle(color: _darkGreen),
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const SignUpPage(),
            ));
          },
          child: const Text(
            'Sign up',
            style: TextStyle(
              color: _darkGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// Custom painter for leaf decoration
class LeafPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2E7D32).withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // Draw stylized leaves
    final path1 = Path()
      ..moveTo(size.width * 0.1, 0)
      ..quadraticBezierTo(size.width * 0.15, 20, size.width * 0.2, 40)
      ..quadraticBezierTo(size.width * 0.18, 60, size.width * 0.1, 80)
      ..quadraticBezierTo(size.width * 0.05, 60, size.width * 0.05, 40)
      ..quadraticBezierTo(size.width * 0.05, 20, size.width * 0.1, 0)
      ..close();

    final path2 = Path()
      ..moveTo(size.width * 0.3, 10)
      ..quadraticBezierTo(size.width * 0.35, 30, size.width * 0.4, 50)
      ..quadraticBezierTo(size.width * 0.38, 70, size.width * 0.3, 90)
      ..quadraticBezierTo(size.width * 0.25, 70, size.width * 0.25, 50)
      ..quadraticBezierTo(size.width * 0.25, 30, size.width * 0.3, 10)
      ..close();

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
