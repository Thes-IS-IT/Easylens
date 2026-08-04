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
import '../../services/emergency_contact_service.dart';

import '../../services/storage/cloudflare_r2_service.dart';
import '../../widgets/screen_tutorial_card.dart';
import 'celebration_screen.dart';
import 'steps/signup_steps.dart';
import 'steps/voice_input_widget.dart';
import '../../services/sound_service.dart';
import '../../utils/app_route.dart';

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
  bool _rememberMe = true;
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
  int? _lastSpokenStep;
  bool _isSpeakingPrompt = false;
  bool _isProcessingCommand = false;

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
    TtsService().stop();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _speakStepPromptAndListen() async {
    if (!_isVoiceActivated || !mounted) return;
    if (_isSpeakingPrompt) return;

    // Speak prompt ONCE per step to avoid repetitive voice loops
    if (_lastSpokenStep == _currentStep && !_isAwaitingConfirmation) {
      _startListeningForStep();
      return;
    }
    _lastSpokenStep = _currentStep;

    // Ensure STT mic is stopped while assistant speaks
    SttService().stopListening((_) {});
    _sttTimeoutTimer?.cancel();

    final isTagalog = _selectedLanguage.toLowerCase().contains('filipino') ||
        _selectedLanguage.toLowerCase().contains('tagalog');

    String prompt = '';
    switch (_currentStep) {
      case 1:
        prompt = isTagalog
            ? "Hakbang 1 sa 17. Piliin ang iyong wika. Sabihin ang English o Filipino."
            : "Step 1 of 17. Choose your language. Say English or Filipino.";
        break;
      case 2:
        prompt = isTagalog
            ? "Hakbang 2 sa 17. Paraan ng Pagpaparehistro. Paano mo gustong mag-set up? Sabihin ang Boses para sa boses, o Manwal para sa pindot."
            : "Step 2 of 17. Registration Method. How would you like to set up your account? Say Voice for voice commands, or Manual for touch controls.";
        break;
      case 3:
        prompt = isTagalog
            ? "Hakbang 3 sa 17. Para kanino ito? Sabihin ang Para sa akin o Para sa iba."
            : "Step 3 of 17. Who is this for? Say Myself or Someone else.";
        break;
      case 4:
        prompt = isTagalog
            ? "Hakbang 4 sa 17. Piliin ang iyong mga kondisyon sa paningin. Maaaring sabihin ang: Cataracts, Glaucoma, Macular Degeneration, Low Vision, Diabetic Retinopathy, Retinitis Pigmentosa, Color Blindness, Hemianopia, o Elderly para sa mga nakakatanda. Sabihin ang Ituloy kapag tapos na."
            : "Step 4 of 17. Select your vision conditions. You can say: Cataracts, Glaucoma, Macular Degeneration, Low Vision, Diabetic Retinopathy, Retinitis Pigmentosa, Color Blindness, Hemianopia, or Elderly. Say Continue when finished.";
        break;
      case 5:
        prompt = isTagalog
            ? "Hakbang 5 sa 17. Tema ng Kontras. Pumili ng kulay ng interface. Sabihin ang Default, Black on White, White on Black, Green on Black, Yellow on Black, o Cyan on Black."
            : "Step 5 of 17. Contrast Theme. Select the color interface. Say Default, Black on White, White on Black, Green on Black, Yellow on Black, or Cyan on Black.";
        break;
      case 6:
        prompt = isTagalog
            ? "Hakbang 6 sa 17. Gabay sa Aksesibilidad. Sabihin ang Boses on, Boses off, Vibrate on, o Vibrate off."
            : "Step 6 of 17. Helpful Cues. Say Voice guide on, Voice guide off, Vibration on, or Vibration off.";
        break;
      case 7:
        prompt = isTagalog
            ? "Hakbang 7 sa 17. Pumili ng boses ng assistant. Sabihin ang Max, Aria, Nova, Echo, Bella, o Buddy."
            : "Step 7 of 17. Choose a Voice Persona. Say Max, Aria, Nova, Echo, Bella, or Buddy.";
        break;
      case 8:
        prompt = isTagalog
            ? "Hakbang 8 sa 17. Kagamitan sa paglalakad. Sabihin ang Tungkod, Aso, Smart Glasses, Salamin, Wheelchair, Walker, o Wala."
            : "Step 8 of 17. Walking Tools and Mobility Aids. Say White Cane, Guide Dog, Smart Glasses, Eyeglasses, Wheelchair, Walker, or None.";
        break;
      case 9:
        prompt = isTagalog
            ? "Hakbang 9 sa 17. Sabihin o i-type ang iyong email address."
            : "Step 9 of 17. Speak or enter your email address.";
        break;
      case 10:
        prompt = isTagalog
            ? "Hakbang 10 sa 17. Pumili ng password. Sabihin o i-type ang iyong password."
            : "Step 10 of 17. Choose a password. Speak or enter your password.";
        break;
      case 11:
        prompt = isTagalog
            ? "Hakbang 11 sa 17. Pahintulot. Payagan ang camera, mikropono, at lokasyon. Sabihin ang Ituloy o Agree."
            : "Step 11 of 17. Enable Permissions. Allow camera, microphone, and location access. Say Continue or Agree.";
        break;
      case 12:
        prompt = isTagalog
            ? "Hakbang 12 sa 17. Mga Tuntunin at Privacy. Sabihin ang Sumasang-ayon ako."
            : "Step 12 of 17. Terms and Privacy Policy. Say Agree to accept.";
        break;
      case 13:
        prompt = isTagalog
            ? "Hakbang 13 sa 17. Larawan ng Profile. Sabihin ang Gallery, Camera, o Laktawan."
            : "Step 13 of 17. Profile Photo. Say Gallery, Camera, or Skip.";
        break;
      case 14:
        prompt = isTagalog
            ? "Hakbang 14 sa 17. Kumpirmahin ang Larawan. Sabihin ang Ituloy o Baguhin."
            : "Step 14 of 17. Photo Confirmation. Say Continue or Reupload.";
        break;
      case 15:
        prompt = isTagalog
            ? "Hakbang 15 sa 17. Ano ang pangalan mo? Sabihin o i-type ang iyong pangalan."
            : "Step 15 of 17. What should I call you? Speak or enter your name.";
        break;
      case 16:
        prompt = isTagalog
            ? "Hakbang 16 sa 17. Kaarawan. Sabihin o i-type ang taon ng iyong kaarawan."
            : "Step 16 of 17. Birthday. Speak or enter your birth year or birthday.";
        break;
      case 17:
        prompt = isTagalog
            ? "Hakbang 17 sa 17. Emergency SOS Contact. Sabihin o i-type ang pangalan at numero, o sabihin ang Tapusin."
            : "Step 17 of 17. Emergency SOS Contact. Speak or enter contact details, or say Finish setting up.";
        break;
      default:
        prompt = "Step $_currentStep of 17.";
    }

    if (!mounted) return;
    setState(() {
      _voiceFeedbackText = prompt;
    });

    // 1. Mute STT completely while assistant reads instruction
    _isSpeakingPrompt = true;
    SttService().stopListening((_) {});
    _sttTimeoutTimer?.cancel();

    // 2. Await complete TTS speech output
    await TtsService().speakAwait(prompt);

    if (!mounted) return;
    // 3. Pause 400ms after TTS finishes to allow speaker echo to decay completely
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _isSpeakingPrompt = false;

    // 4. NOW enable microphone for user's turn
    if (mounted && _isVoiceActivated) {
      _startListeningForStep();
    }
  }

  bool _hasRecognizedKeyword(String input) {
    final text = input.toLowerCase().trim();
    final commonCmds = [
      'back', 'go back', 'previous', 'bumalik', 'pabalik', 'balik', 'nakaraan', 'u-turn', 'kanselain', 'cancel',
      'next', 'continue', 'proceed', 'ituloy', 'sunod', 'sumunod', 'ipagpatuloy', 'sige',
      'repeat', 'read', 're-read', 'ulit', 'paki-ulit', 'ulitin', 'sabihin ulit',
      'yes', 'yeah', 'yep', 'confirm', 'oo', 'opopo', 'opo', 'correct', 'tama',
      'no', 'nope', 'change', 'different', 'hindi', 'baguhin', 'mali', 'palitan'
    ];
    if (commonCmds.any((cmd) => text.contains(cmd))) return true;    switch (_currentStep) {
      case 1:
        return text.contains('english') || text.contains('inggles') || text.contains('filipino') || text.contains('tagalog') || text.contains('pinoy');
      case 2:
        return text.contains('voice') || text.contains('boses') || text.contains('salita') || text.contains('isa') || text.contains('manual') || text.contains('pindot') || text.contains('kamay') || text.contains('dalawa');
      case 3:
        return text.contains('myself') || text.contains('me') || text.contains('akin') || text.contains('sarili') || text.contains('ako') || text.contains('someone') || text.contains('else') || text.contains('iba');
      case 4:
        return text.contains('low vision') || text.contains('malabo') || text.contains('blind') || text.contains('bulag') || text.contains('color') || text.contains('elderly') || text.contains('matanda') || text.contains('done') || text.contains('tapos');
      case 5:
        return text.contains('default') || text.contains('black') || text.contains('white') || text.contains('green') || text.contains('berde') || text.contains('yellow') || text.contains('dilaw') || text.contains('cyan');
      case 6:
        return text.contains('voice') || text.contains('boses') || text.contains('vibration') || text.contains('haptic') || text.contains('vibrate');
      case 7:
        return text.contains('max') || text.contains('aria') || text.contains('nova') || text.contains('echo') || text.contains('bella') || text.contains('leo') || text.contains('buddy');
      case 8:
        return text.contains('cane') || text.contains('tungkod') || text.contains('dog') || text.contains('aso') || text.contains('glasses') || text.contains('salamin') || text.contains('wheelchair') || text.contains('walker') || text.contains('none') || text.contains('wala');
      case 9:
        return text.trim().length >= 3;
      case 10:
        return text.length >= 4;
      case 11:
        return text.contains('continue') || text.contains('agree') || text.contains('ituloy') || text.contains('sumasang');
      case 12:
        return text.contains('agree') || text.contains('sumasang') || text.contains('oo');
      case 13:
        return text.contains('skip') || text.contains('camera') || text.contains('gallery') || text.contains('laktawan');
      case 14:
        return text.contains('continue') || text.contains('reupload') || text.contains('baguhin') || text.contains('ituloy');
      case 15:
      case 16:
      case 17:
        return text.length >= 2;
      default:
        return false;
    }
  }

  void _startListeningForStep() {
    if (!_isVoiceActivated || !mounted || _isSpeakingPrompt) return;

    SttService().startListening(
      onResult: (speechResult, isFinal) {
        if (!mounted || speechResult.trim().isEmpty || _isProcessingCommand || _isSpeakingPrompt) return;
        if (isFinal || _hasRecognizedKeyword(speechResult)) {
          _isProcessingCommand = true;
          _handleVoiceCommand(speechResult);
          Future.delayed(const Duration(milliseconds: 1200), () {
            _isProcessingCommand = false;
          });
        }
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
    if (!mounted) return;

    final isTagalog = _selectedLanguage.toLowerCase().contains('filipino') ||
        _selectedLanguage.toLowerCase().contains('tagalog');

    setState(() {
      _pendingVoiceSelection = selectionName;
      _isAwaitingConfirmation = true;
      _voiceFeedbackText = isTagalog
          ? "Pinili mo ang $selectionName. Sabihin ang Oo o i-tap ang Ituloy para kumpirmahin, Baguhin para pumili ulit, o Bumalik."
          : "Selected: $selectionName. Say 'Yes' or tap 'Continue' to confirm, or 'Change' to pick again.";
    });

    if (!_isVoiceActivated) return;

    // 1. Mute STT completely while assistant speaks confirmation
    _isSpeakingPrompt = true;
    SttService().stopListening((_) {});
    _sttTimeoutTimer?.cancel();

    // 2. Await complete TTS speech output
    await TtsService().speakAwait(_voiceFeedbackText);

    // 3. Pause 400ms after TTS finishes to allow speaker echo to decay completely
    await Future.delayed(const Duration(milliseconds: 400));
    _isSpeakingPrompt = false;

    // 4. NOW enable microphone for user's turn
    if (mounted && _isVoiceActivated) {
      _startListeningForStep();
    }
  }

  void _handleVoiceCommand(String rawText) {
    final text = rawText.toLowerCase().trim();
    final isTagalog = _selectedLanguage.toLowerCase().contains('filipino') ||
        _selectedLanguage.toLowerCase().contains('tagalog');

    // 1. GLOBAL INTERRUPT: "Back" / "Go back"
    if (text == 'back' || text == 'go back' || text == 'previous' || text == 'bumalik' || text == 'pabalik' || text == 'u-turn' || text == 'balik') {
      _prevStep();
      return;
    }

    // 2. CONFIRMATION HANDLER
    if (_isAwaitingConfirmation) {
      final confirmCmds = ['yes', 'yeah', 'yep', 'next', 'confirm', 'proceed', 'sige', 'oo', 'opopo', 'opo', 'continue', 'go', 'okay', 'correct', 'tama', 'ituloy'];
      final cancelCmds = ['no', 'nope', 'change', 'wrong', 'mali', 'hindi', 'baguhin', 'ulitin', 'reenter'];

      if (confirmCmds.any((c) => text.contains(c))) {
        _isAwaitingConfirmation = false;
        TtsService().speak(isTagalog ? "Kumpirmado." : "Confirmed.");
        _nextStep();
        return;
      } else if (cancelCmds.any((c) => text.contains(c))) {
        _isAwaitingConfirmation = false;
        final cancelText = isTagalog ? "Sige, paki-ulit ang iyong sinabi." : "Okay, please repeat your input.";
        TtsService().speakAwait(cancelText).then((_) async {
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            _startListeningForStep();
          }
        });
        return;
      }
    }

    // 3. STEP-BY-STEP INTENT PARSING
    switch (_currentStep) {
      case 1: // Language
        if (text.contains('english') || text.contains('inggles')) {
          setState(() => _selectedLanguage = 'English');
          SettingsService().updateSettings(selectedLanguage: 'English');
          _triggerVoiceConfirmation('English');
        } else if (text.contains('filipino') || text.contains('tagalog') || text.contains('pinoy')) {
          setState(() => _selectedLanguage = 'Tagalog');
          SettingsService().updateSettings(selectedLanguage: 'Tagalog');
          _triggerVoiceConfirmation('Filipino');
        }
        break;

      case 2: // Signup Mode
        if (text.contains('voice') || text.contains('boses') || text.contains('salita') || text.contains('isa')) {
          setState(() => _isVoiceActivated = true);
          _triggerVoiceConfirmation('Voice Command Fillup');
        } else if (text.contains('manual') || text.contains('pindot') || text.contains('kamay') || text.contains('dalawa')) {
          setState(() => _isVoiceActivated = false);
          TtsService().speak(isTagalog ? "Manwal na pagpuno ang napili. Naka-off ang boses." : "Manual Form Fillup selected. Speech assistance muted.");
          SttService().stopListening((_) {});
          _nextStep();
        }
        break;

      case 3: // Persona
        if (text.contains('myself') || text.contains('me') || text.contains('akin') || text.contains('sarili') || text.contains('ako')) {
          setState(() => _isForMyself = true);
          _triggerVoiceConfirmation('Myself');
        } else if (text.contains('someone') || text.contains('else') || text.contains('iba')) {
          setState(() => _isForMyself = false);
          _triggerVoiceConfirmation('Someone else');
        }
        break;

      case 4: // Conditions
        if (text.contains('done') || text.contains('tapos') || text.contains('ituloy') || text.contains('continue')) {
          _triggerVoiceConfirmation(_selectedConditions.isEmpty ? 'No conditions' : _selectedConditions.join(', '));
        } else {
          final conds = <String>[];
          if (text.contains('cataract')) conds.add('Cataracts');
          if (text.contains('glaucoma')) conds.add('Glaucoma');
          if (text.contains('macular')) conds.add('Macular Degeneration');
          if (text.contains('low vision') || text.contains('malabo')) conds.add('Low Vision');
          if (text.contains('diabetic')) conds.add('Diabetic Retinopathy');
          if (text.contains('retinitis')) conds.add('Retinitis Pigmentosa');
          if (text.contains('color')) conds.add('Color Blindness');
          if (text.contains('hemianopia')) conds.add('Hemianopia');
          if (text.contains('elderly') || text.contains('matanda')) conds.add('Elderly');
          if (conds.isNotEmpty) {
            setState(() {
              for (var c in conds) {
                if (!_selectedConditions.contains(c)) _selectedConditions.add(c);
              }
            });
            _triggerVoiceConfirmation(_selectedConditions.join(', '));
          }
        }
        break;

      case 5: // Contrast Theme
        if (text.contains('default')) {
          setState(() => _selectedContrastTheme = 'Default');
          _triggerVoiceConfirmation('Default Theme');
        } else if (text.contains('black on white')) {
          setState(() => _selectedContrastTheme = 'Black on White');
          _triggerVoiceConfirmation('Black on White Theme');
        } else if (text.contains('white on black')) {
          setState(() => _selectedContrastTheme = 'White on Black');
          _triggerVoiceConfirmation('White on Black Theme');
        } else if (text.contains('green')) {
          setState(() => _selectedContrastTheme = 'Green on Black');
          _triggerVoiceConfirmation('Green on Black Theme');
        } else if (text.contains('yellow') || text.contains('dilaw')) {
          setState(() => _selectedContrastTheme = 'Yellow on Black');
          _triggerVoiceConfirmation('Yellow on Black Theme');
        } else if (text.contains('cyan')) {
          setState(() => _selectedContrastTheme = 'Cyan on Black');
          _triggerVoiceConfirmation('Cyan on Black Theme');
        }
        break;

      case 6: // Accessibility
        if (text.contains('voice on') || text.contains('boses on')) {
          setState(() => _voiceFeedback = true);
          _triggerVoiceConfirmation('Voice On');
        } else if (text.contains('voice off') || text.contains('boses off')) {
          setState(() => _voiceFeedback = false);
          _triggerVoiceConfirmation('Voice Off');
        } else if (text.contains('vibration on') || text.contains('haptic on') || text.contains('vibrate on')) {
          setState(() => _hapticFeedback = true);
          _triggerVoiceConfirmation('Vibration On');
        } else if (text.contains('vibration off') || text.contains('haptic off') || text.contains('vibrate off')) {
          setState(() => _hapticFeedback = false);
          _triggerVoiceConfirmation('Vibration Off');
        }
        break;

      case 7: // Voice Persona
        final personas = ['Max', 'Aria', 'Nova', 'Echo', 'Bella', 'Buddy', 'Leo'];
        for (var p in personas) {
          if (text.contains(p.toLowerCase())) {
            final fullName = (p == 'Buddy' || p == 'Leo') ? 'Buddy (Child)' : '$p (Calm)';
            setState(() => _selectedVoicePersona = (p == 'Buddy' || p == 'Leo') ? 'Buddy (Child)' : p);
            _triggerVoiceConfirmation('$p Persona');
            break;
          }
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
        } else if (text.contains('glasses') || text.contains('salamin')) {
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

      case 9: // Email Input
        final formattedEmail = formatSpokenEmail(text);
        if (formattedEmail.isNotEmpty) {
          setState(() => _email = formattedEmail);
          _triggerVoiceConfirmation(formattedEmail);
        }
        break;

      case 10: // Password Input
        if (text.length >= 4) {
          setState(() => _password = rawText);
          _triggerVoiceConfirmation("your password");
        }
        break;

      case 11: // Permissions
        _triggerVoiceConfirmation("Permissions enabled");
        break;

      case 12: // Terms Privacy
        if (text.contains('agree') || text.contains('sumasang')) {
          _triggerVoiceConfirmation("Agreed to terms");
        }
        break;

      case 13: // Photo Upload
        if (text.contains('skip') || text.contains('laktawan')) {
          setState(() => _currentStep = 15);
          _speakStepPromptAndListen();
        } else if (text.contains('camera')) {
          _triggerVoiceConfirmation("Camera Photo");
        } else if (text.contains('gallery')) {
          _triggerVoiceConfirmation("Gallery Photo");
        }
        break;

      case 14: // Photo Confirmation
        _triggerVoiceConfirmation("Photo confirmed");
        break;

      case 15: // Name Input
        if (rawText.trim().isNotEmpty) {
          setState(() => _name = rawText.trim());
          _triggerVoiceConfirmation(_name);
        }
        break;

      case 16: // Birthday Input
        final formattedBday = formatSpokenBirthday(rawText);
        if (formattedBday.isNotEmpty) {
          setState(() => _birthday = formattedBday);
          _triggerVoiceConfirmation(_birthday);
        }
        break;

      case 17: // SOS Contact
        if (text.contains('finish') || text.contains('tapos') || text.contains('done')) {
          _handleRegister();
        } else if (rawText.trim().isNotEmpty) {
          setState(() => _sosName = rawText.trim());
          _triggerVoiceConfirmation("SOS Contact $rawText");
        }
        break;
    }
  }

  Future<void> _nextStep() async {
    SoundService.playPop();
    _lastSpokenStep = null;
    _isAwaitingConfirmation = false;
    // Input validation & exception handling per step
    if (_currentStep == 9) {
      // Step 9: Email Step
      try {
        final emailClean = _email.trim();
        final isTagalog = _selectedLanguage.toLowerCase().contains('filipino') ||
            _selectedLanguage.toLowerCase().contains('tagalog');

        if (emailClean.isEmpty) {
          final msg = isTagalog 
              ? 'Mangyaring ilagay ang iyong email address' 
              : 'Please enter your email address';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
          return;
        }
        if (!emailClean.contains('@')) {
          final msg = isTagalog 
              ? 'Kailangan ng "@" symbol sa email address (hal. pangalan@gmail.com)' 
              : 'Email address must contain an "@" symbol (e.g. name@gmail.com)';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
          return;
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailClean)) {
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

        setState(() => _isLoading = true);
        final isRegistered = await _firebaseService.isEmailAlreadyRegistered(emailClean);
        if (!mounted) return;
        setState(() => _isLoading = false);

        if (isRegistered) {
          final errorMsg = isTagalog
              ? 'Ang email na ito ay ginagamit na. Mangyaring gumamit ng ibang email address.'
              : 'This email address is already in use. Please try using another email address.';
          
          setState(() {
            _errorMessage = errorMsg;
          });
          TtsService().speak(errorMsg);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          return;
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid input: ${e.toString()}'), backgroundColor: Colors.red),
        );
        return;
      }
      
      // Clear error message if validation succeeds
      setState(() => _errorMessage = null);
    } else if (_currentStep == 10) {
      // Step 10: Password Step
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
    } else if (_currentStep == 15) {
      // Step 15: Name Step
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
      if (_currentStep < 17) {
        _currentStep++;
      }
    });

    _speakStepPromptAndListen();
  }

  void _prevStep() {
    SoundService.playTab();
    TtsService().stop();
    SttService().stopListening((_) {});
    _sttTimeoutTimer?.cancel();
    _lastSpokenStep = null;
    _isAwaitingConfirmation = false;
    _pendingVoiceSelection = '';
    if (_showOtherConditionInput) {
      setState(() => _showOtherConditionInput = false);
    } else if (_showTermsDocument) {
      setState(() => _showTermsDocument = false);
    } else if (_isVerifyingCode) {
      setState(() => _isVerifyingCode = false);
    } else if (_currentStep > 1) {
      setState(() {
        _currentStep--;
        if (_currentStep == 14 && _pickedImage == null) {
          _currentStep = 13; // Skip photo confirmation when going back if no photo was uploaded
        }
      });
      _speakStepPromptAndListen();
    } else {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
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

    if (_phone.isEmpty || _phone.trim().length != 11) {
      final isTagalog = _selectedLanguage.toLowerCase().contains('tagalog') || _selectedLanguage.toLowerCase().contains('filipino');
      setState(() => _smsErrorMessage = isTagalog 
          ? 'Mangyaring maglagay ng wastong 11-digit na numero (hal. 09123456789)' 
          : 'Please enter a valid 11-digit phone number (e.g. 09123456789)');
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
    final msg = error.toString().toLowerCase();
    final isTagalog = _selectedLanguage.toLowerCase().contains('filipino') ||
        _selectedLanguage.toLowerCase().contains('tagalog');

    if (msg.contains('email-already-in-use')) {
      return isTagalog
          ? 'Ang email na ito ay ginagamit na. Mangyaring gumamit ng ibang email address.'
          : 'This email address is already in use. Please try using another email address.';
    } else if (msg.contains('weak-password')) {
      return isTagalog
          ? 'Masyadong mahina ang password. Gumamit ng 6 o higit pang karakter.'
          : 'Password is too weak. Please use at least 6 characters.';
    } else if (msg.contains('invalid-email') || msg.contains('invalid_email') || msg.contains('invalid')) {
      return isTagalog
          ? 'Hindi balido ang email format. Mangyaring subukan ulit.'
          : 'Invalid email format. Please check your email address.';
    } else if (msg.contains('network-request-failed') || msg.contains('network_error')) {
      return isTagalog
          ? 'Maling koneksyon sa internet. Paki-subukan ulit.'
          : 'Connection error. Please check your internet connection.';
    } else if (msg.contains('sign_in_failed') || msg.contains('10') || msg.contains('platformexception')) {
      return 'Google Sign-In service error. Please sign in with Email.';
    }

    String clean = msg
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'[\{\}\[\]"\\:]'), ' ')
        .replaceAll(RegExp(r'^(platformexception|firebaseauthexception|exception):\s*'), '')
        .replaceAll(RegExp(r'com\.google\.android\.gms.*'), 'Google Service Error')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (clean.isEmpty || clean == 'error' || clean.length < 3) {
      return 'Registration error. Please try again.';
    }
    return clean;
  }

  Future<void> _handleRegister() async {
    final regEmail = _email.trim();
    final regPassword = _password.trim();
    final regName = _name.isNotEmpty ? _name.trim() : "Buddy User";
    final isTagalog = _selectedLanguage.toLowerCase().contains('filipino') ||
        _selectedLanguage.toLowerCase().contains('tagalog');

    // Validate email format and password
    if (regEmail.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(regEmail)) {
      final invalidMsg = isTagalog
          ? 'Maling email address format. Mangyaring ipasok ang iyong totoong email.'
          : 'Invalid email address format. Please enter a valid email address.';
      setState(() {
        _isLoading = false;
        _errorMessage = invalidMsg;
        _currentStep = 9;
      });
      TtsService().speak(invalidMsg);
      return;
    }

    if (regPassword.length < 6) {
      final passMsg = isTagalog
          ? 'Masyadong maikli ang password. Dapat ay may 6 o higit pang karakter.'
          : 'Password is too short. Please use at least 6 characters.';
      setState(() {
        _isLoading = false;
        _errorMessage = passMsg;
        _currentStep = 10;
      });
      TtsService().speak(passMsg);
      return;
    }

    // Final safety-net: re-validate SOS contact phone before account creation
    if (_sosPhone.trim().isNotEmpty && _sosPhone.trim().length != 11) {
      final sosPhoneMsg = isTagalog
          ? 'Ang numero ng SOS contact ay dapat eksaktong 11 digits (hal. 09123456789). Mangyaring bumalik at itama.'
          : 'SOS contact phone must be exactly 11 digits (e.g. 09123456789). Please go back and fix it.';
      setState(() {
        _isLoading = false;
        _errorMessage = sosPhoneMsg;
        _currentStep = 17;
      });
      TtsService().speak(sosPhoneMsg);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      EasyLensUser? user = _googleUserSession ?? _firebaseService.currentUser;

      if (user == null) {
        if (_authMethod == 'Google') {
          // Use real Google Sign-In — returns the actual Gmail address from the account picker
          user = await _firebaseService.signInWithGoogle(rememberMe: _rememberMe);
          if (user == null) {
            setState(() {
              _isLoading = false;
              _errorMessage = isTagalog
                  ? 'Hindi matagumpay ang Google Sign-In. Mangyaring subukan ulit.'
                  : 'Google Sign-In failed or was cancelled. Please try again.';
            });
            return;
          }
        } else {
          // Direct real Firebase registration (Email auth)
          user = await _firebaseService.signUp(regEmail, regPassword, regName, _isForMyself, rememberMe: _rememberMe);
        }
      }

      if (user == null) {
        throw Exception("Registration failed. Please check your account details.");
      }

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

      // 5. Store/Sync SOS Contact to EmergencyContactService & Firestore
      if (_sosName.isNotEmpty || _sosPhone.isNotEmpty) {
        final normSosPhone = EmergencyContactService.normalizePhoneNumber(_sosPhone);
        try {
          await EmergencyContactService().saveContact(
            SharedEmergencyContact(
              name: _sosName.isNotEmpty ? _sosName : "SOS Contact",
              phone: normSosPhone,
              relationship: _sosRelationship.isNotEmpty ? _sosRelationship : "Family",
              isActive: true,
            ),
          );
        } catch (e) {
          print("Warning: EmergencyContactService save error: $e");
        }

        final sosJson = {
          'name': _sosName.isNotEmpty ? _sosName : "SOS Contact",
          'phone': normSosPhone,
          'relationship': _sosRelationship.isNotEmpty ? _sosRelationship : "Family",
        };
        try {
          await _firebaseService.syncContactToCloud(user.uid, sosJson);
        } catch (sosErr) {
          print("Warning: syncContactToCloud error: $sosErr");
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        // Mark tutorials as unseen for this new user — they will see each one once
        await ScreenTutorialCard.resetForNewUser();
        Navigator.of(context).pushAndRemoveUntil(
          AppRoute.rocketLaunch(CelebrationScreen(userName: regName)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        final friendlyMsg = _getFriendlyErrorMessage(e);
        final errStr = e.toString().toLowerCase();

        setState(() {
          _isLoading = false;
          _errorMessage = friendlyMsg;
          if (errStr.contains('email-already-in-use')) {
            _currentStep = 9; // Jump back to Email input step so user can change email
          } else if (errStr.contains('weak-password')) {
            _currentStep = 10; // Jump back to Password step
          }
        });

        TtsService().speak(friendlyMsg);
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
      9,  // Email input (inline buttons)
      12, // Terms & Privacy (inline buttons)
      13, // Upload Photo (inline buttons)
      14, // Photo Confirmation (inline buttons)
      17, // SOS Contact (inline Finish setup button)
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
        return StepEmailInput(
          email: _email,
          language: _selectedLanguage,
          onEmailChanged: (val) => setState(() => _email = val),
          onContinue: _nextStep,
          onChangeMethod: () {},
        );
      case 10:
        return StepCreatePassword(
          password: _password,
          language: _selectedLanguage,
          onPasswordChanged: (val) => setState(() => _password = val),
          onRememberMeChanged: (val) => setState(() => _rememberMe = val),
        );
      case 11:
        return StepPermissions(
          language: _selectedLanguage,
          onContinue: () {
            setState(() => _currentStep = 12);
            _speakStepPromptAndListen();
          },
        );
      case 12:
        return StepTermsPrivacy(
          language: _selectedLanguage,
          onAgree: () {
            setState(() => _currentStep = 13);
            _speakStepPromptAndListen();
          },
          onReadDocument: () => setState(() => _showTermsDocument = true),
        );
      case 13:
        return StepUploadPhoto(
          language: _selectedLanguage,
          onPhotoPicked: (file) {
            setState(() {
              _pickedImage = file;
              _currentStep = 14;
            });
            _speakStepPromptAndListen();
          },
          onCancel: () {
            setState(() => _currentStep = 15);
            _speakStepPromptAndListen();
          },
        );
      case 14:
        if (_pickedImage == null) {
          return StepUploadPhoto(
            language: _selectedLanguage,
            onPhotoPicked: (file) {
              setState(() {
                _pickedImage = file;
                _currentStep = 14;
              });
              _speakStepPromptAndListen();
            },
            onCancel: () {
              setState(() => _currentStep = 15);
              _speakStepPromptAndListen();
            },
          );
        }
        return StepPhotoConfirmation(
          pickedImage: _pickedImage!,
          language: _selectedLanguage,
          onReupload: () {
            setState(() {
              _pickedImage = null;
              _currentStep = 13;
            });
            _speakStepPromptAndListen();
          },
          onContinue: () {
            setState(() => _currentStep = 15);
            _speakStepPromptAndListen();
          },
        );
      case 15:
        return StepNameInput(
          name: _name,
          language: _selectedLanguage,
          onNameChanged: (val) => setState(() => _name = val),
        );
      case 16:
        return StepBirthdayInput(
          birthday: _birthday,
          language: _selectedLanguage,
          onBirthdayChanged: (val) => setState(() => _birthday = val),
        );
      case 17:
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _prevStep();
      },
      child: Scaffold(
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

                          // Step Indicator Pill (e.g. 1 of 17)
                          if (_shouldShowStepIndicator())
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.lightBackground,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$_currentStep of 17',
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
                          color: AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isVoiceActivated
                                ? (_isAwaitingConfirmation ? const Color(0xFFE5A63C) : AppColors.primaryButton)
                                : AppColors.cardBorder.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: _isVoiceActivated
                                  ? (_isAwaitingConfirmation ? const Color(0xFFE5A63C) : AppColors.primaryButton)
                                  : AppColors.cardBorder.withValues(alpha: 0.4),
                              child: Icon(
                                _isVoiceActivated
                                    ? (_isAwaitingConfirmation
                                        ? Icons.mark_chat_read_rounded
                                        : (_isListening ? Icons.mic : Icons.volume_up))
                                    : Icons.mic_off,
                                color: AppColors.primaryButtonText,
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
                                  color: AppColors.primaryText,
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
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                          return Stack(
                            alignment: Alignment.topCenter,
                            children: <Widget>[
                              ...previousChildren,
                              if (currentChild != null) currentChild,
                            ],
                          );
                        },
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: Align(
                          key: ValueKey<int>(_currentStep),
                          alignment: Alignment.topCenter,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: _buildStepContent(),
                          ),
                        ),
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
      ),
    );
  }
}
