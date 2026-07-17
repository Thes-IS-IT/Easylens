import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
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

  // Registration States (19 Steps)
  bool _isForMyself = true; // Step 1
  List<String> _selectedConditions = []; // Step 2
  String _selectedContrastTheme = 'Default'; // Step 3
  bool _voiceFeedback = true; // Step 4
  bool _hapticFeedback = true; // Step 4
  String _selectedLanguage = 'English'; // Step 5
  String _selectedVoicePersona = 'Aria (Calm)'; // Step 6
  String _selectedUnit = 'Metric'; // Step 7
  String _selectedMobilityAid = 'None'; // Step 8
  
  String _authMethod = ''; // Step 9: 'Google', 'Apple', 'Email', 'Phone'
  String _email = ''; // Step 10
  String _phone = ''; // Step 11
  String _password = ''; // Step 12
  File? _pickedImage; // Step 15
  String _name = ''; // Step 17 ("What should I call you?")
  String _birthday = ''; // Step 18
  
  // Step 19
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
        // Email entered — go straight to password
        if (_email.isEmpty || !_email.contains('@')) return;
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

    if (_phone.isEmpty) {
      setState(() => _smsErrorMessage = 'Please enter a valid phone number');
      return;
    }

    String formattedPhone = _phone.trim();
    if (!formattedPhone.startsWith('+')) {
      formattedPhone = formattedPhone.startsWith('0')
          ? '+63${formattedPhone.substring(1)}'
          : '+63$formattedPhone';
    }

    final success = await _smsService.sendSMS(
      to: formattedPhone,
      message: 'Your EasyLens verification code is: $code',
    );

    if (success) {
      setState(() => _isVerifyingCode = true);
    } else {
      setState(() => _smsErrorMessage = 'Failed to send verification SMS. Please try again.');
    }
  }

  void _verifyCode(String enteredCode) {
    if (enteredCode == _generatedCode) {
      setState(() {
        _isVerifyingCode = false;
        _smsErrorMessage = null;
        _currentStep = 11; // Proceed to Create Password
      });
    } else {
      setState(() {
        _smsErrorMessage = 'Incorrect code. Please check and try again.';
      });
    }
  }

  Future<void> _handleRegister() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final regEmail = _email.isNotEmpty ? _email : "buddy_user@easylens.com";
    final regPassword = _password.isNotEmpty ? _password : "mockPassword123";
    final regName = _name.isNotEmpty ? _name : "Buddy User";
    print("Registering user. Picked photo path: ${_pickedImage?.path}");

    try {
      // 1. Sign up user via Firebase Auth
      EasyLensUser? user;
      if (_authMethod == 'Google') {
        user = _firebaseService.currentUser;
        if (user != null && regName.isNotEmpty) {
          await _firebaseService.updateDisplayName(regName);
          user = _firebaseService.currentUser; // Refresh user display name
        }
      } else {
        user = await _firebaseService.signUp(regEmail, regPassword, regName, _isForMyself);
      }

      if (user != null) {
        String? profilePhotoUrl;
        
        // 2. Upload avatar image to Cloudflare R2 if picked
        if (_pickedImage != null) {
          try {
            print("Uploading profile photo for user: ${user.uid} to Cloudflare R2...");
            profilePhotoUrl = await CloudflareR2Service().uploadAvatar(_pickedImage!, user.uid);
            print("Profile photo uploaded successfully. Public URL: $profilePhotoUrl");
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
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll("Exception:", "").trim();
        _isLoading = false;
        _currentStep = 8; // Fall back to account creation page
      });
    }
  }


  bool _shouldShowStepIndicator() {
    if (_showOtherConditionInput || _showTermsDocument || _isVerifyingCode) {
      return false;
    }
    return true;
  }  bool _shouldShowContinueButton() {
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
        onVerify: _verifyCode,
        onResendCode: _sendVerificationSmsPhone,
        errorMessage: _smsErrorMessage,
      );
    }

    switch (_currentStep) {
      case 1:
        return StepPersona(
          isForMyself: _isForMyself,
          onChanged: (val) => setState(() => _isForMyself = val),
        );
      case 2:
        return StepConditions(
          selectedConditions: _selectedConditions,
          onChanged: (val) => setState(() => _selectedConditions = val),
          onAddCustomCondition: () => setState(() => _showOtherConditionInput = true),
        );
      case 3:
        return StepContrastTheme(
          selectedTheme: _selectedContrastTheme,
          onChanged: (val) {
            setState(() {
              _selectedContrastTheme = val;
            });
            SettingsService().updateSettings(selectedContrastTheme: val);
          },
        );
      case 4:
        return StepAccessibility(
          voiceFeedback: _voiceFeedback,
          hapticFeedback: _hapticFeedback,
          onVoiceChanged: (val) => setState(() => _voiceFeedback = val),
          onHapticChanged: (val) => setState(() => _hapticFeedback = val),
        );
      case 5:
        return StepLanguage(
          selectedLanguage: _selectedLanguage,
          onChanged: (val) => setState(() => _selectedLanguage = val),
        );
      case 6:
        return StepVoicePersona(
          selectedPersona: _selectedVoicePersona,
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
          onChanged: (val) => setState(() => _selectedMobilityAid = val),
        );
      case 8:
        return StepCreateAccount(
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
                    _currentStep = 12; // Social methods skip fields and password setup
                    _isLoading = false;
                  });
                } else {
                  setState(() {
                    _isLoading = false;
                  });
                }
              } catch (e) {
                setState(() {
                  _errorMessage = e.toString().replaceAll("Exception:", "").trim();
                  _isLoading = false;
                });
              }
            } else if (method == 'Email') {
              setState(() {
                _authMethod = 'Email';
                _currentStep = 9;
              });
            }
          },
        );
      case 9:
        return StepEmailInput(
          email: _email,
          onEmailChanged: (val) => setState(() => _email = val),
          onContinue: () {
            if (_email.isEmpty || !_email.contains('@')) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Please enter a valid email address'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            setState(() => _currentStep = 11);
          },
          onChangeMethod: () => setState(() => _currentStep = 8),
        );
      case 10:
        return StepPhoneInput(
          phone: _phone,
          onPhoneChanged: (val) => setState(() => _phone = val),
          onSendCode: _sendVerificationSmsPhone,
          onChangeMethod: () => setState(() => _currentStep = 8),
        );
      case 11:
        return StepCreatePassword(
          password: _password,
          onPasswordChanged: (val) => setState(() => _password = val),
        );
      case 12:
        return StepPermissions(
          onContinue: () => setState(() => _currentStep = 13),
        );
      case 13:
        return StepTermsPrivacy(
          onAgree: () => setState(() => _currentStep = 14),
          onReadDocument: () => setState(() => _showTermsDocument = true),
        );
      case 14:
        return StepUploadPhoto(
          onPhotoPicked: (file) {
            setState(() {
              _pickedImage = file;
              _currentStep = 15; // Proceed to confirmation step
            });
          },
          onCancel: () => setState(() => _currentStep = 16),
        );
      case 15:
        return StepPhotoConfirmation(
          pickedImage: _pickedImage!,
          onReupload: () => setState(() => _currentStep = 14),
          onContinue: () => setState(() => _currentStep = 16),
        );
      case 16:
        return StepNameInput(
          name: _name,
          onNameChanged: (val) => setState(() => _name = val),
        );
      case 17:
        return StepBirthdayInput(
          birthday: _birthday,
          onBirthdayChanged: (val) => setState(() => _birthday = val),
        );
      case 18:
        return StepSosContact(
          name: _sosName,
          phone: _sosPhone,
          relationship: _sosRelationship,
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
                  ? Center(child: CircularProgressIndicator(color: AppColors.primaryButton),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pushes content below the floating back button
                        const SizedBox(height: 135),
                        
                        if (_errorMessage != null) ...[
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                        ],
                        
                        // Dynamic Step Indicator (Step X of 18)
                        if (_shouldShowStepIndicator())
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Text(
                              'Step $_currentStep of 18',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryText,
                              ),
                            ),
                          ),
                        
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 32.0),
                              child: _buildStepContent(),
                            ),
                          ),
                        ),
                        
                        // Bottom Continue Button (if step does not use custom action buttons)
                        if (_shouldShowContinueButton())
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryButton,
                          foregroundColor: AppColors.primaryButtonText,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28.0),
                                  ),
                                ),
                                onPressed: _nextStep,
                                child: Text(
                                  'Continue',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          
          // Absolute Positioned Floating Back Button
          Positioned(
            top: 75.0,
            left: 24.0,
            child: SizedBox(
              width: 95.0,
              height: 44.0,
              child: GestureDetector(
                onTap: _prevStep,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    border: Border.all(color: AppColors.cardBorder, width: 1.5),
                    borderRadius: BorderRadius.circular(30.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowColor,
                        blurRadius: 10.0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chevron_left,
                        size: 20,
                        color: AppColors.primaryText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Back',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
