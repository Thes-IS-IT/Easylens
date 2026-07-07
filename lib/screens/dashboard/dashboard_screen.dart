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
import '../object_detection/object_detection_screen.dart';
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

  @override
  Widget build(BuildContext context) {
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
              onEasyLensTap: () {
                Navigator.of(context).push(
                  AppRoute.to(const ObjectDetectionScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
