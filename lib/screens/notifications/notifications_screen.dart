import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _globalNotifications = true;
  bool _buddyFollowUp = true;
  bool _obstacleAlerts = true;
  bool _batteryAlerts = false;
  bool _connectionAlerts = false;

  Widget _buildItemCard({
    required String title,
    required String description,
    bool? switchValue,
    ValueChanged<bool>? onSwitchChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: const Color(0xFF002663),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
              height: 1.3,
            ),
          ),
          if (switchValue != null && onSwitchChanged != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  switchValue ? 'On' : 'Off',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: switchValue ? const Color(0xFF002663) : const Color(0xFF64748B),
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: Switch(
                    value: switchValue,
                    onChanged: _globalNotifications ? onSwitchChanged : null,
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF48BB78), // Green track color S01
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
          ],
        ],
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
                          color: const Color(0xFF002663),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 2. Notifications Screen Header
              Text(
                'Notifications',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF002663),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 3. Inner White Container holding configuration items
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Global Switch Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notifications',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: const Color(0xFF002663),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Get a daily Buddy follow-up plus near-due alerts for obstacles, battery, and connections.',
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
                          value: _globalNotifications,
                          onChanged: (val) {
                            setState(() {
                              _globalNotifications = val;
                            });
                          },
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF48BB78),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Sub-item cards list
                    _buildItemCard(
                      title: 'Reminder time',
                      description: 'Buddy sends your daily follow-up at 8:00 PM. Obstacle, battery, and connection alerts use the same time.',
                    ),
                    _buildItemCard(
                      title: 'Buddy follow-up',
                      description: "Send one daily follow-up. If you haven't navigated today, Buddy nudges you. If you have, Buddy sends a light reinforcement check-in.",
                      switchValue: _buddyFollowUp,
                      onSwitchChanged: (val) {
                        setState(() {
                          _buddyFollowUp = val;
                        });
                      },
                    ),
                    _buildItemCard(
                      title: 'Obstacle alerts',
                      description: 'Warn when a high-risk obstacle is getting close or directly in your path.',
                      switchValue: _obstacleAlerts,
                      onSwitchChanged: (val) {
                        setState(() {
                          _obstacleAlerts = val;
                        });
                      },
                    ),
                    _buildItemCard(
                      title: 'Battery alerts',
                      description: 'Alert when the smart glasses battery drops below 20%.',
                      switchValue: _batteryAlerts,
                      onSwitchChanged: (val) {
                        setState(() {
                          _batteryAlerts = val;
                        });
                      },
                    ),
                    _buildItemCard(
                      title: 'Connection alerts',
                      description: 'Alert when the smart glasses lose connection to your phone.',
                      switchValue: _connectionAlerts,
                      onSwitchChanged: (val) {
                        setState(() {
                          _connectionAlerts = val;
                        });
                      },
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
}
