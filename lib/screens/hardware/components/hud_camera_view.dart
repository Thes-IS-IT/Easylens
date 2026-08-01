import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../services/notification_service.dart';
import '../../../services/esp32_service.dart';
import '../../../services/active_navigation_service.dart';
import '../../../services/tflite_processor.dart';
import '../../../services/face_registration_service.dart';
import '../../notifications/notifications_screen.dart';
import '../../contacts/contacts_screen.dart';
import '../../settings/settings_screen.dart';
import '../../emergency/emergency_screen.dart';
import '../hardware_screen.dart';
import '../../../utils/app_route.dart';
import 'camera_loading_overlay.dart';

class HudCameraView extends StatelessWidget {
  final HudMode selectedHudMode;
  final List<SSDResult> tfliteDetections;
  final List<DetectedObject> detectedObjectsList;
  final List<String> latestMLKitLabels;
  final List<Face> detectedFacesList;
  final Size faceImageSize;
  final String detectedFaceName;
  final Map<int, String> faceIdToNameMap;
  final List<FaceProfile> registeredFaces;
  final CameraController? cameraController;
  final bool isCameraInitialized;
  final List<String> cocoLabels;

  const HudCameraView({
    super.key,
    required this.selectedHudMode,
    required this.tfliteDetections,
    required this.detectedObjectsList,
    required this.latestMLKitLabels,
    required this.detectedFacesList,
    required this.faceImageSize,
    required this.detectedFaceName,
    required this.faceIdToNameMap,
    required this.registeredFaces,
    required this.cameraController,
    required this.isCameraInitialized,
    required this.cocoLabels,
  });

  String _refineLabel(String rawLabel) {
    final label = rawLabel.replaceAll('_', ' ').toLowerCase();
    if (label.contains('hair drier') || label.contains('hairdryer')) {
      return 'hair drier';
    }
    if (label.contains('musical instrument') || 
        label.contains('piano') || 
        label.contains('musical keyboard') ||
        label.contains('electronic keyboard')) {
      return 'laptop or keyboard';
    }
    if (label.contains('wall') || label.contains('partition') || label.contains('divider') || label.contains('pattern')) {
      return 'wall';
    }
    if (label.contains('door') || label.contains('doorway') || label.contains('entrance') || label.contains('exit') || label.contains('elevator') || label.contains('lift') || label.contains('metal') || label.contains('gate')) {
      return 'door';
    }
    if (label.contains('window') || label.contains('glass window') || label.contains('pane')) {
      return 'window';
    }
    if (label.contains('chair') || label.contains('stool') || label.contains('sofa') || label.contains('couch') || label.contains('armchair')) {
      return 'chair';
    }
    if (label.contains('table') || label.contains('desk') || label.contains('tabletop') || label.contains('countertop')) {
      return 'table';
    }
    if (label.contains('computer') || label.contains('screen') || label.contains('monitor') || label.contains('laptop')) {
      return 'laptop or computer screen';
    }
    if (label.contains('bottle') || label.contains('cup') || label.contains('mug') || label.contains('glass') || label.contains('tableware')) {
      return 'cup or tableware';
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
    return rawLabel;
  }

  @override
  Widget build(BuildContext context) {
    if (!isCameraInitialized || (cameraController == null && !Esp32Service().isConnected)) {
      return const CameraLoadingOverlay();
    }

    return Column(
      children: [
        // App Header Bar (Figma layout matching)
        Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(context, AppRoute.to(const EmergencyScreen()));
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
                          onPressed: () => Navigator.push(context, AppRoute.to(const NotificationsScreen())),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.people_outline, size: 20),
                    onPressed: () => Navigator.push(context, AppRoute.to(const ContactsScreen())),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 20),
                    onPressed: () => Navigator.push(context, AppRoute.to(const SettingsScreen())),
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
                    if (Esp32Service().isConnected && Esp32Service().currentFrame != null)
                      RotatedBox(
                        quarterTurns: 3, // Rotate 270 degrees clockwise for correct vertical alignment of ESP32-CAM
                        child: Image.memory(
                          Esp32Service().currentFrame!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      )
                    else if (cameraController != null && cameraController!.value.isInitialized)
                      CameraPreview(cameraController!)
                    else
                      const CameraLoadingOverlay(),
                    if (selectedHudMode == HudMode.objectDetection) ...[
                      if (tfliteDetections.isNotEmpty)
                        ...tfliteDetections.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final r = entry.value;
                            // SSDResult coordinates are already normalized (0..1)
                            // Rotate coordinates: raw Y (yMin, yMax) maps to screen X (left, width)
                            double left = ((1.0 - r.yMax) * constraints.maxWidth).clamp(0.0, constraints.maxWidth);
                            double width = ((r.yMax - r.yMin) * constraints.maxWidth).clamp(0.0, constraints.maxWidth - left);
                            
                            // Rotate coordinates: raw X (xMin, xMax) maps to screen Y (top, height)
                            double top = (r.xMin * constraints.maxHeight).clamp(0.0, constraints.maxHeight);
                            double height = ((r.xMax - r.xMin) * constraints.maxHeight).clamp(0.0, constraints.maxHeight - top);
                            
                            final label = _refineLabel(r.label);
                            final displayLabel = '${label[0].toUpperCase()}${label.substring(1)} (${(r.confidence * 100).toInt()}%)';

                            return AnimatedPositioned(
                              key: ValueKey('${r.label}_${r.classIndex}_$idx'),
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
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
                      else if (detectedObjectsList.isNotEmpty)
                        ...detectedObjectsList.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final obj = entry.value;
                            final r = obj.boundingBox;
                            final double imgWidth = faceImageSize != Size.zero ? faceImageSize.width : 640.0;
                            final double imgHeight = faceImageSize != Size.zero ? faceImageSize.height : 480.0;
                            
                            double left = ((1.0 - (r.bottom / imgHeight)) * constraints.maxWidth).clamp(0.0, constraints.maxWidth);
                            double top = ((r.left / imgWidth) * constraints.maxHeight).clamp(0.0, constraints.maxHeight);
                            double width = (((r.bottom - r.top) / imgHeight) * constraints.maxWidth).clamp(0.0, constraints.maxWidth - left);
                            double height = (((r.right - r.left) / imgWidth) * constraints.maxHeight).clamp(0.0, constraints.maxHeight - top);
                            
                            final rawLabel = obj.labels.isNotEmpty ? obj.labels.first.text : 'Object';
                            final label = _refineLabel(rawLabel);
                            final displayLabel = '${label[0].toUpperCase()}${label.substring(1)} (Tracked)';

                            return AnimatedPositioned(
                              key: ValueKey('${obj.trackingId?.toString() ?? (label + r.left.toString())}_$idx'),
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              left: left,
                              top: top,
                              width: width.clamp(0.0, constraints.maxWidth - left),
                              height: height.clamp(0.0, constraints.maxHeight - top),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFF59E0B), width: 2.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: Container(
                                    color: const Color(0xFFF59E0B),
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
                    ] else if (selectedHudMode == HudMode.navigation) ...[
                      if (detectedObjectsList.isNotEmpty)
                        ...detectedObjectsList.map((obj) {
                            final r = obj.boundingBox;
                            final double imgWidth = faceImageSize != Size.zero ? faceImageSize.width : 640.0;
                            final double imgHeight = faceImageSize != Size.zero ? faceImageSize.height : 480.0;
                            
                            double left = ((1.0 - (r.bottom / imgHeight)) * constraints.maxWidth).clamp(0.0, constraints.maxWidth);
                            double top = ((r.left / imgWidth) * constraints.maxHeight).clamp(0.0, constraints.maxHeight);
                            double width = ((r.height / imgHeight) * constraints.maxWidth).clamp(0.0, constraints.maxWidth - left);
                            double height = ((r.width / imgWidth) * constraints.maxHeight).clamp(0.0, constraints.maxHeight - top);
                            
                            String label = 'Object';
                            if (obj.labels.isNotEmpty) {
                              final firstLabel = obj.labels.first;
                              if (firstLabel.text.isNotEmpty && firstLabel.text != 'Unknown') {
                                label = _refineLabel(firstLabel.text);
                              } else if (cocoLabels.isNotEmpty && firstLabel.index < cocoLabels.length) {
                                label = _refineLabel(cocoLabels[firstLabel.index]);
                              }
                            }
                            final humanParts = [
                              'leg', 'arm', 'foot', 'hand', 'head', 'body', 'face', 'nose', 'eye', 'mouth', 'hair', 
                              'human', 'pedestrian', 'man', 'woman', 'child', 'boy', 'girl', 'people', 'cyclist', 'rider', 'bystander'
                            ];
                            if (humanParts.any((part) => label.toLowerCase().contains(part))) {
                              label = 'person';
                            }
                            final trackingStr = obj.trackingId != null ? ' #:${obj.trackingId}' : '';
                            final displayLabel = '${label[0].toUpperCase()}${label.substring(1)}$trackingStr';

                            return AnimatedPositioned(
                              key: ValueKey(obj.trackingId ?? obj.boundingBox.topLeft.toString()),
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
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
                      else if (latestMLKitLabels.isNotEmpty)
                        Builder(
                          builder: (context) {
                            String displayLabel = "";
                            for (final label in latestMLKitLabels) {
                              final isPathway = label.toLowerCase().contains('floor') || 
                                                label.toLowerCase().contains('ground') || 
                                                label.toLowerCase().contains('sky') ||
                                                label.toLowerCase().contains('ceiling') ||
                                                label.toLowerCase().contains('indoor') ||
                                                label.toLowerCase().contains('room') ||
                                                label.toLowerCase().contains('building') ||
                                                label.toLowerCase().contains('architecture') ||
                                                label.toLowerCase().contains('house') ||
                                                label.toLowerCase().contains('infrastructure');
                              if (!isPathway) {
                                  displayLabel = label;
                                  break;
                              }
                            }
                            if (displayLabel.isEmpty) {
                              displayLabel = latestMLKitLabels.first;
                            }
                            final isPathway = displayLabel.toLowerCase().contains('floor') || 
                                              displayLabel.toLowerCase().contains('ground') || 
                                              displayLabel.toLowerCase().contains('sky') ||
                                              displayLabel.toLowerCase().contains('ceiling') ||
                                              displayLabel.toLowerCase().contains('indoor') ||
                                              displayLabel.toLowerCase().contains('room');
                            if (isPathway) return const SizedBox.shrink();
                            
                            double left = constraints.maxWidth * 0.15;
                            double top = constraints.maxHeight * 0.20;
                            double width = constraints.maxWidth * 0.70;
                            double height = constraints.maxHeight * 0.50;
                            
                            return AnimatedPositioned(
                              key: const ValueKey('mlkit_label'),
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              left: left,
                              top: top,
                              width: width,
                              height: height,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.orangeAccent, width: 2.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: Container(
                                    color: Colors.orangeAccent,
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Text(
                                      "$displayLabel (Tracked)",
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
                          },
                        )
                    ],

                    // Draw face bounding boxes dynamically in Face Recognition mode
                    if (selectedHudMode == HudMode.faceRecognition && faceImageSize != Size.zero)
                      ...detectedFacesList.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final face = entry.value;
                        final r = face.boundingBox;
                        final scaleX = constraints.maxWidth / faceImageSize.width;
                        final scaleY = constraints.maxHeight / faceImageSize.height;
                        
                        double left = r.left * scaleX;
                        double top = r.top * scaleY;
                        double width = r.width * scaleX;
                        double height = r.height * scaleY;
                        
                        final trackingId = face.trackingId;
                        String name = "Face";
                        if (trackingId != null && faceIdToNameMap.containsKey(trackingId)) {
                          name = faceIdToNameMap[trackingId]!;
                        }
                        final trackingStr = trackingId != null ? " #:$trackingId" : "";
                        
                        return AnimatedPositioned(
                          key: ValueKey('${face.trackingId ?? face.boundingBox.topLeft.toString()}_$idx'),
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
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
                              child: OverflowBox(
                                maxWidth: 160,
                                alignment: Alignment.topLeft,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF7C3AED),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(6),
                                      bottomRight: Radius.circular(6),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Text(
                                    "$name$trackingStr",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
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
                    if (detectedFaceName.isNotEmpty)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 400),
                            opacity: detectedFaceName.isNotEmpty ? 1.0 : 0.0,
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
                                    detectedFaceName,
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
                        if (selectedHudMode != HudMode.navigation) {
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
                                      },
                                      zoomControlsEnabled: false,
                                      myLocationButtonEnabled: false,
                                      myLocationEnabled: false,
                                      compassEnabled: false,
                                      mapToolbarEnabled: false,
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
      ],
    );
  }
}
