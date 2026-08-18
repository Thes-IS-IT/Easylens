import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'constants/colors.dart';
import 'services/firebase_service.dart';
import 'services/settings_service.dart';
import 'services/rag_service.dart';
import 'screens/welcome/welcome_screen.dart';
import 'services/notification_service.dart';
import 'services/esp32_service.dart';
import 'services/sound_service.dart';
import 'widgets/speech_navigation_overlay.dart';
import 'widgets/confetti_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-load flutter_sound_button click sound
  SoundService.init();

  // Global Flutter error handler to prevent native framework crashes
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('[EasyLens Error Boundary] Flutter error: ${details.exception}');
  };

  // Load environment variables (.env file)
  try {
    await dotenv.load(fileName: ".env");
    print(".env variables loaded successfully");
  } catch (e) {
    print("Warning: .env file failed to load: $e");
  }

  // Initialize Firebase Service prior to frame 1 render so Auth user state syncs cleanly
  try {
    final firebaseService = FirebaseService();
    await firebaseService.initialize();
  } catch (e) {
    print("Firebase init safe catch: $e");
  }

  runApp(const EasyLensApp());

  // Initialize background UI & knowledge base services asynchronously
  Future.microtask(() async {
    // Lock screen orientation to portrait
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } catch (e) {
      print('Orientation lock notice: $e');
    }

    // Hide phone navigation and status bars globally (Immersive sticky mode)
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (e) {
      print('System UI mode notice: $e');
    }

    // Load RAG knowledge base on boot; Gemma LLM model warms up lazily when AI Assistant is opened
    try {
      RagService().loadKnowledgeBase().catchError((e) {
        print("RAG knowledge base load warning: $e");
      });
    } catch (e) {
      print("RAG init safe catch: $e");
    }

    // Initialize notification service (loads persisted notifications + daily Buddy follow-up)
    try {
      await NotificationService().initialize();
    } catch (e) {
      print("NotificationService init safe catch: $e");
    }

    // Initialize ESP32 service (restores last used stream URL from prefs)
    try {
      await Esp32Service().initialize();
    } catch (e) {
      print("Esp32Service init safe catch: $e");
    }
  });
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class EasyLensApp extends StatelessWidget {
  const EasyLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsService = SettingsService();
    return AnimatedBuilder(
      animation: settingsService,
      builder: (context, child) {
        final primaryColor = AppColors.primaryButton;
        final primaryTextColor = AppColors.primaryText;
        final bgColor = AppColors.primaryBackground;

        return MaterialApp(
          title: 'EasyLens',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          theme: ThemeData(
            useMaterial3: true,
            primaryColor: primaryColor,
            scaffoldBackgroundColor: bgColor,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryColor,
              primary: primaryColor,
              onPrimary: AppColors.primaryButtonText,
              surface: bgColor,
              onSurface: primaryTextColor,
            ),
            checkboxTheme: CheckboxThemeData(
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return Colors.transparent;
              }),
              checkColor: WidgetStateProperty.all(AppColors.primaryButtonText),
              side: BorderSide(color: primaryColor, width: 2),
            ),
            radioTheme: RadioThemeData(
              fillColor: WidgetStateProperty.all(primaryColor),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primaryButtonText;
                }
                return AppColors.textMuted;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return AppColors.unselectedBorder;
              }),
            ),
            sliderTheme: SliderThemeData(
              activeTrackColor: primaryColor,
              thumbColor: primaryColor,
              inactiveTrackColor: AppColors.unselectedBorder,
            ),
            progressIndicatorTheme: ProgressIndicatorThemeData(
              color: primaryColor,
            ),
            inputDecorationTheme: InputDecorationTheme(
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.unselectedBorder),
              ),
              hintStyle: TextStyle(color: AppColors.textMuted),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: AppColors.primaryButtonText,
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryTextColor,
                side: BorderSide(color: primaryColor, width: 1.5),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
              ),
            ),
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: primaryColor,
              selectionColor: primaryColor.withValues(alpha: 0.3),
              selectionHandleColor: primaryColor,
            ),
          ),
          home: const WelcomeScreen(),
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(settingsService.textSizeScale),
              ),
              child: ConfettiOverlay(
                child: SpeechNavigationOverlay(child: child!),
              ),
            );
          },
        );
      },
    );
  }
}
