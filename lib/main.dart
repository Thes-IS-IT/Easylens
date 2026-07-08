import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/firebase_service.dart';
import 'services/settings_service.dart';
import 'services/rag_service.dart';
import 'screens/welcome/welcome_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock screen orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Hide phone navigation and status bars globally (Immersive sticky mode)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Load environment variables (.env file)
  try {
    await dotenv.load(fileName: ".env");
    print(".env variables loaded successfully");
  } catch (e) {
    print("Warning: .env file failed to load: $e");
  }

  // Initialize Firebase Service (safely fallbacks to Mock Mode if config plist/json is not set up)
  final firebaseService = FirebaseService();
  await firebaseService.initialize();

  // Initialize localized Gemma offline model engine
  try {
    await RagService().initializeGemma();
  } catch (e) {
    print("Gemma initialization warning: $e");
  }

  // Initialize notification service (loads persisted notifications + daily Buddy follow-up)
  await NotificationService().initialize();
 
  runApp(const EasyLensApp());
}

class EasyLensApp extends StatelessWidget {
  const EasyLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsService = SettingsService();
    return AnimatedBuilder(
      animation: settingsService,
      builder: (context, child) {
        return MaterialApp(
          title: 'EasyLens',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            primaryColor: const Color(0xFF002663),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF002663),
              primary: const Color(0xFF002663),
            ),
          ),
          home: const WelcomeScreen(),
        );
      },
    );
  }
}
