import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../services/firebase_service.dart';
import '../onboarding/onboarding_screen.dart';
import '../notifications/notifications_screen.dart';
import 'profile_details_screen.dart';
import 'help_guide_screen.dart';
import 'units_screen.dart';
import 'change_password_screen.dart';
import 'preferences_screen.dart';
import '../../utils/app_route.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _firebaseService = FirebaseService();

  // Local interactive states to match the mockups
  String _selectedLanguage = 'English';
  bool _faceIdUnlock = false;
  String _selectedAppearance = 'Black';
  int _selectedAccentColorIndex = 0; // Index 0 represents Green S01
  bool _shakeToUndo = true;

  final List<Color> _accentColors = [
    const Color(0xFF10B981), // Green S01
    const Color(0xFFF59E0B), // Yellow/Orange S01
    const Color(0xFFFFFFFF), // White S01
    const Color(0xFF06B6D4), // Cyan S01
  ];

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 24.0),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Floating Pill Back Button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 95,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chevron_left, color: Color(0xFF002663), size: 24),
                      const SizedBox(width: 4),
                      Text(
                        'Back',
                        style: GoogleFonts.inter(
                          color: Color(0xFF002663),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 2. Settings Header
              Text(
                'Settings',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF002663),
                ),
              ),

              // 3. PROFILE Section
              _buildSectionTitle('Profile'),
              _buildCardContainer(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline, color: Color(0xFF002663)),
                    title: Text(
                      'Profile Details',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.of(context).push(
                        AppRoute.to(const ProfileDetailsScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: Color(0xFF002663)),
                    title: Text(
                      'Change Password',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.of(context).push(
                        AppRoute.to(const ChangePasswordScreen()),
                      );
                    },
                  ),
                ],
              ),

              // 4. LANGUAGE Section
              _buildSectionTitle('Language'),
              _buildCardContainer(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.chat_bubble_outline, color: Color(0xFF002663)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Language',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Choose how Buddy talks in the app.',
                                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedLanguage = 'English'),
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _selectedLanguage == 'English' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: _selectedLanguage == 'English'
                                      ? Border.all(color: const Color(0xFF3B82F6), width: 1.5)
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'English',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: _selectedLanguage == 'English' ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedLanguage = 'Filipino'),
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _selectedLanguage == 'Filipino' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: _selectedLanguage == 'Filipino'
                                      ? Border.all(color: const Color(0xFF3B82F6), width: 1.5)
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'Filipino',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: _selectedLanguage == 'Filipino' ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // 5. NOTIFICATIONS Section
              _buildSectionTitle('Notifications'),
              _buildCardContainer(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_none_outlined, color: Color(0xFF002663)),
                    title: Text(
                      'Notifications',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    subtitle: Text(
                      'Manage obstacle and battery alerts.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.of(context).push(
                        AppRoute.to(const NotificationsScreen()),
                      );
                    },
                  ),
                ],
              ),

              // 6. PREFERENCES Section
              _buildSectionTitle('Preferences'),
              _buildCardContainer(
                children: [
                  ListTile(
                    leading: const Icon(Icons.tune_outlined, color: Color(0xFF002663)),
                    title: Text(
                      'Preferences',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    subtitle: Text(
                      'Voice feedback, haptics, pitch, and voice persona.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.of(context).push(
                        AppRoute.to(const PreferencesScreen()),
                      );
                    },
                  ),
                ],
              ),

              // 7. SECURITY Section
              _buildSectionTitle('Security'),
              _buildCardContainer(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Face ID unlock',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Require Face ID when opening Buddy and whenever you come back after leaving the app.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Switch(
                          value: _faceIdUnlock,
                          onChanged: (val) => setState(() => _faceIdUnlock = val),
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF48BB78),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 8. APPEARANCE Section
              _buildSectionTitle('Appearance'),
              _buildCardContainer(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appearance',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Match your device or switch between light and dark mode anytime.',
                          style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedAppearance = 'Default'),
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _selectedAppearance == 'Default' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: _selectedAppearance == 'Default'
                                      ? Border.all(color: const Color(0xFF3B82F6), width: 1.5)
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.phone_android_outlined,
                                        size: 16,
                                        color: _selectedAppearance == 'Default' ? const Color(0xFF3B82F6) : Colors.black), // Black when unselected S01
                                    const SizedBox(width: 6),
                                    Text(
                                      'Default',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: _selectedAppearance == 'Default' ? const Color(0xFF3B82F6) : Colors.black, // Black when unselected S01
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedAppearance = 'White'),
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _selectedAppearance == 'White' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: _selectedAppearance == 'White'
                                      ? Border.all(color: const Color(0xFF3B82F6), width: 1.5)
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.wb_sunny_outlined,
                                        size: 16,
                                        color: _selectedAppearance == 'White' ? const Color(0xFF3B82F6) : Colors.black), // Black when unselected S01
                                    const SizedBox(width: 6),
                                    Text(
                                      'White',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: _selectedAppearance == 'White' ? const Color(0xFF3B82F6) : Colors.black, // Black when unselected S01
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedAppearance = 'Black'),
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _selectedAppearance == 'Black' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: _selectedAppearance == 'Black'
                                      ? Border.all(color: const Color(0xFF3B82F6), width: 1.5)
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.nightlight_round,
                                        size: 16,
                                        color: _selectedAppearance == 'Black' ? const Color(0xFF3B82F6) : Colors.black), // Black when unselected S01
                                    const SizedBox(width: 6),
                                    Text(
                                      'Black',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: _selectedAppearance == 'Black' ? const Color(0xFF3B82F6) : Colors.black, // Black when unselected S01
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Text(
                      'Black Accent Colors',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center, // Centered circles S01
                      children: List.generate(_accentColors.length, (idx) {
                        final isSelected = _selectedAccentColorIndex == idx;
                        final color = _accentColors[idx];
                        
                        // Circle 3 (index 2) is white and has a dark green/black outline S01
                        final ringColor = idx == 2 ? const Color(0xFF1B4332) : Colors.black;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedAccentColorIndex = idx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 12.0), // Symmetric horizontal spacing S01
                            width: isSelected ? 40 : 36,
                            height: isSelected ? 40 : 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: ringColor,
                                width: 4.0, // Thick border layout matching mockup S01
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isSelected ? 0.35 : 0.2),
                                  blurRadius: isSelected ? 8 : 4,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),

              // 9. UNITS Section
              _buildSectionTitle('Units'),
              _buildCardContainer(
                children: [
                  ListTile(
                    leading: const Icon(Icons.straighten, color: Color(0xFF002663)),
                    title: Text(
                      'Units',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    subtitle: Text(
                      'Metric (Meters, km)',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.of(context).push(
                        AppRoute.to(const UnitsScreen()),
                      );
                    },
                  ),
                ],
              ),

              // 10. QUICK ACTIONS Section
              _buildSectionTitle('Quick Actions'),
              _buildCardContainer(
                children: [
                  ListTile(
                    leading: const Icon(Icons.dns_outlined, color: Color(0xFF002663)),
                    title: Text(
                      'Customize Home Screen',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    subtitle: Text(
                      'Reorder and customize action cards on your dashboard.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Shake to undo',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'After logging an event, shaking your phone can undo it for a short time.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Switch(
                          value: _shakeToUndo,
                          onChanged: (val) => setState(() => _shakeToUndo = val),
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF48BB78),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 11. HELP Section
              _buildSectionTitle('Help'),
              _buildCardContainer(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.info_outline,
                                color: Color(0xFF0284C7),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'How to use Buddy',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    'A detailed guide for navigation, voice systems, settings, and more.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 38,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(19),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                AppRoute.to(const HelpGuideScreen()),
                              );
                            },
                            icon: Text(
                              'Open help guide',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF3B82F6),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            label: const Icon(
                              Icons.arrow_forward,
                              color: Color(0xFF3B82F6),
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 12. ABOUT Section
              _buildSectionTitle('About'),
              _buildCardContainer(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Transparent sitting dog mascot (no circle avatar) S01
                            Image.asset(
                              'assets/Mascots/App Mascot.png',
                              width: 64,
                              height: 64,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Buddy',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'v.1.0.0',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF64748B),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Meet Buddy, your AI guide. Inspired by the loyalty and guidance of a Golden Retriever.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // 2. Link Row - buddy.cloud is raw text, Contributors has light blue container S01
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {},
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.language, color: Color(0xFF2563EB), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'buddy.cloud',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF2563EB),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.open_in_new, color: Color(0xFF2563EB), size: 12),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () {},
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF), // Capsule background for Contributors S01
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.people_outline, color: Color(0xFF2563EB), size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Contributors',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF2563EB),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // 3. Standalone grey Check for updates Sub-Card S01
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.cloud_download_outlined, color: Color(0xFF3B82F6)), // Blue icon S01
                      title: Text(
                        'Check for updates',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14),
                      ),
                      subtitle: Text(
                        'You are on the latest public version, v1.0.0.',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                      trailing: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
                      onTap: () {},
                    ),
                  ),
                  
                  // 4. Standalone grey Buddy Community Sub-Card S01
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.facebook, color: Color(0xFF1877F2)),
                      title: Text(
                        'Buddy Community',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Join the Facebook community for updates, feedback, and fellow Buddy users.',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                      trailing: const Icon(Icons.open_in_new, color: Color(0xFF94A3B8), size: 16),
                      onTap: () {},
                    ),
                  ),
                  
                  // 5. Bordered Send Feedback Box S01
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.edit_outlined, color: Color(0xFF3B82F6)), // Blue icon S01
                      title: Text(
                        'Send feedback',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Share your ideas or report a bug to help us improve.',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                      onTap: () {},
                    ),
                  ),
                  
                  // 6. Privacy Notice block S01
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'Privacy notice',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF2563EB),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Your navigation data stays on this device by default. If you choose to sign in and use Buddy Cloud, your active profile data and subscription status are sent to our server so sync can work across devices.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
              
              const SizedBox(height: 32),

              // 13. Log Out Button S01
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE2E2), // Soft pink/red S01
                    foregroundColor: const Color(0xFF991B1B), // Dark red S01
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.0),
                    ),
                  ),
                  onPressed: () async {
                    await _firebaseService.signOut();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        AppRoute.to(const OnboardingScreen()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.exit_to_app, color: Color(0xFF991B1B)),
                  label: Text(
                    'Log Out',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // 14. Bottom descriptive bio text paragraph S01
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 8.0),
                child: Text(
                  'Meet Buddy, your AI guide. Inspired by the loyalty and guidance of a Golden Retriever—a remarkable service animal known for its keen awareness and protective nature—EasyLens acts as your eyes. Just as a guide dog leads the way to keep you safe, our mission is to protect your independence and keep you safely navigating the world.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
