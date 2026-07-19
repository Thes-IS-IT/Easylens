import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/colors.dart';
import '../../services/firebase_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../../utils/app_route.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firebaseService = FirebaseService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('remember_me') ?? false;
      if (remember) {
        setState(() {
          _rememberMe = true;
          _emailController.text = prefs.getString('saved_email') ?? '';
          _passwordController.text = prefs.getString('saved_password') ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = "Please enter both email and password.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _firebaseService.signIn(email, password);
      if (user != null) {
        // Save or clear credentials based on Remember Me toggle state
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setBool('remember_me', true);
          await prefs.setString('saved_email', email);
          await prefs.setString('saved_password', password);
        } else {
          await prefs.remove('remember_me');
          await prefs.remove('saved_email');
          await prefs.remove('saved_password');
        }

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            AppRoute.to(const DashboardScreen()),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'Incorrect email or password. Please try again.';
          break;
        case 'invalid-email':
          msg = 'The email address format is invalid.';
          break;
        case 'user-disabled':
          msg = 'This account has been disabled. Please contact support.';
          break;
        case 'too-many-requests':
          msg = 'Too many failed login attempts. Please try again later.';
          break;
        case 'network-request-failed':
          msg = 'Network error. Please check your internet connection.';
          break;
        default:
          msg = 'Incorrect email or password. Please try again.';
      }
      if (mounted) {
        setState(() {
          _errorMessage = msg;
          _isLoading = false;
        });
      }
    } catch (e) {
      String errStr = e.toString().toLowerCase();
      String msg;
      if (errStr.contains('user-not-found') ||
          errStr.contains('wrong-password') ||
          errStr.contains('invalid-credential') ||
          errStr.contains('credential') ||
          errStr.contains('password')) {
        msg = 'Incorrect email or password. Please try again.';
      } else if (errStr.contains('invalid-email') || errStr.contains('email')) {
        msg = 'The email address format is invalid.';
      } else if (errStr.contains('network') || errStr.contains('socketexception')) {
        msg = 'Network connection issue. Please check your connection.';
      } else {
        msg = 'Incorrect email or password. Please try again.';
      }
      if (mounted) {
        setState(() {
          _errorMessage = msg;
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: GoogleFonts.inter(
        fontSize: 16,
        color: AppColors.primaryText,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          color: const Color(0xFF94A3B8).withOpacity(0.8),
          fontSize: 16,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          borderRadius: BorderRadius.circular(20.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF002663), width: 2.0),
          borderRadius: BorderRadius.circular(20.0),
        ),
        suffixIcon: isPassword
            ? Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: const Color(0xFF94A3B8),
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildRememberMeToggle() {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Remember Me',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF002663),
            ),
          ),
          Switch(
            value: _rememberMe,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF002663),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE2E8F0),
            onChanged: (val) {
              setState(() {
                _rememberMe = val;
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: Stack(
        children: [
          // Scrollable login form content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.primaryButton),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Space to clear the floating Back button
                        const SizedBox(height: 135),
                        
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Log In',
                                  style: GoogleFonts.inter(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF002663),
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Enter your email and password to sign in.',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    color: AppColors.textMuted,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                
                                if (_errorMessage != null) ...[
                                  Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                
                                _buildTextField(
                                  controller: _emailController,
                                  hintText: 'Email',
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _passwordController,
                                  hintText: 'Password',
                                  obscureText: _obscurePassword,
                                  isPassword: true,
                                ),
                                const SizedBox(height: 24),
                                _buildRememberMeToggle(),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                        
                        // Action Sign In Button
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF002663),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28.0),
                                ),
                              ),
                              onPressed: _handleLogin,
                              child: Text(
                                'Sign In',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          
          // Absolute Positioned Floating Back Button
          Positioned(
            top: 75.0,
            left: 24.0,
            child: SizedBox(
              width: 95.0,
              height: 44.0,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    border: Border.all(color: AppColors.cardBorder, width: 1.5),
                    borderRadius: BorderRadius.circular(30.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowColor,
                        blurRadius: 10.0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chevron_left,
                        size: 20,
                        color: AppColors.primaryText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Back',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
