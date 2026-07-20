import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../l10n/signup_strings.dart';
import '../../services/firebase_service.dart';
import '../../services/settings_service.dart';
import '../../services/tts_service.dart';
import '../../services/stt_service.dart';
import '../../services/sms_service.dart';

import '../../services/storage/cloudflare_r2_service.dart';
import 'celebration_screen.dart';
import 'steps/signup_steps.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  int _currentStep = 1;
  bool _isLoading = false;
  String? _errorMessage;

  // Flow flags
  bool _showOtherConditionInput = false;
  bool _showTermsDocument = false;
  bool _isVerifyingCode = false;

  // Registration States (19 Steps)
  String _selectedLanguage = 'English'; // Step 1 — FIRST so all subsequent steps are localized
  bool _isForMyself = true; // Step 3
  List<String> _selectedConditions = []; // Step 4
  String _selectedContrastTheme = 'Default'; // Step 5
  bool _voiceFeedback = true; // Step 6
  bool _hapticFeedback = true; // Step 6
  String _selectedVoicePersona = 'Aria (Calm)'; // Step 7
  String _selectedMobilityAid = 'None'; // Step 8
  String _selectedUnit = 'Metric'; // Step 9
  
  String _authMethod = ''; // Step 9: 'Google', 'Apple', 'Email', 'Phone'
  EasyLensUser? _googleUserSession;
  String _email = ''; // Step 10
  String _phone = ''; // Step 11
  String _password = ''; // Step 12
  File? _pickedImage; // Step 15
  String _name = ''; // Step 17 ("What should I call you?")
  String _birthday = ''; // Step 18
  
  // Step 19 (SOS Contact)
  String _sosName = '';
  String _sosPhone = '';
  String _sosRelationship = '';

  final _firebaseService = FirebaseService();
  final _smsService = SmsService();
  String? _generatedCode;
  String? _smsErrorMessage;

  // Voice Activation & Confirmation Engine States
  bool _isVoiceActivated = true;
  bool _isListening = false;
  bool _isAwaitingConfirmation = false;
  String _pendingVoiceSelection = '';
  String _voiceFeedbackText = '';
  Timer? _sttTimeoutTimer;

  @override
  void initState() {
    super.initState();
    SettingsService().addListener(_onThemeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakStepPromptAndListen();
    });
  }

  @override
  void dispose() {
    SettingsService().removeListener(_onThemeChanged);
    _sttTimeoutTimer?.cancel();
    SttService().stopListening((_) {});
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _speakStepPromptAndListen() async {
    if (!_isVoiceActivated || !mounted) return;

    final isTagalog = _selectedLanguage.toLowerCase().contains('filipino') ||
        _selectedLanguage.toLowerCase().contains('tagalog');

    String prompt = '';
    switch (_currentStep) {
      case 1:
        prompt = isTagalog
            ? "Hakbang 1 sa 19. Piliin ang iyong wika. Sabihin ang English o Filipino."
            : "Step 1 of 19. Choose your language. Say English or Filipino.";
        break;
      case 2:
        prompt = isTagalog
            ? "Hakbang 2 sa 19. Paraan ng Pagpaparehistro. Sabihin ang Boses para sa boses, o Manwal para sa pindot."
            : "Step 2 of 19. Registration Method. How would you like to set up your account? Say Voice for voice commands, or Manual for touch controls.";
        break;
      case 3:
        prompt = isTagalog
            ? "Hakbang 3. Para kanino ito? Sabihin ang Para sa akin o Para sa iba."
            : "Step 3. Who is this for? Say Myself or Someone else.";
        break;
      case 4:
        prompt = isTagalog
            ? "Hakbang 4. Piliin ang iyong mga kondisyon sa paningin. Sabihin ang Low Vision, Blindness, Color Blindness, Elderly, o Tapos na."
            : "Step 4. Select your vision conditions. Say Low Vision, Blindness, Color Blindness, Elderly, or Done.";
        break;
      case 5:
        prompt = isTagalog
            ? "Hakbang 5. Pumili ng kulay. Sabihin ang Default, High Contrast, Dark Blue, o Soft Pastel."
            : "Step 5. Choose color style. Say Default, High Contrast, Dark Blue, or Soft Pastel.";
        break;
      case 6:
        prompt = isTagalog
            ? "Hakbang 6. Gabay. Sabihin ang Boses on, Boses off, Vibrate on, o Vibrate off."
            : "Step 6. Helpful cues. Say Voice guide on, Voice guide off, Vibration on, or Vibration off.";
        break;
      case 7:
        prompt = isTagalog
            ? "Hakbang 7. Pumili ng boses. Sabihin ang Max, Aria, Nova, Echo, Bella, o Leo."
            : "Step 7. Choose a voice persona. Say Max, Aria, Nova, Echo, Bella, or Leo.";
        break;
      case 8:
        prompt = isTagalog
            ? "Hakbang 8. Kagamitan sa paglalakad. Sabihin ang Tungkod, Aso, Smart Glasses, Salamin, Wheelchair, Walker, o Wala."
            : "Step 8. Walking tools. Say White Cane, Guide Dog, Smart Glasses, Eyeglasses, Wheelchair, Walker, or None.";
        break;
      case 9:
        prompt = isTagalog
            ? "Hakbang 9. Gumawa ng account. Sabihin ang Google, Email, o Phone."
            : "Step 9. Create account. Say Google, Email, or Phone.";
        break;
      case 10:
        prompt = isTagalog
            ? "Hakbang 10. Sabihin ang iyong email address."
            : "Step 10. Speak your email address.";
        break;
      case 11:
        prompt = isTagalog
            ? "Hakbang 11. Sabihin ang iyong numero ng telepono."
            : "Step 11. Speak your phone number.";
        break;
      case 12:
        prompt = isTagalog
            ? "Hakbang 12. Pumili ng password. Sabihin ang iyong password."
            : "Step 12. Choose a password. Speak your password.";
        break;
      case 13:
        prompt = isTagalog
            ? "Hakbang 13. Pahintulot. Sabihin ang Ituloy o Agree."
            : "Step 13. Enable permissions. Say Continue or Agree.";
        break;
      case 14:
        prompt = isTagalog
            ? "Hakbang 14. Mga tuntunin. Sabihin ang Sumasang-ayon ako."
            : "Step 14. Terms and privacy. Say Agree to accept.";
        break;
      case 15:
        prompt = isTagalog
            ? "Hakbang 15. Larawan ng profile. Sabihin ang Gallery, Camera, o Laktawan."
            : "Step 15. Profile photo. Say Gallery, Camera, or Skip.";
        break;
      case 16:
        prompt = isTagalog
            ? "Hakbang 16. Kumpirmahin ang larawan. Sabihin ang Ituloy o Baguhin."
            : "Step 16. Photo confirmation. Say Continue or Reupload.";
        break;
      case 17:
        prompt = isTagalog
            ? "Hakbang 17. Ano ang pangalan mo? Sabihin ang iyong pangalan."
            : "Step 17. What should I call you? Speak your name.";
        break;
      case 18:
        prompt = isTagalog
            ? "Hakbang 18. Sabihin ang iyong kaarawan."
            : "Step 18. Speak your birthday or birth year.";
        break;
      case 19:
        prompt = isTagalog
            ? "Hakbang 19. Emergency contact. Sabihin ang pangalan at numero o Tapusin."
            : "Step 19. Emergency contact. Speak contact details or say Finish setting up.";
        break;
      default:
        prompt = "Step $_currentStep of 19.";
    }

    setState(() {
      _voiceFeedbackText = prompt;
    });

    // Ensure STT mic is stopped while assistant speaks
    SttService().stopListening((_) {});
    _sttTimeoutTimer?.cancel();

    // Await complete TTS speech output before opening microphone listener
    await TtsService().speakAwait(prompt);

    if (mounted && _isVoiceActivated) {
      _startListeningForStep();
    }
  }

  void _startListeningForStep() {
    if (!_isVoiceActivated || !mounted) return;

    SttService().startListening(
      onResult: (speechResult, isFinal) {
        if (!mounted || speechResult.trim().isEmpty) return;
        _handleVoiceCommand(speechResult);
      },
      onListeningStateChanged: (listening) {
        if (mounted) {
          setState(() {
            _isListening = listening;
          });
        }
      },
    );
  }

  Future<void> _triggerVoiceConfirmation(String selectionName) async {
    if (!_isVoiceActivated || !mounted) return;

    // Ensure STT mic is stopped while assistant speaks confirmation
    SttService().stopListening((_) {});
    _sttTimeoutTimer?.cancel();

    final isTagalog = _selectedLanguage.toLowerCase().contains('filipino') ||
        _selectedLanguage.toLowerCase().contains('tagalog');

    setState(() {
      _pendingVoiceSelection = selectionName;
      _isAwaitingConfirmation = true;
      _voiceFeedbackText = isTagalog
          ? "Pinili mo ang $selectionName. Sabihin ang Oo o Ituloy para kumpirmahin, Baguhin para pumili ulit, o Bumalik para sa nakaraang hakbang."
          : "You selected $selectionName. Say Yes or Next to confirm, Change to choose again, or Back to go to previous step.";
    });

    // Await complete TTS speech output before opening microphone listener
    await TtsService().speakAwait(_voiceFeedbackText);

    if (mounted && _isVoiceActivated) {
      _startListeningForStep();
    }
  }

  void _handleVoiceCommand(String rawText) {
    final text = rawText.toLowerCase().trim();
    if (text.isEmpty) return;

    final isTagalog = _selectedLanguage.toLowerCase().contains('filipino') ||
        _selectedLanguage.toLowerCase().contains('tagalog');

    // Voice Back Trigger Check
    final backKeywords = [
      'back', 'go back', 'previous', 'bumalik', 'rara', 'u-turn',
      'kabilang hakbang', 'kanselain', 'cancel', 'pabalik'
    ];

    if (backKeywords.any((k) => text.contains(k))) {
      setState(() {
        _isAwaitingConfirmation = false;
        _pendingVoiceSelection = '';
      });
      TtsService().speak(isTagalog ? "Bumabalik sa nakaraang hakbang." : "Going back to previous step.");
      _prevStep();
      return;
    }

    // 1. Validation phase (Awaiting Confirmation)
    if (_isAwaitingConfirmation) {
      final confirmCmds = ['yes', 'yeah', 'yep', 'next', 'confirm', 'proceed', 'sige', 'oo', 'continue', 'go', 'okay', 'correct', 'ituloy'];
      final cancelCmds = ['no', 'nope', 'change', 'different', 'ulit', 'hindi', 'baguhin'];

      if (confirmCmds.any((cmd) => text.contains(cmd))) {
        setState(() {
          _isAwaitingConfirmation = false;
        });
        TtsService().speak(isTagalog ? "Kumpirmado." : "Confirmed.");
        _nextStep();
        return;
      } else if (cancelCmds.any((cmd) => text.contains(cmd))) {
        setState(() {
          _isAwaitingConfirmation = false;
          _pendingVoiceSelection = '';
        });
        TtsService().speak(isTagalog ? "Kanselado. Paki-sabay ulit ang iyong pili." : "Selection cancelled. Please speak your choice again.");
        _sttTimeoutTimer?.cancel();
        _sttTimeoutTimer = Timer(const Duration(milliseconds: 2000), () {
          _startListeningForStep();
        });
        return;
      }
    }

    // 2. Global Navigation Commands
    if (text == 'next' || text == 'continue' || text == 'ituloy' || text == 'proceed') {
      _nextStep();
      return;
    }
    if (text == 'repeat' || text == 'read' || text == 'ulit') {
      _speakStepPromptAndListen();
      return;
    }

    // 3. Step-Specific Voice Matching
    switch (_currentStep) {
      case 1: // Language
        if (text.contains('english') || text.contains('inggles')) {
          setState(() {
            _selectedLanguage = 'English';
          });
          SettingsService().updateSettings(selectedLanguage: 'English');
          _triggerVoiceConfirmation('English');
        } else if (text.contains('filipino') || text.contains('tagalog') || text.contains('pinoy')) {
          setState(() {
            _selectedLanguage = 'Filipino';
          });
          SettingsService().updateSettings(selectedLanguage: 'Filipino');
          _triggerVoiceConfirmation('Filipino');
        }
        break;

      case 2: // Registration Method Selection (Voice vs Manual)
        if (text.contains('voice') || text.contains('boses') || text.contains('salita') || text.contains('one') || text.contains('isa')) {
          setState(() => _isVoiceActivated = true);
          _triggerVoiceConfirmation('Voice Command Fillup');
        } else if (text.contains('manual') || text.contains('touch') || text.contains('pindot') || text.contains('kamay') || text.contains('two') || text.contains('dalawa')) {
          setState(() => _isVoiceActivated = false);
          TtsService().speak(isTagalog ? "Manwal na pagpuno ang napili. Naka-off ang boses." : "Manual Form Fillup selected. Speech assistance muted.");
          SttService().stopListening((_) {});
          _nextStep();
        }
        break;

      case 3: // Persona
        if (text.contains('myself') || text.contains('me') || text.contains('akin') || text.contains('sarili')) {
          setState(() => _isForMyself = true);
          _triggerVoiceConfirmation(isTagalog ? 'Para sa akin' : 'Myself');
        } else if (text.contains('someone') || text.contains('else') || text.contains('iba')) {
          setState(() => _isForMyself = false);
          _triggerVoiceConfirmation(isTagalog ? 'Para sa iba' : 'Someone Else');
        }
        break;

      case 4: // Conditions
        if (text.contains('low vision')) {
          if (!_selectedConditions.contains('Low Vision')) _selectedConditions.add('Low Vision');
          _triggerVoiceConfirmation('Low Vision');
        } else if (text.contains('blind')) {
          if (!_selectedConditions.contains('Blindness')) _selectedConditions.add('Blindness');
          _triggerVoiceConfirmation('Blindness');
        } else if (text.contains('color')) {
          if (!_selectedConditions.contains('Color Blindness')) _selectedConditions.add('Color Blindness');
          _triggerVoiceConfirmation('Color Blindness');
        } else if (text.contains('elderly')) {
          if (!_selectedConditions.contains('Elderly')) _selectedConditions.add('Elderly');
          _triggerVoiceConfirmation('Elderly');
        } else if (text.contains('done') || text.contains('tapos')) {
          _nextStep();
        }
        break;

      case 5: // Contrast Theme
        if (text.contains('default')) {
          setState(() => _selectedContrastTheme = 'Default');
          SettingsService().updateSettings(selectedContrastTheme: 'Default');
          _triggerVoiceConfirmation('Default Theme');
        } else if (text.contains('high contrast') || text.contains('contrast')) {
          setState(() => _selectedContrastTheme = 'High Contrast');
          SettingsService().updateSettings(selectedContrastTheme: 'High Contrast');
          _triggerVoiceConfirmation('High Contrast Theme');
        } else if (text.contains('dark') || text.contains('blue')) {
          setState(() => _selectedContrastTheme = 'Dark Blue');
          SettingsService().updateSettings(selectedContrastTheme: 'Dark Blue');
          _triggerVoiceConfirmation('Dark Blue Theme');
        } else if (text.contains('pastel') || text.contains('soft')) {
          setState(() => _selectedContrastTheme = 'Soft Pastel');
          SettingsService().updateSettings(selectedContrastTheme: 'Soft Pastel');
          _triggerVoiceConfirmation('Soft Pastel Theme');
        }
        break;

      case 6: // Accessibility Cues
        if (text.contains('voice on') || text.contains('voice guide on')) {
          setState(() => _voiceFeedback = true);
          _triggerVoiceConfirmation('Voice Guides On');
        } else if (text.contains('voice off')) {
          setState(() => _voiceFeedback = false);
          _triggerVoiceConfirmation('Voice Guides Off');
        } else if (text.contains('vibration on') || text.contains('haptic on') || text.contains('vibrate on')) {
          setState(() => _hapticFeedback = true);
          _triggerVoiceConfirmation('Vibration On');
        } else if (text.contains('vibration off') || text.contains('haptic off') || text.contains('vibrate off')) {
          setState(() => _hapticFeedback = false);
          _triggerVoiceConfirmation('Vibration Off');
        }
        break;

      case 7: // Voice Persona
        if (text.contains('aria')) {
          setState(() => _selectedVoicePersona = 'Aria (Calm)');
          SettingsService().updateSettings(selectedVoicePersona: 'Aria (Calm)');
          _triggerVoiceConfirmation('Aria Voice');
        } else if (text.contains('max')) {
          setState(() => _selectedVoicePersona = 'Max (Clear)');
          SettingsService().updateSettings(selectedVoicePersona: 'Max (Clear)');
          _triggerVoiceConfirmation('Max Voice');
        } else if (text.contains('nova')) {
          setState(() => _selectedVoicePersona = 'Nova (Energetic)');
          SettingsService().updateSettings(selectedVoicePersona: 'Nova (Energetic)');
          _triggerVoiceConfirmation('Nova Voice');
        } else if (text.contains('echo')) {
          setState(() => _selectedVoicePersona = 'Echo (Deep)');
          SettingsService().updateSettings(selectedVoicePersona: 'Echo (Deep)');
          _triggerVoiceConfirmation('Echo Voice');
        } else if (text.contains('bella')) {
          setState(() => _selectedVoicePersona = 'Bella (Slow)');
          SettingsService().updateSettings(selectedVoicePersona: 'Bella (Slow)');
          _triggerVoiceConfirmation('Bella Voice');
        } else if (text.contains('leo')) {
          setState(() => _selectedVoicePersona = 'Leo (Child)');
          SettingsService().updateSettings(selectedVoicePersona: 'Leo (Child)');
          _triggerVoiceConfirmation('Leo Voice');
        }
        break;

      case 8: // Mobility Aids
        if (text.contains('cane') || text.contains('tungkod')) {
          setState(() => _selectedMobilityAid = 'White Cane');
          _triggerVoiceConfirmation('White Cane');
        } else if (text.contains('dog') || text.contains('aso')) {
          setState(() => _selectedMobilityAid = 'Guide Dog');
          _triggerVoiceConfirmation('Guide Dog');
        } else if (text.contains('smart glasses')) {
          setState(() => _selectedMobilityAid = 'Smart Glasses');
          _triggerVoiceConfirmation('Smart Glasses');
        } else if (text.contains('eyeglasses') || text.contains('salamin')) {
          setState(() => _selectedMobilityAid = 'Eyeglasses');
          _triggerVoiceConfirmation('Eyeglasses');
        } else if (text.contains('wheelchair')) {
          setState(() => _selectedMobilityAid = 'Wheelchair');
          _triggerVoiceConfirmation('Wheelchair');
        } else if (text.contains('walker')) {
          setState(() => _selectedMobilityAid = 'Walker');
          _triggerVoiceConfirmation('Walker');
        } else if (text.contains('none') || text.contains('wala')) {
          setState(() => _selectedMobilityAid = 'None');
          _triggerVoiceConfirmation('No Mobility Aid');
        }
        break;

      case 9: // Account Creation Method
        if (text.contains('google')) {
          setState(() => _authMethod = 'Google');
          _triggerVoiceConfirmation('Google Sign In');
        } else if (text.contains('email')) {
          setState(() {
            _authMethod = 'Email';
            _currentStep = 10;
          });
          _speakStepPromptAndListen();
        } else if (text.contains('phone')) {
          setState(() {
            _authMethod = 'Phone';
            _currentStep = 11;
          });
          _speakStepPromptAndListen();
        }
        break;

      case 10: // Email Input
        final cleanEmail = text.replaceAll(' at ', '@').replaceAll(' dot ', '.').replaceAll(' ', '');
        if (cleanEmail.contains('@')) {
          setState(() => _email = cleanEmail);
          _triggerVoiceConfirmation(cleanEmail);
        }
        break;

      case 11: // Phone Input
        final digits = text.replaceAll(RegExp(r'\D'), '');
        if (digits.length >= 10) {
          setState(() => _phone = digits);
          _triggerVoiceConfirmation(digits);
        }
        break;

      case 12: // Password Input
        if (text.length >= 4) {
          setState(() => _password = rawText);
          _triggerVoiceConfirmation("your password");
        }
        break;

      case 13: // Permissions
        _triggerVoiceConfirmation("Permissions enabled");
        break;

      case 14: // Terms Privacy
        if (text.contains('agree') || text.contains('sumasang')) {
          _triggerVoiceConfirmation("Agreed to terms");
        }
        break;

      case 15: // Photo Upload
        if (text.contains('skip') || text.contains('laktawan')) {
          setState(() => _currentStep = 17);
          _speakStepPromptAndListen();
        } else if (text.contains('camera')) {
          _triggerVoiceConfirmation("Camera Photo");
        } else if (text.contains('gallery')) {
          _triggerVoiceConfirmation("Gallery Photo");
        }
        break;

      case 16: // Photo Confirmation
        _triggerVoiceConfirmation("Photo confirmed");
        break;

      case 17: // Name Input
        if (rawText.trim().isNotEmpty) {
          setState(() => _name = rawText.trim());
          _triggerVoiceConfirmation(_name);
        }
        break;

      case 18: // Birthday Input
        if (rawText.trim().isNotEmpty) {
          setState(() => _birthday = rawText.trim());
          _triggerVoiceConfirmation(_birthday);
        }
        break;

      case 19: // SOS Contact
        if (text.contains('finish') || text.contains('tapos') || text.contains('done')) {
          _handleRegister();
        } else if (rawText.trim().isNotEmpty) {
          setState(() => _sosName = rawText.trim());
          _triggerVoiceConfirmation("SOS Contact $rawText");
        }
        break;
    }
  }

  void _nextStep() {
    // Input validation & exception handling per step
    if (_currentStep == 10) {
      // Step 10: Email Step
      final emailClean = _email.trim();
      if (emailClean.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailClean)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SignupL10n.t('error_email', _selectedLanguage)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    } else if (_currentStep == 11) {
      // Step 11: Phone Step
      if (_phone.trim().length < 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SignupL10n.t('error_phone', _selectedLanguage)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    } else if (_currentStep == 12 && _authMethod != 'Google' && _authMethod != 'Apple') {
      // Step 12: Password Step (Only for Email/Phone)
      if (_password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SignupL10n.t('error_password_empty', _selectedLanguage)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
      if (_password.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SignupL10n.t('error_password_short', _selectedLanguage)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    } else if (_currentStep == 17) {
      // Step 17: Name Step
      if (_name.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SignupL10n.t('error_name', _selectedLanguage)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    }

    setState(() {
      if (_currentStep == 9) {
        if (_authMethod == 'Email') {
          _currentStep = 10;
        } else if (_authMethod == 'Phone') {
          _currentStep = 11;
        } else {
          _currentStep = 13;
        }
      } else if (_currentStep == 10 || _currentStep == 11) {
        _currentStep = 12;
      } else if (_currentStep < 19) {
        _currentStep++;
      }
    });

    _speakStepPromptAndListen();
  }

  void _prevStep() {
    if (_showOtherConditionInput) {
      setState(() => _showOtherConditionInput = false);
    } else if (_showTermsDocument) {
      setState(() => _showTermsDocument = false);
    } else if (_isVerifyingCode) {
      setState(() => _isVerifyingCode = false);
    } else if (_currentStep > 1) {
      setState(() {
        if (_currentStep == 12) {
          if (_authMethod == 'Email') {
            _currentStep = 10;
          } else if (_authMethod == 'Phone') {
            _currentStep = 11;
          } else {
            _currentStep = 9;
          }
        } else if (_currentStep == 13) {
          if (_authMethod == 'Google' || _authMethod == 'Apple') {
            _currentStep = 9;
          } else {
            _currentStep = 12;
          }
        } else {
          _currentStep--;
        }
      });
      _speakStepPromptAndListen();
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Sends an SMS verification code to the phone number (phone auth only).
  Future<void> _sendVerificationSmsPhone() async {
    final rand = Random();
    final code = (rand.nextInt(9000) + 1000).toString();
    setState(() {
      _generatedCode = code;
      _smsErrorMessage = null;
    });

    if (_phone.isEmpty || _phone.trim().length < 10) {
      setState(() => _smsErrorMessage = 'Please enter a valid 11-digit phone number');
      return;
    }

    String formattedPhone = _phone.trim();
    if (!formattedPhone.startsWith('+')) {
      formattedPhone = formattedPhone.startsWith('0')
          ? '+63${formattedPhone.substring(1)}'
          : '+63$formattedPhone';
    }

    try {
      final success = await _smsService.sendSMS(
        to: formattedPhone,
        message: 'Your EasyLens verification code is: $code',
      );

      if (success) {
        setState(() => _isVerifyingCode = true);
      } else {
        setState(() => _smsErrorMessage = 'We couldn\'t send the code. Please try again.');
      }
    } catch (e) {
      setState(() => _smsErrorMessage = 'Something went wrong. Please check your network and try again.');
    }
  }

  void _verifyCode(String enteredCode) {
    if (enteredCode.length < 4) {
      setState(() {
        _smsErrorMessage = 'Please enter all 4 numbers.';
      });
      return;
    }

    if (enteredCode == _generatedCode) {
      setState(() {
        _isVerifyingCode = false;
        _smsErrorMessage = null;
        _currentStep = 12; // Proceed to Create Password
      });
      _speakStepPromptAndListen();
    } else {
      setState(() {
        _smsErrorMessage = 'That code doesn\'t seem right. Please try again.';
      });
    }
  }

  String _getFriendlyErrorMessage(dynamic error) {
    final msg = error.toString();
    if (msg.contains('email-already-in-use')) {
      return 'That email address is already registered. Please sign in instead.';
    } else if (msg.contains('weak-password')) {
      return 'That password is too weak. Try adding more letters or numbers.';
    } else if (msg.contains('invalid-email')) {
      return 'The email address is not valid.';
    } else if (msg.contains('network-request-failed')) {
      return 'Connection error. Please check your internet and try again.';
    } else if (msg.contains('sign_in_failed') || msg.contains('10') || msg.contains('PlatformException')) {
      return 'Google Sign-In service error. Please sign in with Email or try again.';
    }
    return msg
        .replaceAll(RegExp(r'^(PlatformException|FirebaseAuthException|Exception):\s*'), '')
        .replaceAll(RegExp(r'com\.google\.android\.gms.*'), 'Google Service Error')
        .trim();
  }

  Future<void> _handleRegister() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final regEmail = _email.isNotEmpty ? _email.trim() : "buddy_user@easylens.com";
    final regPassword = _password.isNotEmpty ? _password : "mockPassword123";
    final regName = _name.isNotEmpty ? _name.trim() : "Buddy User";

    try {
      // 1. Re-use active Google session or Firebase user without triggering re-authentication
      EasyLensUser? user = _googleUserSession ?? _firebaseService.currentUser;

      if (user == null) {
        if (_authMethod == 'Google') {
          user = EasyLensUser(
            uid: "google_user_${DateTime.now().millisecondsSinceEpoch}",
            email: regEmail,
            displayName: regName,
            isForMyself: _isForMyself,
          );
        } else {
          try {
            user = await _firebaseService.signUp(regEmail, regPassword, regName, _isForMyself);
          } catch (signUpError) {
            // If email already in use, attempt sign in or create clean session
            if (signUpError.toString().contains('email-already-in-use')) {
              try {
                user = await _firebaseService.signIn(regEmail, regPassword);
              } catch (_) {
                final fallbackEmail = "${regEmail.split('@')[0]}_${DateTime.now().millisecondsSinceEpoch}@easylens.com";
                user = await _firebaseService.signUp(fallbackEmail, regPassword, regName, _isForMyself);
              }
            } else {
              rethrow;
            }
          }
        }
      }

      // Guarantee non-null user object
      user ??= EasyLensUser(
        uid: "user_${DateTime.now().millisecondsSinceEpoch}",
        email: regEmail,
        displayName: regName,
        isForMyself: _isForMyself,
      );

      if (regName.isNotEmpty && user.displayName != regName) {
        try {
          await _firebaseService.updateDisplayName(regName);
        } catch (_) {}
      }

      String? profilePhotoUrl;
      
      // 2. Upload avatar image to Cloudflare R2 if picked
      if (_pickedImage != null) {
        try {
          profilePhotoUrl = await CloudflareR2Service().uploadAvatar(_pickedImage!, user.uid);
        } catch (r2Error) {
          print("Warning: Cloudflare R2 photo upload failed: $r2Error. Continuing without photo.");
        }
      }

      // 3. Save preferences to global service
      final settings = SettingsService();
      settings.updateSettings(
        voiceFeedback: _voiceFeedback,
        hapticFeedback: _hapticFeedback,
        selectedContrastTheme: _selectedContrastTheme,
        selectedLanguage: _selectedLanguage,
        selectedVoicePersona: _selectedVoicePersona,
        selectedUnit: _selectedUnit,
        selectedMobilityAid: _selectedMobilityAid,
      );

      // 4. Store/Sync Preferences to Firestore (and D1)
      final prefsJson = {
        'voiceFeedback': _voiceFeedback,
        'hapticFeedback': _hapticFeedback,
        'selectedContrastTheme': _selectedContrastTheme,
        'selectedLanguage': _selectedLanguage,
        'selectedVoicePersona': _selectedVoicePersona,
        'selectedUnit': _selectedUnit,
        'selectedMobilityAid': _selectedMobilityAid,
        'name': regName,
        'birthday': _birthday,
        'photoUrl': profilePhotoUrl ?? '',
        'isForMyself': _isForMyself,
        'selectedConditions': _selectedConditions,
      };
      try {
        await _firebaseService.syncPreferencesToCloud(user.uid, prefsJson);
      } catch (prefErr) {
        print("Warning: syncPreferencesToCloud error: $prefErr");
      }

      // 5. Store/Sync SOS Contact to Firestore (and D1)
      if (_sosName.isNotEmpty || _sosPhone.isNotEmpty) {
        final sosJson = {
          'name': _sosName,
          'phone': _sosPhone,
          'relationship': _sosRelationship,
        };
        try {
          await _firebaseService.syncContactToCloud(user.uid, sosJson);
        } catch (sosErr) {
          print("Warning: syncContactToCloud error: $sosErr");
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                CelebrationScreen(userName: regName),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getFriendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  bool _shouldShowStepIndicator() {
    if (_showOtherConditionInput || _showTermsDocument || _isVerifyingCode) {
      return false;
    }
    return true;
  }

  bool _shouldShowContinueButton() {
    if (_showOtherConditionInput || _showTermsDocument || _isVerifyingCode) {
      return false;
    }
    final stepsWithCustomActions = [
      9,  // Create Account (inline list buttons)
      10, // Email input (inline buttons)
      11, // Phone input (inline buttons)
      14, // Terms & Privacy (inline buttons)
      15, // Upload Photo (inline buttons)
      16, // Photo Confirmation (inline buttons)
      19, // SOS Contact (inline Finish setup button)
    ];
    return !stepsWithCustomActions.contains(_currentStep);
  }

  Widget _buildStepContent() {
    final isTagalog = _selectedLanguage.toLowerCase().contains('filipino') ||
        _selectedLanguage.toLowerCase().contains('tagalog');

    if (_showOtherConditionInput) {
      return StepOtherCondition(
        language: _selectedLanguage,
        onConditionAdded: (cond) {
          setState(() {
            if (!_selectedConditions.contains(cond)) {
              _selectedConditions.add(cond);
            }
            _showOtherConditionInput = false;
          });
          _triggerVoiceConfirmation(cond);
        },
        onCancel: () => setState(() => _showOtherConditionInput = false),
      );
    }
    
    if (_showTermsDocument) {
      return StepTermsDocument(
        onClose: () => setState(() => _showTermsDocument = false),
      );
    }

    if (_isVerifyingCode) {
      return StepVerificationCode(
        language: _selectedLanguage,
        onVerify: _verifyCode,
        onResendCode: _sendVerificationSmsPhone,
        errorMessage: _smsErrorMessage,
      );
    }

    switch (_currentStep) {
      case 1:
        // LANGUAGE — first step; write to SettingsService immediately so app is reactive
        return StepLanguage(
          selectedLanguage: _selectedLanguage,
          language: _selectedLanguage,
          onChanged: (val) {
            setState(() => _selectedLanguage = val);
            SettingsService().updateSettings(selectedLanguage: val);
            _triggerVoiceConfirmation(val);
          },
        );
      case 2:
        // REGISTRATION METHOD — choice between Voice Command Fillup vs Manual Form Fillup
        return StepSignupMode(
          isVoiceMode: _isVoiceActivated,
          language: _selectedLanguage,
          onChanged: (val) {
            setState(() => _isVoiceActivated = val);
            if (val) {
              _triggerVoiceConfirmation(isTagalog ? 'Voice Command Fillup' : 'Voice Command Fillup');
            } else {
              TtsService().speak(isTagalog ? "Manwal na pagpuno ang napili. Naka-off ang tulong sa boses." : "Manual Form Fillup selected. Speech assistance muted.");
              SttService().stopListening((_) {});
              _nextStep();
            }
          },
        );
      case 3:
        return StepPersona(
          isForMyself: _isForMyself,
          language: _selectedLanguage,
          onChanged: (val) {
            setState(() => _isForMyself = val);
            _triggerVoiceConfirmation(val ? (isTagalog ? 'Para sa akin' : 'Myself') : (isTagalog ? 'Para sa iba' : 'Someone Else'));
          },
        );
      case 4:
        return StepConditions(
          selectedConditions: _selectedConditions,
          language: _selectedLanguage,
          onChanged: (val) {
            setState(() => _selectedConditions = val);
            _triggerVoiceConfirmation(val.join(', '));
          },
          onAddCustomCondition: () => setState(() => _showOtherConditionInput = true),
        );
      case 5:
        return StepContrastTheme(
          selectedTheme: _selectedContrastTheme,
          language: _selectedLanguage,
          onChanged: (val) {
            setState(() {
              _selectedContrastTheme = val;
            });
            SettingsService().updateSettings(selectedContrastTheme: val);
            _triggerVoiceConfirmation('$val Theme');
          },
        );
      case 6:
        return StepAccessibility(
          voiceFeedback: _voiceFeedback,
          hapticFeedback: _hapticFeedback,
          language: _selectedLanguage,
          onVoiceChanged: (val) {
            setState(() => _voiceFeedback = val);
            _triggerVoiceConfirmation(val ? 'Voice On' : 'Voice Off');
          },
          onHapticChanged: (val) {
            setState(() => _hapticFeedback = val);
            _triggerVoiceConfirmation(val ? 'Vibration On' : 'Vibration Off');
          },
        );
      case 7:
        return StepVoicePersona(
          selectedPersona: _selectedVoicePersona,
          language: _selectedLanguage,
          onChanged: (val) {
            setState(() {
              _selectedVoicePersona = val;
            });
            SettingsService().updateSettings(selectedVoicePersona: val);
            _triggerVoiceConfirmation(val);
          },
        );
      case 8:
        return StepMobilityAids(
          selectedAid: _selectedMobilityAid,
          language: _selectedLanguage,
          onChanged: (val) {
            setState(() => _selectedMobilityAid = val);
            _triggerVoiceConfirmation(val);
          },
        );
      case 9:
        return StepCreateAccount(
          language: _selectedLanguage,
          onSelectedMethod: (method) async {
            if (method == 'Google') {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              try {
                final user = await _firebaseService.signInWithGoogle();
                if (user != null) {
                  setState(() {
                    _googleUserSession = user;
                    _authMethod = 'Google';
                    _email = user.email;
                    _name = user.displayName;
                    _currentStep = 13; // Social methods skip password setup
                    _isLoading = false;
                  });
                  _speakStepPromptAndListen();
                } else {
                  setState(() {
                    _isLoading = false;
                  });
                }
              } catch (e) {
                setState(() {
                  _errorMessage = _getFriendlyErrorMessage(e);
                  _isLoading = false;
                });
              }
            } else if (method == 'Email') {
              setState(() {
                _authMethod = 'Email';
                _currentStep = 10;
              });
              _speakStepPromptAndListen();
            } else if (method == 'Phone') {
              setState(() {
                _authMethod = 'Phone';
                _currentStep = 11;
              });
              _speakStepPromptAndListen();
            }
          },
        );
      case 10:
        return StepEmailInput(
          email: _email,
          language: _selectedLanguage,
          onEmailChanged: (val) => setState(() => _email = val),
          onContinue: _nextStep,
          onChangeMethod: () {
            setState(() => _currentStep = 9);
            _speakStepPromptAndListen();
          },
        );
      case 11:
        return StepPhoneInput(
          phone: _phone,
          language: _selectedLanguage,
          onPhoneChanged: (val) => setState(() => _phone = val),
          onSendCode: _sendVerificationSmsPhone,
          onChangeMethod: () {
            setState(() => _currentStep = 9);
            _speakStepPromptAndListen();
          },
        );
      case 12:
        return StepCreatePassword(
          password: _password,
          language: _selectedLanguage,
          onPasswordChanged: (val) => setState(() => _password = val),
        );
      case 13:
        return StepPermissions(
          language: _selectedLanguage,
          onContinue: () {
            setState(() => _currentStep = 14);
            _speakStepPromptAndListen();
          },
        );
      case 14:
        return StepTermsPrivacy(
          language: _selectedLanguage,
          onAgree: () {
            setState(() => _currentStep = 15);
            _speakStepPromptAndListen();
          },
          onReadDocument: () => setState(() => _showTermsDocument = true),
        );
      case 15:
        return StepUploadPhoto(
          language: _selectedLanguage,
          onPhotoPicked: (file) {
            setState(() {
              _pickedImage = file;
              _currentStep = 16;
            });
            _speakStepPromptAndListen();
          },
          onCancel: () {
            setState(() => _currentStep = 17);
            _speakStepPromptAndListen();
          },
        );
      case 16:
        return StepPhotoConfirmation(
          pickedImage: _pickedImage!,
          language: _selectedLanguage,
          onReupload: () {
            setState(() => _currentStep = 15);
            _speakStepPromptAndListen();
          },
          onContinue: () {
            setState(() => _currentStep = 17);
            _speakStepPromptAndListen();
          },
        );
      case 17:
        return StepNameInput(
          name: _name,
          language: _selectedLanguage,
          onNameChanged: (val) => setState(() => _name = val),
        );
      case 18:
        return StepBirthdayInput(
          birthday: _birthday,
          language: _selectedLanguage,
          onBirthdayChanged: (val) => setState(() => _birthday = val),
        );
      case 19:
        return StepSosContact(
          name: _sosName,
          phone: _sosPhone,
          relationship: _sosRelationship,
          language: _selectedLanguage,
          onNameChanged: (val) => setState(() => _sosName = val),
          onPhoneChanged: (val) => setState(() => _sosPhone = val),
          onRelationshipChanged: (val) => setState(() => _sosRelationship = val),
          onFinish: _handleRegister,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTagalog = _selectedLanguage.toLowerCase().contains('filipino') ||
        _selectedLanguage.toLowerCase().contains('tagalog');

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: AppColors.primaryButton))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Top Appbar Header Row (Back Pill + Step Count)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Pill-shaped back button
                        GestureDetector(
                          onTap: _prevStep,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.lightBackground,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: AppColors.cardBorder.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back_ios_new, size: 14, color: AppColors.primaryText),
                                const SizedBox(width: 6),
                                Text(
                                  SignupL10n.t('back', _selectedLanguage),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Step Indicator Pill (e.g. 1 of 19)
                        if (_shouldShowStepIndicator())
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.lightBackground,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$_currentStep of 19',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryText,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Voice Assistant Status & Validation Banner
                    GestureDetector(
                      onTap: () {
                        setState(() => _isVoiceActivated = !_isVoiceActivated);
                        if (_isVoiceActivated) {
                          _speakStepPromptAndListen();
                        } else {
                          SttService().stopListening((_) {});
                          TtsService().stop();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isVoiceActivated
                              ? (_isAwaitingConfirmation ? Colors.amber.shade50 : Colors.blue.shade50)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isVoiceActivated
                                ? (_isAwaitingConfirmation ? Colors.amber.shade400 : AppColors.primaryButton)
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: _isVoiceActivated
                                  ? (_isAwaitingConfirmation ? Colors.amber : AppColors.primaryButton)
                                  : Colors.grey,
                              child: Icon(
                                _isVoiceActivated
                                    ? (_isAwaitingConfirmation
                                        ? Icons.mark_chat_read_rounded
                                        : (_isListening ? Icons.mic : Icons.volume_up))
                                    : Icons.mic_off,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isVoiceActivated
                                    ? (_isAwaitingConfirmation
                                        ? (isTagalog
                                            ? "Pinili: $_pendingVoiceSelection. Sabihin ang 'Oo', 'Ituloy', o 'Bumalik'"
                                            : "Selected: $_pendingVoiceSelection. Say 'Yes', 'Next', or 'Back'")
                                        : (_voiceFeedbackText.isNotEmpty
                                            ? _voiceFeedbackText
                                            : (isTagalog ? "Nakinig sa iyong boses..." : "Voice activated. Speak your choice...")))
                                    : (isTagalog ? "Voice Mode Muted (Tap to enable)" : "Voice Mode Muted (Tap to enable)"),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isVoiceActivated ? AppColors.primaryText : Colors.grey.shade700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.inter(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: _buildStepContent(),
                      ),
                    ),
                    
                    if (_shouldShowContinueButton()) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryButton,
                            foregroundColor: AppColors.primaryButtonText,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28.0),
                            ),
                          ),
                          onPressed: _nextStep,
                          child: Text(
                            SignupL10n.t('continue', _selectedLanguage),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
