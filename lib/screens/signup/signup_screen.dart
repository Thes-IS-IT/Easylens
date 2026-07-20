import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../l10n/signup_strings.dart';
import '../../services/firebase_service.dart';
import '../../services/settings_service.dart';
import '../../services/tts_service.dart';
import '../../services/sms_service.dart';

import '../../services/storage/cloudflare_r2_service.dart';
import '../dashboard/dashboard_screen.dart';
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

  // Registration States (18 Steps)
  String _selectedLanguage = 'English'; // Step 1 — FIRST so all subsequent steps are localized
  bool _isForMyself = true; // Step 2
  List<String> _selectedConditions = []; // Step 3
  String _selectedContrastTheme = 'Default'; // Step 4
  bool _voiceFeedback = true; // Step 5
  bool _hapticFeedback = true; // Step 5
  String _selectedVoicePersona = 'Aria (Calm)'; // Step 6
  String _selectedMobilityAid = 'None'; // Step 7
  String _selectedUnit = 'Metric'; // Step 8
  
  String _authMethod = ''; // Step 8: 'Google', 'Apple', 'Email', 'Phone'
  String _email = ''; // Step 9
  String _phone = ''; // Step 10
  String _password = ''; // Step 11
  File? _pickedImage; // Step 14
  String _name = ''; // Step 16 ("What should I call you?")
  String _birthday = ''; // Step 17
  
  // Step 18 (SOS Contact)
  String _sosName = '';
  String _sosPhone = '';
  String _sosRelationship = '';

  final _firebaseService = FirebaseService();
  final _smsService = SmsService();
  String? _generatedCode;
  String? _smsErrorMessage;

  @override
  void initState() {
    super.initState();
    SettingsService().addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    SettingsService().removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _nextStep() {
    // Input validation & exception handling per step
    if (_currentStep == 10) {
      // Email Step
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
      // Phone Step
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
    } else if (_currentStep == 12) {
      // Password Step
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
      // Name Step
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
      if (_currentStep == 8) {
        if (_authMethod == 'Email') {
          _currentStep = 9;
        } else if (_authMethod == 'Phone') {
          _currentStep = 10;
        } else {
          _currentStep = 12;
        }
      } else if (_currentStep == 9) {
        _currentStep = 11;
      } else if (_currentStep < 18) {
        _currentStep++;
      }
    });
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
        if (_currentStep == 11) {
          if (_authMethod == 'Email') {
            _currentStep = 9;
          } else if (_authMethod == 'Phone') {
            _currentStep = 10;
          } else {
            _currentStep = 8;
          }
        } else if (_currentStep == 12) {
          if (_authMethod == 'Google' || _authMethod == 'Apple') {
            _currentStep = 8;
          } else {
            _currentStep = 11;
          }
        } else {
          _currentStep--;
        }
      });
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
        _currentStep = 11; // Proceed to Create Password
      });
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
    }
    return msg.replaceAll("Exception:", "").replaceAll("FirebaseAuthException:", "").trim();
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
      // 1. Sign up user via Firebase Auth
      EasyLensUser? user;
      if (_authMethod == 'Google') {
        user = _firebaseService.currentUser;
        if (user != null && regName.isNotEmpty) {
          await _firebaseService.updateDisplayName(regName);
          user = _firebaseService.currentUser;
        }
      } else {
        user = await _firebaseService.signUp(regEmail, regPassword, regName, _isForMyself);
      }

      if (user != null) {
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
        await _firebaseService.syncPreferencesToCloud(user.uid, prefsJson);

        // 5. Store/Sync SOS Contact to Firestore (and D1)
        if (_sosName.isNotEmpty || _sosPhone.isNotEmpty) {
          final sosJson = {
            'name': _sosName,
            'phone': _sosPhone,
            'relationship': _sosRelationship,
          };
          await _firebaseService.syncContactToCloud(user.uid, sosJson);
        }

        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  CelebrationScreen(userName: user?.displayName ?? _name),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _errorMessage = "We couldn't set up your account. Please try again.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getFriendlyErrorMessage(e);
          _isLoading = false;
          _currentStep = 8; // Fall back to account creation step
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
      8,  // Create Account (inline list buttons)
      9,  // Email input (inline buttons)
      10, // Phone input (inline buttons)
      13, // Terms & Privacy (inline buttons)
      14, // Upload Photo (inline buttons)
      15, // Photo Confirmation (inline buttons)
      18, // SOS Contact (inline Finish setup button)
    ];
    return !stepsWithCustomActions.contains(_currentStep);
  }

  Widget _buildStepContent() {
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
          },
        );
      case 2:
        return StepPersona(
          isForMyself: _isForMyself,
          language: _selectedLanguage,
          onChanged: (val) => setState(() => _isForMyself = val),
        );
      case 3:
        return StepConditions(
          selectedConditions: _selectedConditions,
          language: _selectedLanguage,
          onChanged: (val) => setState(() => _selectedConditions = val),
          onAddCustomCondition: () => setState(() => _showOtherConditionInput = true),
        );
      case 4:
        return StepContrastTheme(
          selectedTheme: _selectedContrastTheme,
          language: _selectedLanguage,
          onChanged: (val) {
            setState(() {
              _selectedContrastTheme = val;
            });
            SettingsService().updateSettings(selectedContrastTheme: val);
          },
        );
      case 5:
        return StepAccessibility(
          voiceFeedback: _voiceFeedback,
          hapticFeedback: _hapticFeedback,
          language: _selectedLanguage,
          onVoiceChanged: (val) => setState(() => _voiceFeedback = val),
          onHapticChanged: (val) => setState(() => _hapticFeedback = val),
        );
      case 6:
        return StepVoicePersona(
          selectedPersona: _selectedVoicePersona,
          language: _selectedLanguage,
          onChanged: (val) {
            setState(() {
              _selectedVoicePersona = val;
            });
            SettingsService().updateSettings(selectedVoicePersona: val);
            TtsService().speak("This is the $val voice persona.");
          },
        );
      case 7:
        return StepMobilityAids(
          selectedAid: _selectedMobilityAid,
          language: _selectedLanguage,
          onChanged: (val) => setState(() => _selectedMobilityAid = val),
        );
      case 8:
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
                    _authMethod = 'Google';
                    _email = user.email;
                    _name = user.displayName;
                    _currentStep = 12; // Social methods skip password setup
                    _isLoading = false;
                  });
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
                _currentStep = 9;
              });
            } else if (method == 'Phone') {
              setState(() {
                _authMethod = 'Phone';
                _currentStep = 10;
              });
            }
          },
        );
      case 9:
        return StepEmailInput(
          email: _email,
          language: _selectedLanguage,
          onEmailChanged: (val) => setState(() => _email = val),
          onContinue: _nextStep,
          onChangeMethod: () => setState(() => _currentStep = 8),
        );
      case 10:
        return StepPhoneInput(
          phone: _phone,
          language: _selectedLanguage,
          onPhoneChanged: (val) => setState(() => _phone = val),
          onSendCode: _sendVerificationSmsPhone,
          onChangeMethod: () => setState(() => _currentStep = 8),
        );
      case 11:
        return StepCreatePassword(
          password: _password,
          language: _selectedLanguage,
          onPasswordChanged: (val) => setState(() => _password = val),
        );
      case 12:
        return StepPermissions(
          language: _selectedLanguage,
          onContinue: () => setState(() => _currentStep = 13),
        );
      case 13:
        return StepTermsPrivacy(
          language: _selectedLanguage,
          onAgree: () => setState(() => _currentStep = 14),
          onReadDocument: () => setState(() => _showTermsDocument = true),
        );
      case 14:
        return StepUploadPhoto(
          language: _selectedLanguage,
          onPhotoPicked: (file) {
            setState(() {
              _pickedImage = file;
              _currentStep = 15;
            });
          },
          onCancel: () => setState(() => _currentStep = 16),
        );
      case 15:
        return StepPhotoConfirmation(
          pickedImage: _pickedImage!,
          language: _selectedLanguage,
          onReupload: () => setState(() => _currentStep = 14),
          onContinue: () => setState(() => _currentStep = 16),
        );
      case 16:
        return StepNameInput(
          name: _name,
          language: _selectedLanguage,
          onNameChanged: (val) => setState(() => _name = val),
        );
      case 17:
        return StepBirthdayInput(
          birthday: _birthday,
          language: _selectedLanguage,
          onBirthdayChanged: (val) => setState(() => _birthday = val),
        );
      case 18:
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
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: Stack(
        children: [
          // Scrollable Step Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.primaryButton))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 135),
                        
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
                          const SizedBox(height: 16),
                        ],

                        Expanded(
                          child: SingleChildScrollView(
                            child: _buildStepContent(),
                          ),
                        ),
                        
                        if (_shouldShowContinueButton()) ...[
                          const SizedBox(height: 16),
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
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
            ),
          ),

          // Floating Back & Step Indicator Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                color: AppColors.primaryBackground,
                child: Row(
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

                    // Step Indicator Pill (1/18)
                    if (_shouldShowStepIndicator())
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_currentStep of 18',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
