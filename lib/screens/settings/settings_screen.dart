import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/colors.dart';
import '../../services/firebase_service.dart';
import '../../services/settings_service.dart';
import '../../services/translation_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../notifications/notification_settings_screen.dart';
import 'profile_details_screen.dart';
import 'help_guide_screen.dart';
import 'units_screen.dart';
import 'change_password_screen.dart';
import 'preferences_screen.dart';
import 'customize_home_screen.dart';
import 'survey_screen.dart';
import '../../utils/app_route.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../widgets/screen_tutorial_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _firebaseService = FirebaseService();
  static const String currentVersionTag = 'v1.2.0';
  bool _isCheckingUpdates = false;

  // Local interactive states linked to settings service
  String _selectedLanguage = 'English';
  bool _faceIdUnlock = false;
  String _selectedAppearance = 'Black';
  int _selectedAccentColorIndex = 0; // Index 0 represents Green S01
  bool _shakeToUndo = true;
  bool _speechNavigation = false;
  bool _bubbleTransitionSound = true;
  bool _soundEffects = true;
  bool _useLocalAI = true;
  bool _showFloatingMascot = true;

  final List<Color> _accentColors = [
    const Color(0xFF10B981), // Green S01
    const Color(0xFFF59E0B), // Yellow/Orange S01
    const Color(0xFFFFFFFF), // White S01
    const Color(0xFF06B6D4), // Cyan S01
  ];

  @override
  void initState() {
    super.initState();
    final settings = SettingsService();
    _selectedLanguage = settings.selectedLanguage.toLowerCase().contains('tagalog') ? 'Filipino' : 'English';
    _faceIdUnlock = settings.faceIdUnlock;
    // Sync _selectedAppearance & _selectedAccentColorIndex from selectedContrastTheme if contrast theme was set in signup
    if (settings.selectedContrastTheme != 'Default') {
      if (settings.selectedContrastTheme == 'Black on White') {
        _selectedAppearance = 'White';
        _selectedAccentColorIndex = 0;
      } else if (settings.selectedContrastTheme == 'Green on Black') {
        _selectedAppearance = 'Black';
        _selectedAccentColorIndex = 0;
      } else if (settings.selectedContrastTheme == 'Yellow on Black') {
        _selectedAppearance = 'Black';
        _selectedAccentColorIndex = 1;
      } else if (settings.selectedContrastTheme == 'White on Black') {
        _selectedAppearance = 'Black';
        _selectedAccentColorIndex = 2;
      } else if (settings.selectedContrastTheme == 'Cyan on Black') {
        _selectedAppearance = 'Black';
        _selectedAccentColorIndex = 3;
      }
    } else {
      _selectedAppearance = settings.appearanceTheme;
      _selectedAccentColorIndex = settings.accentColorIndex;
    }
    _shakeToUndo = settings.shakeToUndo;
    _speechNavigation = settings.speechNavigation;
    _bubbleTransitionSound = settings.bubbleTransitionSound;
    _soundEffects = settings.soundEffects;
    _useLocalAI = settings.useLocalAI;
    _showFloatingMascot = settings.showFloatingMascot;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScreenTutorialCard.showIfNeeded(
        context,
        tutorialKey: 'settings',
        titleKey: 'tutorial_settings_title',
        descriptionKey: 'tutorial_settings_desc',
        mascotAsset: 'assets/mascots/01_happy.gif',
      );
    });
  }

  void _saveSettings() {
    String theme = 'Default';
    if (_selectedAppearance == 'White') {
      theme = 'Black on White';
    } else if (_selectedAppearance == 'Black') {
      switch (_selectedAccentColorIndex) {
        case 0:
          theme = 'Green on Black';
          break;
        case 1:
          theme = 'Yellow on Black';
          break;
        case 2:
          theme = 'White on Black';
          break;
        case 3:
          theme = 'Cyan on Black';
          break;
      }
    }

    final languageString = _selectedLanguage == 'Filipino' ? 'Tagalog' : 'English (US)';

    SettingsService().updateSettings(
      selectedLanguage: languageString,
      selectedContrastTheme: theme,
      appearanceTheme: _selectedAppearance,
      accentColorIndex: _selectedAccentColorIndex,
      faceIdUnlock: _faceIdUnlock,
      shakeToUndo: _shakeToUndo,
      speechNavigation: _speechNavigation,
      bubbleTransitionSound: _bubbleTransitionSound,
      useLocalAI: _useLocalAI,
      showFloatingMascot: _showFloatingMascot,
    );

    // Sync user preferences to Cloud
    final user = _firebaseService.currentUser;
    if (user != null) {
      _firebaseService.syncPreferencesToCloud(user.uid, {
        'selectedLanguage': languageString,
        'selectedContrastTheme': theme,
        'appearanceTheme': _selectedAppearance,
        'accentColorIndex': _selectedAccentColorIndex,
        'faceIdUnlock': _faceIdUnlock,
        'shakeToUndo': _shakeToUndo,
        'speechNavigation': _speechNavigation,
        'bubbleTransitionSound': _bubbleTransitionSound,
        'useLocalAI': _useLocalAI,
        'showFloatingMascot': _showFloatingMascot,
      });
    }
  }

  Future<void> _openURL(String urlString) async {
    try {
      final Uri uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("Could not launch URL: $urlString");
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdates) return;
    
    setState(() {
      _isCheckingUpdates = true;
    });

    final lang = SettingsService().selectedLanguage;
    final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');

    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/Thes-IS-IT/Easylens/releases/latest'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestTag = data['tag_name'] as String;
        final releaseNotes = data['body'] as String? ?? '';
        final assets = data['assets'] as List?;

        String? apkUrl;
        if (assets != null) {
          for (var asset in assets) {
            final name = asset['name'] as String? ?? '';
            if (name.endsWith('.apk')) {
              apkUrl = asset['browser_download_url'] as String?;
              break;
            }
          }
        }

        if (latestTag != currentVersionTag && apkUrl != null) {
          if (mounted) {
            _showUpdateDialog(latestTag, releaseNotes, apkUrl);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isFilipino 
                      ? "Nasa pinakabagong bersyon ka na! ($currentVersionTag)" 
                      : "You are on the latest version! ($currentVersionTag)",
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        }
      } else {
        throw Exception("Github API status code ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFilipino 
                  ? "Hindi ma-check ang updates sa ngayon. Subukan muli mamaya." 
                  : "Could not check for updates right now. Please try again later.",
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdates = false;
        });
      }
    }
  }

  Future<bool> _testGeminiApiKey(String key) async {
    const candidates = ['gemini-3.5-flash', 'gemini-1.5-flash', 'gemini-2.0-flash', 'gemini-1.5-pro'];
    for (var modelName in candidates) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: key,
        );
        final response = await model.generateContent([Content.text('Hello')]);
        if (response.text != null) return true;
      } catch (e) {
        debugPrint('Test API Key failed for model $modelName: $e');
      }
    }
    return false;
  }

  void _showGeminiApiKeyDialog() {
    final settings = SettingsService();
    final lang = settings.selectedLanguage;
    final isDefault = settings.selectedContrastTheme == 'Default';
    final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
    
    final controller = TextEditingController(text: settings.geminiApiKey);
    bool obscureText = true;
    bool isTesting = false;
    String? testResult; // 'success' or 'failed' or null
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.primaryBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: isDefault ? BorderSide.none : BorderSide(color: AppColors.cardBorder, width: 2),
              ),
              title: Row(
                children: [
                  const Icon(Icons.key, color: Color(0xFF3B82F6), size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      TranslationService.translate('gemini_dialog_title', lang),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TranslationService.translate('gemini_dialog_desc', lang),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: obscureText,
                    style: GoogleFonts.inter(color: AppColors.primaryText),
                    decoration: InputDecoration(
                      hintText: TranslationService.translate('gemini_dialog_placeholder', lang),
                      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: isDefault ? Colors.grey.shade50 : const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: isDefault ? BorderSide.none : BorderSide(color: AppColors.cardBorder, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: isDefault ? BorderSide.none : BorderSide(color: AppColors.cardBorder, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: const Color(0xFF94A3B8),
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureText = !obscureText;
                          });
                        },
                      ),
                    ),
                  ),
                  if (testResult != null || isTesting) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (isTesting) ...[
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            TranslationService.translate('gemini_dialog_testing', lang),
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                          ),
                        ] else if (testResult == 'success') ...[
                          const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            TranslationService.translate('gemini_dialog_test_success', lang),
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
                          ),
                        ] else if (testResult == 'failed') ...[
                          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              TranslationService.translate('gemini_dialog_test_failed', lang),
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    final keyInput = controller.text.trim();
                    if (keyInput.isEmpty) {
                      setDialogState(() {
                        testResult = null;
                      });
                      return;
                    }
                    setDialogState(() {
                      isTesting = true;
                      testResult = null;
                    });
                    _testGeminiApiKey(keyInput).then((success) {
                      setDialogState(() {
                        isTesting = false;
                        testResult = success ? 'success' : 'failed';
                      });
                    });
                  },
                  child: Text(
                    TranslationService.translate('gemini_dialog_test', lang),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF3B82F6),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    isFilipino ? "Kanselahin" : "Cancel",
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final val = controller.text.trim();
                    setState(() {});
                    settings.updateSettings(geminiApiKey: val);
                    
                    // Sync user preferences to Cloud
                    final user = _firebaseService.currentUser;
                    if (user != null) {
                      _firebaseService.syncPreferencesToCloud(user.uid, {
                        'geminiApiKey': val,
                      });
                    }
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: Text(
                    isFilipino ? "I-save" : "Save",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showUpdateDialog(String newVersion, String notes, String downloadUrl) {
    final settings = SettingsService();
    final isDefault = settings.selectedContrastTheme == 'Default';
    final lang = settings.selectedLanguage;
    final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.primaryBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: isDefault ? BorderSide.none : BorderSide(color: AppColors.cardBorder, width: 2),
          ),
          title: Row(
            children: [
              const Icon(Icons.cloud_download, color: Color(0xFF3B82F6), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isFilipino ? "May Update!" : "Update Available!",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFilipino 
                    ? "Isang bagong bersyon ($newVersion) ang magagamit. Kasalukuyang bersyon: $currentVersionTag."
                    : "A new version ($newVersion) is available. Current version: $currentVersionTag.",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  isFilipino ? "Mga Pagbabago:" : "What's New:",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDefault ? Colors.grey.shade50 : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      notes,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                isFilipino ? "Kanselahin" : "Cancel",
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openURL(downloadUrl);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(
                isFilipino ? "I-download" : "Download Now",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    final settings = SettingsService();
    final isDark = settings.isDarkMode;
    final isDefault = settings.selectedContrastTheme == 'Default' && !isDark;
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 24.0),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.primaryText : (isDefault ? const Color(0xFF64748B) : AppColors.primaryText),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    final settings = SettingsService();
    final isDark = settings.isDarkMode;
    final isDefault = settings.selectedContrastTheme == 'Default' && !isDark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: AppColors.cardBorder.withOpacity(isDark ? 0.6 : (isDefault ? 0.0 : 1.0)), width: 1.5),
        boxShadow: isDefault ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final settings = SettingsService();
        final lang = settings.selectedLanguage;
        final isDark = settings.isDarkMode;
        final isDefault = settings.selectedContrastTheme == 'Default' && !isDark;
        final headerTextColor = AppColors.primaryText;
        final iconColor = isDark ? AppColors.primaryText : (isDefault ? const Color(0xFF002663) : AppColors.primaryText);
        final tileTextColor = isDark ? Colors.white : (isDefault ? Colors.black : AppColors.primaryText);

        final currentUnitText = settings.selectedUnit == 'Metric'
            ? TranslationService.translate('metric', lang)
            : TranslationService.translate('imperial', lang);

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
                            color: isDark ? const Color(0xFF1E1E1E) : (isDefault ? Colors.white : AppColors.primaryBackground),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppColors.cardBorder.withOpacity(isDark ? 0.6 : (isDefault ? 0.0 : 1.0)), width: 1.5),
                            boxShadow: isDefault ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ] : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chevron_left, color: isDefault ? const Color(0xFF002663) : AppColors.primaryText, size: 24),
                              const SizedBox(width: 4),
                              Text(
                                TranslationService.translate('back', lang),
                                style: GoogleFonts.inter(
                                  color: isDefault ? const Color(0xFF002663) : AppColors.primaryText,
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
                        TranslationService.translate('settings', lang),
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: headerTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Scrollable Settings List
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
              // 3. PROFILE Section
              _buildSectionTitle(TranslationService.translate('profile', lang)),
              _buildCardContainer(
                children: [
                  ListTile(
                    leading: Icon(Icons.person_outline, color: iconColor),
                    title: Text(
                      TranslationService.translate('profile_details', lang),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tileTextColor),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.of(context).push(
                        AppRoute.to(const ProfileDetailsScreen()),
                      ).then((_) => setState(() {}));
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Icon(Icons.lock_outline, color: iconColor),
                    title: Text(
                      TranslationService.translate('change_password', lang),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tileTextColor),
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
              _buildSectionTitle(TranslationService.translate('language', lang)),
              _buildCardContainer(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.chat_bubble_outline, color: iconColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                TranslationService.translate('language', lang),
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: tileTextColor),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                TranslationService.translate('language_subtitle', lang),
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
                              onTap: () {
                                setState(() => _selectedLanguage = 'English');
                                _saveSettings();
                              },
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
                              onTap: () {
                                setState(() => _selectedLanguage = 'Filipino');
                                _saveSettings();
                              },
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
              _buildSectionTitle(TranslationService.translate('notifications', lang)),
              _buildCardContainer(
                children: [
                  ListTile(
                    leading: Icon(Icons.notifications_none_outlined, color: iconColor),
                    title: Text(
                      TranslationService.translate('notifications', lang),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tileTextColor),
                    ),
                    subtitle: Text(
                      TranslationService.translate('notifications_subtitle', lang),
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.of(context).push(
                        AppRoute.to(const NotificationSettingsScreen()),
                      );
                    },
                  ),
                ],
              ),

              // 6. PREFERENCES Section
              _buildSectionTitle(TranslationService.translate('preferences', lang)),
              _buildCardContainer(
                children: [
                  ListTile(
                    leading: Icon(Icons.tune_outlined, color: iconColor),
                    title: Text(
                      TranslationService.translate('preferences', lang),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tileTextColor),
                    ),
                    subtitle: Text(
                      TranslationService.translate('preferences_subtitle', lang),
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

              // 8. APPEARANCE Section
              _buildSectionTitle(TranslationService.translate('appearance', lang)),
              _buildCardContainer(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TranslationService.translate('appearance', lang),
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: tileTextColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          TranslationService.translate('appearance_subtitle', lang),
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
                              onTap: () {
                                setState(() => _selectedAppearance = 'Default');
                                _saveSettings();
                              },
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
                                        color: _selectedAppearance == 'Default' ? const Color(0xFF3B82F6) : Colors.black),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Default',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: _selectedAppearance == 'Default' ? const Color(0xFF3B82F6) : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedAppearance = 'White');
                                _saveSettings();
                              },
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
                                        color: _selectedAppearance == 'White' ? const Color(0xFF3B82F6) : Colors.black),
                                    const SizedBox(width: 6),
                                    Text(
                                      'White',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: _selectedAppearance == 'White' ? const Color(0xFF3B82F6) : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedAppearance = 'Black');
                                _saveSettings();
                              },
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
                                        color: _selectedAppearance == 'Black' ? const Color(0xFF3B82F6) : Colors.black),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Black',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: _selectedAppearance == 'Black' ? const Color(0xFF3B82F6) : Colors.black,
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
                  if (_selectedAppearance == 'Black') ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Text(
                        TranslationService.translate('black_accent_colors', lang),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : tileTextColor,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_accentColors.length, (idx) {
                          final isSelected = _selectedAccentColorIndex == idx;
                          final color = _accentColors[idx];
                          final ringColor = idx == 2 ? const Color(0xFF1B4332) : Colors.black;

                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedAccentColorIndex = idx);
                              _saveSettings();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.symmetric(horizontal: 12.0),
                              width: isSelected ? 40 : 36,
                              height: isSelected ? 40 : 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ringColor,
                                  width: 4.0,
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
                ],
              ),

              // 9. UNITS Section
              _buildSectionTitle(TranslationService.translate('units', lang)),
              _buildCardContainer(
                children: [
                  ListTile(
                    leading: Icon(Icons.straighten, color: iconColor),
                    title: Text(
                      TranslationService.translate('units', lang),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tileTextColor),
                    ),
                    subtitle: Text(
                      currentUnitText,
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.of(context).push(
                        AppRoute.to(const UnitsScreen()),
                      ).then((_) => setState(() {}));
                    },
                  ),
                ],
              ),

              // 10. QUICK ACTIONS Section
              _buildSectionTitle(TranslationService.translate('quick_actions', lang)),
              _buildCardContainer(
                children: [
                  ListTile(
                    leading: Icon(Icons.dns_outlined, color: iconColor),
                    title: Text(
                      TranslationService.translate('customize_home', lang),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tileTextColor),
                    ),
                    subtitle: Text(
                      TranslationService.translate('customize_home_subtitle', lang),
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.of(context).push(
                        AppRoute.to(const CustomizeHomeScreen()),
                      ).then((_) => setState(() {}));
                    },
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
                                TranslationService.translate('shake_to_undo', lang),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: tileTextColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                TranslationService.translate('shake_to_undo_subtitle', lang),
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
                          onChanged: (val) {
                            setState(() => _shakeToUndo = val);
                            _saveSettings();
                          },
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF48BB78),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
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
                                TranslationService.translate('speech_navigation', lang),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: tileTextColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                TranslationService.translate('speech_navigation_subtitle', lang),
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
                          value: _speechNavigation,
                          onChanged: (val) {
                            setState(() => _speechNavigation = val);
                            _saveSettings();
                          },
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF48BB78),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
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
                                TranslationService.translate('bubble_transition_sound', lang),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: tileTextColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                TranslationService.translate('bubble_transition_sound_subtitle', lang),
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
                          value: _bubbleTransitionSound,
                          onChanged: (val) {
                            setState(() => _bubbleTransitionSound = val);
                            _saveSettings();
                          },
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

              // 11. AI & Mascot Controls Section
              _buildSectionTitle(TranslationService.translate('ai_mascot_settings', lang)),
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
                                TranslationService.translate('local_ai', lang),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: tileTextColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                TranslationService.translate('local_ai_subtitle', lang),
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
                          value: _useLocalAI,
                          onChanged: (val) {
                            setState(() => _useLocalAI = val);
                            _saveSettings();
                          },
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF48BB78),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
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
                                TranslationService.translate('floating_mascot', lang),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: tileTextColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                TranslationService.translate('floating_mascot_subtitle', lang),
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
                          value: _showFloatingMascot,
                          onChanged: (val) {
                            setState(() => _showFloatingMascot = val);
                            _saveSettings();
                          },
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF48BB78),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Icon(Icons.key_outlined, color: iconColor),
                    title: Text(
                      TranslationService.translate('gemini_api_key', lang),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tileTextColor),
                    ),
                    subtitle: Text(
                      settings.geminiApiKey.isEmpty
                          ? TranslationService.translate('gemini_api_key_subtitle', lang)
                          : (settings.geminiApiKey.length > 8
                              ? '${settings.geminiApiKey.substring(0, 8)}...'
                              : '••••••••'),
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: () {
                      _showGeminiApiKeyDialog();
                    },
                  ),
                ],
              ),

              // 12. HELP Section
              _buildSectionTitle(TranslationService.translate('help', lang)),
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
                                    TranslationService.translate('how_to_use', lang),
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: tileTextColor,
                                    ),
                                  ),
                                  Text(
                                    TranslationService.translate('how_to_use_subtitle', lang),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              height: 38,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.4)),
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
                                  TranslationService.translate('open_help', lang),
                                  style: GoogleFonts.inter(
                                    color: AppColors.primaryButton,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                label: Icon(
                                  Icons.arrow_forward,
                                  color: AppColors.primaryButton,
                                  size: 16,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 38,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryButton,
                                  foregroundColor: AppColors.primaryButtonText,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(19),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                onPressed: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setBool('has_completed_tutorial', false);
                                  DashboardScreen.triggerTutorial();
                                  if (context.mounted) {
                                    Navigator.of(context).popUntil((route) => route.isFirst);
                                  }
                                },
                                icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                                label: Text(
                                  lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino')
                                      ? 'Simulan ang Walkthrough Tour'
                                      : 'Replay Walkthrough Tour',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 13. ABOUT Section
              _buildSectionTitle(TranslationService.translate('about', lang)),
              _buildCardContainer(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Buddy Profile Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/mascots/app_mascot.png',
                              width: 80,
                              height: 80,
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
                                          fontSize: 24,
                                          color: tileTextColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'v.1.0.0',
                                          style: GoogleFonts.inter(
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    TranslationService.translate('about_desc', lang),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _openURL('https://easylense-website.vercel.app/'),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.language_outlined, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB), size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              'buddy.cloud',
                                              style: GoogleFonts.inter(
                                                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(Icons.open_in_new_rounded, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB), size: 12),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _openURL('https://github.com/Thes-IS-IT'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.people_outline, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB), size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Contributors',
                                                style: GoogleFonts.inter(
                                                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
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
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Check for Updates Option
                        Container(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.cardBorder.withOpacity(isDark ? 0.4 : 0.2), width: 1.5),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                              ),
                              child: Icon(Icons.cloud_download_outlined, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB), size: 24),
                            ),
                            title: Text(
                              TranslationService.translate('check_updates', lang),
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tileTextColor, fontSize: 15),
                            ),
                            subtitle: Text(
                              TranslationService.translate('updates_subtitle', lang),
                              style: GoogleFonts.inter(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
                            ),
                            trailing: _isCheckingUpdates 
                                ? SizedBox(
                                    width: 20, 
                                    height: 20, 
                                    child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6)),
                                  )
                                : Icon(Icons.refresh, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8)),
                            onTap: _checkForUpdates,
                          ),
                        ),
                        
                        // Buddy Community Option
                        Container(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.cardBorder.withOpacity(isDark ? 0.4 : 0.2), width: 1.5),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                              ),
                              child: Icon(Icons.facebook, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1877F2), size: 24),
                            ),
                            title: Text(
                              TranslationService.translate('community', lang),
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tileTextColor, fontSize: 15),
                            ),
                            subtitle: Text(
                              TranslationService.translate('community_subtitle', lang),
                              style: GoogleFonts.inter(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
                            ),
                            trailing: Icon(Icons.open_in_new, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8), size: 18),
                            onTap: () => _openURL('https://www.facebook.com/profile.php?id=61566090583740'),
                          ),
                        ),
                        
                        // Send Feedback Option (Outlined/Framed Border like in screenshot)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            border: Border.all(color: AppColors.cardBorder.withOpacity(isDark ? 0.4 : 0.3), width: 1.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                              ),
                              child: Icon(Icons.edit_outlined, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB), size: 24),
                            ),
                            title: Text(
                              TranslationService.translate('send_feedback', lang),
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tileTextColor, fontSize: 15),
                            ),
                            subtitle: Text(
                              TranslationService.translate('feedback_subtitle', lang),
                              style: GoogleFonts.inter(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
                            ),
                            trailing: Icon(Icons.chevron_right, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8), size: 20),
                            onTap: () {
                              Navigator.of(context).push(
                                AppRoute.to(SurveyScreen()),
                              );
                            },
                          ),
                        ),
                        
                        // Privacy Notice Block
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.cardBorder.withOpacity(isDark ? 0.4 : 0.2), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.shield_outlined, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB), size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      TranslationService.translate('privacy_notice', lang),
                                      style: GoogleFonts.inter(
                                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                TranslationService.translate('privacy_desc', lang),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),

              // 14. Log Out Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE2E2),
                    foregroundColor: const Color(0xFF991B1B),
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
                    TranslationService.translate('log_out', lang),
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
                  TranslationService.translate('bottom_bio', lang),
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
    ],
  ),
),
);
      },
    );
  }
}
