import 'dart:ui';
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

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firebaseService = FirebaseService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _loginSuccess = false;

  // Focus tracking for mascot interaction
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _isAnyFieldFocused = false;

  // ── Animation Controllers ──
  late AnimationController _entranceController;
  late AnimationController _buttonPressController;
  late AnimationController _errorSlideController;

  // Staggered entrance animations
  late Animation<double> _heroScale;
  late Animation<double> _heroFade;
  late Animation<Offset> _emailSlide;
  late Animation<double> _emailFade;
  late Animation<Offset> _passwordSlide;
  late Animation<double> _passwordFade;
  late Animation<Offset> _rememberSlide;
  late Animation<double> _rememberFade;
  late Animation<Offset> _signInSlide;
  late Animation<double> _signInFade;
  late Animation<double> _orFade;
  late Animation<Offset> _googleSlide;
  late Animation<double> _googleFade;

  // Button press animation
  late Animation<double> _buttonScale;

  // Error slide animation
  late Animation<Offset> _errorSlide;
  late Animation<double> _errorFade;

  // Mascot speech bubble state
  late _BuddyMessage _currentMessage;
  bool _isBubbleExpanded = false;

  late Animation<double> _bubbleScale;
  late Animation<double> _bubbleFade;

  @override
  void initState() {
    super.initState();
    _currentMessage = (_buddyMessages..shuffle()).first;
    _loadSavedCredentials();
    _setupFocusListeners();
    _initAnimations();
  }

  void _setupFocusListeners() {
    _emailFocus.addListener(_onFocusChange);
    _passwordFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    final focused = _emailFocus.hasFocus || _passwordFocus.hasFocus;
    if (focused != _isAnyFieldFocused) {
      setState(() {
        _isAnyFieldFocused = focused;
      });
    }
  }

  void _initAnimations() {
    // Master entrance controller (1200ms total timeline)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Hero mascot: 0ms–600ms, scale 0.8→1.0 + fade
    _heroScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );
    _heroFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Email field: 300ms–700ms
    _emailSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.25, 0.58, curve: Curves.easeOutCubic),
      ),
    );
    _emailFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
      ),
    );

    // Password field: 400ms–800ms
    _passwordSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.33, 0.67, curve: Curves.easeOutCubic),
      ),
    );
    _passwordFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.33, 0.62, curve: Curves.easeOut),
      ),
    );

    // Remember me: 500ms–900ms
    _rememberSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.42, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _rememberFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.42, 0.7, curve: Curves.easeOut),
      ),
    );

    // Sign In button: 600ms–1000ms
    _signInSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.5, 0.83, curve: Curves.easeOutCubic),
      ),
    );
    _signInFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.5, 0.78, curve: Curves.easeOut),
      ),
    );

    // OR divider: 700ms–1000ms
    _orFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.58, 0.83, curve: Curves.easeOut),
      ),
    );

    // Google button: 800ms–1200ms
    _googleSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.67, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _googleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.67, 0.92, curve: Curves.easeOut),
      ),
    );

    // Button press scale
    _buttonPressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _buttonScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _buttonPressController, curve: Curves.easeInOut),
    );

    // Error slide-in
    _errorSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _errorSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _errorSlideController, curve: Curves.easeOutCubic),
    );
    _errorFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _errorSlideController, curve: Curves.easeOut),
    );

    // Staggered speech bubble entrance
    _bubbleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.75, curve: Curves.easeOutBack),
      ),
    );
    _bubbleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.65, curve: Curves.easeOut),
      ),
    );

    // Start entrance animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.removeListener(_onFocusChange);
    _passwordFocus.removeListener(_onFocusChange);
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _entranceController.dispose();
    _buttonPressController.dispose();
    _errorSlideController.dispose();
    super.dispose();
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

  void _showError(String msg) {
    if (mounted) {
      setState(() {
        _errorMessage = msg;
        _isLoading = false;
      });
      _errorSlideController.forward(from: 0.0);
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError("Please enter both email and password.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _firebaseService.signIn(email, password);
      if (user != null) {
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
          setState(() {
            _loginSuccess = true;
            _isLoading = false;
          });
          Navigator.of(context).pushAndRemoveUntil(
            AppRoute.rocketLaunch(const DashboardScreen()),
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
      _showError(msg);
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
      _showError(msg);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _firebaseService.signInWithGoogle();
      if (user != null && mounted) {
        setState(() {
          _loginSuccess = true;
          _isLoading = false;
        });
        Navigator.of(context).pushAndRemoveUntil(
          AppRoute.rocketLaunch(const DashboardScreen()),
          (route) => false,
        );
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().replaceAll(RegExp(r'^(Exception|PlatformException):\s*'), '');
        _showError(
          errStr.contains('10') || errStr.contains('sign_in_failed')
              ? 'Google Sign-In is unavailable on this device build (Developer Code 10). Please sign in using your Email.'
              : errStr,
        );
      }
    }
  }

  // ── Determine which mascot GIF to display ──
  String get _activeMascotAsset {
    if (_loginSuccess) return 'assets/Mascots/01 Happy.gif';
    if (_isLoading) return 'assets/Mascots/03 Loading.gif';
    if (_errorMessage != null) return 'assets/Mascots/02 Error.gif';
    if (_isAnyFieldFocused) return 'assets/Mascots/06 Thinking.gif';
    return 'assets/Mascots/05 Welcome.gif';
  }

  // ═══════════════════════════════════════════════
  //  WIDGET BUILDERS
  // ═══════════════════════════════════════════════

  Widget _buildHeroSection() {
    // Determine gradient colors based on theme
    final bool isDarkTheme = AppColors.primaryBackground == Colors.black;
    final gradientColors = isDarkTheme
        ? [const Color(0xFF0A0A0A), const Color(0xFF1A1A2E)]
        : [const Color(0xFF00205B), const Color(0xFF0F3E8F)];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Bar: Back button + Title & Tagline
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back_ios_new, size: 13, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              'Back',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BUDDY',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2.0,
                          ),
                        ),
                        Text(
                          _loginSuccess
                              ? 'Welcome back! Logging you in...'
                              : 'Sign in to continue',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Mascot & Speech Bubble Row (Bigger mascot sitting on top of white card)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Left Side: Bigger Mascot GIF sitting on top of white card
                    ScaleTransition(
                      scale: _heroScale,
                      child: FadeTransition(
                        opacity: _heroFade,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: Image.asset(
                            _activeMascotAsset,
                            key: ValueKey(_activeMascotAsset),
                            fit: BoxFit.contain,
                            height: 145,
                            errorBuilder: (_, __, ___) => Image.asset(
                              'assets/Mascots/App Logo.png',
                              fit: BoxFit.contain,
                              height: 145,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Middle: Solid white speech bubble pointer triangle
                    ScaleTransition(
                      scale: _bubbleScale,
                      child: FadeTransition(
                        opacity: _bubbleFade,
                        child: Transform.translate(
                          offset: const Offset(4, -32),
                          child: Transform.rotate(
                            angle: 3.14159 / 4, // 45 degrees
                            child: Container(
                              width: 12,
                              height: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    // Right Side: Clean White Speech Bubble Card
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: ScaleTransition(
                          scale: _bubbleScale,
                          child: FadeTransition(
                            opacity: _bubbleFade,
                            child: _buildSpeechBubble(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool isPassword = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: focusNode.hasFocus
            ? [
                BoxShadow(
                  color: AppColors.primaryButton.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
        cursorColor: AppColors.primaryButton,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryText,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(
            color: AppColors.textMuted.withValues(alpha: 0.7),
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          filled: true,
          fillColor: AppColors.lightBackground,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 10),
            child: Icon(
              prefixIcon,
              size: 20,
              color: focusNode.hasFocus
                  ? AppColors.primaryButton
                  : AppColors.textMuted.withValues(alpha: 0.6),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 46),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: AppColors.cardBorder.withValues(alpha: 0.15),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: AppColors.primaryButton.withValues(alpha: 0.6),
              width: 2.0,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          suffixIcon: isPassword
              ? Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: child,
                      ),
                      child: Icon(
                        obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        key: ValueKey(obscureText),
                        color: AppColors.textMuted,
                        size: 20,
                      ),
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
      ),
    );
  }

  Widget _buildRememberMeToggle() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: AppColors.cardBorder.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 18,
                color: _rememberMe
                    ? AppColors.primaryButton
                    : AppColors.textMuted.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 10),
              Text(
                'Keep me signed in',
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
          Switch(
            value: _rememberMe,
            activeThumbColor: AppColors.primaryButtonText,
            activeTrackColor: AppColors.primaryButton,
            inactiveThumbColor: AppColors.primaryText.withValues(alpha: 0.5),
            inactiveTrackColor: AppColors.unselectedBorder,
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

  Widget _buildSignInButton() {
    final bool isDarkTheme = AppColors.primaryBackground == Colors.black;
    final gradientColors = isDarkTheme
        ? [AppColors.primaryButton, AppColors.primaryButton]
        : [const Color(0xFF002663), const Color(0xFF0F3E8F)];

    return GestureDetector(
      onTapDown: (_) => _buttonPressController.forward(),
      onTapUp: (_) {
        _buttonPressController.reverse();
        if (!_isLoading && !_loginSuccess) _handleLogin();
      },
      onTapCancel: () => _buttonPressController.reverse(),
      child: AnimatedBuilder(
        animation: _buttonScale,
        builder: (context, child) {
          return Transform.scale(
            scale: _buttonScale.value,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: _loginSuccess
                ? const LinearGradient(colors: [Color(0xFF16A34A), Color(0xFF22C55E)])
                : LinearGradient(colors: gradientColors),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (_loginSuccess
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF002663))
                    .withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _loginSuccess
                  ? const Row(
                      key: ValueKey('success'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Success!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : _isLoading
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Sign in',
                          key: const ValueKey('signin'),
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: (!_isLoading && !_loginSuccess) ? _handleGoogleLogin : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.lightBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.cardBorder.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google "G" multi-color icon container
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  'G',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF4285F4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    if (_errorMessage == null) return const SizedBox.shrink();

    return SlideTransition(
      position: _errorSlide,
      child: FadeTransition(
        opacity: _errorFade,
        child: GestureDetector(
          onTap: () {
            _errorSlideController.reverse();
            Future.delayed(const Duration(milliseconds: 350), () {
              if (mounted) {
                setState(() {
                  _errorMessage = null;
                });
              }
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.red.shade100,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Left red accent line
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/Mascots/02 Error.gif',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.inter(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
                Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.red.shade300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: Stack(
        children: [
          // Main content: Hero + Form Sheet
          Column(
            children: [
              // ── GRADIENT HERO ZONE ──
              _buildHeroSection(),

              // ── WHITE FORM SHEET (overlaps hero by ~20px) ──
              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryBackground,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Error card (animated)
                            _buildErrorCard(),

                            // Email field
                            SlideTransition(
                              position: _emailSlide,
                              child: FadeTransition(
                                opacity: _emailFade,
                                child: _buildPremiumTextField(
                                  controller: _emailController,
                                  focusNode: _emailFocus,
                                  hintText: 'Email address',
                                  prefixIcon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Password field
                            SlideTransition(
                              position: _passwordSlide,
                              child: FadeTransition(
                                opacity: _passwordFade,
                                child: _buildPremiumTextField(
                                  controller: _passwordController,
                                  focusNode: _passwordFocus,
                                  hintText: 'Password',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  isPassword: true,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Remember me
                            SlideTransition(
                              position: _rememberSlide,
                              child: FadeTransition(
                                opacity: _rememberFade,
                                child: _buildRememberMeToggle(),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Sign In button
                            SlideTransition(
                              position: _signInSlide,
                              child: FadeTransition(
                                opacity: _signInFade,
                                child: _buildSignInButton(),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // OR divider
                            FadeTransition(
                              opacity: _orFade,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: AppColors.cardBorder.withValues(alpha: 0.15),
                                      thickness: 1.5,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'OR',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textMuted.withValues(alpha: 0.5),
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: AppColors.cardBorder.withValues(alpha: 0.15),
                                      thickness: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Google button
                            SlideTransition(
                              position: _googleSlide,
                              child: FadeTransition(
                                opacity: _googleFade,
                                child: _buildGoogleButton(),
                              ),
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Blur overlay during loading ──
          if (_isLoading)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: AnimatedOpacity(
                  opacity: _isLoading ? 0.4 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpeechBubble() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isBubbleExpanded = !_isBubbleExpanded;
        });
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 290),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Buddy',
                style: GoogleFonts.inter(
                  color: const Color(0xFF002663),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _currentMessage.shortText,
                style: GoogleFonts.inter(
                  color: const Color(0xFF4A5568),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              if (_isBubbleExpanded) ...[
                const SizedBox(height: 8),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 8),
                Text(
                  _currentMessage.expandedText,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF4A5568),
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BuddyMessage {
  final String shortText;
  final String expandedText;
  final IconData icon;

  const _BuddyMessage({
    required this.shortText,
    required this.expandedText,
    required this.icon,
  });
}

final List<_BuddyMessage> _buddyMessages = [
  const _BuddyMessage(
    shortText: "Woof! Tap any field to start!",
    expandedText: "I'll watch you type. If you get stuck, remember you can save your credentials to log in faster next time!",
    icon: Icons.keyboard_rounded,
  ),
  const _BuddyMessage(
    shortText: "I'm ready to assist you!",
    expandedText: "Once you log in, I can guide you with real-time obstacle avoidance and Tagalog voice commands!",
    icon: Icons.assistant_navigation,
  ),
  const _BuddyMessage(
    shortText: "Need help? Tap me!",
    expandedText: "Tip: EasyLens uses AI to detect hazards like fire, vehicles, and stairs, and tells you which way to move!",
    icon: Icons.help_outline_rounded,
  ),
  const _BuddyMessage(
    shortText: "Welcome back, friend!",
    expandedText: "Double-tap cards on the home screen to activate voice feedback instantly. Safety first!",
    icon: Icons.pets_rounded,
  ),
];

