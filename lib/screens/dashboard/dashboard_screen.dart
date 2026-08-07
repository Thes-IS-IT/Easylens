import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../services/firebase_service.dart';
import '../../services/sound_service.dart';
import '../../constants/colors.dart';
import '../navigation/navigation_screen.dart';
import '../hardware/hardware_screen.dart';
import '../emergency/emergency_screen.dart';
import '../settings/settings_screen.dart';
import '../notifications/notifications_screen.dart';
import '../contacts/contacts_screen.dart';
import 'components/custom_navbar.dart';
import 'components/buddy_assistant_sheet.dart';
import 'components/header_bar.dart';
import 'components/weather_effects_overlay.dart';
import '../../widgets/interactive_tutorial_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../image_labeling/image_labeling_screen.dart';
import '../face_registration/face_registration_screen.dart';
import 'dashboard_home.dart';
import '../../utils/app_route.dart';
import '../../services/tts_service.dart';
import '../../services/settings_service.dart';
import '../../services/translation_service.dart';
import '../../services/undo_service.dart';
import '../../widgets/speech_navigation_overlay.dart';
import '../../services/rag_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static final ValueNotifier<bool> tutorialNotifier = ValueNotifier<bool>(false);

  static void triggerTutorial() {
    tutorialNotifier.value = true;
  }

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final _firebaseService = FirebaseService();
  late String _displayName;
  int _currentIndex = 0;

  // Fade-in animation for smooth dashboard entry
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Single unified smooth tab-transition controller
  late AnimationController _transitionController;
  bool _isTransitioning = false;
  bool _hasSwitchedTab = false;
  int _pendingIndex = 0;

  StreamSubscription? _accelerometerSubscription;
  int _lastShakeTime = 0;
  bool _isBuddySheetOpen = false;
  bool _showTutorial = false;
  bool _showWeatherEffect = true;

  final GlobalKey _buddyMascotKey = GlobalKey();
  final GlobalKey _easylensScanKey = GlobalKey();
  final GlobalKey _audioNavKey = GlobalKey();
  final GlobalKey _sosEmergencyKey = GlobalKey();
  final GlobalKey _settingsKey = GlobalKey();
  final GlobalKey _notificationsKey = GlobalKey();
  final GlobalKey _contactsKey = GlobalKey();
  final GlobalKey _buddyCardKey = GlobalKey();
  final GlobalKey _easylensCardKey = GlobalKey();
  final GlobalKey _facesCardKey = GlobalKey();
  final GlobalKey _textCardKey = GlobalKey();
  final GlobalKey _navigationCardKey = GlobalKey();
  final GlobalKey _sosCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Fade-in animation: 0 → 1 over 600ms with easeOut curve
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    // Single smooth transition controller synchronized with 3.24s spongebob bubble audio
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 3240),
      vsync: this,
    );

    _displayName = "User";
    _loadUserDisplayName();
    _checkTutorialStatus();
    _startShakeListening();



    SpeechNavigationNotifier.tabChangeNotifier.addListener(_onSpeechTabChange);
    SpeechNavigationNotifier.openBuddyNotifier.addListener(_onSpeechOpenBuddy);
    DashboardScreen.tutorialNotifier.addListener(_onTutorialTriggered);
  }

  void _onTutorialTriggered() {
    if (DashboardScreen.tutorialNotifier.value && mounted) {
      setState(() {
        _showTutorial = true;
        _currentIndex = 0;
      });
      DashboardScreen.tutorialNotifier.value = false;
    }
  }

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCompleted = prefs.getBool('has_completed_tutorial') ?? false;
    if (!hasCompleted && mounted) {
      setState(() {
        _showTutorial = true;
      });
    }
  }

  @override
  void dispose() {
    SpeechNavigationNotifier.tabChangeNotifier.removeListener(_onSpeechTabChange);
    SpeechNavigationNotifier.openBuddyNotifier.removeListener(_onSpeechOpenBuddy);
    DashboardScreen.tutorialNotifier.removeListener(_onTutorialTriggered);
    _fadeController.dispose();
    _transitionController.dispose();
    _stopShakeListening();
    super.dispose();
  }

  void _onSpeechTabChange() {
    final idx = SpeechNavigationNotifier.tabChangeNotifier.value;
    if (idx != null && mounted) {
      _onTabChanged(idx);
    }
  }

  void _onSpeechOpenBuddy() {
    final shouldOpen = SpeechNavigationNotifier.openBuddyNotifier.value;
    if (shouldOpen == true && mounted && !_isBuddySheetOpen) {
      _openBuddyAssistant();
    }
  }

  /// Central tab-change handler with buttery-smooth single-controller transition.
  void _onTabChanged(int index, {bool isUndo = false}) {
    if (index == _currentIndex || _isTransitioning) return;
    final previousIndex = _currentIndex;

    final tabNames = ["Dashboard Home", "Audio Navigation", "Camera/Hardware Mode"];
    if (index >= 0 && index < tabNames.length) {
      final name = tabNames[index];
      RagService.recordNavigation(name, actionDescription: isUndo ? "Undid switch to $name" : "Switched tab to $name");
    }

    if (!isUndo) {
      UndoService().add(() {
        _onTabChanged(previousIndex, isUndo: true);
      }, description: "Switch tab to index $previousIndex");
    }

    _pendingIndex = index;
    _hasSwitchedTab = false;

    setState(() {
      _isTransitioning = true;
    });

    SoundService.playBubbleTransition();

    _transitionController.reset();
    _transitionController.forward();

    // Listener: switch tab at 45% progress (when curtain fully covers screen)
    void listener() {
      if (!_hasSwitchedTab && _transitionController.value >= 0.45 && mounted) {
        _hasSwitchedTab = true;
        setState(() => _currentIndex = _pendingIndex);
      }
      if (_transitionController.isCompleted && mounted) {
        _transitionController.removeListener(listener);
        setState(() => _isTransitioning = false);
      }
    }
    _transitionController.addListener(listener);
  }

  Future<void> _loadUserDisplayName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('userDisplayName') ??
          prefs.getString('user_display_name') ??
          prefs.getString('user_name') ??
          '';

      if (savedName.isNotEmpty && savedName != 'User' && savedName != 'EasyLens Explorer') {
        if (mounted) {
          setState(() {
            _displayName = savedName;
          });
        }
      }
    } catch (_) {}

    final user = _firebaseService.currentUser;
    if (user != null) {
      if (user.displayName.isNotEmpty && user.displayName != 'User') {
        if (mounted) {
          setState(() {
            _displayName = user.displayName;
          });
        }
        SettingsService().updateDisplayName(user.displayName);
      }

      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          String name = '';
          if (data.containsKey('name') && (data['name'] as String).trim().isNotEmpty) {
            name = data['name'];
          } else if (data.containsKey('displayName') && (data['displayName'] as String).trim().isNotEmpty) {
            name = data['displayName'];
          } else if (data.containsKey('preferences')) {
            final prefsMap = data['preferences'] as Map<String, dynamic>;
            if (prefsMap.containsKey('name') && (prefsMap['name'] as String).trim().isNotEmpty) {
              name = prefsMap['name'];
            }
          }

          if (name.isNotEmpty && mounted) {
            setState(() {
              _displayName = name;
            });
            SettingsService().updateDisplayName(name);
          }
        }
      } catch (e) {
        print("Error fetching dynamic displayName: $e");
      }
    }
  }

  void _startShakeListening() {
    _accelerometerSubscription = userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      if (!mounted) return;
      if (!SettingsService().shakeToUndo) return;

      final double gX = event.x / 9.80665;
      final double gY = event.y / 9.80665;
      final double gZ = event.z / 9.80665;
      final double gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

      if (gForce > 2.5) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastShakeTime > 1500) {
          _lastShakeTime = now;
          _onShakeDetected();
        }
      }
    });
  }

  void _stopShakeListening() {
    _accelerometerSubscription?.cancel();
  }  void _navigateTo(Widget screen, String description) {
    final nav = Navigator.of(context);
    final prev = RagService.currentScreen;
    
    RagService.recordNavigation(description, actionDescription: "Navigated to $description");

    UndoService().add(() {
      if (nav.canPop()) {
        RagService.recordNavigation(prev, actionDescription: "Undid navigation to $description");
        nav.pop();
      }
    }, description: "Pop screen: $description");

    Future.microtask(() async {
      await nav.push(AppRoute.to(screen));
      RagService.recordNavigation(prev, actionDescription: "Returned from $description");
    });
  }

  void _onShakeDetected() {
    final success = UndoService().performUndo();
    if (success) {
      final lang = SettingsService().selectedLanguage;
      final isTagalog = lang.toLowerCase().contains('tagalog') ||
          lang.toLowerCase().contains('filipino');
      TtsService().speak(isTagalog ? "Na-undo ang huling aksyon." : "Action undone.");
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            TranslationService.translate('shake_detected_undo', SettingsService().selectedLanguage),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openBuddyAssistant() {
    _isBuddySheetOpen = true;
    
    // Register the undo action to close the sheet
    UndoService().add(() {
      if (_isBuddySheetOpen && mounted) {
        Navigator.of(context).pop();
      }
    }, description: "Close Buddy Assistant Sheet");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BuddyAssistantSheet(
        onNavigate: (screenKey) {
          _isBuddySheetOpen = false;
          Navigator.of(context).pop(); // Close sheet
          if (screenKey == 'home') {
            _onTabChanged(0);
          } else if (screenKey == 'nav') {
            _onTabChanged(1);
          } else if (screenKey == 'hardware') {
            _onTabChanged(2);
          } else if (screenKey == 'text') {
            _navigateTo(ImageLabelingScreen(
              onTabSelected: (index) {
                setState(() => _currentIndex = index);
              },
            ), "Image Labeling");
          } else if (screenKey == 'objects') {
            _navigateTo(const HardwareScreen(initialStep: 4), "Objects Hardware Mode");
          } else if (screenKey == 'emergency') {
            _navigateTo(const EmergencyScreen(), "Emergency SOS");
          } else if (screenKey == 'settings') {
            _navigateTo(const SettingsScreen(), "Settings");
          } else if (screenKey == 'notifications') {
            _navigateTo(const NotificationsScreen(), "Notifications");
          } else if (screenKey == 'contacts') {
            _navigateTo(const ContactsScreen(), "Contacts");
          }
        },
      ),
    ).then((_) {
      _isBuddySheetOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListenableBuilder(
        listenable: SettingsService(),
        builder: (context, _) {
          final settings = SettingsService();
          final appearance = settings.appearanceTheme;
          final bg = (appearance == 'Black') ? Colors.black : AppColors.lightBackground;

        final List<Widget> tabs = [
          DashboardHome(
            displayName: _displayName,
            showStickyHeader: false,
            buddyCardKey: _buddyCardKey,
            easylensCardKey: _easylensCardKey,
            facesCardKey: _facesCardKey,
            textCardKey: _textCardKey,
            navigationCardKey: _navigationCardKey,
            sosCardKey: _sosCardKey,
            onTabSelected: (index) {
              _onTabChanged(index);
            },
            onSOSSelected: () {
              _navigateTo(const EmergencyScreen(), "Emergency SOS");
            },
            onSettingsSelected: () {
              _navigateTo(const SettingsScreen(), "Settings");
            },
            onNotificationsSelected: () {
              _navigateTo(const NotificationsScreen(), "Notifications");
            },
            onContactsSelected: () {
              _navigateTo(const ContactsScreen(), "Contacts");
            },
            onBuddyAssistantTap: _openBuddyAssistant,
            onFaceRegistrationSelected: () {
              _navigateTo(const FaceRegistrationScreen(), "Face Registration");
            },
          ),
          NavigationScreen(isActive: _currentIndex == 1),
          HardwareScreen(isActive: _currentIndex == 2),
        ];

        return Scaffold(
          backgroundColor: bg,
          body: Stack(
            children: [
              // Tabs stacked content (curtain handles visual transition)
              SafeArea(
                bottom: false,
                child: IndexedStack(
                  index: _currentIndex,
                  children: tabs.map((tab) {
                    if (tab is DashboardHome) {
                      return Column(
                        children: [
                          Container(
                            color: bg,
                            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 8.0),
                            child: HeaderBar(
                              sosKey: _sosEmergencyKey,
                              settingsKey: _settingsKey,
                              notificationsKey: _notificationsKey,
                              contactsKey: _contactsKey,
                              onSOSSelected: () {
                                _navigateTo(const EmergencyScreen(), "Emergency SOS");
                              },
                              onSettingsSelected: () {
                                _navigateTo(const SettingsScreen(), "Settings");
                              },
                              onNotificationsSelected: () {
                                _navigateTo(const NotificationsScreen(), "Notifications");
                              },
                              onContactsSelected: () {
                                _navigateTo(const ContactsScreen(), "Contacts");
                              },
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 120.0),
                                child: tab,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    if (tab is NavigationScreen) {
                      return tab;
                    }
                    if (tab is HardwareScreen) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 100.0),
                        child: tab,
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 120.0),
                      child: tab,
                    );
                  }).toList(),
                ),
              ),
              
              // Custom Floating Bottom Navigation Bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: CustomNavbar(
                  currentIndex: _currentIndex,
                  navKey: _audioNavKey,
                  easylensKey: _easylensScanKey,
                  onTap: (index) {
                    _onTabChanged(index);
                  },
                  onEasyLensTap: _openBuddyAssistant,
                ),
              ),

              // Draggable Floating Mascot Button S01
              if (settings.showFloatingMascot)
                DraggableBuddyButton(
                  buttonKey: _buddyMascotKey,
                  onTap: _openBuddyAssistant,
                ),

              // ── Fullscreen Lock Overlay ──────────────────────────────
              ValueListenableBuilder<bool>(
                valueListenable: HardwareScreen.screenLockNotifier,
                builder: (context, isLocked, _) {
                  if (!isLocked) return const SizedBox.shrink();
                  return Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPress: () {
                        HardwareScreen.screenLockNotifier.value = false;
                      },
                      child: Container(
                        color: Colors.black.withOpacity(0.92),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.08),
                                border: Border.all(color: Colors.white24, width: 2),
                              ),
                              child: const Icon(
                                Icons.lock,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Screen Locked',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Long press anywhere to unlock',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Interactive Tutorial Overlay
              if (_showTutorial)
                Positioned.fill(
                  child: InteractiveTutorialOverlay(
                    buddyMascotKey: _buddyMascotKey,
                    easylensScanKey: _easylensScanKey,
                    audioNavKey: _audioNavKey,
                    sosEmergencyKey: _sosEmergencyKey,
                    settingsKey: _settingsKey,
                    notificationsKey: _notificationsKey,
                    contactsKey: _contactsKey,
                    buddyCardKey: _buddyCardKey,
                    easylensCardKey: _easylensCardKey,
                    facesCardKey: _facesCardKey,
                    textCardKey: _textCardKey,
                    navigationCardKey: _navigationCardKey,
                    sosCardKey: _sosCardKey,
                    onTabRequested: (index) => _onTabChanged(index),
                    onComplete: () {
                      setState(() {
                        _showTutorial = false;
                      });
                    },
                  ),
                ),

              // ── Weather-Reactive Fresh Start Effect (5s duration) ────────
              if (_showWeatherEffect && _currentIndex == 0)
                Positioned.fill(
                  child: WeatherEffectsOverlay(
                    onComplete: () {
                      if (mounted) {
                        setState(() {
                          _showWeatherEffect = false;
                        });
                      }
                    },
                  ),
                ),

              // ── Light Blue Wave Transition Curtain ────────────
              if (_isTransitioning)
                Positioned.fill(
                  child: _LightBlueWaveCurtain(
                    controller: _transitionController,
                    theme: settings.selectedContrastTheme,
                  ),
                ),
            ],
          ),
        );
        },
      ),
    );
  }
}

class DraggableBuddyButton extends StatefulWidget {
  final VoidCallback onTap;
  final Key? buttonKey;

  const DraggableBuddyButton({super.key, required this.onTap, this.buttonKey});

  @override
  State<DraggableBuddyButton> createState() => _DraggableBuddyButtonState();
}

class _DraggableBuddyButtonState extends State<DraggableBuddyButton> {
  double? _left;
  double? _top;

  @override
  Widget build(BuildContext context) {
    if (_left == null || _top == null) {
      final size = MediaQuery.of(context).size;
      _left = size.width - 94.0;
      _top = size.height - 220.0;
    }

    final settings = SettingsService();
    final theme = settings.selectedContrastTheme;
    final isDefault = theme == 'Default';
    final isBlack = settings.appearanceTheme == 'Black';

    final buttonColor = isDefault 
        ? const Color(0xFF6B21A8) 
        : (isBlack ? AppColors.primaryButton : Colors.black);
        
    final borderColor = isDefault 
        ? Colors.white 
        : AppColors.primaryButtonText;

    return Positioned(
      left: _left,
      top: _top,
      child: GestureDetector(
        key: widget.buttonKey,
        onPanUpdate: (details) {
          setState(() {
            _top = (_top! + details.delta.dy).clamp(
              50.0,
              MediaQuery.of(context).size.height - 180.0,
            );
            _left = (_left! + details.delta.dx).clamp(
              20.0,
              MediaQuery.of(context).size.width - 100.0,
            );
          });
        },
        onTap: widget.onTap,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: buttonColor,
            boxShadow: isDefault ? [
              BoxShadow(
                color: const Color(0xFF6B21A8).withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ] : null,
            border: Border.all(
              color: borderColor,
              width: 2.5,
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/Mascots/App Mascot.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.pets,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── GPU-Optimized Theme-Synced Wave Curtain (AnimatedWidget) ────────
class _LightBlueWaveCurtain extends AnimatedWidget {
  final String theme;

  const _LightBlueWaveCurtain({
    required AnimationController controller,
    required this.theme,
  }) : super(listenable: controller);

  @override
  Widget build(BuildContext context) {
    final controller = listenable as AnimationController;
    final v = controller.value;

    // Three-phase animation:
    // Phase 1 (0.00–0.40): Sweep up from below → covers screen
    // Phase 2 (0.40–0.60): Hold — screen fully covered (tab switches behind)
    // Phase 3 (0.60–1.00): Sweep up off top → reveals new tab

    double translateY;
    double opacity;

    if (v <= 0.40) {
      final t = v / 0.40;
      final curved = Curves.easeOutCubic.transform(t);
      translateY = 1.0 - curved;
      opacity = curved;
    } else if (v <= 0.60) {
      translateY = 0.0;
      opacity = 1.0;
    } else {
      final t = (v - 0.60) / 0.40;
      final curved = Curves.easeInCubic.transform(t);
      translateY = -curved;
      opacity = 1.0 - (curved * 0.3);
    }

    return IgnorePointer(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: FractionalTranslation(
          translation: Offset(0.0, translateY),
          child: CustomPaint(
            painter: _OceanWavePainter(progress: v, theme: theme),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// GPU-accelerated ocean wave painter — theme-synced colors.
class _OceanWavePainter extends CustomPainter {
  final double progress;
  final String theme;
  const _OceanWavePainter({required this.progress, required this.theme});

  // Theme-aware color palettes
  List<Color> get _gradientColors {
    switch (theme) {
      case 'Green on Black':
        return const [
          Color(0xFF0A2E0A), // Dark forest
          Color(0xFF145214), // Deep green
          Color(0xFF1E7A1E), // Mid green
          Color(0xFF32CD32), // Lime green
        ];
      case 'Yellow on Black':
        return const [
          Color(0xFF2E2600), // Dark gold
          Color(0xFF5C4D00), // Deep amber
          Color(0xFF8B7500), // Mid gold
          Color(0xFFFFD700), // Gold yellow
        ];
      case 'Cyan on Black':
        return const [
          Color(0xFF002B28), // Dark teal
          Color(0xFF004D47), // Deep cyan
          Color(0xFF007A70), // Mid cyan
          Color(0xFF00D2C4), // Bright cyan
        ];
      case 'White on Black':
        return const [
          Color(0xFF1A1A1A), // Near black
          Color(0xFF2D2D2D), // Dark grey
          Color(0xFF404040), // Mid grey
          Color(0xFF666666), // Lighter grey
        ];
      case 'Black on White':
        return const [
          Color(0xFFE8E8E8), // Light grey
          Color(0xFFCCCCCC), // Mid grey
          Color(0xFFAAAAAA), // Darker grey
          Color(0xFF888888), // Dark grey
        ];
      case 'Default':
      default:
        return const [
          Color(0xFFBFDBFE), // Light blue top
          Color(0xFF60A5FA), // Mid blue
          Color(0xFF3B82F6), // Richer blue
          Color(0xFF2563EB), // Deep blue bottom
        ];
    }
  }

  Color get _waveTint {
    switch (theme) {
      case 'Green on Black':  return const Color(0xFF32CD32).withOpacity(0.35);
      case 'Yellow on Black': return const Color(0xFFFFD700).withOpacity(0.35);
      case 'Cyan on Black':   return const Color(0xFF00D2C4).withOpacity(0.35);
      case 'White on Black':  return Colors.white.withOpacity(0.15);
      case 'Black on White':  return Colors.black.withOpacity(0.12);
      default:                return const Color(0xFFDBEAFE).withOpacity(0.55);
    }
  }

  Color get _bubbleColor {
    switch (theme) {
      case 'Green on Black':  return const Color(0xFF32CD32);
      case 'Yellow on Black': return const Color(0xFFFFD700);
      case 'Cyan on Black':   return const Color(0xFF00D2C4);
      case 'White on Black':  return Colors.white;
      case 'Black on White':  return Colors.black;
      default:                return Colors.white;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final waveAmp = 28.0;
    final wavePhase = progress * 3.14159 * 4;

    // ── 1. Main Organic Wavy Curtain Body (No straight box lines!) ─
    final mainPath = Path();
    final startTopY = sin(wavePhase) * waveAmp;
    mainPath.moveTo(0, startTopY);

    // Top wave curve (0 -> w)
    for (double x = 0; x <= w; x += 2) {
      final y = sin((x / w) * 3.14159 * 3 + wavePhase) * waveAmp;
      mainPath.lineTo(x, y);
    }

    // Right edge to bottom wave
    final startBotY = h - (sin(3.14159 * 3 - wavePhase) * waveAmp);
    mainPath.lineTo(w, startBotY);

    // Bottom wave curve (w -> 0)
    for (double x = w; x >= 0; x -= 2) {
      final y = h - (sin((x / w) * 3.14159 * 3 - wavePhase) * waveAmp);
      mainPath.lineTo(x, y);
    }
    mainPath.close();

    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: _gradientColors,
        stops: const [0.0, 0.3, 0.65, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(mainPath, bgPaint);

    // ── 2. Top Organic Wave Ribbon Highlight ────────────────────
    final topFoamPath = Path();
    topFoamPath.moveTo(0, startTopY);
    for (double x = 0; x <= w; x += 2) {
      final y = sin((x / w) * 3.14159 * 3 + wavePhase) * waveAmp;
      topFoamPath.lineTo(x, y);
    }
    for (double x = w; x >= 0; x -= 2) {
      final y = sin((x / w) * 3.14159 * 3 + wavePhase) * waveAmp + 14.0;
      topFoamPath.lineTo(x, y);
    }
    topFoamPath.close();
    canvas.drawPath(topFoamPath, Paint()..color = _waveTint);

    // ── 3. Bottom Organic Wave Ribbon Highlight ─────────────────
    final botFoamPath = Path();
    final endBotY = h - (sin(-wavePhase) * waveAmp);
    botFoamPath.moveTo(0, endBotY);
    for (double x = 0; x <= w; x += 2) {
      final y = h - (sin((x / w) * 3.14159 * 3 - wavePhase) * waveAmp);
      botFoamPath.lineTo(x, y);
    }
    for (double x = w; x >= 0; x -= 2) {
      final y = h - (sin((x / w) * 3.14159 * 3 - wavePhase) * waveAmp) - 14.0;
      botFoamPath.lineTo(x, y);
    }
    botFoamPath.close();
    canvas.drawPath(botFoamPath, Paint()..color = _waveTint);

    // ── 4. Floating bubbles ────────────────────────────────────
    final bubbleOpacity = (0.25 + (sin(progress * 3.14159 * 2) * 0.15)).clamp(0.1, 0.4);
    final bColor = _bubbleColor;
    final bubblePaint = Paint()
      ..color = bColor.withOpacity(bubbleOpacity)
      ..style = PaintingStyle.fill;
    final bubbleBorderPaint = Paint()
      ..color = bColor.withOpacity((bubbleOpacity + 0.2).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final bubbles = [
      _Bubble(w * 0.12, h * 0.12, 14),
      _Bubble(w * 0.75, h * 0.18, 20),
      _Bubble(w * 0.45, h * 0.30, 16),
      _Bubble(w * 0.85, h * 0.42, 12),
      _Bubble(w * 0.25, h * 0.55, 18),
      _Bubble(w * 0.65, h * 0.65, 10),
      _Bubble(w * 0.35, h * 0.78, 14),
      _Bubble(w * 0.80, h * 0.85, 16),
    ];

    for (final b in bubbles) {
      canvas.drawCircle(Offset(b.x, b.y), b.r, bubblePaint);
      canvas.drawCircle(Offset(b.x, b.y), b.r, bubbleBorderPaint);
      final shinePaint = Paint()
        ..color = bColor.withOpacity((bubbleOpacity + 0.1).clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset(b.x - b.r * 0.3, b.y - b.r * 0.3),
        b.r * 0.25,
        shinePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_OceanWavePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.theme != theme;
}

class _Bubble {
  final double x, y, r;
  const _Bubble(this.x, this.y, this.r);
}
