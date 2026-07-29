import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../services/firebase_service.dart';
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

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final _firebaseService = FirebaseService();
  late String _displayName;
  int _currentIndex = 0;
  final _barkPlayer = AudioPlayer();

  // Fade-in animation for smooth dashboard entry
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  StreamSubscription? _accelerometerSubscription;
  int _lastShakeTime = 0;
  bool _isBuddySheetOpen = false;
  bool _showTutorial = false;

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

    _displayName = "User";
    _loadUserDisplayName();
    _checkTutorialStatus();
    _startShakeListening();
    _playDashboardBark();
    SpeechNavigationNotifier.tabChangeNotifier.addListener(_onSpeechTabChange);
    SpeechNavigationNotifier.openBuddyNotifier.addListener(_onSpeechOpenBuddy);
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
    _fadeController.dispose();
    SpeechNavigationNotifier.tabChangeNotifier.removeListener(_onSpeechTabChange);
    SpeechNavigationNotifier.openBuddyNotifier.removeListener(_onSpeechOpenBuddy);
    _stopShakeListening();
    _barkPlayer.dispose();
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

  /// Plays bark_dashboard.mp3 once when the user arrives on the Home tab.
  Future<void> _playDashboardBark() async {
    try {
      await _barkPlayer.stop();
      await _barkPlayer.play(
        AssetSource('sounds/bark_dashboard.mp3'),
        volume: 1.0,
      );
    } catch (e) {
      // Non-fatal — audio failure should never block navigation
    }
  }

  /// Central tab-change handler. Plays bark when navigating to dashboard.
  void _onTabChanged(int index, {bool isUndo = false}) {
    if (index == _currentIndex) return;
    final previousIndex = _currentIndex;
    final wasOnHome = _currentIndex == 0;
    final goingHome = index == 0;

    final tabNames = ["Dashboard Home", "Audio Navigation", "Camera/Hardware Mode"];
    if (index >= 0 && index < tabNames.length) {
      final name = tabNames[index];
      RagService.recordNavigation(name, actionDescription: isUndo ? "Undid switch to $name" : "Switched tab to $name");
    }

    setState(() => _currentIndex = index);
    if (goingHome && !wasOnHome) {
      _playDashboardBark();
    }
    if (!isUndo) {
      UndoService().add(() {
        _onTabChanged(previousIndex, isUndo: true);
      }, description: "Switch tab to index $previousIndex");
    }
  }

  Future<void> _loadUserDisplayName() async {
    final user = _firebaseService.currentUser;
    if (user != null) {
      // 1. First fallback to Auth display name
      if (user.displayName.isNotEmpty && user.displayName != 'User') {
        setState(() {
          _displayName = user.displayName;
        });
        SettingsService().updateDisplayName(_displayName);
      }

      // 2. Fetch from Firestore to get the registered name
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data.containsKey('preferences')) {
            final prefs = data['preferences'] as Map<String, dynamic>;
            if (prefs.containsKey('name') && (prefs['name'] as String).trim().isNotEmpty) {
              setState(() {
                _displayName = prefs['name'];
              });
              SettingsService().updateDisplayName(_displayName);
            }
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
              // Tabs stacked content
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
                  onTap: (index) {
                    _onTabChanged(index);
                  },
                  onEasyLensTap: _openBuddyAssistant,
                ),
              ),

              // Draggable Floating Mascot Button S01
              if (settings.showFloatingMascot)
                DraggableBuddyButton(onTap: _openBuddyAssistant),

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
                    onComplete: () {
                      setState(() {
                        _showTutorial = false;
                      });
                    },
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

  const DraggableBuddyButton({super.key, required this.onTap});

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
