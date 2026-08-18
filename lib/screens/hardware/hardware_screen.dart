import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import '../../constants/colors.dart';
import '../../services/tts_service.dart';
import '../face_registration/face_registration_screen.dart';
import '../../services/stt_service.dart';
import '../../services/rag_service.dart';
import '../../services/settings_service.dart';
import '../../services/sound_service.dart';
import '../../services/tflite_processor.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/active_navigation_service.dart';
import '../../services/danger_warning_service.dart';
import '../../services/face_registration_service.dart';
import '../../services/notification_service.dart';
import '../../services/esp32_service.dart';
import 'package:battery_plus/battery_plus.dart';
import '../../widgets/screen_tutorial_card.dart';
import '../dashboard/components/buddy_assistant_sheet.dart';
import '../../widgets/speech_navigation_overlay.dart';
import '../../utils/app_route.dart';
import 'components/pairing_wizard.dart';
import 'components/hud_mode_selector.dart';
import 'components/hud_controls_panel.dart';
import 'components/hud_camera_view.dart';
import 'components/camera_loading_overlay.dart';
import '../../widgets/local_ai_instructions_dialog.dart';

enum HudMode {
  navigation,
  objectDetection,
  scenery,
  faceRecognition,
}

class HardwareScreen extends StatefulWidget {
  /// Global lock state notifier so the dashboard can render a fullscreen overlay.
  static final ValueNotifier<bool> screenLockNotifier = ValueNotifier<bool>(false);

  final bool isActive;
  final int initialStep;
  const HardwareScreen({super.key, this.isActive = true, this.initialStep = 1});

  @override
  State<HardwareScreen> createState() => _HardwareScreenState();
}

class _HardwareScreenState extends State<HardwareScreen> with WidgetsBindingObserver {
  // Navigation: 1=Main, 2=Pairing instructions, 3=Pairing progress GIF, 4=Object Detection Screen
  int _pairStep = 1;

  // Camera & ML Kit Variables
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isInitializingCamera = false;
  ImageLabeler? _imageLabeler;
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isProcessingFrame = false;
  bool _wasPathBlocked = false;
  DateTime? _lastHazardDetectionTime;

  // Native Object Detector
  ObjectDetector? _objectDetector;
  bool _isModelLoaded = false;
  int _lastObjectDetectionTime = 0;
  List<DetectedObject> _detectedObjectsList = [];
  List<String> _cocoLabels = [];
  final TfliteProcessor _tfliteProcessor = TfliteProcessor();
  List<SSDResult> _tfliteDetections = [];
  bool _isProcessingObjectDetection = false;
  int _lastLabelerTime = 0;
  final List<String> _conversationHistory = [];
  bool _isContinuousVoiceEnabled = false;
  String _continuousVoiceText = '';
  Timer? _silenceTimer;
  bool get _isScreenLocked => HardwareScreen.screenLockNotifier.value;
  set _isScreenLocked(bool v) => HardwareScreen.screenLockNotifier.value = v;
  bool _useLocalAI = true;

  StreamSubscription<BatteryState>? _batterySubscription;
  final Battery _battery = Battery();
  Timer? _objectDetectionTimer;

  // Track bounding boxes for detected objects
  List<Rect> _detectedObjectRects = [];
  List<String> _detectedObjectLabels = [];

  // Active detected status values matching user design
  String _activeTitle = "Path Clear";
  String _activeDescription = "No hazards detected nearby.";
  Color _statusCardBg = const Color(0xFFE8F5E9); // Light green matching first screen mockup
  IconData _statusIcon = Icons.check_circle_outline;
  Color _statusIconColor = Colors.green;

  // Controls values S01
  int _batteryPercent = 67;
  bool _isBluetoothConnected = true;
  bool _isGeminiEnabled = false;
  bool _isWifiOn = false;
  bool _isAudioSpeaker = true; // true = Phone Speaker, false = Glasses
  bool _useMobileCamera = false;
  bool _isFlashOn = false;

  // Cooldown trackers for TTS announcements S01
  final Map<String, DateTime> _lastSpokenMap = {};
  String _lastSpokenObjectText = '';
  String _lastSpokenSceneryText = '';

  // Gemini Dialog details
  bool _isGeminiListening = false;
  String _geminiSpokenQuestion = "";
  String _geminiAssistantResponse = "";
  bool _isThinking = false;

  List<String> _latestMLKitLabels = [];
  bool _isCameraCovered = false;
  bool _isDetectionEnabled = true;
  HudMode _selectedHudMode = HudMode.objectDetection;
  bool _isPaused = false;
  bool _isStreamingPausedForBuddy = false;
  Uint8List? _latestNv21Bytes;
  int _latestWidth = 0;
  int _latestHeight = 0;
  String _voiceState = "idle"; // S01: Tracks speech state ('idle', 'listening', 'thinking', 'speaking')
  File? _esp32CachedFile;

  // Face recognition
  FaceDetector? _faceDetector;
  int _lastFaceDetectionTime = 0;
  String _detectedFaceName = '';
  DateTime? _lastFaceAnnouncedAt;
  List<FaceProfile> _registeredFaces = [];
  List<Face> _detectedFacesList = [];
  Size _faceImageSize = Size.zero;
  final Map<int, String> _faceIdToNameMap = {};
  Map<int, Offset> _lastFaceCentroids = {};

  String _lastGuidanceText = "";
  DateTime? _lastGuidanceTime;

  // Dynamic Hazard simulation lists
  final List<Map<String, dynamic>> _hazardSimulations = [
    {
      'title': 'Path Clear',
      'desc': 'No hazards detected nearby.',
      'bg': Color(0xFFE8F5E9),
      'icon': Icons.check_circle_outline,
      'iconColor': Colors.green,
      'speech': 'Path clear. No hazards detected nearby.'
    },
    {
      'title': 'Traffic Sign Located',
      'desc': 'Traffic sign detected. Slow down and proceed carefully.',
      'bg': Color(0xFFE8EAF6),
      'icon': Icons.remove_road_rounded,
      'iconColor': Colors.indigo,
      'speech': 'Traffic sign located. Slow down and proceed carefully.'
    },
    {
      'title': 'Caution',
      'desc': 'Obstacle approaching. Proceed slowly.',
      'bg': Color(0xFFFFFDE7),
      'icon': Icons.warning_amber_rounded,
      'iconColor': Colors.amber,
      'speech': 'Caution. Obstacle approaching. Proceed slowly.'
    },
    {
      'title': 'Stairs Detected',
      'desc': 'Slow down and step carefully.',
      'bg': Color(0xFFFFF8E1),
      'icon': Icons.stairs_rounded,
      'iconColor': Colors.orange,
      'speech': 'Stairs detected. Slow down and step carefully.'
    },
    {
      'title': 'Low Light Detected',
      'desc': 'Camera visibility is low. Scanning accuracy reduced.',
      'bg': Color(0xFFFFFDE7),
      'icon': Icons.lightbulb_outline_rounded,
      'iconColor': Colors.amber,
      'speech': 'Low light detected. Scanning accuracy reduced.'
    },
    {
      'title': 'Moving Too Fast',
      'desc': 'Hold steady for a moment to resume scanning.',
      'bg': Color(0xFFFFF8E1),
      'icon': Icons.access_time_rounded,
      'iconColor': Colors.orange,
      'speech': 'Moving too fast. Hold steady for a moment.'
    },
    {
      'title': 'Vehicle Detected',
      'desc': 'Vehicle approaching. Please slow down and wait.',
      'bg': Color(0xFFFFF8E1),
      'icon': Icons.directions_car_rounded,
      'iconColor': Colors.orange,
      'speech': 'Vehicle detected. A vehicle is approaching. Please slow down and wait.'
    },
    {
      'title': 'Damaged Pathway',
      'desc': 'Pothole detected. Slow down and step carefully.',
      'bg': Color(0xFFFFF8E1),
      'icon': Icons.trending_down_rounded,
      'iconColor': Colors.orange,
      'speech': 'Damaged pathway. Pothole detected. Slow down and step carefully.'
    },
    {
      'title': 'Multiple Hazards',
      'desc': 'Complex environment detected. Proceed with extreme caution.',
      'bg': Color(0xFFFFF8E1),
      'icon': Icons.warning_amber_rounded,
      'iconColor': Colors.orange,
      'speech': 'Multiple hazards. Complex environment detected. Proceed with extreme caution.'
    },
    {
      'title': 'Obstacle Ahead',
      'desc': 'Object blocking path. Slow down.',
      'bg': Color(0xFFFFF8E1),
      'icon': Icons.block_flipped,
      'iconColor': Colors.orange,
      'speech': 'Obstacle ahead. Object blocking path. Slow down.'
    },
    {
      'title': 'Fire Hazard!',
      'desc': 'Fire or heavy smoke detected nearby. Move away immediately.',
      'bg': Color(0xFFFFEBEE),
      'icon': Icons.local_fire_department_rounded,
      'iconColor': Colors.red,
      'speech': 'Fire hazard! Fire or heavy smoke detected nearby. Move away immediately.'
    },
    {
      'title': 'STOP!',
      'desc': 'Immediate hazard in your path.',
      'bg': Color(0xFFFFEBEE),
      'icon': Icons.error_outline_rounded,
      'iconColor': Colors.red,
      'speech': 'STOP! Immediate hazard in your path.'
    },
    {
      'title': 'Person Ahead',
      'desc': 'A person is in front of you. Be careful!',
      'bg': Color(0xFFE8EAF6),
      'icon': Icons.person_rounded,
      'iconColor': Colors.indigo,
      'speech': 'Person detected. A person is in front of you, be careful.'
    },
    {
      'title': 'GO Signal Detected',
      'desc': 'Go or walk signal detected. You may proceed.',
      'bg': Color(0xFFE8F5E9),
      'icon': Icons.arrow_circle_right_outlined,
      'iconColor': Colors.green,
      'speech': 'Go signal detected. Proceed carefully.'
    },
    {
      'title': 'Traffic Light Detected',
      'desc': 'Traffic light detected. Slow down and check the signal.',
      'bg': Color(0xFFE8EAF6),
      'icon': Icons.traffic_rounded,
      'iconColor': Colors.indigo,
      'speech': 'Traffic light detected. Slow down and check the signal.'
    },
    {
      'title': 'Door Detected',
      'desc': 'You are approaching a door.',
      'bg': Color(0xFFE0F7FA),
      'icon': Icons.door_front_door_outlined,
      'iconColor': Colors.teal,
      'speech': 'You are approaching a door.'
    },
    {
      'title': 'CRITICAL: VEHICLE TOO CLOSE!',
      'desc': 'Vehicle is dangerously close! Stop or avoid immediately!',
      'bg': Color(0xFFFFEBEE),
      'icon': Icons.directions_car_rounded,
      'iconColor': Colors.red,
      'speech': 'Warning! Vehicle is too close! Stop or avoid immediately!'
    }
  ];

  @override
  void initState() {
    super.initState();
    _pairStep = widget.initialStep;
    _initializeMLKitLabeler();
    _loadObjectDetectionModel();
    _initBatteryTracker();
    _initFaceDetector();
    _loadRegisteredFaces();
    FaceRegistrationService().addListener(_loadRegisteredFaces);
    Esp32Service().addListener(_onEsp32FrameAvailable);
    BuddyAssistantSheet.isVisible.addListener(_onBuddyVisibilityChanged);
    SpeechNavigationNotifier.hardwareControlNotifier.addListener(_onSpeechHardwareControl);

    WidgetsBinding.instance.addObserver(this);
    if (_pairStep == 4 && !_isCameraInitialized) {
      _initializeCamera();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScreenTutorialCard.showIfNeeded(
        context,
        tutorialKey: 'camera',
        titleKey: 'tutorial_camera_title',
        descriptionKey: 'tutorial_camera_desc',
        mascotAsset: 'assets/mascots/03_loading.gif',
      );
    });
  }

  @override
  void didUpdateWidget(covariant HardwareScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      setState(() {
        _isPaused = !widget.isActive;
      });
      if (!widget.isActive) {
        TtsService().stop();
      }
    }
  }

  Future<void> _pauseStreamAndSpeaker() async {
    setState(() {
      _isPaused = true;
    });
    await TtsService().stop();
  }

  Future<void> _resumeStreamAndSpeaker() async {
    setState(() {
      _isPaused = false;
    });
  }

  void _onSpeechHardwareControl() {
    final control = SpeechNavigationNotifier.hardwareControlNotifier.value;
    if (control == null || !mounted) return;

    final isTagalog = SettingsService().selectedLanguage.toLowerCase().contains('tagalog') || SettingsService().selectedLanguage.toLowerCase().contains('filipino');

    if (control == 'use_camera') {
      _initializeCamera();
      return;
    } else if (control == 'add_device') {
      _onAddDevice();
      return;
    }

    if (control == 'scenery') {
      setState(() {
        _selectedHudMode = HudMode.scenery;
      });
      _applyModeChange(HudMode.scenery);
    } else if (control == 'faces') {
      setState(() {
        _selectedHudMode = HudMode.faceRecognition;
      });
      _applyModeChange(HudMode.faceRecognition);
    } else if (control == 'navigation') {
      setState(() {
        _selectedHudMode = HudMode.navigation;
      });
      _applyModeChange(HudMode.navigation);
    } else if (control == 'objects') {
      setState(() {
        _selectedHudMode = HudMode.objectDetection;
      });
      _applyModeChange(HudMode.objectDetection);
    } else if (control == 'bluetooth') {
      setState(() {
        _isBluetoothConnected = !_isBluetoothConnected;
      });
      TtsService().speak(
        _isBluetoothConnected 
            ? (isTagalog ? "Konektado na ang salamin." : "Glasses connected.")
            : (isTagalog ? "Idinekoneta ang salamin." : "Glasses disconnected.")
      );
    } else if (control == 'gemini') {
      setState(() {
        if (_isContinuousVoiceEnabled && !_useLocalAI) {
          _isContinuousVoiceEnabled = false;
          _isGeminiEnabled = false;
          _silenceTimer?.cancel();
          _conversationHistory.clear();
          SttService().stopListening((_) {});
          TtsService().stop();
          TtsService().speak(isTagalog ? "Naka-off na ang tuloy-tuloy na boses." : "Continuous voice disabled.");
        } else {
          _useLocalAI = false;
          _isContinuousVoiceEnabled = true;
          _isGeminiEnabled = true;
          _conversationHistory.clear();
          TtsService().speak(isTagalog ? "Aktibo ang Advance AI. Simulan ang tuloy-tuloy na boses." : "Advanced online AI active. Continuous voice enabled.");
          _runContinuousVoiceLoop();
        }
      });
    } else if (control == 'local_ai') {
      setState(() {
        if (_isContinuousVoiceEnabled && _useLocalAI) {
          _isContinuousVoiceEnabled = false;
          _isGeminiEnabled = false;
          _silenceTimer?.cancel();
          _conversationHistory.clear();
          SttService().stopListening((_) {});
          TtsService().stop();
          TtsService().speak(isTagalog ? "Naka-off na ang tuloy-tuloy na boses." : "Continuous voice disabled.");
        } else {
          _useLocalAI = true;
          _isContinuousVoiceEnabled = true;
          _isGeminiEnabled = false;
          _conversationHistory.clear();
          TtsService().speak(isTagalog ? "Aktibo ang Local AI. Simulan ang tuloy-tuloy na boses." : "Local offline AI active. Continuous voice enabled.");
          _runContinuousVoiceLoop();
          LocalAiInstructionsDialog.show(context);
        }
      });
    } else if (control == 'audio') {
      setState(() {
        _isAudioSpeaker = !_isAudioSpeaker;
      });
      TtsService().speak(
        _isAudioSpeaker 
            ? (isTagalog ? "Output sa speaker." : "Outputting to speaker.")
            : (isTagalog ? "Output sa salamin." : "Outputting to glasses.")
      );
    } else if (control == 'network') {
      setState(() {
        _isWifiOn = !_isWifiOn;
      });
      TtsService().speak(
        _isWifiOn 
            ? (isTagalog ? "Naka-on ang internet." : "Network connection enabled.")
            : (isTagalog ? "Naka-off ang internet." : "Network connection disabled.")
      );
    } else if (control == 'lock') {
      setState(() {
        _isScreenLocked = !_isScreenLocked;
      });
      TtsService().speak(
        _isScreenLocked 
            ? (isTagalog ? "Naka-lock ang screen." : "Screen locked.")
            : (isTagalog ? "Naka-unlock ang screen." : "Screen unlocked.")
      );
    }
  }

  void _onCameraFrameReceived(CameraImage image) {
    if (_isPaused) return;
    if (!_isDetectionEnabled) return;
    if (_isProcessingFrame) return;
    if (!mounted) return;

    _isProcessingFrame = true;

    Future.microtask(() async {
      if (!mounted || (_selectedHudMode == HudMode.objectDetection && !_tfliteProcessor.isReady)) {
        _isProcessingFrame = false;
        return;
      }
      try {
        final nv21Bytes = _yuvToNv21Sync(image);
        final yBytes = Uint8List.fromList(image.planes[0].bytes);
        final width = image.width;
        final height = image.height;
        _latestNv21Bytes = nv21Bytes;
        _latestWidth = width;
        _latestHeight = height;
        final nowMs = DateTime.now().millisecondsSinceEpoch;

        if (_selectedHudMode == HudMode.faceRecognition) {
          if (nowMs - _lastFaceDetectionTime > 800 && _faceDetector != null) {
            _lastFaceDetectionTime = nowMs;
            await _detectFaceOnFrame(nv21Bytes, width, height);
          }
        } else if (_selectedHudMode == HudMode.navigation) {
          if (nowMs - _lastObjectDetectionTime > 800 && _objectDetector != null) {
            _lastObjectDetectionTime = nowMs;
            await _detectObjectsOnFrame(nv21Bytes, width, height);
          } else if (nowMs - _lastLabelerTime > 800) {
            _lastLabelerTime = nowMs;
            await _processCameraImage(nv21Bytes, yBytes, width, height);
          }
        } else if (_selectedHudMode == HudMode.objectDetection) {
          if (nowMs - _lastObjectDetectionTime > 180 && !_isProcessingObjectDetection) {
            _lastObjectDetectionTime = nowMs;
            unawaited(_detectAndProcessTfliteOnly(nv21Bytes, width, height));
          }
        } else {
          await _processCameraImage(nv21Bytes, yBytes, width, height);
        }
      } catch (e) {
        print("ML Kit frame processing error: $e");
      } finally {
        await Future.delayed(const Duration(milliseconds: 400));
        _isProcessingFrame = false;
      }
    });
  }

  void _onBuddyVisibilityChanged() {
    final isBuddyVisible = BuddyAssistantSheet.isVisible.value;
    if (isBuddyVisible) {
      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        try {
          _cameraController!.stopImageStream();
          setState(() {
            _isStreamingPausedForBuddy = true;
          });
          print('[Camera] Paused image stream because Buddy Assistant is active.');
        } catch (e) {
          print('[Camera] Error stopping image stream: $e');
        }
      }
    } else {
      if (_isStreamingPausedForBuddy && _cameraController != null && _cameraController!.value.isInitialized) {
        setState(() {
          _isStreamingPausedForBuddy = false;
        });
        try {
          _cameraController!.startImageStream(_onCameraFrameReceived);
          print('[Camera] Resumed image stream because Buddy Assistant is closed.');
        } catch (e) {
          print('[Camera] Error restarting image stream: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    FaceRegistrationService().removeListener(_loadRegisteredFaces);
    BuddyAssistantSheet.isVisible.removeListener(_onBuddyVisibilityChanged);
    SpeechNavigationNotifier.hardwareControlNotifier.removeListener(_onSpeechHardwareControl);
    Esp32Service().removeListener(_onEsp32FrameAvailable);
    _silenceTimer?.cancel();
    SttService().stopListening((_) {});
    TtsService().stop();
    _batterySubscription?.cancel();
    _objectDetectionTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _objectDetector?.close();
    _tfliteProcessor.dispose();
    // Stop the image stream BEFORE disposing the camera controller
    // to prevent frames from piling up in native memory after disposal.
    try {
      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        _cameraController!.stopImageStream();
      }
    } catch (_) {}
    _cameraController?.dispose();
    _imageLabeler?.close();
    _textRecognizer.close();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      try {
        if (_cameraController!.value.isStreamingImages) {
          _cameraController!.stopImageStream();
        }
      } catch (_) {}
    } else if (state == AppLifecycleState.resumed) {
      if (!_cameraController!.value.isStreamingImages && mounted && !_isPaused) {
        try {
          _cameraController!.startImageStream(_onCameraFrameReceived);
        } catch (_) {}
      }
    }
  }

  Future<void> _loadCocoLabels() async {
    try {
      final labelsText = await rootBundle.loadString('assets/models/coco_labels.txt');
      if (mounted) {
        setState(() {
          _cocoLabels = labelsText.split('\n').map((e) => e.trim()).toList();
        });
      }
    } catch (e) {
      print("Error loading COCO labels: $e");
    }
  }

  Future<String> _getOrExtractTfliteModel() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/ssd_mobilenet_v2.tflite');
    
    if (await file.exists()) {
      final size = await file.length();
      if (size > 10000000) {
        return file.path;
      }
    }
    
    print('[ObjectDetector] Extracting ssd_mobilenet_v2.tflite from assets to ${file.path}...');
    final byteData = await rootBundle.load('assets/models/ssd_mobilenet_v2.tflite');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      flush: true,
    );
    print('[ObjectDetector] Extraction complete.');
    return file.path;
  }

  Future<void> _loadObjectDetectionModel() async {
    try {
      await _loadCocoLabels();
      final options = ObjectDetectorOptions(
        mode: DetectionMode.stream,
        classifyObjects: true,
        multipleObjects: true,
      );
      _objectDetector = ObjectDetector(options: options);
      setState(() {
        _isModelLoaded = true;
      });
      print("Google ML Kit Base Object Detector initialized successfully");
    } catch (e) {
      print("Error loading Google ML Kit Base Object Detector: $e");
    }

    try {
      final modelBytes = await rootBundle.load('assets/models/ssd_mobilenet.tflite');
      final labelsContent = await rootBundle.loadString('assets/models/ssd_labels.txt');
      await _tfliteProcessor.init(modelBytes.buffer.asUint8List(), labelsContent);
      print("[SSD] SSD MobileNet V1 initialized successfully with SSD labels. isReady=${_tfliteProcessor.isReady}");
    } catch (e) {
      print("[SSD] Non-fatal: SSD MobileNet model not loaded: $e");
    }
  }

  Future<void> _initBatteryTracker() async {
    // Get initial battery level S01
    try {
      final level = await _battery.batteryLevel;
      if (mounted) {
        setState(() {
          _batteryPercent = level;
        });
      }
    } catch (e) {
      print("Error getting initial battery level: $e");
    }

    // Subscribe to battery level/state changes S01
    _batterySubscription = _battery.onBatteryStateChanged.listen((BatteryState state) async {
      try {
        final level = await _battery.batteryLevel;
        if (mounted) {
          setState(() {
            _batteryPercent = level;
          });
        }
      } catch (e) {
        print("Error getting battery level: $e");
      }
    });
  }

  void _toggleDetection(bool enabled) {
    setState(() {
      _isDetectionEnabled = enabled;
      if (!enabled) {
        _detectedObjectsList = [];
        _tfliteDetections = [];
        _detectedObjectLabels = [];
        _detectedObjectRects = [];
        _activeTitle = "Detection Disabled";
        _activeDescription = "Hazards scanning is currently paused.";
        _statusCardBg = Colors.grey.shade100;
        _statusIcon = Icons.pause_circle_outline;
        _statusIconColor = Colors.grey;
      } else {
        _activeTitle = "Path Clear";
        _activeDescription = "No hazards detected nearby.";
        _statusCardBg = const Color(0xFFE8F5E9);
        _statusIcon = Icons.check_circle_outline;
        _statusIconColor = Colors.green;
      }
    });
  }

  void _applyModeChange(HudMode mode) {
    setState(() {
      _detectedObjectsList = [];
      _detectedObjectLabels = [];
      _detectedObjectRects = [];
      _latestMLKitLabels = [];
      _detectedFacesList = [];
      _detectedFaceName = '';
      _lastSpokenSceneryText = '';
    });

    String voiceMessage = "";
    switch (mode) {
      case HudMode.navigation:
        voiceMessage = "Navigation Mode activated. Guidance warnings enabled.";
        _activeTitle = "Navigation Mode Active";
        _activeDescription = "Focusing on path clearance and walking guidance.";
        _statusCardBg = const Color(0xFFEBF8FF);
        _statusIcon = Icons.directions_walk;
        _statusIconColor = const Color(0xFF3182CE);
        break;
      case HudMode.objectDetection:
        voiceMessage = "Object Detection Mode activated. Scanning surrounds.";
        _activeTitle = "Object Detection Active";
        _activeDescription = "Scanning and highlighting all objects in view.";
        _statusCardBg = const Color(0xFFE6FFFA);
        _statusIcon = Icons.radar;
        _statusIconColor = const Color(0xFF38A169);
        break;
      case HudMode.scenery:
        voiceMessage = "Scenery Mode activated. Environment descriptions enabled.";
        _activeTitle = "Scenery Mode Active";
        _activeDescription = "Analyzing general scene layout and ambient details.";
        _statusCardBg = const Color(0xFFFEFCBF);
        _statusIcon = Icons.photo_size_select_actual;
        _statusIconColor = const Color(0xFFD69E2E);
        break;
      case HudMode.faceRecognition:
        voiceMessage = "Face Recognition Mode activated. Scanning for registered faces.";
        _activeTitle = "Face Recognition Active";
        _activeDescription = "Looking for registered faces and family members.";
        _statusCardBg = const Color(0xFFF3E8FF);
        _statusIcon = Icons.face_retouching_natural;
        _statusIconColor = const Color(0xFF7C3AED);
        break;
    }
    if (!_isContinuousVoiceEnabled) {
      TtsService().speak(voiceMessage);
    }
  }

  void _initializeMLKitLabeler() {
    final options = ImageLabelerOptions(confidenceThreshold: 0.35);
    _imageLabeler = ImageLabeler(options: options);
  }

  void _initFaceDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: true,
        enableClassification: true,
        minFaceSize: 0.10,
        performanceMode: FaceDetectorMode.fast,
        enableTracking: true,
      ),
    );
  }

  /// Extracts geometric face features using the shared contour-based algorithm.
  /// No pixel grid — purely geometric ratios for robust cross-condition matching.
  List<double> _extractFaceFeatures(Face face, Size imageSize) {
    return FaceRegistrationScreen.extractFaceFeatures(face, imageSize);
  }

  /// Compares two geometric feature vectors using normalized Euclidean distance.
  /// 100% geometric — no pixel grid component.
  double _compareFaceFeatures(List<double> v1, List<double> v2) {
    if (v1.isEmpty || v2.isEmpty) return double.infinity;
    final len = math.min(v1.length, v2.length);
    if (len == 0) return double.infinity;

    double sumSq = 0.0;
    for (int i = 0; i < len; i++) {
      final diff = v1[i] - v2[i];
      sumSq += diff * diff;
    }
    return math.sqrt(sumSq / len);
  }

  /// Compares detected features against all stored sample vectors for a profile.
  /// Returns the best (minimum) distance across all samples.
  double _compareFaceToProfile(List<double> detectedFeats, FaceProfile prof) {
    final vectors = prof.allFeatureVectors;
    if (vectors.isEmpty) return double.infinity;
    double bestDist = double.infinity;
    for (final stored in vectors) {
      final dist = _compareFaceFeatures(detectedFeats, stored);
      if (dist < bestDist) bestDist = dist;
    }
    return bestDist;
  }

  Future<void> _loadRegisteredFaces() async {
    final profiles = await FaceRegistrationService().getAllProfiles();
    final accurateDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: true,
        enableClassification: true,
        minFaceSize: 0.05,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );

    try {
      for (int i = 0; i < profiles.length; i++) {
        final prof = profiles[i];
        // Always re-extract features with the new contour-based algorithm.
        // Old profiles had 71 features (7 landmarks + 64 pixel grid), new ones have ~25.
        // Force re-extraction if feature count doesn't match the new algorithm output.
        final needsReExtraction = prof.faceFeatures == null ||
            prof.faceFeatures!.isEmpty ||
            prof.faceFeatures!.length > 30 || // Old 71-feature profiles
            prof.faceFeatures!.length < 15;    // Incomplete profiles
        if (needsReExtraction && prof.imageLocalPath != null) {
          try {
            final file = File(prof.imageLocalPath!);
            if (await file.exists()) {
              final fileBytes = await file.readAsBytes();
              final decodedImage = await decodeImageFromList(fileBytes);
              final imgSize = Size(
                decodedImage.width.toDouble(),
                decodedImage.height.toDouble(),
              );
              final inputImage = InputImage.fromFile(file);
              final faces = await accurateDetector.processImage(inputImage);
              if (faces.isNotEmpty) {
                final feats = _extractFaceFeatures(faces.first, imgSize);
                final updatedProf = FaceProfile(
                  id: prof.id,
                  name: prof.name,
                  imageLocalPath: prof.imageLocalPath,
                  faceFeatures: feats,
                  multiSampleFeatures: prof.multiSampleFeatures,
                  registeredAt: prof.registeredAt,
                  userId: prof.userId,
                );
                await FaceRegistrationService().saveProfile(updatedProf);
                profiles[i] = updatedProf;
                debugPrint('[FaceRecog] Re-extracted ${feats.length} geometric features for "${prof.name}"');
              }
            }
          } catch (e) {
            debugPrint('[FaceRecog] Error re-extracting features for "${prof.name}": $e');
          }
        }
      }
    } finally {
      await accurateDetector.close();
    }

    if (mounted) {
      setState(() {
        _registeredFaces = profiles;
      });
      debugPrint('[FaceRecog] Loaded ${profiles.length} registered faces. Feature lengths: ${profiles.map((p) => "${p.name}:${p.faceFeatures?.length ?? 0}").join(", ")}');
    }
  }

  InputImageRotation _getImageRotation() {
    if (_cameraController == null || _cameras == null || _cameras!.isEmpty) {
      return InputImageRotation.rotation90deg;
    }
    final sensorOrientation = _cameras![0].sensorOrientation;
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  /// Throttled face detection on camera frames.
  Future<void> _detectFaceOnFrame(Uint8List bytes, int width, int height) async {
    if (_faceDetector == null) return;
    try {
      final rotation = _getImageRotation();
      final bool isRotated = rotation == InputImageRotation.rotation90deg || rotation == InputImageRotation.rotation270deg;
      final Size bufferSize = Size(width.toDouble(), height.toDouble());
      final Size displayImageSize = isRotated
          ? Size(height.toDouble(), width.toDouble())
          : Size(width.toDouble(), height.toDouble());

      final inputImageMetadata = InputImageMetadata(
        size: bufferSize,
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: width,
      );
      final inputImage =
          InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
      final faces = await _faceDetector!.processImage(inputImage);
      await _processFaceResults(faces, displayImageSize);
    } catch (e) {
      // Face detection errors are non-fatal
    }
  }

  Future<void> _processFaceResults(List<Face> faces, Size imageSize) async {
    if (!mounted) return;

    setState(() {
      _detectedFacesList = faces;
      _faceImageSize = imageSize;
    });

    if (faces.isNotEmpty) {
      final isTagalog = SettingsService().selectedLanguage.toLowerCase().contains('tagalog') || 
          SettingsService().selectedLanguage.toLowerCase().contains('filipino');
          
      // Clean stale tracking IDs from _faceIdToNameMap
      final currentIds = faces.map((f) => f.trackingId).whereType<int>().toSet();
      _faceIdToNameMap.removeWhere((id, _) => !currentIds.contains(id));

      // Sort faces spatially from left to right across the camera frame
      final sortedFaces = List<Face>.from(faces)
        ..sort((a, b) => a.boundingBox.center.dx.compareTo(b.boundingBox.center.dx));

      final assignedNamesInFrame = <String>{};

      for (int i = 0; i < sortedFaces.length; i++) {
        final face = sortedFaces[i];
        final id = face.trackingId;
        final center = face.boundingBox.center;
        final bbox = face.boundingBox;

        // Skip identity matching on tiny background/thumbnail faces (e.g. photos on a monitor screen or poster)
        final isPrimaryFace = imageSize != Size.zero
            ? (bbox.width >= imageSize.width * 0.10 || bbox.height >= imageSize.height * 0.10)
            : true;

        if (id != null) {
          // Check spatial proximity to inherit name if tracking ID shifted
          if (!_faceIdToNameMap.containsKey(id)) {
            int? matchedPrevId;
            double minDistance = 100.0; // max pixel distance threshold
            _lastFaceCentroids.forEach((prevId, prevCenter) {
              final d = (center - prevCenter).distance;
              if (d < minDistance && _faceIdToNameMap.containsKey(prevId)) {
                minDistance = d;
                matchedPrevId = prevId;
              }
            });

            if (matchedPrevId != null) {
              _faceIdToNameMap[id] = _faceIdToNameMap[matchedPrevId]!;
            } else if (isPrimaryFace && _registeredFaces.isNotEmpty) {
              final detectedFeats = _extractFaceFeatures(
                face, 
                imageSize, 
              );
              String? matchedName;
              double bestDistance = 0.30; // Tuned threshold for contour-based geometric matching

              for (final prof in _registeredFaces) {
                if (assignedNamesInFrame.contains(prof.name)) continue; // 1 assignment per person per frame
                final dist = _compareFaceToProfile(detectedFeats, prof);
                if (dist < bestDistance) {
                  bestDistance = dist;
                  matchedName = prof.name;
                }
              }
              if (matchedName != null) {
                debugPrint('[FaceRecog] Matched "$matchedName" with distance $bestDistance');
                assignedNamesInFrame.add(matchedName);
              }
              _faceIdToNameMap[id] = matchedName ?? 'Unknown Face';
            } else {
              _faceIdToNameMap[id] = 'Unknown Face';
            }
          } else {
            final name = _faceIdToNameMap[id]!;
            if (name != 'Unknown Face' && name != 'Unregistered' && name != 'Face') {
              assignedNamesInFrame.add(name);
            }
          }
        }
      }

      // Update centroid tracker for next frame
      _lastFaceCentroids = {
        for (final f in faces)
          if (f.trackingId != null) f.trackingId!: f.boundingBox.center
      };

      // Collect recognized vs unrecognized face names
      final recognizedNames = <String>[];
      int unrecognizedCount = 0;

      for (final face in faces) {
        final id = face.trackingId;
        final name = (id != null) ? _faceIdToNameMap[id] : null;
        if (name != null &&
            name != 'Face' &&
            name != 'Unregistered' &&
            name != 'Unknown Face' &&
            name != 'Person') {
          if (!recognizedNames.contains(name)) {
            recognizedNames.add(name);
          }
        } else {
          unrecognizedCount++;
        }
      }

      String faceAnnouncement = '';
      String faceDescription = '';

      if (recognizedNames.isNotEmpty) {
        if (recognizedNames.length == 1 && unrecognizedCount == 0) {
          faceAnnouncement = isTagalog ? "Nakakita ako kay ${recognizedNames.first}" : "I see ${recognizedNames.first}";
          faceDescription = "Buddy recognized ${recognizedNames.first}.";
        } else if (recognizedNames.length > 1 && unrecognizedCount == 0) {
          final namesStr = recognizedNames.join(isTagalog ? ' at ' : ' and ');
          faceAnnouncement = isTagalog ? "Nakakita ako kina $namesStr" : "I see $namesStr";
          faceDescription = "Buddy recognized $namesStr.";
        } else {
          final first = recognizedNames.first;
          faceAnnouncement = isTagalog 
              ? "Nakakita ako kay $first at $unrecognizedCount pang tao"
              : "I see $first and $unrecognizedCount other ${unrecognizedCount == 1 ? 'person' : 'people'}";
          faceDescription = "Buddy recognized $first and detected $unrecognizedCount other ${unrecognizedCount == 1 ? 'person' : 'people'}.";
        }
      } else {
        final count = faces.length;
        faceAnnouncement = isTagalog 
            ? (count == 1 ? "Nakakita ako ng hindi kilalang mukha" : "Nakakita ako ng $count hindi kilalang mukha")
            : (count == 1 ? "I see an unknown face" : "I see $count unknown faces");
        faceDescription = count == 1
            ? "Buddy detected an unknown face."
            : "Buddy detected $count unknown faces.";
      }

      final now = DateTime.now();
      final cooldownElapsed = _lastFaceAnnouncedAt == null ||
          now.difference(_lastFaceAnnouncedAt!).inSeconds >= 15;

      if (cooldownElapsed) {
        _lastFaceAnnouncedAt = now;
        if (!_isContinuousVoiceEnabled && faceAnnouncement.isNotEmpty) {
          TtsService().speak(faceAnnouncement);
        }
        if (mounted) {
          setState(() {
            if (recognizedNames.isNotEmpty) {
              _detectedFaceName = recognizedNames.join(' & ');
            } else if (unrecognizedCount > 0) {
              _detectedFaceName = unrecognizedCount == 1 ? 'Unknown Face' : '$unrecognizedCount Unknown Faces';
            } else {
              _detectedFaceName = '';
            }
          });
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() => _detectedFaceName = '');
          });
        }
      }

      if (_selectedHudMode == HudMode.faceRecognition && mounted) {
        setState(() {
          if (recognizedNames.isNotEmpty) {
            _activeTitle = recognizedNames.length > 1 ? "Multiple Faces Recognized" : "Face Recognized";
          } else {
            _activeTitle = faces.length > 1 ? "Unknown Faces Detected" : "Unknown Face Detected";
          }
          _activeDescription = faceDescription;
          _statusCardBg = const Color(0xFFF3E8FF);
          _statusIcon = Icons.face_retouching_natural;
          _statusIconColor = const Color(0xFF7C3AED);
        });
      }
    } else {
      _lastFaceCentroids.clear();
      _faceIdToNameMap.clear();
      if (_detectedFaceName.isNotEmpty && mounted) {
        setState(() => _detectedFaceName = '');
      }
      if (_selectedHudMode == HudMode.faceRecognition && mounted) {
        setState(() {
          _activeTitle = "Scanning Faces";
          _activeDescription = "Looking for registered profiles...";
          _statusCardBg = const Color(0xFFF9F5FF);
          _statusIcon = Icons.face;
          _statusIconColor = const Color(0xFF9E77ED);
        });
      }
    }
  }

  Future<void> _initializeCamera({bool forceMobile = false}) async {
    if (_isInitializingCamera) return;
    _isInitializingCamera = true;

    if (mounted) {
      setState(() {
        _pairStep = 4;
        _isCameraInitialized = false;
      });
    }

    final stopwatch = Stopwatch()..start();

    if (!forceMobile && !_useMobileCamera && !Esp32Service().isConnected && !Esp32Service().isConnecting) {
      await Esp32Service().connect().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
    }
    if (!forceMobile && !_useMobileCamera && Esp32Service().isConnected) {
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < 1800) {
        await Future.delayed(Duration(milliseconds: 1800 - elapsed));
      }
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isInitializingCamera = false;
          _pairStep = 4;
        });
      }
      return;
    }
    
    // Instant Fallback to Phone/Mobile Camera without hanging
    await _initializeMobileCameraOnly(stopwatch: stopwatch);
  }

  Future<void> _initializeMobileCameraOnly({Stopwatch? stopwatch}) async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      if (stopwatch != null) {
        final elapsed = stopwatch.elapsedMilliseconds;
        if (elapsed < 1800) {
          await Future.delayed(Duration(milliseconds: 1800 - elapsed));
        }
      }
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isInitializingCamera = false;
          _pairStep = 4;
        });
      }
      return;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        final controller = CameraController(
          _cameras![0],
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid
              ? ImageFormatGroup.yuv420
              : ImageFormatGroup.bgra8888,
        );
        await controller.initialize();
        if (!mounted) {
          controller.dispose();
          _isInitializingCamera = false;
          return;
        }
        controller.startImageStream(_onCameraFrameReceived);

        if (stopwatch != null) {
          final elapsed = stopwatch.elapsedMilliseconds;
          if (elapsed < 1800) {
            await Future.delayed(Duration(milliseconds: 1800 - elapsed));
          }
        }

        if (mounted) {
          setState(() {
            _cameraController = controller;
            _isCameraInitialized = true;
            _isInitializingCamera = false;
            _useMobileCamera = true;
            _pairStep = 4;
          });
        }
      } else {
        _isInitializingCamera = false;
        _showNoCameraMessage();
      }
    } catch (e) {
      _isInitializingCamera = false;
      print('Camera initialization error: $e');
      _showNoCameraMessage();
    }
  }

  String _getLabelForObject(DetectedObject r) {
    if (r.labels.isNotEmpty) {
      final firstLabel = r.labels.first;
      String lbl = 'object';
      if (firstLabel.text.isNotEmpty && firstLabel.text != 'Unknown') {
        lbl = _refineLabel(firstLabel.text).toLowerCase();
      } else if (_cocoLabels.isNotEmpty && firstLabel.index < _cocoLabels.length) {
        lbl = _refineLabel(_cocoLabels[firstLabel.index]).toLowerCase();
      }
      if (lbl.contains('fog')) lbl = 'wall';
      
      final humanParts = [
        'leg', 'arm', 'foot', 'hand', 'head', 'body', 'face', 'nose', 'eye', 'mouth', 'hair', 
        'human', 'pedestrian', 'man', 'woman', 'child', 'boy', 'girl', 'people', 'cyclist', 'rider', 'bystander'
      ];
      if (humanParts.any((part) => lbl.contains(part))) {
        lbl = 'person';
      }
      return lbl;
    }
    return 'object';
  }

  double _getRiskScore(String label) {
    final l = label.toLowerCase();
    if (l.contains('stair') || l.contains('step') || l.contains('escalator') || l.contains('elevator') ||
        l.contains('car') || l.contains('bus') || l.contains('truck') || l.contains('vehicle') ||
        l.contains('motorcycle') || l.contains('bicycle') || l.contains('hole') || l.contains('pothole') ||
        l.contains('fire') || l.contains('flame') || l.contains('train') ||
        l.contains('person') || l.contains('human') || l.contains('pedestrian') || l.contains('man') ||
        l.contains('woman') || l.contains('child') || l.contains('boy') || l.contains('girl') ||
        l.contains('people') || l.contains('cyclist') || l.contains('rider') || l.contains('bystander') ||
        l.contains('leg') || l.contains('arm') || l.contains('foot') || l.contains('head') || l.contains('hand') ||
        l.contains('body') || l.contains('face')) {
      return 1.0;
    }
    if (l.contains('dog') || l.contains('cat') || l.contains('pet') ||
        l.contains('chair') || l.contains('table') || l.contains('sofa') || l.contains('bench') ||
        l.contains('door') || l.contains('barrier') || l.contains('post') || l.contains('pole') ||
        l.contains('wall') || l.contains('tree') || l.contains('branch')) {
      return 0.6;
    }
    return 0.3;
  }

  bool _isHapticVibrating = false;
  DateTime? _lastHapticAlertTime;

  void _triggerHapticAlert({required bool isCritical}) {
    final hapticEnabled = SettingsService().hapticFeedback;
    if (!hapticEnabled) return;

    final now = DateTime.now();
    // Anti-spam cooldown: prevent spamming haptics on rapid frame updates.
    // Allow at most 1 haptic alert sequence per hazard event cycle (at least 3.5s cooldown).
    if (_isHapticVibrating) return;
    if (_lastHapticAlertTime != null && now.difference(_lastHapticAlertTime!).inMilliseconds < 3500) {
      return;
    }

    _isHapticVibrating = true;
    _lastHapticAlertTime = now;

    Future.microtask(() async {
      try {
        await DangerWarningService().triggerStrongHazardVibration(isCritical: isCritical);
      } catch (e) {
        print('[Haptic] Feedback failed: $e');
      } finally {
        _isHapticVibrating = false;
      }
    });
  }


  Future<void> _detectObjectsOnFrame(Uint8List bytes, int width, int height) async {
    if (_objectDetector == null) return;
    try {
      final Size imageSize = Size(width.toDouble(), height.toDouble());
      final inputImageMetadata = InputImageMetadata(
        size: imageSize,
        rotation: _getImageRotation(),
        format: InputImageFormat.nv21,
        bytesPerRow: width,
      );
      final inputImage =
          InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
      final objects = await _objectDetector!.processImage(inputImage);
      await _processObjectResults(objects, imageSize);
    } catch (e) {
      print("ML Kit object detection inference error: $e");
    }
  }

  /// Runs TFLite SSD MobileNet inference on NV21 camera bytes for navigation mode.
  /// Produces real COCO labels (person, chair, car, etc.) instead of ML Kit's generic 'Object'.
  /// Falls back to ML Kit ObjectDetector if TFLite model isn't loaded.
  Future<void> _detectAndProcessNavigationTflite(Uint8List nv21Bytes, int width, int height) async {
    if (!mounted) return;
    // Fallback to ML Kit if TFLite model not ready
    if (!_tfliteProcessor.isReady) {
      if (_objectDetector != null) {
        await _detectObjectsOnFrame(nv21Bytes, width, height);
      }
      return;
    }
    try {
      final rgbInput = _tfliteProcessor.prepareInputFromNv21(nv21Bytes, width, height);
      final results = _tfliteProcessor.runInference(rgbInput);
      if (!mounted) return;
      await _processNavigationTfliteResults(results);
    } catch (e) {
      print('[Navigation TFLite] Inference error: $e');
    }
  }

  /// Processes TFLite SSD results for navigation warnings.
  /// Uses normalized bounding box coordinates (0–1) from SSDResult directly.
  Future<void> _processNavigationTfliteResults(List<SSDResult> results) async {
    if (!mounted) return;
    final now = DateTime.now();
    final lang = SettingsService().selectedLanguage;
    final isTagalog = lang.toLowerCase().contains('tagalog') ||
        lang.toLowerCase().contains('filipino');

    // Filter to confidence > 0.40, excluding generic indoor clutter but explicitly allowing structural elements
    final ignoredLabels = [
      'chair', 'table', 'sofa', 'couch', 'bed', 'pottedplant', 'tv', 'laptop', 
      'mouse', 'remote', 'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 
      'sink', 'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear', 
      'hair drier', 'toothbrush', 'cup', 'bottle', 'wine glass', 'fork', 'knife', 
      'spoon', 'bowl', 'banana', 'apple', 'sandwich', 'orange', 'broccoli', 'carrot', 
      'hot dog', 'pizza', 'donut', 'cake', 'handbag', 'tie', 'suitcase', 'frisbee', 
      'skis', 'snowboard', 'sports ball', 'kite', 'baseball bat', 'baseball glove', 
      'skateboard', 'surfboard', 'tennis racket'
    ];

    final validResults = results.where((r) {
      if (r.confidence <= 0.40 || r.label == '???' || r.label.isEmpty) return false;
      final labelLower = _refineLabel(r.label).toLowerCase();
      
      // Always allow critical structural hazards
      if (labelLower.contains('stair') || labelLower.contains('step') || 
          labelLower.contains('elevator') || labelLower.contains('wall') || 
          labelLower.contains('door')) {
        return true;
      }
      
      return !ignoredLabels.any((ignored) => labelLower.contains(ignored));
    }).toList();

    if (validResults.isEmpty) {
      if (mounted) {
        setState(() {
          _tfliteDetections = [];
        });
      }
      _clearPath(isTagalog);
      return;
    }

    // Update detections for bounding box rendering in Navigation Mode
    if (mounted) {
      setState(() {
        _tfliteDetections = validResults;
      });
    }

    // Find the closest (largest area) object
    SSDResult? targetResult;
    double largestArea = 0.0;

    for (final r in validResults) {
      final w = (r.xMax - r.xMin).abs();
      final h = (r.yMax - r.yMin).abs();
      final area = w * h;
      if (area > largestArea) {
        largestArea = area;
        targetResult = r;
      }
    }

    if (targetResult == null || largestArea < 0.03) {
      if (mounted) {
        setState(() {
          _tfliteDetections = [];
        });
      }
      _clearPath(isTagalog);
      return;
    }

    // Centering: Normalized horizontal center on portrait screen
    final normCenterX = (targetResult.xMin + targetResult.xMax) / 2.0;
    final isCentered = normCenterX >= 0.38 && normCenterX <= 0.62;
    final direction = normCenterX < 0.38 ? 'left' : (normCenterX > 0.62 ? 'right' : 'center');

    String refinedLabel = _refineLabel(targetResult.label);
    
    // Map human parts and detailed person labels to "person"
    final humanParts = [
      'leg', 'arm', 'foot', 'hand', 'head', 'body', 'face', 'nose', 'eye', 'mouth', 'hair', 
      'human', 'pedestrian', 'man', 'woman', 'child', 'boy', 'girl', 'people', 'cyclist', 'rider', 'bystander'
    ];
    if (humanParts.any((part) => refinedLabel.toLowerCase().contains(part))) {
      refinedLabel = 'person';
    }
    
    final displayLabel = refinedLabel[0].toUpperCase() + refinedLabel.substring(1);

    final criticalKeywords = [
      'fire', 'flame', 'smoke', 'lighter', 'torch', 'burning', 'explosion',
      'knife', 'blade', 'dagger', 'scissors', 'cutter', 'machete', 'sword',
      'gun', 'weapon', 'pistol', 'rifle',
      'car', 'bus', 'truck', 'vehicle', 'jeepney', 'tricycle', 'motorcycle', 'van', 'automobile'
    ];
    final hazardKeywords = [
      'wall', 'pothole', 'hole', 'stair', 'step', 'barrier', 
      'fence', 'rail', 'post', 'pole', 'door', 'tree', 'bush',
      'elevator', 'lift', 'escalator', 'metal', 'chair', 'table', 'sofa', 'bench', 'desk'
    ];

    final isCriticalDanger = criticalKeywords.any((k) => refinedLabel.toLowerCase().contains(k));
    final isHazard = hazardKeywords.any((k) => refinedLabel.toLowerCase().contains(k));
    final isPerson = refinedLabel.toLowerCase() == 'person';

    if (isCriticalDanger) {
      // CRITICAL RED WARNING: Fire, Knife, Weapon, or Vehicle detected!
      final isFire = refinedLabel.toLowerCase().contains('fire') || refinedLabel.toLowerCase().contains('flame') || refinedLabel.toLowerCase().contains('smoke');
      final guidance = isTagalog
          ? 'KRITIKAL NA PANGANIB! May ${isFire ? "apoy" : displayLabel} sa iyong daanan! HUMINTO AT UMIWAS AGAD!'
          : 'CRITICAL DANGER! $displayLabel hazard detected ahead! STOP AND AVOID THIS AREA IMMEDIATELY!';

      _triggerHapticAlert(isCritical: true);
      _wasPathBlocked = true;

      // Sync to ActiveNavigationService for persistent app-wide warning overlay & card
      // Determine escape direction: if obstacle is on left, tell user to move right, and vice versa
      final escapeDirection = direction == 'left' ? 'right' : (direction == 'right' ? 'left' : 'center');
      ActiveNavigationService().triggerHazardAlert(
        hazardName: displayLabel,
        severity: HazardSeverity.critical,
        message: guidance,
        avoidanceDirection: escapeDirection,
      );

      final isDifferent = guidance != _lastGuidanceText;
      final elapsed = _lastGuidanceTime == null ? const Duration(seconds: 99) : now.difference(_lastGuidanceTime!);
      
      bool shouldSpeak = false;
      if (isDifferent) {
        if (_lastGuidanceTime == null || now.difference(_lastGuidanceTime!).inSeconds >= 2) {
          shouldSpeak = true;
        }
      } else {
        if (elapsed.inSeconds >= 5) {
          shouldSpeak = true;
        }
      }

      if (shouldSpeak) {
        _lastGuidanceText = guidance;
        _lastGuidanceTime = now;
        if (!_isContinuousVoiceEnabled) {
          TtsService().speak(guidance);
        }
        NotificationService().pushWarning(
          isTagalog ? 'KRITIKAL NA PANGANIB!' : 'CRITICAL DANGER ALERT!',
          guidance,
        );
      }

      if (mounted) {
        setState(() {
          _activeTitle = isTagalog
              ? 'KRITIKAL: MAY ${displayLabel.toUpperCase()} — UMIWAS AGAD!'
              : 'CRITICAL: ${displayLabel.toUpperCase()} DETECTED — AVOID IMMEDIATELY!';
          _activeDescription = guidance;
          _statusCardBg = const Color(0xFFFFEBEE); // Crimson Red background card
          _statusIcon = isFire ? Icons.local_fire_department_rounded : Icons.report_problem_rounded;
          _statusIconColor = Colors.red;
        });
      }
    } else if (isCentered && largestArea > 0.45) {
      // STOP immediately — extremely close centered obstacle covering the camera
      // Check which side is clear for escape
      bool leftBlocked = false;
      bool rightBlocked = false;
      for (final r in validResults) {
        if (r == targetResult) continue;
        final cX = 1.0 - ((r.yMin + r.yMax) / 2.0);
        if (cX < 0.38) leftBlocked = true;
        if (cX > 0.62) rightBlocked = true;
      }
      final stopEscapeDir = (leftBlocked && !rightBlocked) ? 'right' : (!leftBlocked ? 'left' : 'center');
      final stopEscapeTagalog = stopEscapeDir == 'left' ? 'kaliwa' : (stopEscapeDir == 'right' ? 'kanan' : 'gilid');

      final guidance = isTagalog
          ? 'Huminto agad. May $displayLabel sa iyong tapat. Tumabi sa iyong $stopEscapeTagalog upang maiwasan ito.'
          : 'Stop immediately. $displayLabel is directly in front of you. Move to your $stopEscapeDir to avoid it.';

      _triggerHapticAlert(isCritical: true);
      _wasPathBlocked = true;

      // Sync to ActiveNavigationService for navigation screen
      ActiveNavigationService().triggerHazardAlert(
        hazardName: displayLabel,
        severity: HazardSeverity.critical,
        message: guidance,
        avoidanceDirection: stopEscapeDir,
      );

      final isDifferent = guidance != _lastGuidanceText;
      final elapsed = _lastGuidanceTime == null ? const Duration(seconds: 99) : now.difference(_lastGuidanceTime!);
      
      bool shouldSpeak = false;
      if (isDifferent) {
        if (_lastGuidanceTime == null || now.difference(_lastGuidanceTime!).inSeconds >= 4) {
          shouldSpeak = true;
        }
      } else {
        if (elapsed.inSeconds >= 10) {
          shouldSpeak = true;
        }
      }

      if (shouldSpeak) {
        _lastGuidanceText = guidance;
        _lastGuidanceTime = now;
        if (!_isContinuousVoiceEnabled) {
          TtsService().speak(guidance);
        }
        NotificationService().pushObstacleAlert('center', refinedLabel, isCritical: true);
      }

      if (mounted) {
        setState(() {
          _activeTitle = isTagalog ? 'Huminto agad' : 'Stop immediately';
          _activeDescription = guidance;
          _statusCardBg = const Color(0xFFFFEBEE);
          _statusIcon = Icons.report_problem;
          _statusIconColor = Colors.red;
        });
      }
    } else if (isCentered && largestArea > 0.18) {
      // AVOID — centered obstacle at medium-close distance
      bool leftBlocked = false;
      bool rightBlocked = false;
      for (final r in validResults) {
        if (r == targetResult) continue;
        final cX = 1.0 - ((r.yMin + r.yMax) / 2.0);
        if (cX < 0.38) leftBlocked = true;
        if (cX > 0.62) rightBlocked = true;
      }
      final escapeDir = (leftBlocked && !rightBlocked) ? 'right' : 'left';
      final escapeTagalog = escapeDir == 'left' ? 'kaliwa' : 'kanan';

      final guidance = isPerson
          ? (isTagalog
              ? 'May tao sa iyong harapan, mag-iingat ka. Tumabi sa iyong $escapeTagalog upang maiwasan ito.'
              : 'A person is in front of you, be careful. Step aside to your $escapeDir to avoid them.')
          : (isTagalog
              ? 'May harang sa harap: ang $displayLabel ay nasa tapat mo. Tumabi sa iyong $escapeTagalog upang maiwasan ito.'
              : 'Obstacle ahead: $displayLabel is directly in your path. Step aside to your $escapeDir to avoid it.');

      _triggerHapticAlert(isCritical: false);
      _wasPathBlocked = true;

      // Sync to ActiveNavigationService for navigation screen
      ActiveNavigationService().triggerHazardAlert(
        hazardName: displayLabel,
        severity: HazardSeverity.caution,
        message: guidance,
        avoidanceDirection: escapeDir,
      );

      final isDifferent = guidance != _lastGuidanceText;
      final elapsed = _lastGuidanceTime == null ? const Duration(seconds: 99) : now.difference(_lastGuidanceTime!);
      
      bool shouldSpeak = false;
      if (isDifferent) {
        if (_lastGuidanceTime == null || now.difference(_lastGuidanceTime!).inSeconds >= 4) {
          shouldSpeak = true;
        }
      } else {
        if (elapsed.inSeconds >= 10) {
          shouldSpeak = true;
        }
      }

      if (shouldSpeak) {
        _lastGuidanceText = guidance;
        _lastGuidanceTime = now;
        if (!_isContinuousVoiceEnabled) {
          TtsService().speak(guidance);
        }
        NotificationService().pushObstacleAlert('center', refinedLabel, isCritical: false);
      }

      if (mounted) {
        setState(() {
          _activeTitle = isPerson 
              ? (isTagalog ? 'May Tao sa Harap' : 'Person Ahead')
              : (isTagalog ? 'Iwasan ang Harang' : 'Avoid Obstacle');
          _activeDescription = guidance;
          _statusCardBg = isPerson ? const Color(0xFFE8EAF6) : const Color(0xFFFFF3E0);
          _statusIcon = isPerson ? Icons.person_rounded : Icons.warning_amber_rounded;
          _statusIconColor = isPerson ? Colors.indigo : Colors.orange;
        });
      }
    } else if (isPerson && (largestArea > 0.02 || isCentered)) {
      // Explicit Person Ahead Warning ("A person is in front of you, be careful")
      // Determine which side the person is on so we can suggest escape direction
      final personEscapeDir = direction == 'left' ? 'right' : (direction == 'right' ? 'left' : '');
      final String guidance = isTagalog
          ? 'May tao sa iyong ${direction == "center" ? "harapan" : (direction == "left" ? "kaliwa" : "kanan")}, mag-iingat ka.${personEscapeDir.isNotEmpty ? " Lumipat sa iyong ${personEscapeDir == "left" ? "kaliwa" : "kanan"}." : ""}'
          : 'Person detected on your ${direction == "center" ? "front" : direction}, be careful.${personEscapeDir.isNotEmpty ? " Move to your $personEscapeDir." : ""}';

      _triggerHapticAlert(isCritical: false);

      // Sync to ActiveNavigationService for navigation screen
      ActiveNavigationService().triggerHazardAlert(
        hazardName: displayLabel,
        severity: HazardSeverity.caution,
        message: guidance,
        avoidanceDirection: personEscapeDir.isNotEmpty ? personEscapeDir : direction,
      );

      final isDifferent = guidance != _lastGuidanceText;
      final elapsed = _lastGuidanceTime == null ? const Duration(seconds: 99) : now.difference(_lastGuidanceTime!);
      
      bool shouldSpeak = false;
      if (isDifferent) {
        if (_lastGuidanceTime == null || now.difference(_lastGuidanceTime!).inSeconds >= 4) {
          shouldSpeak = true;
        }
      } else {
        if (elapsed.inSeconds >= 10) {
          shouldSpeak = true;
        }
      }

      if (shouldSpeak) {
        _lastGuidanceText = guidance;
        _lastGuidanceTime = now;
        if (!_isContinuousVoiceEnabled) {
          TtsService().speak(guidance);
        }
      }

      if (mounted) {
        setState(() {
          _activeTitle = isTagalog ? 'May Tao sa Harap' : 'Person Ahead';
          _activeDescription = guidance;
          _statusCardBg = const Color(0xFFE8EAF6);
          _statusIcon = Icons.person_rounded;
          _statusIconColor = Colors.indigo;
        });
      }
    } else if (isHazard && largestArea > 0.02) {
      // SLOW DOWN — structural hazard (wall, pothole, step, door, etc.) detected early
      final String guidance;
      final bool isDoor = refinedLabel.toLowerCase().contains('door');
      if (isDoor) {
        guidance = isTagalog
            ? 'Papalapit ka sa isang pintuan.'
            : 'You are approaching a door.';
      } else if (isCentered) {
        guidance = isTagalog
            ? 'Magdahan-dahan. May harang na $displayLabel sa iyong harap.'
            : 'Slow down. $displayLabel hazard detected ahead.';
      } else {
        final sideDir = direction == 'left' ? (isTagalog ? 'kaliwa' : 'left') : (isTagalog ? 'kanan' : 'right');
        guidance = isTagalog
            ? 'Magdahan-dahan. May harang na $displayLabel sa iyong $sideDir.'
            : 'Slow down. $displayLabel hazard detected on your $sideDir.';
      }

      final hazardEscapeDir = direction == 'left' ? 'right' : (direction == 'right' ? 'left' : '');

      _triggerHapticAlert(isCritical: false);

      // Sync to ActiveNavigationService for navigation screen
      ActiveNavigationService().triggerHazardAlert(
        hazardName: displayLabel,
        severity: HazardSeverity.caution,
        message: guidance,
        avoidanceDirection: hazardEscapeDir.isNotEmpty ? hazardEscapeDir : direction,
      );

      final isDifferent = guidance != _lastGuidanceText;
      final elapsed = _lastGuidanceTime == null ? const Duration(seconds: 99) : now.difference(_lastGuidanceTime!);
      
      bool shouldSpeak = false;
      if (isDifferent) {
        if (_lastGuidanceTime == null || now.difference(_lastGuidanceTime!).inSeconds >= 4) {
          shouldSpeak = true;
        }
      } else {
        if (elapsed.inSeconds >= 10) {
          shouldSpeak = true;
        }
      }

      if (shouldSpeak) {
        _lastGuidanceText = guidance;
        _lastGuidanceTime = now;
        if (!_isContinuousVoiceEnabled) {
          TtsService().speak(guidance);
        }
      }

      if (mounted) {
        setState(() {
          _activeTitle = isDoor
              ? (isTagalog ? 'May Pintuan sa Harap' : 'Door Ahead')
              : (isTagalog ? 'Dahan-dahan' : 'Slow Down');
          _activeDescription = guidance;
          _statusCardBg = isDoor ? const Color(0xFFE0F7FA) : const Color(0xFFFFFDE7);
          _statusIcon = isDoor ? Icons.door_front_door_outlined : Icons.speed;
          _statusIconColor = isDoor ? Colors.teal : Colors.yellow[800]!;
        });
      }
    } else if ((isCentered && largestArea > 0.03) || (!isCentered && largestArea > 0.06)) {
      // SLOW DOWN — standard object further away or side object close by
      final String guidance;
      if (isCentered) {
        guidance = isTagalog
            ? 'Magdahan-dahan. May $displayLabel sa iyong harap.'
            : 'Slow down. $displayLabel detected ahead.';
      } else {
        final sideDir = direction == 'left' ? (isTagalog ? 'kaliwa' : 'left') : (isTagalog ? 'kanan' : 'right');
        guidance = isTagalog
            ? 'Magdahan-dahan. May $displayLabel sa iyong $sideDir.'
            : 'Slow down. $displayLabel detected on your $sideDir.';
      }

      final isDifferent = guidance != _lastGuidanceText;
      final elapsed = _lastGuidanceTime == null ? const Duration(seconds: 99) : now.difference(_lastGuidanceTime!);
      
      bool shouldSpeak = false;
      if (isDifferent) {
        if (_lastGuidanceTime == null || now.difference(_lastGuidanceTime!).inSeconds >= 4) {
          shouldSpeak = true;
        }
      } else {
        if (elapsed.inSeconds >= 10) {
          shouldSpeak = true;
        }
      }

      if (shouldSpeak) {
        _lastGuidanceText = guidance;
        _lastGuidanceTime = now;
        if (!_isContinuousVoiceEnabled) {
          TtsService().speak(guidance);
        }
      }

      if (mounted) {
        setState(() {
          _activeTitle = isTagalog ? 'Dahan-dahan' : 'Slow Down';
          _activeDescription = guidance;
          _statusCardBg = const Color(0xFFFFFDE7);
          _statusIcon = Icons.speed;
          _statusIconColor = Colors.yellow[800]!;
        });
      }
    } else {
      _clearPath(isTagalog);
    }
  }

  /// Runs TFLite SSD MobileNet inference on NV21 camera bytes for Object Detection Mode.
  /// Sets _tfliteDetections to draw bounding boxes and announces detected items via TTS.
  Future<void> _detectAndProcessTfliteOnly(Uint8List nv21Bytes, int width, int height) async {
    if (!_tfliteProcessor.isReady || !mounted || _isProcessingObjectDetection) return;
    _isProcessingObjectDetection = true;
    try {
      final rgbInput = _tfliteProcessor.prepareInputFromNv21(nv21Bytes, width, height);
      final results = _tfliteProcessor.runInference(rgbInput);
      if (!mounted) return;
      
      final validResults = results.where((r) => r.confidence > 0.40 && r.label != '???' && r.label.isNotEmpty).toList();
      setState(() {
        _tfliteDetections = validResults;
      });

      // TTS announcement in Object Detection Mode using MobileNet labels
      final now = DateTime.now();
      if (validResults.isNotEmpty) {
        final detectedNames = validResults
            .take(3)
            .map((r) => _refineLabel(r.label))
            .join(", ");
        final alertKey = 'detection_list_tflite';
        final lastSpoken = _lastSpokenMap[alertKey];
        final isDifferent = detectedNames != _lastSpokenObjectText;
        final cooldownElapsed = lastSpoken == null ||
            now.difference(lastSpoken).inSeconds >= (isDifferent ? 12 : 30);
        if (cooldownElapsed && detectedNames.isNotEmpty) {
          _lastSpokenMap[alertKey] = now;
          _lastSpokenObjectText = detectedNames;
          final isTagalog = SettingsService().selectedLanguage.toLowerCase().contains('tagalog') || SettingsService().selectedLanguage.toLowerCase().contains('filipino');
          final phrase = isTagalog ? "Nakakita ako ng $detectedNames" : "I see $detectedNames";
          if (!_isContinuousVoiceEnabled) {
            TtsService().speak(phrase);
          }
          
          setState(() {
            _activeTitle = "Objects Detected";
            _activeDescription = "Detected: $detectedNames";
            _statusCardBg = const Color(0xFFE6FFFA);
            _statusIcon = Icons.search;
            _statusIconColor = const Color(0xFF38A169);
          });
        }
      } else {
        setState(() {
          _activeTitle = "Scanning Objects";
          _activeDescription = "Searching for objects in view...";
          _statusCardBg = const Color(0xFFF1F8E9);
          _statusIcon = Icons.radar_outlined;
          _statusIconColor = const Color(0xFF81C784);
        });
      }
    } catch (e) {
      print('[TFLite ObjectDetection] Inference error: $e');
    } finally {
      _isProcessingObjectDetection = false;
    }
  }

  /// Runs TFLite SSD MobileNet inference on JPEG camera bytes from ESP32 stream for Object Detection Mode.
  Future<void> _detectAndProcessTfliteOnlyFromJpg(Uint8List jpgBytes) async {
    if (!_tfliteProcessor.isReady || !mounted) return;
    try {
      final rgbInput = _tfliteProcessor.prepareInputFromJpg(jpgBytes);
      final results = _tfliteProcessor.runInference(rgbInput);
      if (!mounted) return;
      
      final validResults = results.where((r) => r.confidence > 0.30 && r.label != '???' && r.label.isNotEmpty).toList();
      setState(() {
        _tfliteDetections = validResults;
      });

      final now = DateTime.now();
      if (validResults.isNotEmpty) {
        final detectedNames = validResults
            .take(3)
            .map((r) => _refineLabel(r.label))
            .join(", ");
        final alertKey = 'detection_list_tflite_esp32';
        final lastSpoken = _lastSpokenMap[alertKey];
        final isDifferent = detectedNames != _lastSpokenObjectText;
        final cooldownElapsed = lastSpoken == null ||
            now.difference(lastSpoken).inSeconds >= (isDifferent ? 12 : 30);
        if (cooldownElapsed && detectedNames.isNotEmpty) {
          _lastSpokenMap[alertKey] = now;
          _lastSpokenObjectText = detectedNames;
          final isTagalog = SettingsService().selectedLanguage.toLowerCase().contains('tagalog') || SettingsService().selectedLanguage.toLowerCase().contains('filipino');
          final phrase = isTagalog ? "Nakakita ako ng $detectedNames" : "I see $detectedNames";
          if (!_isContinuousVoiceEnabled) {
            TtsService().speak(phrase);
          }
        }
        if (mounted) {
          final isTagalog = SettingsService().selectedLanguage.toLowerCase().contains('tagalog') || SettingsService().selectedLanguage.toLowerCase().contains('filipino');
          setState(() {
            _activeTitle = isTagalog ? "May Nakitang Bagay" : "Objects Detected";
            _activeDescription = isTagalog ? "Nakakita ng: $detectedNames" : "Detected: $detectedNames";
            _statusCardBg = const Color(0xFFE6FFFA);
            _statusIcon = Icons.search;
            _statusIconColor = const Color(0xFF38A169);
          });
        }
      } else {
        if (mounted) {
          final isTagalog = SettingsService().selectedLanguage.toLowerCase().contains('tagalog') || SettingsService().selectedLanguage.toLowerCase().contains('filipino');
          setState(() {
            _activeTitle = isTagalog ? "Naghahanap ng Bagay" : "Scanning Objects";
            _activeDescription = isTagalog ? "Naghahanap ng mga bagay sa paligid..." : "Searching for objects in view...";
            _statusCardBg = const Color(0xFFF1F8E9);
            _statusIcon = Icons.radar_outlined;
            _statusIconColor = const Color(0xFF81C784);
          });
        }
      }
    } catch (e) {
      print('[TFLite ESP32 ObjectDetection] Error: $e');
    }
  }

  /// Processes ML Kit Object Detector results for walking navigation warnings.
  Future<void> _processObjectResults(List<DetectedObject> objects, Size imageSize) async {
    if (!mounted) return;
    final double width = imageSize.width;
    final double height = imageSize.height;

    setState(() {
      _detectedObjectsList = objects;
      _faceImageSize = imageSize;
    });

    final now = DateTime.now();

    if (_selectedHudMode == HudMode.navigation) {
      final lang = SettingsService().selectedLanguage;
      final isTagalog = lang.toLowerCase().contains('tagalog') ||
          lang.toLowerCase().contains('filipino');

      DetectedObject? targetObject;
      double largestArea = 0.0;
      String targetLabel = 'object';

      for (final obj in objects) {
        final normW = obj.boundingBox.width / width;
        final normH = obj.boundingBox.height / height;
        final area = normW * normH;
        if (area > largestArea) {
          largestArea = area;
          targetObject = obj;
          targetLabel = _getLabelForObject(obj);
        }
      }

      // Map human parts and detailed person labels to "person"
      final humanParts = [
        'leg', 'arm', 'foot', 'hand', 'head', 'body', 'face', 'nose', 'eye', 'mouth', 'hair', 
        'human', 'pedestrian', 'man', 'woman', 'child', 'boy', 'girl', 'people', 'cyclist', 'rider', 'bystander'
      ];
      if (humanParts.any((part) => targetLabel.toLowerCase().contains(part))) {
        targetLabel = 'person';
      }

      if (targetObject == null || largestArea < 0.03) {
        final elapsedHazard = _lastHazardDetectionTime == null 
            ? const Duration(seconds: 99) 
            : now.difference(_lastHazardDetectionTime!);
        if (elapsedHazard.inMilliseconds > 2500) {
          _clearPath(isTagalog);
        }
        return;
      }

      // Centering: In portrait mode, raw image Y maps to screen X.
      final normCenterX = 1.0 - (((targetObject.boundingBox.top + targetObject.boundingBox.bottom) / 2.0) / height);
      final isCentered = normCenterX >= 0.38 && normCenterX <= 0.62;
      final direction = normCenterX < 0.38 ? 'left' : (normCenterX > 0.62 ? 'right' : 'center');
      
      final refinedLabel = targetLabel[0].toUpperCase() + targetLabel.substring(1);

      final hazardKeywords = [
        'wall', 'pothole', 'hole', 'stair', 'step', 'barrier', 
        'fence', 'rail', 'post', 'pole', 'door', 'tree', 'bush',
        'traffic light', 'traffic sign', 'stop sign',
        'elevator', 'lift', 'escalator', 'metal'
      ];
      final isHazard = hazardKeywords.any((k) => targetLabel.toLowerCase().contains(k));

      if (isCentered && largestArea > 0.45) {
        // STOP immediately — extremely close centered obstacle covering the camera
        final guidance = isTagalog
            ? 'Huminto agad. May $refinedLabel sa iyong tapat. Mangyaring tumabi upang maiwasan ito.'
            : 'Stop immediately. $refinedLabel is directly in front of you. Please step aside to avoid it.';

        _triggerHapticAlert(isCritical: true);
        _wasPathBlocked = true;

        final isDifferent = guidance != _lastGuidanceText;
        final elapsed = _lastGuidanceTime == null ? const Duration(seconds: 99) : now.difference(_lastGuidanceTime!);
        
        bool shouldSpeak = false;
        if (isDifferent) {
          if (_lastGuidanceTime == null || now.difference(_lastGuidanceTime!).inSeconds >= 4) {
            shouldSpeak = true;
          }
        } else {
          if (elapsed.inSeconds >= 10) {
            shouldSpeak = true;
          }
        }

        if (shouldSpeak) {
          _lastGuidanceText = guidance;
          _lastGuidanceTime = now;
          if (!_isContinuousVoiceEnabled) {
            TtsService().speak(guidance);
          }
          NotificationService().pushObstacleAlert('center', targetLabel, isCritical: true);
        }

        if (mounted) {
          setState(() {
            _activeTitle = isTagalog ? 'Huminto agad' : 'Stop immediately';
            _activeDescription = guidance;
            _statusCardBg = const Color(0xFFFFEBEE);
            _statusIcon = Icons.report_problem;
            _statusIconColor = Colors.red;
          });
        }
      } else if (isCentered && largestArea > 0.18) {
        // AVOID — centered obstacle at medium-close distance
        bool leftBlocked = false;
        bool rightBlocked = false;
        for (final r in objects) {
          if (r == targetObject) continue;
          final cX = 1.0 - (((r.boundingBox.top + r.boundingBox.bottom) / 2.0) / height);
          if (cX < 0.38) leftBlocked = true;
          if (cX > 0.62) rightBlocked = true;
        }
        final escapeDir = (leftBlocked && !rightBlocked) ? 'right' : 'left';
        final escapeTagalog = escapeDir == 'left' ? 'kaliwa' : 'kanan';

        final guidance = isTagalog
            ? 'May harang sa harap: ang $refinedLabel ay nasa tapat mo. Tumabi sa iyong $escapeTagalog upang maiwasan ito.'
            : 'Obstacle ahead: $refinedLabel is directly in your path. Step aside to your $escapeDir to avoid it.';

        _triggerHapticAlert(isCritical: false);
        _wasPathBlocked = true;

        final isDifferent = guidance != _lastGuidanceText;
        final elapsed = _lastGuidanceTime == null ? const Duration(seconds: 99) : now.difference(_lastGuidanceTime!);
        
        bool shouldSpeak = false;
        if (isDifferent) {
          if (_lastGuidanceTime == null || now.difference(_lastGuidanceTime!).inSeconds >= 4) {
            shouldSpeak = true;
          }
        } else {
          if (elapsed.inSeconds >= 10) {
            shouldSpeak = true;
          }
        }

        if (shouldSpeak) {
          _lastGuidanceText = guidance;
          _lastGuidanceTime = now;
          if (!_isContinuousVoiceEnabled) {
            TtsService().speak(guidance);
          }
          NotificationService().pushObstacleAlert('center', targetLabel, isCritical: false);
        }

        if (mounted) {
          setState(() {
            _activeTitle = isTagalog ? 'Iwasan ang Harang' : 'Avoid Obstacle';
            _activeDescription = guidance;
            _statusCardBg = const Color(0xFFFFF3E0);
            _statusIcon = Icons.warning_amber_rounded;
            _statusIconColor = Colors.orange;
          });
        }
      } else if (isHazard && largestArea > 0.02) {
        // SLOW DOWN — structural hazard (wall, pothole, step, door, etc.) detected early
        final String guidance;
        final bool isDoor = targetLabel.contains('door') || refinedLabel.toLowerCase().contains('door');
        if (isDoor) {
          guidance = isTagalog
              ? 'Papalapit ka sa isang pintuan.'
              : 'You are approaching a door.';
        } else if (targetLabel.contains('traffic light')) {
          guidance = isTagalog
              ? 'May ilaw ng trapiko sa iyong tapat.'
              : 'Traffic light detected ahead. Slow down and check the signal.';
        } else if (targetLabel.contains('fire') || targetLabel.contains('smoke')) {
          guidance = isTagalog
              ? 'Babala sa sunog! May usok o apoy na natuklasan sa malapit.'
              : 'Fire hazard! Fire or heavy smoke detected nearby. Move away immediately.';
        } else {
          guidance = isTagalog
              ? 'May $targetLabel sa iyong daan. Mag-ingat.'
              : 'May encounter $targetLabel ahead. Slow down.';
        }

        final isDifferent = guidance != _lastGuidanceText;
        final elapsed = _lastGuidanceTime == null ? const Duration(seconds: 99) : now.difference(_lastGuidanceTime!);

        if (isDifferent || elapsed.inSeconds >= 12) {
          _lastGuidanceText = guidance;
          _lastGuidanceTime = now;
          if (!_isContinuousVoiceEnabled) {
            TtsService().speak(guidance);
          }
        }

        if (mounted) {
          setState(() {
            _activeTitle = isDoor 
                ? (isTagalog ? 'May Pintuan sa Harap' : 'Door Ahead')
                : (isTagalog ? 'Dahan-dahan' : 'Slow Down');
            _activeDescription = guidance;
            _statusCardBg = const Color(0xFFFFFDE7);
            _statusIcon = isDoor ? Icons.door_front_door_outlined : Icons.speed;
            _statusIconColor = isDoor ? Colors.teal : Colors.yellow[800]!;
          });
        }
      } else if ((isCentered && largestArea > 0.03) || (!isCentered && largestArea > 0.06)) {
        // SLOW DOWN — standard object further away or side object close by
        final String guidance;
        if (isCentered) {
          guidance = isTagalog
              ? 'Magdahan-dahan. May $refinedLabel sa iyong harap. Mangyaring tumabi.'
              : 'Slow down. $refinedLabel detected ahead. Please step aside.';
        } else if (direction == 'left') {
          guidance = isTagalog
              ? 'Magdahan-dahan. May $refinedLabel sa iyong kaliwa. Mangyaring lumipat sa kanan.'
              : 'Slow down. $refinedLabel detected on your left. Please move to the right.';
        } else {
          guidance = isTagalog
              ? 'Magdahan-dahan. May $refinedLabel sa iyong kanan. Mangyaring lumipat sa kaliwa.'
              : 'Slow down. $refinedLabel detected on your right. Please move to the left.';
        }

        final isDifferent = guidance != _lastGuidanceText;
        final elapsed = _lastGuidanceTime == null ? const Duration(seconds: 99) : now.difference(_lastGuidanceTime!);
        
        bool shouldSpeak = false;
        if (isDifferent) {
          if (_lastGuidanceTime == null || now.difference(_lastGuidanceTime!).inSeconds >= 4) {
            shouldSpeak = true;
          }
        } else {
          if (elapsed.inSeconds >= 10) {
            shouldSpeak = true;
          }
        }

        if (shouldSpeak) {
          _lastGuidanceText = guidance;
          _lastGuidanceTime = now;
          if (!_isContinuousVoiceEnabled) {
            TtsService().speak(guidance);
          }
        }

        if (mounted) {
          setState(() {
            _activeTitle = isTagalog ? 'Dahan-dahan' : 'Slow Down';
            _activeDescription = guidance;
            _statusCardBg = const Color(0xFFFFFDE7);
            _statusIcon = Icons.speed;
            _statusIconColor = Colors.yellow[800]!;
          });
        }
      } else {
        final elapsedHazard = _lastHazardDetectionTime == null 
            ? const Duration(seconds: 99) 
            : now.difference(_lastHazardDetectionTime!);
        if (elapsedHazard.inMilliseconds > 2500) {
          _clearPath(isTagalog);
        }
      }
    }
  }

  void _clearPath(bool isTagalog) {
    if (_selectedHudMode != HudMode.navigation) return;
    _lastGuidanceText = "";
    if (_wasPathBlocked) {
      _wasPathBlocked = false;
      ActiveNavigationService().clearHazardAlert();
      final clearText = isTagalog ? "Malinis ang daan." : "The pathway ahead is clear.";
      if (!_isContinuousVoiceEnabled) {
        TtsService().speak(clearText);
      }
    }
    setState(() {
      _activeTitle = isTagalog ? "Malinis ang Daan" : "Path Clear";
      _activeDescription = isTagalog ? "Walang nakaharang sa daanan." : "The pathway ahead is clear.";
      _statusCardBg = const Color(0xFFE8F5E9);
      _statusIcon = Icons.check_circle_outline;
      _statusIconColor = Colors.green;
    });
  }

  Uint8List _yuvToNv21Sync(CameraImage image) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final data = YuvData(
      yBytes: yPlane.bytes,
      uBytes: uPlane.bytes,
      vBytes: vPlane.bytes,
      width: image.width,
      height: image.height,
      yRowStride: yPlane.bytesPerRow,
      uRowStride: uPlane.bytesPerRow,
      vRowStride: vPlane.bytesPerRow,
      uPixelStride: uPlane.bytesPerPixel ?? 1,
      vPixelStride: vPlane.bytesPerPixel ?? 1,
    );

    return convertYuvToNv21(data);
  }

  Future<void> _navigateTo(Widget screen) async {
    // 1. Pause frame processing S01
    setState(() {
      _isPaused = true;
    });
    
    // 2. Stop TTS speaking
    await TtsService().stop();
    
    // 3. Navigate to route
    if (mounted) {
      await Navigator.push(context, AppRoute.to(screen));
    }
    
    // 4. Resume frame processing after coming back
    setState(() {
      _isPaused = false;
    });
  }

  String _refineLabel(String rawLabel) {
    final label = rawLabel.replaceAll('_', ' ').trim().toLowerCase();
    if (label.contains('doorway') || 
        label.contains('entrance') || 
        label.contains('exit') || 
        label.contains('elevator') || 
        label.contains('lift') || 
        label.contains('gate')) {
      return 'door';
    }
    if (label.contains('chair') || label.contains('stool') || label.contains('armchair')) {
      return 'chair';
    }
    if (label.contains('sofa') || label.contains('couch')) {
      return 'sofa';
    }
    if (label.contains('dining table') || label.contains('desk') || label.contains('tabletop') || label.contains('countertop')) {
      return 'table';
    }
    if (label.contains('laptop')) {
      return 'laptop';
    }
    if (label.contains('computer') || label.contains('screen') || label.contains('monitor')) {
      return 'computer screen';
    }
    if (label.contains('cell phone') || label.contains('mobile phone') || label.contains('phone')) {
      return 'cell phone';
    }
    if (label.contains('bottle')) {
      return 'bottle';
    }
    if (label.contains('wine glass')) {
      return 'wine glass';
    }
    if (label.contains('cup') || label.contains('mug')) {
      return 'cup';
    }
    if (label.contains('person') || label.contains('human') || label.contains('man') || label.contains('woman') || 
        label.contains('child') || label.contains('boy') || label.contains('girl') || label.contains('pedestrian') || 
        label.contains('bystander') || label.contains('people') || label.contains('cyclist') || label.contains('rider') || 
        label.contains('skin') || label.contains('hand') || label.contains('finger') || label.contains('nail') || 
        label.contains('eyelash') || label.contains('eyebrow') || label.contains('eye') || label.contains('face') || 
        label.contains('head') || label.contains('hair') || label.contains('arm') || label.contains('leg') || 
        label.contains('foot') || label.contains('feet') || label.contains('forehead') || label.contains('chin') || 
        label.contains('lip') || label.contains('mouth') || label.contains('nose') || label.contains('cheek') || 
        label.contains('thumb') || label.contains('wrist') || label.contains('elbow') || label.contains('knee') || 
        label.contains('shoulder') || label.contains('torso') || label.contains('body') || label.contains('selfie') || 
        label.contains('portrait')) {
      return 'person';
    }
    return rawLabel.replaceAll('_', ' ').trim();
  }

  // Processes each streaming camera frame through Google ML Kit Labeler continuously
  Future<void> _processCameraImage(Uint8List nv21Bytes, Uint8List yBytes, int width, int height) async {
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    if (!isCurrent) {
      TtsService().stop();
      return;
    }
    try {
      final Size imageSize = Size(width.toDouble(), height.toDouble());
      final InputImageRotation imageRotation = _getImageRotation();

      final inputImageMetadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: InputImageFormat.nv21,
        bytesPerRow: width,
      );

      final inputImage = InputImage.fromBytes(bytes: nv21Bytes, metadata: inputImageMetadata);

      if (_imageLabeler != null) {
        final List<ImageLabel> labels = await _imageLabeler!.processImage(inputImage);
        
        // Calculate average luminance for camera covered check
        int sampleCount = 400;
        int step = yBytes.length ~/ sampleCount;
        if (step < 1) step = 1;
        int sum = 0;
        int count = 0;
        for (int i = 0; i < yBytes.length; i += step) {
          sum += yBytes[i];
          count++;
        }
        final avgLuminance = count > 0 ? sum / count : 128.0;
        final isCovered = avgLuminance < 15.0;

        await _processImageLabeling(labels, inputImage, isCovered: isCovered);
      }
    } catch (e) {
      print('ML Kit Frame processing error: $e');
    }
  }

  Future<void> _processImageLabeling(List<ImageLabel> labels, InputImage inputImage, {bool isCovered = false}) async {
    if (!mounted) return;

    if (mounted) {
      setState(() {
        _latestMLKitLabels = labels.take(5).map((l) => _refineLabel(l.label)).toList();
      });
    }

    if (labels.isNotEmpty && mounted) {
      ImageLabel? targetLabelObj;
      for (final l in labels) {
        final labelText = _refineLabel(l.label).toLowerCase();
        final isBackground = labelText.contains('floor') || 
                             labelText.contains('ground') || 
                             labelText.contains('sky') || 
                             labelText.contains('ceiling') || 
                             labelText.contains('indoor') || 
                             labelText.contains('room') ||
                             labelText.contains('building') ||
                             labelText.contains('architecture') ||
                             labelText.contains('house') ||
                             labelText.contains('infrastructure');
        if (!isBackground) {
          targetLabelObj = l;
          break;
        }
      }
      targetLabelObj ??= labels[0];

      final topLabelText = _refineLabel(targetLabelObj.label);
      final topLabel = topLabelText.toLowerCase();

      if (mounted) {
        setState(() {
          _isCameraCovered = isCovered;
        });
      }

      if (_selectedHudMode == HudMode.navigation || _selectedHudMode == HudMode.objectDetection) {
        Map<String, dynamic>? selectedSim;
        if (isCovered) {
          selectedSim = {
            'title': 'Camera Covered',
            'desc': 'Please check your camera lens.',
            'bg': const Color(0xFFFFEBEE),
            'icon': Icons.block,
            'iconColor': Colors.red,
            'speech': 'The camera is covered. Please remove any obstruction.'
          };
        } else {
          if (_selectedHudMode == HudMode.navigation) {
            final essentialKeywords = [
              'stair', 'step', 'escalator', 'elevator', 'lift',
              'door', 'gate', 'entrance', 'doorway', 'exit',
              'window', 'glass window', 'pane', 'glass',
              'wall', 'partition', 'fence', 'barrier', 'post', 'pole', 'column', 'pillar',
              'pothole', 'hole', 'crack', 'depression',
              'car', 'bus', 'truck', 'vehicle', 'jeepney', 'tricycle', 'motorcycle', 'bicycle',
              'person', 'human', 'man', 'woman', 'pedestrian',
              'sign', 'traffic light', 'traffic signal', 'light signal',
              'chair', 'table', 'desk', 'bench', 'bin', 'trash', 'garbage', 'dumpster',
              'tree', 'branch', 'bush', 'plant', 'obstacle'
            ];
            final isEssential = essentialKeywords.any((k) => topLabel.contains(k));
            if (!isEssential) {
              return;
            }
            _lastHazardDetectionTime = DateTime.now();
          }

          if (topLabel.contains('traffic light') || topLabel.contains('traffic signal') || topLabel.contains('light signal')) {
            selectedSim = _hazardSimulations[14]; // Traffic Light
          } else if (topLabel.contains('fire') || topLabel.contains('smoke') || topLabel.contains('flame')) {
            selectedSim = _hazardSimulations[10]; // Fire
          } else if (topLabel.contains('car') || topLabel.contains('bus') || topLabel.contains('truck') || topLabel.contains('vehicle') || topLabel.contains('traffic')) {
            selectedSim = _hazardSimulations[6]; // Vehicle
          } else if (topLabel.contains('stair') || topLabel.contains('step') || topLabel.contains('escalator')) {
            selectedSim = _hazardSimulations[3]; // Stairs
          } else if (topLabel.contains('sign') || topLabel.contains('traffic sign') || topLabel == 'board' || topLabel.contains('signboard') || topLabel.contains('billboard') || topLabel.contains('banner')) {
            try {
              final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
              final String signText = recognizedText.text.toUpperCase();
              if (signText.contains('STOP')) {
                selectedSim = _hazardSimulations[11]; // STOP!
                selectedSim = Map<String, dynamic>.from(selectedSim)..['speech'] = 'STOP! Stop sign detected. Please halt immediately.';
              } else if (signText.contains('GO') || signText.contains('WALK') || signText.contains('CROSS')) {
                selectedSim = _hazardSimulations[13]; // GO Signal Detected
              } else {
                selectedSim = _hazardSimulations[1]; // General Traffic Sign
                if (recognizedText.text.trim().isNotEmpty) {
                  final words = recognizedText.text.split('\n').first.trim();
                  selectedSim = Map<String, dynamic>.from(selectedSim)..['desc'] = 'Traffic sign detected reading: "$words"'..['speech'] = 'Traffic sign detected reading: $words';
                }
              }
            } catch (e) {
              selectedSim = _hazardSimulations[1]; // General Traffic Sign
            }
          } else if (topLabel.contains('pothole') || topLabel.contains('crack') || topLabel.contains('hole') || topLabel.contains('depression')) {
            selectedSim = _hazardSimulations[7]; // Damaged pathway / Pothole
          } else if (topLabel.contains('person') || topLabel.contains('human') || topLabel.contains('man') || topLabel.contains('woman') || topLabel.contains('child') || topLabel.contains('pedestrian')) {
            selectedSim = _hazardSimulations[12]; // Person Detected
          } else if (topLabel.contains('door') || topLabel.contains('gate') || topLabel.contains('entrance') || topLabel.contains('doorway') || topLabel.contains('exit') || topLabel.contains('elevator') || topLabel.contains('lift')) {
            final isTagalog = SettingsService().selectedLanguage.toLowerCase().contains('tagalog') || SettingsService().selectedLanguage.toLowerCase().contains('filipino');
            selectedSim = {
              'title': isTagalog ? 'May Pintuan sa Harap' : 'Door Ahead',
              'desc': isTagalog ? 'Papalapit ka sa isang pintuan.' : 'You are approaching a door.',
              'bg': const Color(0xFFE0F7FA), // Soft cyan non-critical notice
              'icon': Icons.door_front_door_outlined,
              'iconColor': Colors.teal,
              'speech': isTagalog ? 'Papalapit ka sa isang pintuan.' : 'You are approaching a door.'
            };
          } else if (topLabel.contains('window') || topLabel.contains('glass window') || topLabel.contains('pane')) {
            final isTagalog = SettingsService().selectedLanguage.toLowerCase().contains('tagalog') || SettingsService().selectedLanguage.toLowerCase().contains('filipino');
            selectedSim = {
              'title': isTagalog ? 'May Bintana sa Malapit' : 'Window Nearby',
              'desc': isTagalog ? 'Papalapit ka sa bintana o salamin.' : 'You are approaching a window or glass pane.',
              'bg': const Color(0xFFE3F2FD), // Soft blue non-critical notice
              'icon': Icons.window_outlined,
              'iconColor': Colors.blue,
              'speech': isTagalog ? 'Papalapit ka sa bintana.' : 'You are approaching a window.'
            };
          } else if (topLabel.contains('wall')) {
            selectedSim = {
              'title': 'Wall Detected',
              'desc': 'Slow down. Wall blocking path.',
              'bg': const Color(0xFFFFF8E1),
              'icon': Icons.fence_rounded,
              'iconColor': Colors.orange,
              'speech': 'Wall detected. Slow down.'
            };
          } else if (topLabel.contains('tree') || topLabel.contains('branch') || topLabel.contains('pole') || topLabel.contains('obstacle') || topLabel.contains('post') || topLabel.contains('barrier')) {
            selectedSim = _hazardSimulations[9]; // Obstacle ahead
          } else {
            final cleanLabel = topLabelText[0].toUpperCase() + topLabelText.substring(1);
            final isPathway = topLabel.contains('floor') || 
                              topLabel.contains('ground') || 
                              topLabel.contains('sky') || 
                              topLabel.contains('ceiling') || 
                              topLabel.contains('indoor') ||
                              topLabel.contains('room');

            if (_selectedHudMode == HudMode.navigation && !isPathway) {
              selectedSim = {
                'title': '$cleanLabel Obstacle',
                'desc': 'Slow down. $cleanLabel detected ahead. Please step aside.',
                'bg': const Color(0xFFFFF3E0),
                'icon': Icons.warning_amber_rounded,
                'iconColor': Colors.orange,
                'speech': 'Slow down. $cleanLabel detected ahead. Please step aside.'
              };
            } else {
              selectedSim = {
                'title': '$cleanLabel Detected',
                'desc': '$cleanLabel located in front of you.',
                'bg': const Color(0xFFE8F5E9),
                'icon': Icons.check_circle_outline,
                'iconColor': Colors.green,
                'speech': '$cleanLabel detected.'
              };
            }
          }
        }

        setState(() {
          _detectedObjectLabels = labels.take(3).map((l) => l.label).toList();
          _detectedObjectRects = List.generate(
            _detectedObjectLabels.length,
            (index) {
              double xOffset = 20.0 + (index * 40.0);
              double yOffset = 50.0 + (index * 30.0);
              return Rect.fromLTWH(xOffset, yOffset, 150, 100);
            },
          );

          _activeTitle = selectedSim!['title'];
          _activeDescription = selectedSim['desc'];
          _statusCardBg = selectedSim['bg'];
          _statusIcon = selectedSim['icon'];
          _statusIconColor = selectedSim['iconColor'];
        });

        final now = DateTime.now();
        final String title = selectedSim['title'];
        final String speech = selectedSim['speech'];

        final isImmediate = title == 'STOP!' || title == 'Fire Hazard!';
        final cooldownLimit = isImmediate ? 5 : 15;

        final lastSpoken = _lastSpokenMap[title];
        final cooldownElapsed = lastSpoken == null ||
            now.difference(lastSpoken).inSeconds >= cooldownLimit;

        if (cooldownElapsed) {
          _lastSpokenMap[title] = now;
          _triggerHapticAlert(isCritical: isImmediate);
          if (!_isContinuousVoiceEnabled) {
            TtsService().speak(speech);
          }
          NotificationService().pushWarning(title, speech);
        }
      } else if (_selectedHudMode == HudMode.scenery) {
        final now = DateTime.now();
        final alertKey = 'scenery_details';
        final lastSpoken = _lastSpokenMap[alertKey];
        final ambientLabels = _latestMLKitLabels.take(3).join(" and ");
        if (ambientLabels.isNotEmpty) {
          final isDifferent = ambientLabels != _lastSpokenSceneryText;
          final cooldownElapsed = lastSpoken == null ||
              now.difference(lastSpoken).inSeconds >= (isDifferent ? 15 : 35);
          if (cooldownElapsed) {
            _lastSpokenMap[alertKey] = now;
            _lastSpokenSceneryText = ambientLabels;

            final isTagalog = SettingsService().selectedLanguage.toLowerCase().contains('tagalog') || SettingsService().selectedLanguage.toLowerCase().contains('filipino');
            final isOutside = _latestMLKitLabels.any((label) {
              final l = label.toLowerCase();
              return l.contains('outside') ||
                     l.contains('nature') ||
                     l.contains('road') ||
                     l.contains('sky') ||
                     l.contains('building') ||
                     l.contains('street') ||
                     l.contains('outdoor') ||
                     l.contains('tree') ||
                     l.contains('grass') ||
                     l.contains('plant') ||
                     l.contains('vehicle') ||
                     l.contains('car') ||
                     l.contains('sidewalk') ||
                     l.contains('park') ||
                     l.contains('garden') ||
                     l.contains('scenery') ||
                     l.contains('infrastructure');
            });

            final speech = isOutside
                ? (isTagalog
                    ? "Mag-ingat palagi, tila nasa labas ka. Nakikita ko ang $ambientLabels."
                    : "Always be careful, you are most likely outside. I see $ambientLabels.")
                : (isTagalog
                    ? "Mukhang nasa loob ka ng silid. Nakikita ko ang $ambientLabels."
                    : "It seems you are indoors. I see $ambientLabels.");

            if (!_isContinuousVoiceEnabled) {
              TtsService().speak(speech);
            }
            
            setState(() {
              _activeTitle = "Scenery Mode";
              _activeDescription = "Resembles $ambientLabels";
              _statusCardBg = const Color(0xFFFEFCBF);
              _statusIcon = Icons.nature_people;
              _statusIconColor = const Color(0xFFD69E2E);
            });
          }
        }
      }
    }
  }

  bool _wasEsp32Connected = false;

  Future<void> _onEsp32FrameAvailable() async {
    if (!mounted) return;
    final connected = Esp32Service().isConnected;
    if (connected != _wasEsp32Connected) {
      _wasEsp32Connected = connected;
      if (connected) {
        // Pause/dispose native camera when glasses connect to save battery
        _cameraController?.stopImageStream();
        _cameraController?.dispose();
        _cameraController = null;
        setState(() {
          _useMobileCamera = false;
          _isCameraInitialized = true;
          _pairStep = 4; // Go directly to live preview screen S01
        });
      } else {
        // Glasses cut off, lost connection, or battery died out!
        // Immediately fall back to mobile camera by default without hanging!
        _initializeCamera(forceMobile: true);
        final isTagalog = SettingsService().selectedLanguage.toLowerCase().contains('tagalog') || SettingsService().selectedLanguage.toLowerCase().contains('filipino');
        TtsService().speak(isTagalog ? "Nawala ang koneksyon ng salamin. Lumipat sa camera ng telepono." : "Glasses disconnected. Switched to phone camera.");
      }
    }

    if (_isPaused || !connected || _useMobileCamera) return;
    await _processEsp32Frame();
  }

  Future<void> _processEsp32Frame() async {
    final esp32 = Esp32Service();
    final frameBytes = esp32.currentFrame;
    if (frameBytes == null || frameBytes.isEmpty) return;

    if (_isProcessingFrame) return;
    _isProcessingFrame = true;

    try {
      _esp32CachedFile ??= File('${(await getTemporaryDirectory()).path}/esp32_frame.jpg');
      final file = _esp32CachedFile!;
      await file.writeAsBytes(frameBytes);

      final inputImage = InputImage.fromFile(file);
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final Size imageSize = const Size(640, 480); // Default ESP32-CAM stream dimensions

      if (_selectedHudMode == HudMode.faceRecognition) {
        if (nowMs - _lastFaceDetectionTime > 1500 && _faceDetector != null) {
          _lastFaceDetectionTime = nowMs;
          final faces = await _faceDetector!.processImage(inputImage);
          await _processFaceResults(faces, imageSize);
        }
      } else if (_selectedHudMode == HudMode.objectDetection) {
        if (nowMs - _lastObjectDetectionTime > 350) {
          _lastObjectDetectionTime = nowMs;
          await _detectAndProcessTfliteOnlyFromJpg(frameBytes);
        }
        if (_imageLabeler != null) {
          final List<ImageLabel> labels = await _imageLabeler!.processImage(inputImage);
          if (mounted) {
            setState(() {
              _latestMLKitLabels = labels.take(5).map((l) => _refineLabel(l.label)).toList();
            });
          }
        }
      } else if (_selectedHudMode == HudMode.navigation) {
        if (nowMs - _lastObjectDetectionTime > 400 && _objectDetector != null) {
          _lastObjectDetectionTime = nowMs;
          final objects = await _objectDetector!.processImage(inputImage);
          await _processObjectResults(objects, imageSize);
        }
        if (_imageLabeler != null) {
          final List<ImageLabel> labels = await _imageLabeler!.processImage(inputImage);
          await _processImageLabeling(labels, inputImage, isCovered: false);
        }
      } else {
        if (_imageLabeler != null) {
          final List<ImageLabel> labels = await _imageLabeler!.processImage(inputImage);
          await _processImageLabeling(labels, inputImage, isCovered: false);
        }
      }
    } catch (e) {
      print('ESP32 frame processing error: $e');
    } finally {
      await Future.delayed(const Duration(milliseconds: 300));
      _isProcessingFrame = false;
    }
  }

  void _showNoCameraMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No camera device found on this emulator.')),
    );
  }

  void _onAddDevice() {
    setState(() {
      _pairStep = 2;
    });
  }

  Future<void> _onStartPairing() async {
    if (!mounted) return;
    setState(() => _pairStep = 3);

    // If already connected, skip straight to HUD live view
    if (Esp32Service().isConnected) {
      setState(() {
        _isCameraInitialized = true;
        _pairStep = 4;
      });
      return;
    }

    // Attempt connection with a 10-second timeout so the
    // scanning screen never hangs indefinitely.
    bool ok = false;
    try {
      ok = await Esp32Service().connect().timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );
    } catch (_) {
      ok = false;
    }

    if (!mounted) return;

    if (ok) {
      setState(() {
        _isCameraInitialized = true;
        _pairStep = 4;
      });
    } else {
      // Return to step 2 so the user can try again
      setState(() => _pairStep = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not connect. Make sure you joined "EasyLens-Camera" WiFi and the glasses are on.',
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _onCancelOrBack() {
    _cameraController?.dispose();
    _cameraController = null;
    setState(() {
      _isCameraInitialized = false;
      _pairStep = 1;
    });
  }

  // STT, Gemini & TTS Voice Assistant Integration

  Future<void> _runContinuousVoiceLoop() async {
    if (!_isContinuousVoiceEnabled || !mounted) return;

    final lang = SettingsService().selectedLanguage;
    final isFilipino = lang.toLowerCase().contains('tagalog') ||
        lang.toLowerCase().contains('filipino');

    setState(() {
      _voiceState = "listening";
      _activeTitle = isFilipino ? "Magsalita na..." : "Buddy Listening...";
      _activeDescription = isFilipino 
          ? "Magsalita o manatiling tahimik upang mag-scan."
          : "Say something or remain silent to scan.";
      _statusCardBg = const Color(0xFFE8F5E9);
      _statusIcon = Icons.mic;
      _statusIconColor = Colors.green;
    });

    _continuousVoiceText = "";
    _startSilenceTimer();

    try {
      await SttService().startListening(
        onResult: (text, isFinal) {
          if (!_isContinuousVoiceEnabled || !mounted) return;
          _continuousVoiceText = text;
          // Show live transcription in status card
          if (text.trim().isNotEmpty) {
            setState(() {
              _activeDescription = '"$text"';
            });
          }
          // Reset silence timer on every partial result so speech isn't cut off
          _startSilenceTimer();
          // If STT engine finalized the result, process immediately
          if (isFinal && text.trim().isNotEmpty) {
            _silenceTimer?.cancel();
            _processSilenceOrSpeech();
          }
        },
        onListeningStateChanged: (listening) {
          if (!listening && mounted && _isContinuousVoiceEnabled) {
            // STT stopped naturally — process whatever we captured
            if (_continuousVoiceText.trim().isNotEmpty) {
              _silenceTimer?.cancel();
              _processSilenceOrSpeech();
            } else {
              setState(() {
                _voiceState = "idle";
              });
              // Restart listening loop after a brief pause
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_isContinuousVoiceEnabled && mounted) {
                  _runContinuousVoiceLoop();
                }
              });
            }
          }
        },
      );
    } catch (e) {
      print("[Continuous Voice] STT Error: $e");
    }
  }

  void _startSilenceTimer() {
    _silenceTimer?.cancel();
    if (!_isContinuousVoiceEnabled || !mounted) return;
    _silenceTimer = Timer(const Duration(seconds: 4), () async {
      await _processSilenceOrSpeech();
    });
  }

  Future<Uint8List?> _captureCurrentImageBytes() async {
    if (Esp32Service().isConnected) {
      final frame = Esp32Service().currentFrame;
      if (frame != null && frame.isNotEmpty) {
        return frame;
      }
    }
    // Perform background in-memory frame capture without taking shutter photos or stopping camera stream
    if (_latestNv21Bytes != null && _latestWidth > 0 && _latestHeight > 0) {
      try {
        final jpegBytes = await compute(_nv21ToJpegInIsolate, {
          'nv21': _latestNv21Bytes,
          'width': _latestWidth,
          'height': _latestHeight,
        });
        if (jpegBytes != null && jpegBytes.isNotEmpty) {
          return jpegBytes;
        }
      } catch (e) {
        print("[Camera] Background frame JPEG conversion error: $e");
      }
    }
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final xfile = await _cameraController!.takePicture();
        return await xfile.readAsBytes();
      } catch (e) {
        print("Error capturing native camera image for Gemini: $e");
      }
    }
    return null;
  }

  Future<void> _processSilenceOrSpeech() async {
    _silenceTimer?.cancel();
    if (!_isContinuousVoiceEnabled || !mounted) return;

    final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    if (!isCurrent) {
      TtsService().stop();
      _silenceTimer = Timer(const Duration(seconds: 2), () {
        _processSilenceOrSpeech();
      });
      return;
    }

    final lang = SettingsService().selectedLanguage;
    final isFilipino = lang.toLowerCase().contains('tagalog') ||
        lang.toLowerCase().contains('filipino');

    try {
      await SttService().stopListening((_) {});

      final question = _continuousVoiceText.trim().toLowerCase();
      final isTagalogQuestion = question.contains("ano") ||
          question.contains("paano") ||
          question.contains("bakit") ||
          question.contains("saan") ||
          question.contains("sino") ||
          question.contains("kamusta") ||
          question.contains("kumusta") ||
          question.contains("salamat") ||
          question.contains("tulong") ||
          question.contains("harap") ||
          question.contains("nakikita") ||
          question.contains("ilarawan") ||
          question.contains("tingin") ||
          question.contains("meron") ||
          question.contains("mayroon") ||
          question.contains("nasaan");
      final isFilipino = lang.toLowerCase().contains('tagalog') ||
          lang.toLowerCase().contains('filipino') ||
          isTagalogQuestion;
      
      setState(() {
        _voiceState = "thinking";
        _activeTitle = isFilipino ? "Buddy Nag-iisip..." : "Buddy Thinking...";
        _activeDescription = isFilipino ? "Sinusuri ang paligid..." : "Analyzing view context...";
        _statusCardBg = const Color(0xFFFFF8E1);
        _statusIcon = Icons.hourglass_empty;
        _statusIconColor = Colors.orange;
      });

      final List<String> allDetectedLabels = [];
      if (_tfliteDetections.isNotEmpty) {
        for (final r in _tfliteDetections) {
          final label = _refineLabel(r.label);
          if (label.isNotEmpty && label != '???' && !allDetectedLabels.contains(label)) {
            allDetectedLabels.add(label);
          }
        }
      }
      if (_detectedObjectsList.isNotEmpty) {
        for (final d in _detectedObjectsList) {
          final rawLabel = d.labels.isNotEmpty ? d.labels.first.text : 'Object';
          final label = _refineLabel(rawLabel);
          if (label.isNotEmpty && label != 'object' && !allDetectedLabels.contains(label)) {
            allDetectedLabels.add(label);
          }
        }
      }
      if (_latestMLKitLabels.isNotEmpty) {
        for (final l in _latestMLKitLabels) {
          final label = _refineLabel(l);
          if (label.isNotEmpty && !allDetectedLabels.contains(label)) {
            allDetectedLabels.add(label);
          }
        }
      }

      final detectedItems = allDetectedLabels.join(", ");

      String response = "";
      bool handledByVoiceCommand = false;

      // 1. Voice commands: Switch modes, query scene, and interact
      if (question.isNotEmpty && question != "listening...") {
        if (question.contains("switch to gemini") ||
            question.contains("lumipat sa gemini") ||
            question.contains("use gemini") ||
            question.contains("gemini mode") ||
            question.contains("turn on gemini")) {
          setState(() {
            _useLocalAI = false;
            _isGeminiEnabled = true;
          });
          response = isFilipino
              ? "Lumipat na sa Gemini AI mode. Pwedeng magtanong ng anumang malalim na bagay."
              : "Switched to Gemini AI mode. Feel free to ask complex questions.";
          handledByVoiceCommand = true;
        } else if (question.contains("what's in front of me") ||
            question.contains("what is in front of me") ||
            question.contains("ano ang nasa harap ko") ||
            question.contains("ano nasa harap ko") ||
            question.contains("describe") ||
            question.contains("ilarawan")) {
          // Direct request for visual scene description fallback
          if (detectedItems.trim().isEmpty) {
            response = isFilipino
                ? "Wala akong makitang malinaw na bagay sa iyong harapan sa ngayon."
                : "I don't see any clear objects in front of you right now.";
          } else {
            response = isFilipino
                ? "Sa iyong harapan, nakikita ko ang: $detectedItems."
                : "In front of you, I see: $detectedItems.";
          }
          handledByVoiceCommand = true;
        } else if (question.contains("object") || question.contains("bagay")) {
          setState(() {
            _selectedHudMode = HudMode.objectDetection;
          });
          _applyModeChange(HudMode.objectDetection);
          response = isFilipino 
              ? "Lumipat na sa Object Detection mode." 
              : "Switched to Object Detection mode.";
          handledByVoiceCommand = true;
        } else if (question.contains("face") || question.contains("mukha") || question.contains("register")) {
          setState(() {
            _selectedHudMode = HudMode.faceRecognition;
          });
          _applyModeChange(HudMode.faceRecognition);
          response = isFilipino 
              ? "Lumipat na sa Face Recognition mode." 
              : "Switched to Face Recognition mode.";
          handledByVoiceCommand = true;
        } else if (question.contains("navigation") || question.contains("lakad") || question.contains("map") || question.contains("navigate")) {
          setState(() {
            _selectedHudMode = HudMode.navigation;
          });
          _applyModeChange(HudMode.navigation);
          response = isFilipino 
              ? "Lumipat na sa Navigation mode." 
              : "Switched to Navigation mode.";
          handledByVoiceCommand = true;
        } else if (question.contains("scenery") || question.contains("tanawin")) {
          setState(() {
            _selectedHudMode = HudMode.scenery;
          });
          _applyModeChange(HudMode.scenery);
          response = isFilipino 
              ? "Lumipat na sa Scenery mode." 
              : "Switched to Scenery mode.";
          handledByVoiceCommand = true;
        } else if (question.contains("lock screen") || question.contains("lock mode") || question.contains("i-lock") || question.contains("susi")) {
          setState(() {
            _isScreenLocked = true;
          });
          response = isFilipino 
              ? "Naka-lock na ang screen. Pindutin nang matagal ang screen upang i-unlock." 
              : "Screen locked. Long press the screen to unlock.";
          handledByVoiceCommand = true;
        } else if (question.contains("unlock screen") || question.contains("unlock mode") || question.contains("i-unlock")) {
          setState(() {
            _isScreenLocked = false;
          });
          response = isFilipino 
              ? "Naka-unlock na ang screen." 
              : "Screen unlocked.";
          handledByVoiceCommand = true;
        } else if (question.contains("search place") || question.contains("search for") || question.contains("navigate to") ||
                   question.contains("pumunta sa") || question.contains("hanapin ang") || question.contains("hanapin sa")) {
          // 2. Search place by speech command S01
          final prefixes = ["search place", "search for", "navigate to", "pumunta sa", "hanapin ang", "hanapin sa"];
          String matchedPrefix = "";
          for (final prefix in prefixes) {
            if (question.contains(prefix)) {
              matchedPrefix = prefix;
              break;
            }
          }
          String searchPlace = "";
          if (matchedPrefix.isNotEmpty) {
            final idx = question.indexOf(matchedPrefix) + matchedPrefix.length;
            searchPlace = question.substring(idx).trim();
          }
          if (searchPlace.isNotEmpty) {
            response = isFilipino 
                ? "Hinahanap ang $searchPlace. Sinisimulan ang ruta patungo doon." 
                : "Searching for $searchPlace. Starting route guidance.";
            handledByVoiceCommand = true;
            
            final start = const LatLng(15.1325, 120.5901);
            final end = LatLng(15.1325 + 0.012, 120.5901 + 0.015);
            
            ActiveNavigationService().startNavigation(
              destinationName: searchPlace[0].toUpperCase() + searchPlace.substring(1),
              destinationLocation: end,
              routePoints: [start, end],
            );
            ActiveNavigationService().updateProgress(
              currentStepText: isFilipino
                  ? "Maglakad nang diretso patungo sa $searchPlace"
                  : "Walk straight towards $searchPlace",
              distanceRemaining: "1.2 km",
              timeRemaining: "15 mins",
              currentLocation: start,
            );
          }
        }
      }

      if (handledByVoiceCommand) {
        // Voice command processed S01
      } else if (question.isEmpty || question == "listening...") {
        if (detectedItems.trim().isEmpty && !_useLocalAI) {
          final imageBytes = await _captureCurrentImageBytes();
          final prompt = isFilipino
              ? "You are Buddy, the visual assistant dog. Describe what you see in the provided image in Tagalog. Start the response with 'Nakakita ako ng...' or 'Nakikita ko ang...'. Keep the response to exactly one natural, friendly sentence."
              : "You are Buddy, the visual assistant dog. Describe what you see in the provided image. Start the response with 'I saw...' or 'I see...' (e.g. 'I see a laptop on a table'). Keep the response to exactly one natural, friendly sentence.";
          response = await RagService().askBuddyOnlineGemini(prompt, imageBytes: imageBytes);
        } else if (detectedItems.trim().isEmpty) {
          response = isFilipino 
              ? "Wala akong makitang malinaw na bagay sa iyong harapan."
              : "I don't see any clear objects in front of you.";
        } else {
          final prompt = isFilipino
              ? """
You are Buddy, the visual assistant dog.
Describe these environment labels in Tagalog: $detectedItems.
Start the response with "Nakakita ako ng..." or "Nakikita ko ang...".
Keep the response to exactly one natural, friendly sentence.
"""
              : """
You are Buddy, the visual assistant dog.
Describe the environment based on these visual labels: $detectedItems.
Start the response with "I saw..." or "I see..." (e.g. "I saw a park with a tree" or "I see a laptop or keyboard").
Keep the response to exactly one natural, friendly sentence.
""";
          if (_useLocalAI) {
            response = await RagService().askBuddyLocalOnly(prompt);
          } else {
            final imageBytes = await _captureCurrentImageBytes();
            response = await RagService().askBuddyOnlineGemini(prompt, imageBytes: imageBytes);
          }
        }
      } else {
        // Complex Question Check when Local AI is active
        final isComplexQuery = [
          'why', 'how to', 'explain', 'detail', 'recipe', 'code', 'history',
          'paano', 'bakit', 'ipaliwanag', 'detalye', 'complex', 'summarize'
        ].any((kw) => question.contains(kw));

        if (_useLocalAI && isComplexQuery) {
          response = isFilipino
              ? "Mukhang malalim ang iyong tanong. Pwedeng lumipat sa Gemini AI mode para sa mas detalyadong sagot. Sabihin lang ang 'lumipat sa Gemini'."
              : "That question seems complex! You can switch to Gemini AI mode for deeper answers. Just say 'switch to Gemini'.";
        } else {
          final historyContext = _conversationHistory.isNotEmpty 
              ? "Conversation history context for context awareness:\n${_conversationHistory.join('\n')}\n\n" 
              : "";
          if (_useLocalAI) {
            final prompt = isFilipino
                ? """
You are Buddy, the visual assistant dog.
${historyContext}The user asked: "$question".
The camera reports these environment labels: $detectedItems.
Answer the user's question directly in Tagalog based on the labels and history context. Keep the response to 1 or 2 friendly sentences.
"""
                : """
You are Buddy, the friendly dog mascot and EasyLens assistant.
${historyContext}The user asked: "$question".
The camera reports these environment labels: $detectedItems.
Answer the user's question directly based on the labels and history context. Keep the response to 1 or 2 friendly sentences.
""";
            response = await RagService().askBuddyLocalOnly(prompt);
          } else {
            final prompt = isFilipino
                ? """
You are Buddy, the visual assistant dog.
${historyContext}The user asked: "$question".
Answer the user's question directly in Tagalog based on the provided camera image and history context. Keep the response to 1 or 2 friendly sentences.
"""
                : """
You are Buddy, the friendly dog mascot and EasyLens assistant.
${historyContext}The user asked: "$question".
Answer the user's question directly based on the provided camera image and history context. Keep the response to 1 or 2 friendly sentences.
""";
            final imageBytes = await _captureCurrentImageBytes();
            response = await RagService().askBuddyOnlineGemini(prompt, imageBytes: imageBytes);
          }
        }
      }

      if (response.isEmpty) {
        response = isFilipino ? "Pasensya na, hindi ko naintindihan." : "Sorry, I didn't catch that.";
      }

      if (question.isNotEmpty && question != "listening...") {
        _conversationHistory.add("User: $question");
        _conversationHistory.add("Buddy: $response");
        if (_conversationHistory.length > 10) {
          _conversationHistory.removeRange(0, 2);
        }
      }

      if (mounted) {
        setState(() {
          _voiceState = "speaking";
          _activeTitle = isFilipino ? "Nagsasalita si Buddy" : "Buddy Speaking";
          _activeDescription = response;
          _statusCardBg = const Color(0xFFE6FFFA);
          _statusIcon = Icons.volume_up;
          _statusIconColor = const Color(0xFF38A169);
        });
        await TtsService().speakAwait(response);
      }
    } catch (e) {
      print("[Continuous Voice] Error in _processSilenceOrSpeech: $e");
    } finally {
      setState(() {
        _voiceState = "idle";
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && _isContinuousVoiceEnabled) {
        _runContinuousVoiceLoop();
      }
    }
  }

  Future<void> _describeActiveScene() async {
    setState(() {
      _activeTitle = "Describing scene...";
      _activeDescription = "Analyzing current view...";
      _statusCardBg = const Color(0xFFFFF8E1);
      _statusIcon = Icons.auto_awesome;
      _statusIconColor = Colors.orange;
    });
    TtsService().speak("Analyzing surroundings.");

    final detections = _detectedObjectsList;
    final mlKitLabels = _latestMLKitLabels.join(", ");
    final detectedItems = [
      if (detections.isNotEmpty)
        detections.map((d) {
          final label = d.labels.isNotEmpty ? d.labels.first.text : 'Object';
          final refined = _refineLabel(label);
          return refined;
        }).join(", "),
      if (mlKitLabels.isNotEmpty)
        "general surroundings: $mlKitLabels"
    ].join("; ");

    if (detectedItems.trim().isEmpty) {
      final String noObjectText = "I see a clear space ahead.";
      TtsService().speak(noObjectText);
      setState(() {
        _activeTitle = "Scene Description";
        _activeDescription = noObjectText;
        _statusCardBg = const Color(0xFFE8F5E9);
        _statusIcon = Icons.check_circle_outline;
        _statusIconColor = Colors.green;
      });
      return;
    }

    final prompt = """
You are Buddy, the visual assistant dog.
The user asked you to describe the scene. The camera reports these visual labels: $detectedItems.
Describe the scene in a natural, friendly visual assistant persona, starting with "I saw..." or "I see..." (e.g. "I saw a park with a tree and a bench" or "I see a room with a laptop or keyboard").
Keep the response to exactly one natural, friendly sentence.
""";

    final lang = SettingsService().selectedLanguage;
    final isFilipino = lang.toLowerCase().contains('tagalog') ||
        lang.toLowerCase().contains('filipino');

    String response;
    if (_useLocalAI) {
      response = await RagService().askBuddyLocalOnly(prompt);
      if (response.isEmpty) {
        response = "I see some objects in front of you.";
      }
    } else {
      if (isFilipino) {
        final tagalogPrompt = """
You are Buddy, the visual assistant dog.
Describe these environment labels in Tagalog: $detectedItems.
Start the response with "Nakakita ako ng..." or "Nakikita ko ang...".
Keep the response to exactly one natural, friendly sentence.
""";
        response = await RagService().askBuddyOnlineGemini(tagalogPrompt);
        if (response.isEmpty) {
          response = "Nakikita ko ang ilang mga bagay sa iyong harapan.";
        }
      } else {
        response = await RagService().askBuddyOnlineGemini(prompt);
        if (response.isEmpty) {
          response = "I see some objects in front of you.";
        }
      }
    }

    if (mounted) {
      setState(() {
        _activeTitle = "Scene Description";
        _activeDescription = response;
        _statusCardBg = const Color(0xFFE6FFFA);
        _statusIcon = Icons.visibility;
        _statusIconColor = const Color(0xFF38A169);
      });
      TtsService().speak(response);
    }
  }



  Future<void> _describeSurroundings(StateSetter modalSetState) async {
    modalSetState(() {
      _isThinking = true;
      _geminiAssistantResponse = "Scanning surroundings...";
    });
    TtsService().speak("Analyzing surroundings. Please hold steady.");

    // Simulate scanning delay without freezing the camera
    await Future.delayed(const Duration(milliseconds: 900));

    if (_isCameraCovered) {
      final response = "It looks completely dark! It seems the camera lens is covered. Please check it so I can see your surroundings.";
      if (mounted) {
        modalSetState(() {
          _geminiAssistantResponse = response;
          _isThinking = false;
        });
        TtsService().speak(response);
      }
      return;
    }

    final detections = _detectedObjectsList;
    
    // Draw real bounding boxes on screen dynamically if found
    if (detections.isNotEmpty && mounted) {
      setState(() {
        _detectedObjectLabels = detections.map((d) => d.labels.isNotEmpty ? d.labels.first.text : 'Object').toList();
        _detectedObjectRects = detections.map((d) {
          final r = d.boundingBox;
          final double imgWidth = _faceImageSize != Size.zero ? _faceImageSize.width : 640.0;
          final double imgHeight = _faceImageSize != Size.zero ? _faceImageSize.height : 480.0;
          
          double left = ((1.0 - (r.bottom / imgHeight)) * 300.0).clamp(0.0, 300.0);
          double top = ((r.left / imgWidth) * 250.0).clamp(0.0, 250.0);
          double width = ((r.height / imgHeight) * 300.0).clamp(0.0, 300.0 - left);
          double height = ((r.width / imgWidth) * 250.0).clamp(0.0, 250.0 - top);
          return Rect.fromLTWH(left, top, width, height);
        }).toList();
      });
    }

    final mlKitLabels = _latestMLKitLabels.join(", ");
    final detectedItems = [
      if (detections.isNotEmpty)
        detections.map((d) {
          final label = d.labels.isNotEmpty ? d.labels.first.text : 'Object';
          final confidence = d.labels.isNotEmpty ? d.labels.first.confidence : 0.85;
          return "$label (${(confidence * 100).toInt()}% confidence)";
        }).join(", "),
      if (mlKitLabels.isNotEmpty)
        "general environment labels: $mlKitLabels"
    ].join("; ");

    final prompt = """
You are Buddy, the friendly Golden Retriever visual assistant.
The camera reports these environment objects: $detectedItems.
Explain the surroundings to the user in a short, friendly golden retriever visual assistant persona under 3 sentences.
""";
    
    final response = await RagService().askBuddy(prompt);
    
    if (mounted) {
      modalSetState(() {
        _geminiAssistantResponse = response;
        _isThinking = false;
      });
      TtsService().speak(response);
    }
  }

  Future<void> _startListening(StateSetter modalSetState) async {
    modalSetState(() {
      _isGeminiListening = true;
      _geminiSpokenQuestion = "Listening...";
      _geminiAssistantResponse = "";
    });

    try {
      await SttService().startListening(
        onResult: (text, isFinal) {
          if (mounted) {
            modalSetState(() {
              _geminiSpokenQuestion = text;
            });
          }
        },
        onListeningStateChanged: (listening) {
          if (mounted) {
            modalSetState(() {
              _isGeminiListening = listening;
            });
            if (!listening && !_isThinking) {
              _stopListeningAndQuery(modalSetState);
            }
          }
        },
      );
    } catch (e) {
      modalSetState(() {
        _isGeminiListening = false;
        _geminiSpokenQuestion = "Voice recognition failed: $e";
      });
    }
  }

  Future<void> _stopListeningAndQuery(StateSetter modalSetState) async {
    modalSetState(() {
      _isGeminiListening = false;
      _isThinking = true;
    });

    await SttService().stopListening((listening) {});
    
    if (_geminiSpokenQuestion.isEmpty || _geminiSpokenQuestion == "Listening...") {
      modalSetState(() {
        _isThinking = false;
        _geminiAssistantResponse = "I didn't catch that. Please try asking again.";
      });
      TtsService().speak("I didn't catch that. Please try asking again.");
      return;
    }

    final question = _geminiSpokenQuestion.toLowerCase();
    
    // Check if user specifically requested surroundings description
    if (question.contains("surrounding") || question.contains("environment") || question.contains("see") || question.contains("front")) {
      await _describeSurroundings(modalSetState);
      return;
    }

    // General query using RAG & Gemini
    final response = await RagService().askBuddy(_geminiSpokenQuestion);
    
    if (mounted) {
      modalSetState(() {
        _geminiAssistantResponse = response;
        _isThinking = false;
      });
      TtsService().speak(response);
    }
  }

  void _showGeminiVoiceAssistantBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            // Automatically start listening upon build S01
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_isGeminiListening && !_isThinking && _geminiSpokenQuestion.isEmpty) {
                _startListening(modalSetState);
              }
            });
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Pull Handle
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.orange, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Buddy Voice Assistant',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Mascot Image
                  Image.asset(
                    _isThinking 
                        ? 'assets/mascots/06_thinking.gif' 
                        : _isGeminiListening 
                            ? 'assets/mascots/03_loading.gif'
                            : 'assets/mascots/01_happy.gif',
                    width: 140,
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),

                  // Question Box
                  if (_geminiSpokenQuestion.isNotEmpty) ...[
                    Text(
                      'You said:',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '"$_geminiSpokenQuestion"',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Response/Status Bubble
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder.withOpacity(0.3)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: _isThinking
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(color: Colors.orange),
                                  const SizedBox(height: 12),
                                  Text(
                                    _geminiAssistantResponse.isEmpty ? 'Buddy is processing...' : _geminiAssistantResponse,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(color: AppColors.textMuted),
                                  ),
                                ],
                              )
                            : Text(
                                _geminiAssistantResponse.isEmpty
                                    ? "Hold the microphone button and ask Buddy a question, or tap 'Scan Surroundings' to get a visual description of your environment."
                                    : _geminiAssistantResponse,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: AppColors.primaryText,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quick Scan Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryButton,
                        foregroundColor: AppColors.primaryButtonText,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                      onPressed: _isThinking ? null : () => _describeSurroundings(modalSetState),
                      icon: const Icon(Icons.center_focus_strong, size: 20),
                      label: Text(
                        'Scan Surroundings',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mic Control
                  GestureDetector(
                    onTapDown: (_) => _startListening(modalSetState),
                    onTapUp: (_) => _stopListeningAndQuery(modalSetState),
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: _isGeminiListening ? Colors.red : Colors.orange,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isGeminiListening ? Colors.red : Colors.orange).withOpacity(0.3),
                            blurRadius: 16,
                            spreadRadius: 4,
                          )
                        ],
                      ),
                      child: Icon(
                        _isGeminiListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isGeminiListening ? "Release to Send" : "Hold to Talk",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _isGeminiListening ? Colors.red : Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      // Clean up on modal dismissed S01
      SttService().stopListening((_) {});
      TtsService().stop();
      if (mounted) {
        setState(() {
          _isGeminiListening = false;
          _geminiSpokenQuestion = "";
          _geminiAssistantResponse = "";
          _isThinking = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_pairStep <= 3) {
      return PairingWizard(
        pairStep: _pairStep,
        onInitializeCamera: _initializeCamera,
        onAddDevice: _onAddDevice,
        onStartPairing: _onStartPairing,
        onCancelOrBack: _onCancelOrBack,
      );
    }
    return _buildObjectDetectionScreen();
  }

  Widget _buildObjectDetectionScreen() {
    if (!_isCameraInitialized || (_cameraController == null && !Esp32Service().isConnected)) {
      if (!_isCameraInitialized && (_cameraController == null || !_cameraController!.value.isInitialized)) {
        _initializeCamera();
      }
      return const CameraLoadingOverlay();
    }

    final isTagalog = SettingsService().selectedLanguage.toLowerCase().contains('tagalog') || SettingsService().selectedLanguage.toLowerCase().contains('filipino');

    return Stack(
      children: [
        // Speech Status floating pill S01
        if (_isContinuousVoiceEnabled)
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: _voiceState == "listening"
                      ? Colors.green.withOpacity(0.9)
                      : _voiceState == "thinking"
                          ? Colors.orange.withOpacity(0.9)
                          : _voiceState == "speaking"
                              ? Colors.blue.withOpacity(0.9)
                              : Colors.grey.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _voiceState == "listening"
                          ? Icons.mic
                          : _voiceState == "thinking"
                              ? Icons.hourglass_empty
                              : _voiceState == "speaking"
                                  ? Icons.volume_up
                                  : Icons.mic_off,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _voiceState == "listening"
                          ? (isTagalog ? "Magsalita na" : "Speak Now")
                          : _voiceState == "thinking"
                              ? (isTagalog ? "Nag-iisip..." : "Thinking...")
                              : _voiceState == "speaking"
                                  ? (isTagalog ? "Nagsasalita..." : "Speaking...")
                                  : "Idle",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        Column(
          children: [
            Expanded(
              child: HudCameraView(
                selectedHudMode: _selectedHudMode,
                tfliteDetections: _tfliteDetections,
                detectedObjectsList: _detectedObjectsList,
                latestMLKitLabels: _latestMLKitLabels,
                detectedFacesList: _detectedFacesList,
                faceImageSize: _faceImageSize,
                detectedFaceName: _detectedFaceName,
                faceIdToNameMap: _faceIdToNameMap,
                registeredFaces: _registeredFaces,
                cameraController: _cameraController,
                isCameraInitialized: _isCameraInitialized,
                cocoLabels: _cocoLabels,
              ),
            ),
            const SizedBox(height: 6),
            // Status Card overlay displaying ML Kit Hazard warning matching mockup
            ListenableBuilder(
              listenable: ActiveNavigationService(),
              builder: (context, _) {
                final activeNav = ActiveNavigationService();
                final isArrived = activeNav.isNavigating && activeNav.hasArrived;
                
                final title = isArrived 
                    ? (isTagalog ? "Nakarating Ka Na" : "Destination Arrived") 
                    : _activeTitle;
                final desc = isArrived 
                    ? (isTagalog 
                        ? "Nakarating ka na sa iyong patutunguhan, ${activeNav.destinationName}." 
                        : "You have arrived at your destination, ${activeNav.destinationName}.") 
                    : _activeDescription;
                final bg = isArrived ? const Color(0xFFE9F7EF) : _statusCardBg;
                final icon = isArrived ? Icons.pin_drop_rounded : _statusIcon;
                final iconColor = isArrived ? Colors.green : _statusIconColor;

                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: iconColor.withOpacity(0.12),
                        radius: 16,
                        child: Icon(icon, color: iconColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            Text(
                              desc,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        child: Text(
                          'ACTIVE',
                          style: GoogleFonts.inter(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            HudControlsPanel(
              batteryPercent: _batteryPercent,
              isBluetoothConnected: _isBluetoothConnected,
              isGeminiEnabled: _isGeminiEnabled,
              isWifiOn: _isWifiOn,
              isAudioSpeaker: _isAudioSpeaker,
              isScreenLocked: _isScreenLocked,
              useLocalAI: _useLocalAI,
              isContinuousVoiceEnabled: _isContinuousVoiceEnabled,
              isFlashOn: _isFlashOn,
              useMobileCamera: _useMobileCamera || !Esp32Service().isConnected,
              isDetectionPaused: _isPaused,
              onBluetoothToggled: () async {
                final isTagalog = SettingsService().selectedLanguage.toLowerCase().contains('tagalog') || SettingsService().selectedLanguage.toLowerCase().contains('filipino');
                setState(() {
                  _isBluetoothConnected = !_isBluetoothConnected;
                });
                if (!_isBluetoothConnected) {
                  await Esp32Service().disconnect();
                  setState(() {
                    _useMobileCamera = true;
                  });
                  _initializeCamera(forceMobile: true);
                  TtsService().speak(isTagalog ? "Naka-disconnect na sa EasyLens. Gagamitin ang mobile camera." : "Disconnected from EasyLens. Using mobile camera.");
                } else {
                  setState(() {
                    _useMobileCamera = false;
                  });
                  TtsService().speak(isTagalog ? "Kumokonekta sa EasyLens Smart Glasses..." : "Connecting to EasyLens Smart Glasses...");
                  final connected = await Esp32Service().connect();
                  if (!connected && mounted) {
                    // Open Pairing Wizard if glasses AP is not directly reachable
                    setState(() {
                      _pairStep = 2;
                    });
                  } else if (mounted) {
                    TtsService().speak(isTagalog ? "Naka-connect na sa EasyLens Smart Glasses!" : "Connected to EasyLens Smart Glasses!");
                  }
                }
              },
              onGeminiToggled: () {
                setState(() {
                  if (_isContinuousVoiceEnabled && !_useLocalAI) {
                    _isContinuousVoiceEnabled = false;
                    _isGeminiEnabled = false;
                    _conversationHistory.clear();
                    TtsService().speak(isTagalog ? "Naka-off na ang tuloy-tuloy na boses." : "Continuous voice disabled.");
                  } else {
                    _useLocalAI = false;
                    _isContinuousVoiceEnabled = true;
                    _isGeminiEnabled = true;
                    _conversationHistory.clear();
                    TtsService().speak(isTagalog ? "Aktibo ang Advance AI. Simulan ang tuloy-tuloy na boses." : "Advanced online AI active. Continuous voice enabled.");
                  }
                });
                if (_isContinuousVoiceEnabled) {
                  _runContinuousVoiceLoop();
                } else {
                  _silenceTimer?.cancel();
                  SttService().stopListening((_) {});
                  TtsService().stop();
                  setState(() {
                    _activeTitle = "Path Clear";
                    _activeDescription = "No hazards detected nearby.";
                    _statusCardBg = const Color(0xFFE8F5E9);
                    _statusIcon = Icons.check_circle_outline;
                    _statusIconColor = Colors.green;
                  });
                }
              },
              onLocalAiToggled: () {
                setState(() {
                  if (_isContinuousVoiceEnabled && _useLocalAI) {
                    _isContinuousVoiceEnabled = false;
                    _isGeminiEnabled = false;
                    _conversationHistory.clear();
                    TtsService().speak(isTagalog ? "Naka-off na ang tuloy-tuloy na boses." : "Continuous voice disabled.");
                  } else {
                    _useLocalAI = true;
                    _isContinuousVoiceEnabled = true;
                    _isGeminiEnabled = false;
                    _conversationHistory.clear();
                    TtsService().speak(isTagalog ? "Aktibo ang Local AI. Simulan ang tuloy-tuloy na boses." : "Local offline AI active. Continuous voice enabled.");
                  }
                });
                if (_isContinuousVoiceEnabled) {
                  _runContinuousVoiceLoop();
                  LocalAiInstructionsDialog.show(context);
                } else {
                  _silenceTimer?.cancel();
                  SttService().stopListening((_) {});
                  TtsService().stop();
                  setState(() {
                    _activeTitle = "Path Clear";
                    _activeDescription = "No hazards detected nearby.";
                    _statusCardBg = const Color(0xFFE8F5E9);
                    _statusIcon = Icons.check_circle_outline;
                    _statusIconColor = Colors.green;
                  });
                }
              },
              onAudioToggled: () {
                setState(() {
                  _isAudioSpeaker = !_isAudioSpeaker;
                });
                TtsService().speak(_isAudioSpeaker ? "Phone speaker active." : "Glasses audio route active.");
              },
              onWifiToggled: () {
                setState(() {
                  _isWifiOn = !_isWifiOn;
                });
              },
              onLockToggled: () {
                HapticFeedback.mediumImpact();
                TtsService().speak("Screen locked.");
                setState(() {
                  _isScreenLocked = true;
                });
              },
              onFlashToggled: () async {
                setState(() {
                  _isFlashOn = !_isFlashOn;
                });
                if (Esp32Service().isConnected) {
                  await Esp32Service().setFlash(_isFlashOn);
                } else if (_cameraController != null && _cameraController!.value.isInitialized) {
                  try {
                    await _cameraController!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
                  } catch (_) {}
                }
              },
              onCameraSourceToggled: () async {
                setState(() {
                  _useMobileCamera = !_useMobileCamera;
                });
                if (_useMobileCamera) {
                  await Esp32Service().disconnect(silent: true);
                  _initializeCamera(forceMobile: true);
                  TtsService().speak("Switched to phone camera.");
                } else {
                  _cameraController?.stopImageStream();
                  _cameraController?.dispose();
                  _cameraController = null;
                  final success = await Esp32Service().connect();
                  if (!success) {
                    _initializeCamera(forceMobile: true);
                    TtsService().speak("Could not reach glasses. Using phone camera.");
                  } else {
                    TtsService().speak("Connected to glasses stream.");
                  }
                }
              },
              onDetectionToggled: () {
                setState(() {
                  _isPaused = !_isPaused;
                });
                TtsService().speak(_isPaused ? "Scanner paused." : "Scanner resumed.");
              },
              modeSelector: HudModeSelector(
                selectedHudMode: _selectedHudMode,
                onModeChanged: (mode) {
                  setState(() {
                    _selectedHudMode = mode;
                    _applyModeChange(mode);
                  });
                },
              ),
              disconnectButton: SizedBox(
                width: double.infinity,
                height: 38,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryText,
                    backgroundColor: AppColors.lightBackground,
                    side: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.4), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: _onCancelOrBack,
                  child: Text(
                    'Disconnect HUD Feed',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class YuvData {
  final Uint8List yBytes;
  final Uint8List uBytes;
  final Uint8List vBytes;
  final int width;
  final int height;
  final int yRowStride;
  final int uRowStride;
  final int vRowStride;
  final int uPixelStride;
  final int vPixelStride;

  YuvData({
    required this.yBytes,
    required this.uBytes,
    required this.vBytes,
    required this.width,
    required this.height,
    required this.yRowStride,
    required this.uRowStride,
    required this.vRowStride,
    required this.uPixelStride,
    required this.vPixelStride,
  });
}

Uint8List convertYuvToNv21(YuvData data) {
  final width = data.width;
  final height = data.height;
  final yBuffer = data.yBytes;

  final numPixels = width * height;
  final nv21 = Uint8List(numPixels + (width * height ~/ 2));

  int idY = 0;
  for (int row = 0; row < height; row++) {
    nv21.setRange(idY, idY + width, yBuffer, row * data.yRowStride);
    idY += width;
  }

  final int uvWidth = width ~/ 2;
  final int uvHeight = height ~/ 2;
  final int uPixelStride = data.uPixelStride;
  final int vPixelStride = data.vPixelStride;
  final int uRowStride = data.uRowStride;
  final int vRowStride = data.vRowStride;

  int idUV = numPixels;
  for (int row = 0; row < uvHeight; row++) {
    for (int col = 0; col < uvWidth; col++) {
      nv21[idUV++] = data.vBytes[row * vRowStride + col * vPixelStride];
      nv21[idUV++] = data.uBytes[row * uRowStride + col * uPixelStride];
    }
  }
  return nv21;
}

Uint8List? _nv21ToJpegInIsolate(Map<String, dynamic> params) {
  try {
    final Uint8List nv21 = params['nv21'];
    final int width = params['width'];
    final int height = params['height'];

    final img.Image image = img.Image(width: width, height: height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * width + x;
        final int yValue = nv21[yIndex] & 0xff;
        image.setPixelRgb(x, y, yValue, yValue, yValue);
      }
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 75));
  } catch (_) {
    return null;
  }
}
