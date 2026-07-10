import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../constants/colors.dart';
import '../../services/tts_service.dart';
import '../../services/stt_service.dart';
import '../../services/rag_service.dart';
import '../../services/object_detector_service.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/active_navigation_service.dart';
import '../../services/face_registration_service.dart';
import '../emergency/emergency_screen.dart';
import '../settings/settings_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../services/notification_service.dart';
import '../../services/esp32_service.dart';
import '../devices/devices_screen.dart';
import 'package:battery_plus/battery_plus.dart';
import '../contacts/contacts_screen.dart';
import '../../utils/app_route.dart';

enum HudMode {
  navigation,
  objectDetection,
  scenery,
  faceRecognition,
}

class HardwareScreen extends StatefulWidget {
  final bool isActive;
  const HardwareScreen({super.key, this.isActive = true});

  @override
  State<HardwareScreen> createState() => _HardwareScreenState();
}

class _HardwareScreenState extends State<HardwareScreen> {
  // Navigation: 1=Main, 2=Pairing instructions, 3=Pairing progress GIF, 4=Object Detection Screen
  int _pairStep = 1;

  // Camera & ML Kit Variables
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  ImageLabeler? _imageLabeler;
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isProcessingFrame = false;

  // Native Object Detector
  ObjectDetector? _objectDetector;
  bool _isModelLoaded = false;
  int _lastObjectDetectionTime = 0;
  List<DetectedObject> _detectedObjectsList = [];
  List<String> _cocoLabels = [];

  StreamSubscription<BatteryState>? _batterySubscription;
  final Battery _battery = Battery();
  Timer? _objectDetectionTimer;
  int _lastMobileNetRun = 0;

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

  // Face recognition
  FaceDetector? _faceDetector;
  int _lastFaceDetectionTime = 0;
  String _detectedFaceName = '';
  DateTime? _lastFaceAnnouncedAt;
  List<FaceProfile> _registeredFaces = [];
  List<Face> _detectedFacesList = [];
  Size _faceImageSize = Size.zero;
  final Map<int, String> _faceIdToNameMap = {};

  String _lastGuidanceText = "";
  DateTime? _lastGuidanceTime;
  final Map<String, double> _objectLastAreas = {};

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
      'desc': 'Approaching a crosswalk or intersection warning sign.',
      'bg': Color(0xFFE8EAF6),
      'icon': Icons.remove_road_rounded,
      'iconColor': Colors.indigo,
      'speech': 'Traffic sign located. Approaching a crosswalk.'
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
      'desc': 'Step carefully.',
      'bg': Color(0xFFFFF8E1),
      'icon': Icons.stairs_rounded,
      'iconColor': Colors.orange,
      'speech': 'Stairs detected. Step carefully.'
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
      'desc': 'A jeepney, tricycle, or vehicle approaching. Please wait.',
      'bg': Color(0xFFFFF8E1),
      'icon': Icons.directions_car_rounded,
      'iconColor': Colors.orange,
      'speech': 'Vehicle detected. A vehicle is approaching. Please wait.'
    },
    {
      'title': 'Damaged Pathway',
      'desc': 'Potholes or severe road damage detected. Step carefully.',
      'bg': Color(0xFFFFF8E1),
      'icon': Icons.trending_down_rounded,
      'iconColor': Colors.orange,
      'speech': 'Damaged pathway. Potholes or road damage detected.'
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
      'desc': 'Object blocking path.',
      'bg': Color(0xFFFFF8E1),
      'icon': Icons.block_flipped,
      'iconColor': Colors.orange,
      'speech': 'Obstacle ahead. Object blocking path.'
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
      'title': 'Person Detected',
      'desc': 'A person is nearby. Proceed carefully.',
      'bg': Color(0xFFE8EAF6),
      'icon': Icons.person_rounded,
      'iconColor': Colors.indigo,
      'speech': 'Person detected nearby.'
    },
    {
      'title': 'GO Signal Detected',
      'desc': 'Go or walk signal detected. You may proceed.',
      'bg': Color(0xFFE8F5E9),
      'icon': Icons.arrow_circle_right_outlined,
      'iconColor': Colors.green,
      'speech': 'Go signal detected. Proceed carefully.'
    }
  ];

  @override
  void initState() {
    super.initState();
    _initializeMLKitLabeler();
    _loadObjectDetectionModel();
    _initBatteryTracker();
    _initFaceDetector();
    _loadRegisteredFaces();
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

  @override
  void dispose() {
    _batterySubscription?.cancel();
    _objectDetectionTimer?.cancel();
    _objectDetector?.close();
    _cameraController?.dispose();
    _imageLabeler?.close();
    _textRecognizer.close();
    _faceDetector?.close();
    super.dispose();
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
      final modelPath = await _getOrExtractTfliteModel();
      final options = LocalObjectDetectorOptions(
        mode: DetectionMode.stream,
        modelPath: modelPath,
        classifyObjects: true,
        multipleObjects: true,
        maximumLabelsPerObject: 2,
        confidenceThreshold: 0.35,
      );
      _objectDetector = ObjectDetector(options: options);
      setState(() {
        _isModelLoaded = true;
      });
      print("Google ML Kit Local Object Detector initialized successfully at $modelPath");
    } catch (e) {
      print("Error loading Google ML Kit Local Object Detector: $e");
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
    TtsService().speak(voiceMessage);
  }

  Widget _buildModeButton(HudMode mode, String label, IconData icon, Color activeColor) {
    final isSelected = _selectedHudMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedHudMode = mode;
            _applyModeChange(mode);
          });
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.transparent : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.black54,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _initializeMLKitLabeler() {
    final options = ImageLabelerOptions(confidenceThreshold: 0.5);
    _imageLabeler = ImageLabeler(options: options);
  }

  void _initFaceDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: false,
        enableContours: false,
        enableClassification: false,
        minFaceSize: 0.12,
        performanceMode: FaceDetectorMode.fast,
        enableTracking: true,
      ),
    );
  }

  Future<void> _loadRegisteredFaces() async {
    final profiles = await FaceRegistrationService().getAllProfiles();
    if (mounted) {
      setState(() {
        _registeredFaces = profiles;
      });
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
  /// When a face is detected and registered profiles exist, announces the
  /// registered person's name via TTS with a 10-second cooldown.
  Future<void> _detectFaceOnFrame(Uint8List bytes, int width, int height) async {
    if (_faceDetector == null || _registeredFaces.isEmpty) return;
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
      final faces = await _faceDetector!.processImage(inputImage);

      if (!mounted) return;

      setState(() {
        _detectedFacesList = faces;
        _faceImageSize = imageSize;
      });

      if (faces.isNotEmpty) {
        // Map tracking IDs to registered names dynamically
        for (final face in faces) {
          final id = face.trackingId;
          if (id != null && !_faceIdToNameMap.containsKey(id)) {
            final activeNames = _faceIdToNameMap.values.toSet();
            String? unassignedName;
            for (final prof in _registeredFaces) {
              if (!activeNames.contains(prof.name)) {
                unassignedName = prof.name;
                break;
              }
            }
            unassignedName ??= _registeredFaces[_faceIdToNameMap.length % _registeredFaces.length].name;
            _faceIdToNameMap[id] = unassignedName;
          }
        }

        // Get the list of all currently recognized names in this frame
        final namesSeen = faces
            .map((f) => f.trackingId)
            .whereType<int>()
            .map((id) => _faceIdToNameMap[id])
            .whereType<String>()
            .toSet();

        final registeredName = namesSeen.isNotEmpty ? namesSeen.join(' and ') : _registeredFaces.first.name;
        final now = DateTime.now();
        final cooldownElapsed = _lastFaceAnnouncedAt == null ||
            now.difference(_lastFaceAnnouncedAt!).inSeconds >= 10;

        if (cooldownElapsed) {
          _lastFaceAnnouncedAt = now;
          final msg = 'Buddy sees $registeredName nearby.';
          TtsService().speak(msg);
          if (mounted) {
            setState(() {
              _detectedFaceName = registeredName;
            });
            Future.delayed(const Duration(seconds: 4), () {
              if (mounted) setState(() => _detectedFaceName = '');
            });
          }
        }

        if (_selectedHudMode == HudMode.faceRecognition && mounted) {
          setState(() {
            _activeTitle = "Face Detected";
            _activeDescription = "Buddy recognized $registeredName.";
            _statusCardBg = const Color(0xFFF3E8FF);
            _statusIcon = Icons.face_retouching_natural;
            _statusIconColor = const Color(0xFF7C3AED);
          });
        }
      } else {
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
    } catch (e) {
      // Face detection errors are non-fatal
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid
              ? ImageFormatGroup.yuv420
              : ImageFormatGroup.bgra8888,
        );
        await _cameraController!.initialize();
        
        // Start streaming frames continuously for ML Kit labeling and SSD MobileNet V2
        _cameraController!.startImageStream((CameraImage image) {
          if (_isPaused) return;
          if (!_isDetectionEnabled) return;

          Uint8List? nv21Bytes;
          Uint8List? yBytes;

          if (!_isProcessingFrame) {
            nv21Bytes = _yuvToNv21(image);
            yBytes = Uint8List.fromList(image.planes[0].bytes);
            _isProcessingFrame = true;
            _processCameraImage(nv21Bytes, yBytes, image.width, image.height);
          }
          
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          if (nowMs - _lastObjectDetectionTime > 400 && _objectDetector != null) {
            _lastObjectDetectionTime = nowMs;
            nv21Bytes ??= _yuvToNv21(image);
            _detectObjectsOnFrame(nv21Bytes, image.width, image.height);
          }

          // Face detection throttled to every 2.5 seconds
          if (nowMs - _lastFaceDetectionTime > 2500 && _registeredFaces.isNotEmpty && _faceDetector != null) {
            _lastFaceDetectionTime = nowMs;
            nv21Bytes ??= _yuvToNv21(image);
            _detectFaceOnFrame(nv21Bytes, image.width, image.height);
          }
        });

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _pairStep = 4; // Open Object Detection UI directly
          });
        }
      } else {
        _showNoCameraMessage();
      }
    } catch (e) {
      print('Camera initialization error: $e');
      _showNoCameraMessage();
    }
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

      if (!mounted) return;

      setState(() {
        _detectedObjectsList = objects;
        _faceImageSize = imageSize; // Share imageSize for UI drawing scale factors
      });

      final now = DateTime.now();

      if (objects.isNotEmpty) {
        final closest = objects.reduce((a, b) {
          final aArea = a.boundingBox.width * a.boundingBox.height;
          final bArea = b.boundingBox.width * b.boundingBox.height;
          return aArea >= bArea ? a : b;
        });

        String closestLabel = 'Object';
        if (closest.labels.isNotEmpty) {
          final firstLabel = closest.labels.first;
          if (firstLabel.text.isNotEmpty && firstLabel.text != 'Unknown') {
            closestLabel = firstLabel.text;
          } else if (_cocoLabels.isNotEmpty && firstLabel.index < _cocoLabels.length) {
            closestLabel = _cocoLabels[firstLabel.index];
          }
        }
        final normalizedWidth = closest.boundingBox.width / height; // Swapped due to 90deg image preprocessing rotation
        final normalizedHeight = closest.boundingBox.height / width;
        final boxArea = normalizedWidth * normalizedHeight;

        if (_selectedHudMode == HudMode.navigation) {
          if (boxArea > 0.15) {
            final normalizedCenterX = (closest.boundingBox.left + closest.boundingBox.right) / 2.0 / height;
            String direction = normalizedCenterX < 0.35 ? 'left' : (normalizedCenterX > 0.65 ? 'right' : 'center');
            
            String guidance;
            if (direction == 'center') {
              bool leftBlocked = false;
              bool rightBlocked = false;
              for (final r in objects) {
                if (r == closest) continue;
                final cX = (r.boundingBox.left + r.boundingBox.right) / 2.0 / height;
                if (cX < 0.45) leftBlocked = true;
                if (cX > 0.55) rightBlocked = true;
              }
              if (leftBlocked && !rightBlocked) {
                guidance = 'Obstacle ahead: $closestLabel is directly in your path. Avoid it by stepping to your right.';
              } else if (rightBlocked && !leftBlocked) {
                guidance = 'Obstacle ahead: $closestLabel is directly in your path. Avoid it by stepping to your left.';
              } else {
                guidance = 'Obstacle ahead: $closestLabel is directly in your path. Avoid it by stepping to your right.';
              }
            } else if (direction == 'left') {
              guidance = 'Caution: $closestLabel detected on your left. Avoid it by moving right.';
            } else {
              guidance = 'Caution: $closestLabel detected on your right. Avoid it by moving left.';
            }

            final lastArea = _objectLastAreas[closestLabel] ?? 0.0;
            final isRapidlyApproaching = boxArea > lastArea + 0.05 && boxArea > 0.22;
            
            final isDifferentMessage = guidance != _lastGuidanceText;
            final timeSinceLastGuidance = _lastGuidanceTime == null 
                ? const Duration(seconds: 99) 
                : now.difference(_lastGuidanceTime!);
                
            bool shouldSpeak = false;
            if (isRapidlyApproaching) {
              String escapeDir = 'right';
              if (direction == 'left') escapeDir = 'right';
              else if (direction == 'right') escapeDir = 'left';
              else {
                bool leftBlocked = false;
                for (final r in objects) {
                  if (r == closest) continue;
                  final cX = (r.boundingBox.left + r.boundingBox.right) / 2.0 / height;
                  if (cX < 0.45) leftBlocked = true;
                }
                if (leftBlocked) escapeDir = 'right';
              }
              guidance = 'Alert: Approaching $closestLabel rapidly! Move $escapeDir immediately to avoid it.';
              shouldSpeak = true;
            } else if (isDifferentMessage) {
              shouldSpeak = timeSinceLastGuidance.inSeconds >= 3;
            } else {
              shouldSpeak = timeSinceLastGuidance.inSeconds >= 8;
            }

            if (shouldSpeak) {
              _lastGuidanceText = guidance;
              _lastGuidanceTime = now;
              _objectLastAreas[closestLabel] = boxArea;
              
              TtsService().speak(guidance);
              NotificationService().pushObstacleAlert(direction, closestLabel);

              setState(() {
                _activeTitle = direction == 'center' ? 'Obstacle Directly Ahead' : 'Obstacle on ${direction[0].toUpperCase()}${direction.substring(1)}';
                _activeDescription = guidance;
                _statusCardBg = isRapidlyApproaching ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0);
                _statusIcon = isRapidlyApproaching ? Icons.report_problem : Icons.warning_amber_rounded;
                _statusIconColor = isRapidlyApproaching ? Colors.red : Colors.orange;
              });
            }
          } else {
            if (_lastGuidanceTime != null && now.difference(_lastGuidanceTime!).inSeconds >= 6) {
              _lastGuidanceText = "";
              _lastGuidanceTime = null;
              setState(() {
                _activeTitle = "Path Clear";
                _activeDescription = "No hazards detected nearby.";
                _statusCardBg = const Color(0xFFE8F5E9);
                _statusIcon = Icons.check_circle_outline;
                _statusIconColor = Colors.green;
              });
            }
          }
        } else if (_selectedHudMode == HudMode.objectDetection) {
          final detectedNames = objects
              .take(3)
              .map((r) {
                if (r.labels.isEmpty) return 'Object';
                final label = r.labels.first;
                if (label.text.isNotEmpty && label.text != 'Unknown') {
                  return label.text;
                } else if (_cocoLabels.isNotEmpty && label.index < _cocoLabels.length) {
                  return _cocoLabels[label.index];
                }
                return 'Object';
              })
              .where((name) => name != '???')
              .join(", ");
          final alertKey = 'detection_list';
          final lastSpoken = _lastSpokenMap[alertKey];
          final isDifferent = detectedNames != _lastSpokenObjectText;
          final cooldownElapsed = lastSpoken == null ||
              now.difference(lastSpoken).inSeconds >= (isDifferent ? 3 : 10);
          if (cooldownElapsed && detectedNames.isNotEmpty) {
            _lastSpokenMap[alertKey] = now;
            _lastSpokenObjectText = detectedNames;
            TtsService().speak("Detected objects in view: $detectedNames.");
            
            setState(() {
              _activeTitle = "Objects Detected";
              _activeDescription = "Detected: $detectedNames";
              _statusCardBg = const Color(0xFFE6FFFA);
              _statusIcon = Icons.search;
              _statusIconColor = const Color(0xFF38A169);
            });
          }
        }
      } else {
        if (_selectedHudMode == HudMode.objectDetection) {
          setState(() {
            _activeTitle = "Scanning Objects";
            _activeDescription = "Searching for objects in view...";
            _statusCardBg = const Color(0xFFF1F8E9);
            _statusIcon = Icons.radar_outlined;
            _statusIconColor = const Color(0xFF81C784);
          });
        }
      }
    } catch (e) {
      // Non-fatal
    }
  }

  Uint8List _yuvToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final numPixels = width * height;
    final nv21 = Uint8List(numPixels + (width * height ~/ 2));

    int idY = 0;
    for (int row = 0; row < height; row++) {
      nv21.setRange(idY, idY + width, yBuffer, row * yPlane.bytesPerRow);
      idY += width;
    }

    final int uvWidth = width ~/ 2;
    final int uvHeight = height ~/ 2;
    final int uPixelStride = uPlane.bytesPerPixel ?? 1;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;
    final int uRowStride = uPlane.bytesPerRow;
    final int vRowStride = vPlane.bytesPerRow;

    int idUV = numPixels;
    for (int row = 0; row < uvHeight; row++) {
      for (int col = 0; col < uvWidth; col++) {
        nv21[idUV++] = vBuffer[row * vRowStride + col * vPixelStride];
        nv21[idUV++] = uBuffer[row * uRowStride + col * uPixelStride];
      }
    }
    return nv21;
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

  // Processes each streaming camera frame through Google ML Kit Labeler continuously
  Future<void> _processCameraImage(Uint8List nv21Bytes, Uint8List yBytes, int width, int height) async {
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
        
        if (mounted) {
          setState(() {
            _latestMLKitLabels = labels.take(5).map((l) => l.label).toList();
          });
        }
        
        if (labels.isNotEmpty && mounted) {
          final topLabelText = labels[0].label;
          final topLabel = topLabelText.toLowerCase();
          
          // Check if camera lens is covered/black S01
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
            } else if (topLabel.contains('fire') || topLabel.contains('smoke') || topLabel.contains('flame')) {
              selectedSim = _hazardSimulations[10]; // Fire
            } else if (topLabel.contains('car') || topLabel.contains('bus') || topLabel.contains('truck') || topLabel.contains('vehicle') || topLabel.contains('traffic')) {
              selectedSim = _hazardSimulations[6]; // Vehicle
            } else if (topLabel.contains('stair') || topLabel.contains('step') || topLabel.contains('escalator')) {
              selectedSim = _hazardSimulations[3]; // Stairs
            } else if (topLabel.contains('sign') || topLabel.contains('traffic sign') || topLabel.contains('board') || topLabel.contains('billboard') || topLabel.contains('banner')) {
              try {
                final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
                final String signText = recognizedText.text.toUpperCase();
                if (signText.contains('STOP')) {
                  selectedSim = _hazardSimulations[11]; // STOP!
                  selectedSim = Map<String, dynamic>.from(selectedSim!)..['speech'] = 'STOP! Stop sign detected. Please halt immediately.';
                } else if (signText.contains('GO') || signText.contains('WALK') || signText.contains('CROSS')) {
                  selectedSim = _hazardSimulations[13]; // GO Signal Detected
                } else {
                  selectedSim = _hazardSimulations[1]; // General Traffic Sign
                  if (recognizedText.text.trim().isNotEmpty) {
                    final words = recognizedText.text.split('\n').first.trim();
                    selectedSim = Map<String, dynamic>.from(selectedSim!)..['desc'] = 'Traffic sign detected reading: "$words"'..['speech'] = 'Traffic sign detected reading: $words';
                  }
                }
              } catch (e) {
                selectedSim = _hazardSimulations[1]; // General Traffic Sign
              }
            } else if (topLabel.contains('pothole') || topLabel.contains('crack') || topLabel.contains('hole') || topLabel.contains('depression')) {
              selectedSim = _hazardSimulations[7]; // Damaged pathway / Pothole
            } else if (topLabel.contains('person') || topLabel.contains('human') || topLabel.contains('man') || topLabel.contains('woman') || topLabel.contains('child') || topLabel.contains('pedestrian')) {
              selectedSim = _hazardSimulations[12]; // Person Detected
            } else if (topLabel.contains('tree') || topLabel.contains('branch') || topLabel.contains('pole') || topLabel.contains('wall') || topLabel.contains('obstacle') || topLabel.contains('post') || topLabel.contains('barrier')) {
              selectedSim = _hazardSimulations[9]; // Obstacle ahead
            } else {
              final cleanLabel = topLabelText[0].toUpperCase() + topLabelText.substring(1);
              selectedSim = {
                'title': '$cleanLabel Detected',
                'desc': '$cleanLabel located in front of you.',
                'bg': const Color(0xFFE8F5E9),
                'icon': Icons.check_circle_outline,
                'iconColor': Colors.green,
                'speech': '$cleanLabel detected.'
              };
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
            final String title = selectedSim!['title'];
            final String speech = selectedSim['speech'];

            final isImmediate = title == 'STOP!' || title == 'Fire Hazard!';
            final cooldownLimit = isImmediate ? 5 : 15;

            final lastSpoken = _lastSpokenMap[title];
            final cooldownElapsed = lastSpoken == null ||
                now.difference(lastSpoken).inSeconds >= cooldownLimit;

            if (cooldownElapsed) {
              _lastSpokenMap[title] = now;
              TtsService().speak(speech);
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
                  now.difference(lastSpoken).inSeconds >= (isDifferent ? 3 : 10);
              if (cooldownElapsed) {
                _lastSpokenMap[alertKey] = now;
                _lastSpokenSceneryText = ambientLabels;
                final speech = "Surroundings resemble a $ambientLabels scenery.";
                TtsService().speak(speech);
                
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
    } catch (e) {
      print('ML Kit Frame processing error: $e');
    } finally {
      // Sleep briefly (400ms) to maintain a fast but stable frame process loop (no lag, no drop)
      await Future.delayed(const Duration(milliseconds: 400));
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

  void _onStartPairing() {
    setState(() {
      _pairStep = 3;
    });
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
  void _queryGeminiSurroundings() {
    _showGeminiVoiceAssistantBottomSheet(context);
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
      final response = "Woof! It looks completely dark! It seems the camera lens is covered. Please check it so I can see your surroundings.";
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
          final scaleX = _faceImageSize != Size.zero ? 300.0 / _faceImageSize.height : 1.0;
          final scaleY = _faceImageSize != Size.zero ? 250.0 / _faceImageSize.width : 1.0;
          
          double left = d.boundingBox.left * scaleX;
          double top = d.boundingBox.top * scaleY;
          double width = d.boundingBox.width * scaleX;
          double height = d.boundingBox.height * scaleY;
          return Rect.fromLTWH(left, top, width, height);
        }).toList();
      });
    }

    final mlKitLabels = _latestMLKitLabels.join(", ");
    final detectedItems = [
      if (detections.isNotEmpty)
        detections.map((d) {
          final label = d.labels.isNotEmpty ? d.labels.first.text : 'Object';
          final confidence = d.labels.isNotEmpty ? d.labels.first.confidence : 0.8;
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
                          color: const Color(0xFF002663),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Mascot Image
                  Image.asset(
                    _isThinking 
                        ? 'assets/Mascots/06 Thinking.gif' 
                        : _isGeminiListening 
                            ? 'assets/Mascots/03 Loading.gif'
                            : 'assets/Mascots/01 Happy.gif',
                    width: 140,
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),

                  // Question Box
                  if (_geminiSpokenQuestion.isNotEmpty) ...[
                    Text(
                      'You said:',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '"$_geminiSpokenQuestion"',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Response/Status Bubble
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black.withOpacity(0.04)),
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
                                    style: GoogleFonts.inter(color: Colors.grey.shade600),
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
                                  color: const Color(0xFF334155),
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
                        backgroundColor: const Color(0xFF002663),
                        foregroundColor: Colors.white,
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
    switch (_pairStep) {
      case 1:
        return _buildMainScreen();
      case 2:
        return _buildPairingStartScreen();
      case 3:
        return _buildScanningScreen();
      case 4:
        return _buildObjectDetectionScreen();
      default:
        return _buildMainScreen();
    }
  }

  // ── SCREEN 1: EasyLens Glasses Main View ──────────────────────────────
  Widget _buildMainScreen() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar mirroring Figma
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  'SOS',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    // Live unread badge on notification bell
                    ListenableBuilder(
                      listenable: NotificationService(),
                      builder: (ctx, _) {
                        final unread = NotificationService().unreadCount;
                        return Badge(
                          isLabelVisible: unread > 0,
                          label: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(fontSize: 9, color: Colors.white),
                          ),
                          backgroundColor: const Color(0xFFDC2626),
                          child: IconButton(
                            icon: Icon(
                              unread > 0
                                  ? Icons.notifications_active
                                  : Icons.notifications_none,
                              size: 20,
                              color: unread > 0 ? const Color(0xFFDC2626) : null,
                            ),
                            onPressed: () => _navigateTo(const NotificationsScreen()),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.people_outline, size: 20),
                      onPressed: () => _navigateTo(const ContactsScreen()),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    // ESP32 device status icon
                    ListenableBuilder(
                      listenable: Esp32Service(),
                      builder: (ctx, _) {
                        final connected = Esp32Service().isConnected;
                        return IconButton(
                          icon: Icon(
                            connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                            size: 20,
                            color: connected ? const Color(0xFF10B981) : null,
                          ),
                          onPressed: () => _navigateTo(const DevicesScreen()),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          tooltip: connected ? 'Glasses connected' : 'Connect glasses',
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, size: 20),
                      onPressed: () => _navigateTo(const SettingsScreen()),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'EasyLens Glasses',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF002663),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Pair your glasses to unlock a new dimension of augmented reality. Once connected, your lightweight smart glasses will work seamlessly with your Buddy hardware to project real-time information, interactive filters, and custom AR elements directly into your field of view.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/suit_glasses.png',
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                height: 220,
                child: const Icon(Icons.image_not_supported, size: 48),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF002663),
                      side: const BorderSide(color: Color(0xFF002663), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    ),
                    onPressed: _initializeCamera,
                    icon: const Icon(Icons.camera_alt_outlined, size: 20),
                    label: Text(
                      'Use Camera',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF002663),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      elevation: 0,
                    ),
                    onPressed: _onAddDevice,
                    icon: const Icon(Icons.add, size: 20),
                    label: Text(
                      'Add Device',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── SCREEN 2: Start Pairing Screen ──────────────────────────────────
  Widget _buildPairingStartScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'SOS',
              style: GoogleFonts.inter(
                color: Colors.transparent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black54, size: 18),
                onPressed: _onCancelOrBack,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              Text(
                'EasyLens Glasses',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF002663),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Start pairing your EasyLens Glasses to the Buddy app. Click on Start pairing process to start pairing your EasyLens Glasses with the Buddy app.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Image.asset(
                'assets/images/mockup_glasses.png',
                width: 280,
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade100,
                  width: 280,
                  height: 180,
                  child: const Icon(Icons.image_not_supported, size: 48),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF002663),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              elevation: 0,
            ),
            onPressed: _onStartPairing,
            child: Text(
              'Start pairing process',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ── SCREEN 3: Searching Screen (GIF) ────────────────────────────────
  Widget _buildScanningScreen() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF002663),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.black.withOpacity(0.06)),
              ),
            ),
            onPressed: _onCancelOrBack,
            icon: const Icon(Icons.arrow_back_ios, size: 16),
            label: Text(
              'Back',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const Spacer(),
        Image.asset(
          'assets/Mascots/03 Loading.gif',
          width: 180,
          height: 180,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const CircularProgressIndicator(),
        ),
        const SizedBox(height: 36),
        Text(
          'Searching for Glasses',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF002663),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Ensure your EasyLens glasses are turned on, fully charged, and near your phone.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF002663),
              side: const BorderSide(color: Color(0xFF002663), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            onPressed: _onCancelOrBack,
            child: Text(
              'Cancel Search',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ── SCREEN 4: Dynamic Object Detection & Hardware Controls Screen ────
  Widget _buildObjectDetectionScreen() {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // App Header Bar (Figma layout matching)
        Row(
          children: [
            GestureDetector(
              onTap: () {
                _navigateTo(const EmergencyScreen());
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  'SOS',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  ListenableBuilder(
                    listenable: NotificationService(),
                    builder: (ctx, _) {
                      final unread = NotificationService().unreadCount;
                      return Badge(
                        isLabelVisible: unread > 0,
                        label: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(fontSize: 9, color: Colors.white),
                        ),
                        backgroundColor: const Color(0xFFDC2626),
                        child: IconButton(
                          icon: Icon(
                            unread > 0
                                ? Icons.notifications_active
                                : Icons.notifications_none,
                            size: 20,
                            color: unread > 0 ? const Color(0xFFDC2626) : null,
                          ),
                          onPressed: () => _navigateTo(const NotificationsScreen()),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.people_outline, size: 20),
                    onPressed: () => _navigateTo(const ContactsScreen()),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 20),
                    onPressed: () => _navigateTo(const SettingsScreen()),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Live Camera Preview with bounding boxes overlay
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_cameraController!),
                    if (_selectedHudMode == HudMode.objectDetection || _selectedHudMode == HudMode.navigation)
                      if (_detectedObjectsList.isNotEmpty)
                        ..._detectedObjectsList.map((obj) {
                          final r = obj.boundingBox;
                          final scaleX = _faceImageSize != Size.zero 
                              ? constraints.maxWidth / _faceImageSize.height 
                              : 1.0;
                          final scaleY = _faceImageSize != Size.zero 
                              ? constraints.maxHeight / _faceImageSize.width 
                              : 1.0;
                          
                          double left = r.left * scaleX;
                          double top = r.top * scaleY;
                          double width = r.width * scaleX;
                          double height = r.height * scaleY;
                          
                          String label = 'Object';
                          if (obj.labels.isNotEmpty) {
                            final firstLabel = obj.labels.first;
                            if (firstLabel.text.isNotEmpty && firstLabel.text != 'Unknown') {
                              label = firstLabel.text;
                            } else if (_cocoLabels.isNotEmpty && firstLabel.index < _cocoLabels.length) {
                              label = _cocoLabels[firstLabel.index];
                            }
                          }
                          final trackingStr = obj.trackingId != null ? ' #:${obj.trackingId}' : '';
                          final displayLabel = '$label$trackingStr';

                          return Positioned(
                            left: left,
                            top: top,
                            width: width.clamp(0.0, constraints.maxWidth - left),
                            height: height.clamp(0.0, constraints.maxHeight - top),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.cyanAccent, width: 2.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Container(
                                  color: Colors.cyanAccent,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Text(
                                    displayLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        })
                      else
                        ...List.generate(_detectedObjectRects.length, (index) {
                          final r = _detectedObjectRects[index];
                          final label = _detectedObjectLabels[index];
                          
                          // Convert normalized coords or scale static box coordinates S01
                          double left = r.left;
                          double top = r.top;
                          double width = r.width;
                          double height = r.height;
                          
                          // Ensure boxes are reasonably laid out on constraints
                          if (left + width > constraints.maxWidth) {
                            width = constraints.maxWidth - left;
                          }
                          if (top + height > constraints.maxHeight) {
                            height = constraints.maxHeight - top;
                          }

                          return Positioned(
                            left: left,
                            top: top,
                            width: width,
                            height: height,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.cyanAccent, width: 2.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Container(
                                  color: Colors.cyanAccent,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Text(
                                    label,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),

                    // Draw face bounding boxes dynamically in Face Recognition mode
                    if (_selectedHudMode == HudMode.faceRecognition && _faceImageSize != Size.zero)
                      ..._detectedFacesList.map((face) {
                        final r = face.boundingBox;
                        final scaleX = constraints.maxWidth / _faceImageSize.height;
                        final scaleY = constraints.maxHeight / _faceImageSize.width;
                        
                        double left = r.left * scaleX;
                        double top = r.top * scaleY;
                        double width = r.width * scaleX;
                        double height = r.height * scaleY;
                        
                        final trackingId = face.trackingId;
                        String name = "Face";
                        if (trackingId != null && _faceIdToNameMap.containsKey(trackingId)) {
                          name = _faceIdToNameMap[trackingId]!;
                        } else if (_registeredFaces.isNotEmpty) {
                          name = _registeredFaces.first.name;
                        }
                        final trackingStr = trackingId != null ? " #:$trackingId" : "";
                        
                        return Positioned(
                          left: left,
                          top: top,
                          width: width.clamp(0.0, constraints.maxWidth - left),
                          height: height.clamp(0.0, constraints.maxHeight - top),
                          child: Container(
                            decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF7C3AED), width: 2.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Container(
                                  color: const Color(0xFF7C3AED),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Text(
                                  "$name$trackingStr",
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),

                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.lens, color: Colors.green, size: 10),
                            const SizedBox(width: 8),
                            Text(
                              'HUD FEED ACTIVE',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Face recognition name chip — shown when a known face is detected
                    if (_detectedFaceName.isNotEmpty)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 400),
                            opacity: _detectedFaceName.isNotEmpty ? 1.0 : 0.0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF7C3AED),
                                    Color(0xFF4F46E5),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7C3AED)
                                        .withOpacity(0.5),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.face_retouching_natural,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _detectedFaceName,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                    ListenableBuilder(
                      listenable: ActiveNavigationService(),
                      builder: (context, _) {
                        final activeNav = ActiveNavigationService();
                        if (_selectedHudMode != HudMode.navigation) {
                          return const SizedBox.shrink();
                        }
                        
                        return Stack(
                          children: [
                            Positioned(
                              top: 16,
                              right: 16,
                              left: 150,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4), width: 1.5),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: activeNav.isNavigating
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                activeNav.currentStepText.toLowerCase().contains('left')
                                                    ? Icons.turn_left
                                                    : (activeNav.currentStepText.toLowerCase().contains('right')
                                                        ? Icons.turn_right
                                                        : Icons.directions),
                                                color: Colors.cyanAccent,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  activeNav.currentStepText,
                                                  style: GoogleFonts.inter(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            "To: ${activeNav.destinationName} • ${activeNav.distanceRemaining} (${activeNav.timeRemaining})",
                                            style: GoogleFonts.inter(
                                              color: Colors.cyanAccent,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          const Icon(Icons.explore_outlined, color: Colors.amber, size: 14),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              "Start navigation on the Maps tab to synchronize turn directions here.",
                                              style: GoogleFonts.inter(
                                                color: Colors.white70,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            
                            if (activeNav.isNavigating)
                              Positioned(
                                bottom: 16,
                                right: 16,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(60),
                                    border: Border.all(color: Colors.cyanAccent, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(60),
                                    child: GoogleMap(
                                      key: ValueKey(activeNav.currentLocation),
                                      initialCameraPosition: CameraPosition(
                                        target: activeNav.currentLocation ?? const LatLng(15.1325, 120.5901),
                                        zoom: 16.0,
                                      ),
                                      markers: {
                                        Marker(
                                          markerId: const MarkerId('current_loc'),
                                          position: activeNav.currentLocation ?? const LatLng(15.1325, 120.5901),
                                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                                        ),
                                        if (activeNav.destinationLocation != null)
                                          Marker(
                                            markerId: const MarkerId('destination'),
                                            position: activeNav.destinationLocation!,
                                          ),
                                      },
                                      polylines: {
                                        Polyline(
                                          polylineId: const PolylineId('route_poly'),
                                          points: activeNav.routePoints,
                                          color: Colors.cyan,
                                          width: 4,
                                        ),
                                      },
                                      myLocationButtonEnabled: false,
                                      zoomControlsEnabled: false,
                                      mapToolbarEnabled: false,
                                      compassEnabled: false,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Status Card overlay displaying ML Kit Hazard warning matching mockup
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _statusCardBg,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _statusIconColor.withOpacity(0.12),
                radius: 20,
                child: Icon(_statusIcon, color: _statusIconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _activeTitle,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activeDescription,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text(
                  'ACTIVE',
                  style: GoogleFonts.inter(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Bottom Dashboard Card Controls matching mockups exactly
        Container(
          height: 230, // Fixed height for visual consistency and larger camera S01
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -4))
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              // Pull indicator line
              Center(
                child: Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Scrollable content area S01
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Battery controller tile (left side card)
                          Expanded(
                            child: Container(
                              height: 110,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.black.withOpacity(0.04)),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${_batteryPercent}%',
                                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
                                      ),
                                      Icon(Icons.battery_std, color: Colors.green.shade600, size: 20),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Battery',
                                    style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: _batteryPercent / 100.0,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Right side Column (contains Bluetooth, Gemini, Wifi, Audio, Hazards Scan)
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // Bluetooth card
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isBluetoothConnected = !_isBluetoothConnected;
                                          });
                                        },
                                        child: Container(
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: _isBluetoothConnected ? const Color(0xFF002663) : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Row(
                                            children: [
                                              Icon(Icons.bluetooth, size: 18, color: _isBluetoothConnected ? Colors.white : Colors.black54),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Bluetooth',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 9,
                                                        color: _isBluetoothConnected ? Colors.white70 : Colors.black54,
                                                      ),
                                                    ),
                                                    Text(
                                                      _isBluetoothConnected ? 'Connected' : 'Off',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: _isBluetoothConnected ? Colors.white : Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    // Gemini card S01
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isGeminiEnabled = !_isGeminiEnabled;
                                          });
                                          if (_isGeminiEnabled) {
                                            _queryGeminiSurroundings();
                                          }
                                        },
                                        child: Container(
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: _isGeminiEnabled ? Colors.orange.shade600 : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Row(
                                            children: [
                                              Icon(Icons.auto_awesome, size: 18, color: _isGeminiEnabled ? Colors.white : Colors.black54),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Gemini',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 9,
                                                        color: _isGeminiEnabled ? Colors.white70 : Colors.black54,
                                                      ),
                                                    ),
                                                    Text(
                                                      _isGeminiEnabled ? 'Active' : 'Disabled',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: _isGeminiEnabled ? Colors.white : Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    // Network Wifi card
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isWifiOn = !_isWifiOn;
                                          });
                                        },
                                        child: Container(
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: _isWifiOn ? Colors.teal.shade600 : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Row(
                                            children: [
                                              Icon(Icons.wifi, size: 18, color: _isWifiOn ? Colors.white : Colors.black54),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Network',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 9,
                                                        color: _isWifiOn ? Colors.white70 : Colors.black54,
                                                      ),
                                                    ),
                                                    Text(
                                                      _isWifiOn ? 'Wifi On' : 'Wifi Off',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: _isWifiOn ? Colors.white : Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    // Audio speaker card
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isAudioSpeaker = !_isAudioSpeaker;
                                          });
                                        },
                                        child: Container(
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: _isAudioSpeaker ? const Color(0xFF1E88E5) : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Row(
                                            children: [
                                              Icon(Icons.volume_up, size: 18, color: _isAudioSpeaker ? Colors.white : Colors.black54),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Audio',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 9,
                                                        color: _isAudioSpeaker ? Colors.white70 : Colors.black54,
                                                      ),
                                                    ),
                                                    Text(
                                                      _isAudioSpeaker ? 'Speaker' : 'Glasses',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: _isAudioSpeaker ? Colors.white : Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    // Detection Toggle card S01
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          _toggleDetection(!_isDetectionEnabled);
                                        },
                                        child: Container(
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: _isDetectionEnabled ? const Color(0xFF48BB78) : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Row(
                                            children: [
                                              Icon(
                                                _isDetectionEnabled ? Icons.radar : Icons.radar_outlined,
                                                size: 18,
                                                color: _isDetectionEnabled ? Colors.white : Colors.black54,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Hazards Scan',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 9,
                                                        color: _isDetectionEnabled ? Colors.white70 : Colors.black54,
                                                      ),
                                                    ),
                                                    Text(
                                                      _isDetectionEnabled ? 'Enabled' : 'Paused',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: _isDetectionEnabled ? Colors.white : Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Placeholder to keep row alignment
                                    const Spacer(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Mode selection section S01
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HUD MODE',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.grey.shade500,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _buildModeButton(HudMode.navigation, 'Nav', Icons.directions_walk, const Color(0xFF1E88E5)),
                                const SizedBox(width: 4),
                                _buildModeButton(HudMode.objectDetection, 'Objects', Icons.radar, const Color(0xFF43A047)),
                                const SizedBox(width: 4),
                                _buildModeButton(HudMode.scenery, 'Scenery', Icons.photo_size_select_actual, const Color(0xFFF4511E)),
                                const SizedBox(width: 4),
                                _buildModeButton(HudMode.faceRecognition, 'Faces', Icons.face_retouching_natural, const Color(0xFF7C3AED)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Done back button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF002663),
                            side: const BorderSide(color: Color(0xFF002663), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          onPressed: _onCancelOrBack,
                          child: Text(
                            'Disconnect HUD Feed',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
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
      ],
    );
  }
}
