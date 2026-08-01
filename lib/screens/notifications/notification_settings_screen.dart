import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/colors.dart';
import '../../services/settings_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _allNotifications = true;
  bool _buddyFollowUp = true;
  bool _obstacleAlerts = true;
  bool _batteryAlerts = false;
  bool _connectionAlerts = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _allNotifications = prefs.getBool('settings_notify_all') ?? true;
      _buddyFollowUp = prefs.getBool('settings_notify_buddy') ?? true;
      _obstacleAlerts = prefs.getBool('settings_notify_obstacle') ?? true;
      _batteryAlerts = prefs.getBool('settings_notify_battery') ?? false;
      _connectionAlerts = prefs.getBool('settings_notify_connection') ?? false;
    });
  }

  Future<void> _saveNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_notify_all', _allNotifications);
    await prefs.setBool('settings_notify_buddy', _buddyFollowUp);
    await prefs.setBool('settings_notify_obstacle', _obstacleAlerts);
    await prefs.setBool('settings_notify_battery', _batteryAlerts);
    await prefs.setBool('settings_notify_connection', _connectionAlerts);
  }

  Widget _buildToggleTile({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final settings = SettingsService();
    final isDark = settings.isDarkMode;
    final isDefault = settings.selectedContrastTheme == 'Default' && !isDark;
    final textColor = isDark ? AppColors.primaryText : (isDefault ? Colors.black : AppColors.primaryText);
    final secondaryTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);
    final subCardBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC);
    final cardBorder = Border.all(color: AppColors.cardBorder.withOpacity(isDark ? 0.6 : 0.3), width: 1.5);
    final activeColor = AppColors.primaryButton;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: subCardBg,
        borderRadius: BorderRadius.circular(16),
        border: cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: isDark ? AppColors.primaryButtonText : Colors.white,
                activeTrackColor: activeColor,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: secondaryTextColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value ? 'On' : 'Off',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: value ? activeColor : secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService();
    final isDark = settings.isDarkMode;
    final isDefault = settings.selectedContrastTheme == 'Default' && !isDark;
    final headerTextColor = AppColors.primaryText;
    final textColor = isDark ? AppColors.primaryText : (isDefault ? Colors.black : AppColors.primaryText);
    final cardBg = isDark ? const Color(0xFF141414) : Colors.white;
    final subCardBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC);
    final secondaryTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);
    final cardBorder = Border.all(color: AppColors.cardBorder.withOpacity(isDark ? 0.6 : 0.3), width: 1.5);
    final activeColor = AppColors.primaryButton;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Sticky Header Bar (Back Button + Title)
            Container(
              color: AppColors.lightBackground,
              padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: isDefault ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ] : null,
                        border: cardBorder,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chevron_left, color: headerTextColor, size: 24),
                          const SizedBox(width: 4),
                          Text(
                            'Back',
                            style: GoogleFonts.inter(
                              color: headerTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Notification Settings',
                    style: GoogleFonts.inter(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: headerTextColor,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    
                    // Main Master Switch Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: cardBorder,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Allow Notifications',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Switch(
                                value: _allNotifications,
                                onChanged: (val) {
                                  setState(() {
                                    _allNotifications = val;
                                    if (!val) {
                                      _buddyFollowUp = false;
                                      _obstacleAlerts = false;
                                      _batteryAlerts = false;
                                      _connectionAlerts = false;
                                    }
                                  });
                                  _saveNotificationSettings();
                                },
                                activeColor: isDark ? AppColors.primaryButtonText : Colors.white,
                                activeTrackColor: activeColor,
                                inactiveThumbColor: Colors.white,
                                inactiveTrackColor: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Get a daily Buddy follow-up plus near-due alerts for obstacles, battery, and connections.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: secondaryTextColor,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Buddy follow-up switch
                    _buildToggleTile(
                      title: 'Buddy follow-up',
                      description: 'Send one daily follow-up. If you haven\'t navigated today, Buddy nudges you.',
                      value: _buddyFollowUp,
                      onChanged: !_allNotifications ? (_) {} : (val) {
                        setState(() => _buddyFollowUp = val);
                        _saveNotificationSettings();
                      },
                    ),

                    // Obstacle alerts switch
                    _buildToggleTile(
                      title: 'Obstacle alerts',
                      description: 'Warn when a high-risk obstacle is getting close or directly in your path.',
                      value: _obstacleAlerts,
                      onChanged: !_allNotifications ? (_) {} : (val) {
                        setState(() => _obstacleAlerts = val);
                        _saveNotificationSettings();
                      },
                    ),

                    // Battery alerts switch
                    _buildToggleTile(
                      title: 'Battery alerts',
                      description: 'Alert when the smart glasses battery drops below 20%.',
                      value: _batteryAlerts,
                      onChanged: !_allNotifications ? (_) {} : (val) {
                        setState(() => _batteryAlerts = val);
                        _saveNotificationSettings();
                      },
                    ),

                    // Connection alerts switch
                    _buildToggleTile(
                      title: 'Connection alerts',
                      description: 'Alert when the smart glasses lose connection to your phone.',
                      value: _connectionAlerts,
                      onChanged: !_allNotifications ? (_) {} : (val) {
                        setState(() => _connectionAlerts = val);
                        _saveNotificationSettings();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
