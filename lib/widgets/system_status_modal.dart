import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../services/settings_service.dart';
import '../services/connectivity_service.dart';
import '../services/sound_service.dart';

/// Modal dialog displaying system status, connectivity breakdown (online vs offline features),
/// Google API / OS requirements, and hardware isolation (Phone vs. Lens).
class SystemStatusModal extends StatefulWidget {
  const SystemStatusModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => const SystemStatusModal(),
    );
  }

  @override
  State<SystemStatusModal> createState() => _SystemStatusModalState();
}

class _SystemStatusModalState extends State<SystemStatusModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([SettingsService(), ConnectivityService()]),
      builder: (context, _) {
        final settings = SettingsService();
        final conn = ConnectivityService();
        final isDark = settings.isDarkMode;
        final isDefault = settings.selectedContrastTheme == 'Default' && !isDark;
        final isOnline = conn.isOnline;
        final lang = SettingsService().selectedLanguage;
        final isFilipino = lang.toLowerCase().contains('filipino') || lang.toLowerCase().contains('tagalog');

        final dialogBg = isDark
            ? const Color(0xFF1E1E1E)
            : (isDefault ? Colors.white : AppColors.primaryBackground);
        final textColor = isDark ? Colors.white : AppColors.primaryText;
        final cardBg = isDark
            ? const Color(0xFF2A2A2A)
            : (isDefault ? const Color(0xFFF8FAFC) : AppColors.lightBackground);
        final borderColor = AppColors.cardBorder.withValues(alpha: 0.35);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isOnline ? Colors.green : Colors.amber)
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isOnline ? Icons.wifi : Icons.wifi_off_rounded,
                          color: isOnline ? Colors.green : Colors.amber[700],
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isFilipino
                                  ? 'Katayuan ng Sistema ng EasyLens'
                                  : 'EasyLens System Status',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isOnline
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF59E0B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    isOnline
                                        ? (isFilipino
                                            ? 'Aktibong Koneksyon sa Internet'
                                            : 'Active Internet Connection')
                                        : (isFilipino
                                            ? 'Offline Mode (Aktibo sa Device)'
                                            : 'Offline Mode (On-Device Active)'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isOnline
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          SoundService.playClick();
                          Navigator.of(context).pop();
                        },
                        icon: Icon(Icons.close_rounded,
                            color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),

                // Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.primaryButton,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: AppColors.primaryButtonText,
                    unselectedLabelColor: AppColors.textMuted,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: [
                      Tab(
                        height: 34,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(isFilipino ? 'Koneksyon' : 'Connectivity'),
                        ),
                      ),
                      Tab(
                        height: 34,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(isFilipino ? 'Seguridad' : 'Isolation'),
                        ),
                      ),
                      Tab(
                        height: 34,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(isFilipino ? 'Kinakailangan' : 'Requirements'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildConnectivityTab(cardBg, borderColor, textColor, isOnline, conn, isFilipino),
                      _buildIsolationTab(cardBg, borderColor, textColor, isFilipino),
                      _buildRequirementsTab(cardBg, borderColor, textColor, isFilipino),
                    ],
                  ),
                ),

                // Footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        SoundService.playClick();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryButton,
                        foregroundColor: AppColors.primaryButtonText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isFilipino ? 'Isara' : 'Close',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Tab 1: Online vs Offline Features ──────────────────────────────────────
  Widget _buildConnectivityTab(
    Color cardBg,
    Color borderColor,
    Color textColor,
    bool isOnline,
    ConnectivityService conn,
    bool isFilipino,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Status Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isOnline
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isOnline
                    ? const Color(0xFFA7F3D0)
                    : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isOnline
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  color: isOnline
                      ? const Color(0xFF059669)
                      : const Color(0xFFD97706),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isOnline
                        ? (isFilipino
                            ? 'Konektado sa internet. Gumagana ang Cloud AI at Maps routing nang maayos.'
                            : 'Connected to internet. Cloud AI and Maps routing are fully functional.')
                        : (isFilipino
                            ? 'Aktibo ang offline mode. Gumagana ang on-device AI, face recognition, at Smart Glasses kahit walang internet!'
                            : 'Offline mode active. On-device AI, face recognition, and Smart Glasses work without internet!'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isOnline
                          ? const Color(0xFF065F46)
                          : const Color(0xFF92400E),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    SoundService.playClick();
                    await conn.checkConnectivity();
                  },
                  child: Text(
                    isFilipino ? 'Suriing Muli' : 'Re-check',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isOnline
                          ? const Color(0xFF059669)
                          : const Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Features breakdown
          _sectionTitle(
            icon: Icons.swap_horiz_rounded,
            iconColor: const Color(0xFF7C3AED),
            title: isFilipino ? 'Mga Serbisyong Hybrid (Online at Offline)' : 'Hybrid Features (Online & Offline)',
            textColor: textColor,
          ),
          _featureRow(
            icon: Icons.chat_bubble_outline_rounded,
            title: isFilipino ? 'Kausapin si Buddy' : 'Talk to Buddy Assistant',
            desc: isFilipino
                ? 'Hybrid: Online Gemini Cloud AI + Offline na Gemma 2 model sa device.'
                : 'Hybrid: Online Gemini Cloud AI + Offline on-device Gemma 2 model.',
            badgeText: 'Hybrid',
            badgeColor: const Color(0xFF7C3AED),
          ),
          _featureRow(
            icon: Icons.near_me_rounded,
            title: isFilipino ? 'Gabay sa Nabigasyon' : 'Audio Navigation',
            desc: isFilipino
                ? 'Hybrid: Online Google Maps routing + Offline na GPS sensor, kompas, at gabay sa hakbang.'
                : 'Hybrid: Online Google Maps routing + Offline GPS sensors, compass, and step guidance.',
            badgeText: 'Hybrid',
            badgeColor: const Color(0xFF7C3AED),
          ),

          const SizedBox(height: 14),
          _sectionTitle(
            icon: Icons.sms_outlined,
            iconColor: const Color(0xFFDC2626),
            title: isFilipino ? 'Cellular / SMS Lamang' : 'Cellular / SMS Only',
            textColor: textColor,
          ),
          _featureRow(
            icon: Icons.phone_in_talk_rounded,
            title: isFilipino ? 'SOS Emergency Saklolo' : 'SOS Emergency Alert',
            desc: isFilipino
                ? 'Nagpapadala ng automated emergency SMS na may GPS coordinates gamit ang mobile cellular network (Hindi kailangan ng Wi-Fi o internet).'
                : 'Sends automated emergency SMS with location coordinates via mobile cellular network (No Wi-Fi/Internet required).',
            badgeText: isFilipino ? 'SMS lamang' : 'SMS only',
            badgeColor: const Color(0xFFDC2626),
          ),

          const SizedBox(height: 14),
          _sectionTitle(
            icon: Icons.cloud_outlined,
            iconColor: const Color(0xFF2563EB),
            title: isFilipino ? 'Nangangailangan ng Koneksyon sa Internet' : 'Features Requiring Online Connection',
            textColor: textColor,
          ),
          _featureRow(
            icon: Icons.cloud_outlined,
            title: isFilipino ? 'Impormasyon sa Panahon' : 'Weather Information',
            desc: isFilipino
                ? 'Real-time na radar at temperatura sa panahon.'
                : 'Real-time weather radar & temperature updates.',
            isOnline: true,
          ),
          _featureRow(
            icon: Icons.sync_rounded,
            title: isFilipino ? 'Firebase Account at Notion Sync' : 'Firebase Account & Notion Sync',
            desc: isFilipino
                ? 'Cloud profile backup at pag-sync ng journal.'
                : 'Cloud profile backup and journal synchronization.',
            isOnline: true,
          ),

          const SizedBox(height: 16),
          _sectionTitle(
            icon: Icons.offline_bolt_outlined,
            iconColor: const Color(0xFF059669),
            title: isFilipino ? '100% Offline (Hindi Kailangan ng Internet)' : '100% Offline (No Internet Required)',
            textColor: textColor,
          ),
          const SizedBox(height: 8),
          _featureRow(
            icon: Icons.view_in_ar_rounded,
            title: isFilipino ? 'Pagtukoy ng Bagay at Harang' : 'Real-Time Object & Hazard Detection',
            desc: isFilipino
                ? 'Tumatakbo sa on-device TFLite neural network gamit ang mabilis na background isolate.'
                : 'Runs on-device TFLite neural network via high-speed background isolate.',
            isOnline: false,
          ),
          _featureRow(
            icon: Icons.face_retouching_natural_rounded,
            title: isFilipino ? 'Pagkilala sa Mukha at Geometric ID' : 'Face Recognition & Geometric ID',
            desc: isFilipino
                ? 'ML Kit facial landmark extraction at 25 Euclidean geometric vectors na nakaimbak sa device.'
                : 'ML Kit facial landmark extraction and 25 Euclidean geometric vectors stored locally.',
            isOnline: false,
          ),
          _featureRow(
            icon: Icons.text_snippet_outlined,
            title: isFilipino ? 'Babasahing Teksto sa Malapit (OCR)' : 'Nearby Text Reader (OCR)',
            desc: isFilipino
                ? 'Lokal na optical character recognition sa mga karatula at dokumento.'
                : 'Local optical character recognition on signs and documents.',
            isOnline: false,
          ),
          _featureRow(
            icon: Icons.camera_outdoor_rounded,
            title: 'EasyLens Smart Glasses Live Stream',
            desc: isFilipino
                ? 'Direktang koneksyon ng Wi-Fi SoftAP sa pagitan ng ESP32-CAM glasses at telepono.'
                : 'Direct Wi-Fi SoftAP connection between ESP32-CAM glasses and phone.',
            isOnline: false,
          ),
          _featureRow(
            icon: Icons.volume_up_rounded,
            title: isFilipino ? 'Boses na Feedback (STT at TTS)' : 'Voice Feedback (STT & TTS)',
            desc: isFilipino
                ? 'On-device Android text-to-speech at lokal na voice commands.'
                : 'On-device Android text-to-speech and local voice commands.',
            isOnline: false,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Tab 2: Phone vs. Lens Isolation ────────────────────────────────────────
  Widget _buildIsolationTab(Color cardBg, Color borderColor, Color textColor, bool isFilipino) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFilipino ? 'Arkitektura ng Hardware at Privacy' : 'Hardware & Privacy Architecture',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isFilipino
                ? 'Ang EasyLens ay binuo nang may privacy-by-design. Ang sensitibong biometric data ay hindi kailanman lumalabas sa iyong device.'
                : 'EasyLens is engineered with privacy-by-design. Sensitive biometric data never leaves your device.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),

          // Glasses Isolation Card
          _isolationCard(
            icon: Icons.visibility_outlined,
            iconColor: const Color(0xFF2563EB),
            title: 'EasyLens Smart Glasses (Hardware)',
            badge: isFilipino ? 'Pribadong Network' : 'Private Local Network',
            badgeColor: Colors.blue,
            items: isFilipino
                ? [
                    'ESP32-CAM video capture module (OV2640 camera sensor)',
                    'Direktang Wi-Fi SoftAP koneksyon: direktang dumadaloy ang video frames sa telepono sa lokal na 192.168.4.1 subnet nang hindi dumaraan sa internet',
                    'Integrated Ultrasonic / ToF sensor para sa pagsukat ng distansya sa hardware',
                    'LED assist headlight at pagsubaybay sa baterya',
                    'Walang panlabas na pagsubaybay o hindi naka-encrypt na telemetry sa hardware',
                  ]
                : [
                    'ESP32-CAM video capture module (OV2640 camera sensor)',
                    'Direct Wi-Fi SoftAP connection: video frames stream directly to the phone via local 192.168.4.1 subnet, never passing through the internet',
                    'Integrated Ultrasonic / ToF sensor for hardware distance measurement',
                    'LED assist headlight & battery telemetry monitoring',
                    'No external tracking or unencrypted telemetry on hardware',
                  ],
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
          ),

          const SizedBox(height: 14),

          // Phone Isolation Card
          _isolationCard(
            icon: Icons.phone_android_rounded,
            iconColor: const Color(0xFF059669),
            title: isFilipino ? 'Telepono (100% Nasa Device)' : 'Mobile Phone (100% On-Device)',
            badge: isFilipino ? 'Lokal na Sandbox' : 'Local Device Sandbox',
            badgeColor: Colors.green,
            items: isFilipino
                ? [
                    'Facial Biometric Data: 25 geometric landmark vectors na nakaimbak lamang sa lokal na storage ng device (SQLite/Prefs)',
                    'TFLite AI Model: Tumatakbo sa NPU / GPU ng telepono gamit ang nakalaang Dart Isolate nang walang pagpapadala sa cloud',
                    'Google ML Kit OCR: Nag-i-scan ng teksto nang lokal sa processor ng telepono',
                    'Lokal na Speech Synthesis at Speech Recognition engine',
                    'Direktoryo ng mga Kontak sa Emergency at lokal na sirena ng alarma',
                  ]
                : [
                    'Facial Biometric Data: 25 geometric landmark vectors stored strictly in local device storage (SQLite/Prefs)',
                    'TFLite AI Model: Runs on phone NPU / GPU via dedicated Dart Isolate with zero cloud transmission',
                    'Google ML Kit OCR: Scans text locally on the phone processor',
                    'Local Speech Synthesis & Speech Recognition engine',
                    'Emergency Contact directory and local alarm siren',
                  ],
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
          ),

          const SizedBox(height: 14),

          // Cloud Card
          _isolationCard(
            icon: Icons.cloud_done_outlined,
            iconColor: const Color(0xFF7C3AED),
            title: isFilipino ? 'Mga Serbisyong Cloud (Naka-encrypt)' : 'Cloud Services (External Encrypted)',
            badge: isFilipino ? 'Opsyonal at may Pahintulot' : 'Optional & User-Gated',
            badgeColor: Colors.purple,
            items: isFilipino
                ? [
                    'Google Gemini API: Ginagamit lamang kapag nagtanong ang user ng cloud AI o buong paglalarawan ng paligid',
                    'Google Maps Directions API: Naka-encrypt na pagkalkula ng ruta sa paglalakad at biyahe',
                    'Firebase Auth: Mga kredensyal ng user at opsyonal na cloud backup',
                  ]
                : [
                    'Google Gemini API: Invoked only when user initiates cloud AI questions or full scenery descriptions',
                    'Google Maps Directions API: Encrypted transit & walking navigation route calculations',
                    'Firebase Auth: User credentials & optional cloud backup',
                  ],
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Tab 3: System Requirements ─────────────────────────────────────────────
  Widget _buildRequirementsTab(Color cardBg, Color borderColor, Color textColor, bool isFilipino) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFilipino ? 'Mga Kinakailangan sa App at Sistema' : 'App & System Requirements',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isFilipino
                ? 'Tiyaking natutugunan ng iyong device ang mga kinakailangang ito para sa maayos na pagtakbo.'
                : 'Ensure your device and environment satisfy these prerequisites for optimal performance.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),

          _requirementGroup(
            icon: Icons.android_rounded,
            iconColor: const Color(0xFF059669),
            category: isFilipino ? 'Operating System at Platform' : 'Operating System & Platform',
            items: isFilipino
                ? [
                    'Android OS 8.0 (API Level 26) o mas mataas',
                    'Inirerekomenda: Android 10+ (API 29+) 64-bit architecture',
                    'RAM: Minimum 3GB, Inirerekomenda 4GB+ para sa tuluy-tuloy na AI inference',
                    'Internal Storage: Hindi bababa sa 2.5GB bakanteng espasyo (para sa Gemma 2 local weights at offline cache)',
                  ]
                : [
                    'Android OS 8.0 (API Level 26) or higher',
                    'Recommended: Android 10+ (API 29+) 64-bit architecture',
                    'RAM: Minimum 3GB, Recommended 4GB+ for seamless multi-model AI inference',
                    'Internal Storage: At least 2.5GB free space (for Gemma 2 local model weights and offline cache)',
                  ],
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
          ),

          const SizedBox(height: 14),

          _requirementGroup(
            icon: Icons.api_rounded,
            iconColor: const Color(0xFF2563EB),
            category: isFilipino ? 'Mga Serbisyo at API ng Google' : 'Google APIs & Services',
            items: isFilipino
                ? [
                    'Google Play Services: v20.0+ (kailangan para sa Google ML Kit Vision at Face Detection)',
                    'Google Maps SDK at Directions API: Kailangan para sa live turn-by-turn audio routing',
                    'Google Gemini API (Google Generative AI): Kailangan para sa Buddy Cloud multi-modal assistant',
                    'Firebase Authentication at Cloud Firestore: Kailangan para sa cloud sync (opsyonal sa guest mode)',
                  ]
                : [
                    'Google Play Services: v20.0+ (required for Google ML Kit Vision & Face Detection)',
                    'Google Maps SDK & Directions API: Required for live turn-by-turn audio routing',
                    'Google Gemini API (Google Generative AI): Required for Buddy Cloud multi-modal assistant',
                    'Firebase Authentication & Cloud Firestore: Required for cloud sync (optional in guest mode)',
                  ],
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
          ),

          const SizedBox(height: 14),

          _requirementGroup(
            icon: Icons.sensors_rounded,
            iconColor: const Color(0xFF7C3AED),
            category: isFilipino ? 'Smart Glasses at Hardware Sensors' : 'Smart Glasses & Hardware Sensors',
            items: isFilipino
                ? [
                    'EasyLens Smart Glasses: ESP32-CAM module na may 2.4GHz Wi-Fi (802.11 b/g/n)',
                    'Camera ng Device: 1080p camera na may continuous autofocus',
                    'Hardware Sensors: Accelerometer, Gyroscope (para sa 3D UI at shake-to-undo), Magnetometer/Compass (para sa direksyon ng nabigasyon)',
                    'Mga Serbisyo sa Lokasyon: Naka-enable ang high-accuracy GPS',
                    'Audio: Mikropono na may noise suppression at speaker o bone-conduction headset',
                  ]
                : [
                    'EasyLens Smart Glasses: ESP32-CAM module with 2.4GHz Wi-Fi (802.11 b/g/n)',
                    'Device Camera: 1080p camera with continuous autofocus',
                    'Hardware Sensors: Accelerometer, Gyroscope (for 3D UI & shake-to-undo), Magnetometer/Compass (for navigation heading)',
                    'Location Services: High-accuracy GPS enabled',
                    'Audio: Microphone with noise suppression & speaker or bone-conduction headset',
                  ],
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _sectionTitle({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow({
    required IconData icon,
    required String title,
    required String desc,
    bool isOnline = false,
    String? badgeText,
    Color? badgeColor,
  }) {
    final effectiveBadgeText = badgeText ?? (isOnline ? 'Online' : 'Offline');
    final effectiveColor = badgeColor ??
        (isOnline ? const Color(0xFF2563EB) : const Color(0xFF059669));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 16,
              color: effectiveColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: effectiveColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        effectiveBadgeText,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: effectiveColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _isolationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String badge,
    required Color badgeColor,
    required List<String> items,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.circle, size: 5, color: Colors.blueAccent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requirementGroup({
    required IconData icon,
    required Color iconColor,
    required String category,
    required List<String> items,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.check_rounded, size: 14, color: Colors.green),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
