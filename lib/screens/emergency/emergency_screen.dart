import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../constants/colors.dart';
import '../../services/sms_service.dart';
import '../../services/emergency_contact_service.dart';
import '../../services/tts_service.dart';
import '../../services/sound_service.dart';
import '../../widgets/screen_tutorial_card.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _isCountdownActive = true;
  bool _alertSent = false;
  int _countdownTimer = 5;
  Timer? _timer;
  String _sosStatusMessage = 'Alerting in 5 seconds…';

  @override
  void initState() {
    super.initState();
    _startCountdown();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScreenTutorialCard.showIfNeeded(
        context,
        tutorialKey: 'emergency',
        titleKey: 'tutorial_emergency_title',
        descriptionKey: 'tutorial_emergency_desc',
        mascotAsset: 'assets/Mascots/05 Welcome.gif',
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    HapticFeedback.vibrate();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownTimer > 1) {
        setState(() {
          _countdownTimer--;
          _sosStatusMessage = 'Alerting in $_countdownTimer seconds…';
        });
        HapticFeedback.vibrate();
      } else {
        _timer?.cancel();
        setState(() {
          _isCountdownActive = false;
          _alertSent = true;
          _sosStatusMessage = 'Acquiring GPS location…';
        });
        HapticFeedback.vibrate();
        _sendSosEmergencyAlert();
      }
    });
  }

  Future<void> _sendSosEmergencyAlert() async {
    // 1. Fetch active emergency contacts
    final contacts = await EmergencyContactService().getContacts();
    final activeContacts = contacts.where((c) => c.isActive).toList();

    if (activeContacts.isEmpty) {
      setState(() {
        _sosStatusMessage = 'No active contacts found. Add contacts first.';
      });
      TtsService().speak("No active emergency contacts found. Please add emergency contacts in settings.");
      return;
    }

    // 2. Try fetching location coordinates
    Position? position;
    bool serviceEnabled = false;
    LocationPermission permission = LocationPermission.denied;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Explicitly warn user that location is turned off completely
        TtsService().speak("Please turn on location completely in your settings so Buddy can share your coordinates with emergency contacts.");
      } else {
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
      }
    } catch (_) {}

    final hasLocationAccess = serviceEnabled &&
        (permission == LocationPermission.always || permission == LocationPermission.whileInUse);

    if (hasLocationAccess) {
      try {
        setState(() {
          _sosStatusMessage = 'Fetching coordinates…';
        });
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 4),
        );
      } catch (_) {
        // Fallback to last known position
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }
    }

    // Construct SOS Alert Message
    String message = "EasyLens SOS Emergency alert! I need assistance immediately.";
    if (position != null) {
      final googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      message += " My current location is: $googleMapsUrl (Coordinates: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}).";
    } else {
      message += " (Location coordinates unavailable - please enable GPS).";
    }

    setState(() {
      _sosStatusMessage = 'Sending SMS to ${activeContacts.length} contact(s)…';
    });

    // 3. Send SMS to all active contacts
    int successCount = 0;
    for (var contact in activeContacts) {
      final success = await SmsService().sendSMS(
        to: contact.phone,
        message: message,
      );
      if (success) {
        successCount++;
      }
    }

    if (mounted) {
      setState(() {
        if (!hasLocationAccess) {
          _sosStatusMessage = 'Alert sent! (Enable location for GPS coordinates)';
        } else if (successCount > 0) {
          _sosStatusMessage = 'SOS Sent with coordinates successfully!';
        } else {
          _sosStatusMessage = 'Alert delivery failed. Check network.';
        }
      });
    }

    // Speak results to the visually impaired user
    if (!hasLocationAccess) {
      TtsService().speak("Alerts sent, but please turn on location completely in settings to send location coordinates next time.");
    } else if (successCount > 0) {
      TtsService().speak("SOS alert and location coordinates have been sent to your emergency contacts.");
    } else {
      TtsService().speak("Alert delivery failed. Please check network connection.");
    }
  }

  void _cancelSOS() {
    _timer?.cancel();
    // Return back to dashboard
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _isCountdownActive ? 'SENDING SOS IN...' : 'SOS SENT!';
    
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Floating Pill Back Button
              GestureDetector(
                onTap: () {
                  SoundService.playClick();
                  _cancelSOS();
                },
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
              
              const Spacer(),
              
              // 2. SOS Title Indicator
              Center(
                child: Text(
                  titleText,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFC53030), // Dark red / orange S01
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              
              const SizedBox(height: 48),
              
              // 3. Main SOS Center Circle
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE8E8), // Light pink S01
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFC53030), // Dark red S01
                      width: 5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC53030).withOpacity(0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Center(
                    child: _isCountdownActive
                        ? Text(
                            '$_countdownTimer',
                            style: GoogleFonts.inter(
                              fontSize: 104,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFC53030),
                            ),
                          )
                        : Text(
                            _alertSent ? 'SOS' : '...',
                            style: GoogleFonts.inter(
                              fontSize: 78,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFC53030),
                            ),
                          ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),

              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    _sosStatusMessage,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
              
              const Spacer(flex: 2),
              
              // 4. Cancel SOS Bottom Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDE8E8), // Light pink S01
                    foregroundColor: const Color(0xFFC53030), // Dark red S01
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.0),
                    ),
                  ),
                  onPressed: () {
                    SoundService.playClick();
                    _cancelSOS();
                  },
                  child: Text(
                    'Cancel SOS',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
