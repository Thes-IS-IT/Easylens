import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_service.dart';
import '../../constants/colors.dart';
import '../onboarding/onboarding_screen.dart';
import '../navigation/navigation_screen.dart';
import '../hardware/hardware_screen.dart';
import '../emergency/emergency_screen.dart';
import '../settings/settings_screen.dart';
import '../notifications/notifications_screen.dart';
import '../contacts/contacts_screen.dart';
import 'components/custom_navbar.dart';
import 'components/buddy_assistant_sheet.dart';
import '../object_detection/object_detection_screen.dart';
import '../image_labeling/image_labeling_screen.dart';
import 'dashboard_home.dart';
import '../../utils/app_route.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _firebaseService = FirebaseService();
  late String _displayName;
  int _currentIndex = 0;
  double? _fabLeft;
  double? _fabTop;

  @override
  void initState() {
    super.initState();
    _displayName = "User";
    _loadUserDisplayName();
  }

  Future<void> _loadUserDisplayName() async {
    final user = _firebaseService.currentUser;
    if (user != null) {
      // 1. First fallback to Auth display name
      if (user.displayName.isNotEmpty && user.displayName != 'User') {
        setState(() {
          _displayName = user.displayName;
        });
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
            }
          }
        }
      } catch (e) {
        print("Error fetching dynamic displayName: $e");
      }
    }
  }

  Future<void> _handleLogout() async {
    await _firebaseService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        AppRoute.to(const OnboardingScreen()),
        (route) => false,
      );
    }
  }

  void _openBuddyAssistant() {
    BuddyAssistantSheet.show(
      context,
      onNavigate: (screenKey) {
        if (screenKey == 'home') {
          setState(() => _currentIndex = 0);
        } else if (screenKey == 'nav') {
          setState(() => _currentIndex = 1);
        } else if (screenKey == 'hardware') {
          setState(() => _currentIndex = 2);
        } else if (screenKey == 'text') {
          Navigator.of(context).push(
            AppRoute.to(ImageLabelingScreen(
              onTabSelected: (index) {
                setState(() => _currentIndex = index);
              },
            )),
          );
        } else if (screenKey == 'objects') {
          Navigator.of(context).push(
            AppRoute.to(const ObjectDetectionScreen()),
          );
        } else if (screenKey == 'emergency') {
          Navigator.of(context).push(
            AppRoute.to(const EmergencyScreen()),
          );
        } else if (screenKey == 'settings') {
          Navigator.of(context).push(
            AppRoute.to(const SettingsScreen()),
          );
        } else if (screenKey == 'notifications') {
          Navigator.of(context).push(
            AppRoute.to(const NotificationsScreen()),
          );
        } else if (screenKey == 'contacts') {
          Navigator.of(context).push(
            AppRoute.to(const ContactsScreen()),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_fabLeft == null || _fabTop == null) {
      final size = MediaQuery.of(context).size;
      _fabLeft = size.width - 94.0;
      _fabTop = size.height - 220.0;
    }

    // Define bottom tabs
    final List<Widget> tabs = [
      DashboardHome(
        displayName: _displayName,
        onTabSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        onSOSSelected: () {
          Navigator.of(context).push(
            AppRoute.to(const EmergencyScreen()),
          );
        },
        onSettingsSelected: () {
          Navigator.of(context).push(
            AppRoute.to(const SettingsScreen()),
          );
        },
        onNotificationsSelected: () {
          Navigator.of(context).push(
            AppRoute.to(const NotificationsScreen()),
          );
        },
        onContactsSelected: () {
          Navigator.of(context).push(
            AppRoute.to(const ContactsScreen()),
          );
        },
        onBuddyAssistantTap: _openBuddyAssistant,
      ),
      const NavigationScreen(),
      HardwareScreen(isActive: _currentIndex == 2),
    ];

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Stack(
        children: [
          // Tabs stacked content
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _currentIndex,
              children: tabs.map((tab) {
                if (tab is DashboardHome) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0.0, 16.0, 0.0, 120.0),
                      child: tab,
                    ),
                  );
                }
                if (tab is NavigationScreen) {
                  return tab;
                }
                if (tab is HardwareScreen) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 90.0),
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
                setState(() {
                  _currentIndex = index;
                });
              },
              onEasyLensTap: _openBuddyAssistant,
            ),
          ),

          // Draggable Floating Mascot Button S01
          Positioned(
            left: _fabLeft,
            top: _fabTop,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _fabTop = (_fabTop! + details.delta.dy).clamp(
                    50.0,
                    MediaQuery.of(context).size.height - 180.0,
                  );
                  _fabLeft = (_fabLeft! + details.delta.dx).clamp(
                    20.0,
                    MediaQuery.of(context).size.width - 100.0,
                  );
                });
              },
              onTap: _openBuddyAssistant,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6B21A8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6B21A8).withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white,
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
          ),
        ],
      ),
    );
  }
}
