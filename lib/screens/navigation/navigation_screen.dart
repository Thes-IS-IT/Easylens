import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../constants/colors.dart';
import '../../services/tts_service.dart';
import '../../services/firebase_service.dart';
import '../emergency/emergency_screen.dart';
import '../settings/settings_screen.dart';
import '../notifications/notifications_screen.dart';
import '../contacts/contacts_screen.dart';
import '../../utils/app_route.dart';
import '../../services/settings_service.dart';
import '../../services/sound_service.dart';
import '../../services/active_navigation_service.dart';
import '../../services/translation_service.dart';
import '../../widgets/speech_navigation_overlay.dart';
import '../../widgets/screen_tutorial_card.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../services/danger_warning_service.dart';
import '../../widgets/critical_danger_overlay.dart';
import '../../services/navigation_voice_assistant.dart';
import '../../services/journal_service.dart';

class NavigationScreen extends StatefulWidget {
  final bool isActive;
  const NavigationScreen({super.key, this.isActive = true});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {

  String _formatDistance(String distanceStr, String unit) {
    if (unit == 'Imperial') {
      final kmReg = RegExp(r'([\d.]+)\s*km', caseSensitive: false);
      final mReg = RegExp(r'([\d.]+)\s*(?:meters|meter|m\b)', caseSensitive: false);
      
      if (kmReg.hasMatch(distanceStr)) {
        final match = kmReg.firstMatch(distanceStr);
        final kmVal = double.tryParse(match?.group(1) ?? '');
        if (kmVal != null) {
          final miles = kmVal * 0.621371;
          return "${miles.toStringAsFixed(1)} mi";
        }
      } else if (mReg.hasMatch(distanceStr)) {
        final match = mReg.firstMatch(distanceStr);
        final mVal = double.tryParse(match?.group(1) ?? '');
        if (mVal != null) {
          final feet = (mVal * 3.28084).round();
          return "$feet ft";
        }
      }
    }
    return distanceStr;
  }

  String _formatStep(String stepText, String unit) {
    if (unit == 'Imperial') {
      final mReg = RegExp(r'(\d+)\s*(?:meters|meter|m\b)', caseSensitive: false);
      return stepText.replaceAllMapped(mReg, (match) {
        final mVal = double.tryParse(match.group(1) ?? '');
        if (mVal != null) {
          final feet = (mVal * 3.28084).round();
          return "$feet feet";
        }
        return match.group(0) ?? '';
      });
    }
    return stepText;
  }
  // Navigation states
  // 0 = Initial map (Figma screen 1/2) with search card overlay
  // 1 = Navigation Active status (Figma screen 3)
  // 2 = Full navigation detail map view (Figma screen 4)
  int _navState = 0;

  final _searchController = TextEditingController();
  final List<String> _filters = ['Restaurants', 'Gas Stations', 'Hospitals', 'Supermarkets', 'ATMs'];
  String _selectedFilter = '';

  // Google Map Controller & Native Map availability flag
  GoogleMapController? _mapController;
  bool _isNativeMapAvailable = true;
  MapType _currentMapType = MapType.normal;

  // Option E: Map layers, accessibility POI overlay, 3D perspective, and traffic states
  bool _showAccessibilityOverlay = false;
  bool _showTraffic = false;
  bool _is3DPerspective = false;
  bool _isLoadingAccessibilityPOIs = false;
  double _currentHeading = 0.0;
  List<Map<String, dynamic>> _accessibilityPOIs = [];
  static BitmapDescriptor? _staticUser3DPinLight;
  static BitmapDescriptor? _staticUser3DPinDark;
  static BitmapDescriptor? _staticDest3DPinLight;
  static BitmapDescriptor? _staticDest3DPinDark;
  static final Map<String, BitmapDescriptor> _staticBuilding3DMarkerCache = {};

  final Map<String, BitmapDescriptor> _building3DMarkerCache = {};
  BitmapDescriptor? _userLocation3DPin;
  BitmapDescriptor? _destination3DPin;

  Future<void> _preload3DBuildingIcons() async {
    final isDark = SettingsService().isDarkMode ||
        (SettingsService().selectedContrastTheme != 'Default' &&
            SettingsService().selectedContrastTheme != 'Black on White');

    // Populate from static cache immediately if available
    final cachedUserPin = isDark ? _staticUser3DPinDark : _staticUser3DPinLight;
    final cachedDestPin = isDark ? _staticDest3DPinDark : _staticDest3DPinLight;
    if (cachedUserPin != null) _userLocation3DPin = cachedUserPin;
    if (cachedDestPin != null) _destination3DPin = cachedDestPin;
    _building3DMarkerCache.addAll(_staticBuilding3DMarkerCache);

    final types = [
      'style_0', 'style_1', 'style_2', 'style_3',
      'style_4', 'style_5', 'style_6', 'style_7',
      'hospital', 'transit', 'store', 'destination', 'crossing', 'hazard'
    ];

    try {
      final userPin = await _generate3DUserPin(isDark: isDark, heading: _currentHeading);
      final destPin = await _generate3DDestinationPin(isDark: isDark);
      _userLocation3DPin = userPin;
      _destination3DPin = destPin;
      if (isDark) {
        _staticUser3DPinDark = userPin;
        _staticDest3DPinDark = destPin;
      } else {
        _staticUser3DPinLight = userPin;
        _staticDest3DPinLight = destPin;
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("3D pin immediate error: $e");
    }

    await Future.wait(types.map((t) async {
      final key = '${t}_$isDark';
      if (!_building3DMarkerCache.containsKey(key)) {
        try {
          final icon = await _generate3DBuildingBitmap(type: t, isDark: isDark);
          _building3DMarkerCache[key] = icon;
          _staticBuilding3DMarkerCache[key] = icon;
        } catch (e) {
          debugPrint("3D marker gen error: $e");
        }
      }
    }));
    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _generate3DBuildingBitmap({
    required String type,
    required bool isDark,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 140, 160));

    Color wallLeftColor;
    Color wallRightColor;
    Color roofColor;
    Color windowGlowColor;
    Color frameColor;
    Color accentBorder;
    IconData buildingIcon;

    if (type == 'style_0' || type == 'destination') {
      // 1. Cyber Neon Cyan Highrise Tower
      wallLeftColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0);
      wallRightColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      roofColor = isDark ? const Color(0xFF0284C7) : const Color(0xFF38BDF8);
      windowGlowColor = const Color(0xFF38BDF8); // Electric cyan windows
      frameColor = isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7);
      accentBorder = const Color(0xFF0284C7);
      buildingIcon = Icons.apartment_rounded;
    } else if (type == 'style_1' || type == 'store') {
      // 2. Warm Amber Commercial Complex
      wallLeftColor = isDark ? const Color(0xFF1C1917) : const Color(0xFFF5F5F4);
      wallRightColor = isDark ? const Color(0xFF292524) : const Color(0xFFFAFAF9);
      roofColor = isDark ? const Color(0xFFD97706) : const Color(0xFFFBBF24);
      windowGlowColor = const Color(0xFFFBBF24); // Warm illuminated amber windows
      frameColor = isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309);
      accentBorder = const Color(0xFFD97706);
      buildingIcon = Icons.store_rounded;
    } else if (type == 'style_2' || type == 'hospital') {
      // 3. Rose Healthcare & Biotech Center
      wallLeftColor = isDark ? const Color(0xFF831843) : const Color(0xFFFCE7F3);
      wallRightColor = isDark ? const Color(0xFF9D174D) : const Color(0xFFFBCFE8);
      roofColor = isDark ? const Color(0xFFE11D48) : const Color(0xFFFB7185);
      windowGlowColor = const Color(0xFFF43F5E); // Crimson rose windows
      frameColor = isDark ? const Color(0xFFFDA4AF) : const Color(0xFF9F1239);
      accentBorder = const Color(0xFFE11D48);
      buildingIcon = Icons.local_hospital_rounded;
    } else if (type == 'style_3' || type == 'crossing') {
      // 4. Emerald Eco-Terrace / Park Residence
      wallLeftColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
      wallRightColor = isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0);
      roofColor = isDark ? const Color(0xFF059669) : const Color(0xFF34D399);
      windowGlowColor = const Color(0xFF10B981); // Emerald windows
      frameColor = isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46);
      accentBorder = const Color(0xFF10B981);
      buildingIcon = Icons.park_rounded;
    } else if (type == 'style_4') {
      // 5. Violet Modern Residential Highrise
      wallLeftColor = isDark ? const Color(0xFF312E81) : const Color(0xFFEDE9FE);
      wallRightColor = isDark ? const Color(0xFF3730A3) : const Color(0xFFDDD6FE);
      roofColor = isDark ? const Color(0xFF7C3AED) : const Color(0xFFA78BFA);
      windowGlowColor = const Color(0xFFA855F7); // Violet windows
      frameColor = isDark ? const Color(0xFFDDD6FE) : const Color(0xFF6D28D9);
      accentBorder = const Color(0xFF7C3AED);
      buildingIcon = Icons.home_rounded;
    } else if (type == 'style_5') {
      // 6. Golden Horizon Hotel / Corporate Office
      wallLeftColor = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
      wallRightColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A);
      roofColor = isDark ? const Color(0xFFB45309) : const Color(0xFFF59E0B);
      windowGlowColor = const Color(0xFFFDE047); // Golden windows
      frameColor = isDark ? const Color(0xFFFEF08A) : const Color(0xFF92400E);
      accentBorder = const Color(0xFFF59E0B);
      buildingIcon = Icons.corporate_fare_rounded;
    } else if (type == 'style_6' || type == 'transit') {
      // 7. Cobalt Sapphire Transit Hub
      wallLeftColor = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
      wallRightColor = isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE);
      roofColor = isDark ? const Color(0xFF2563EB) : const Color(0xFF60A5FA);
      windowGlowColor = const Color(0xFF60A5FA); // Sapphire windows
      frameColor = isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1D4ED8);
      accentBorder = const Color(0xFF2563EB);
      buildingIcon = Icons.directions_bus_rounded;
    } else {
      // 8. Sunset Coral Plaza & Community Hub
      wallLeftColor = isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFEDD5);
      wallRightColor = isDark ? const Color(0xFF9A3412) : const Color(0xFFFED7AA);
      roofColor = isDark ? const Color(0xFFEA580C) : const Color(0xFFFB923C);
      windowGlowColor = const Color(0xFFFB923C); // Sunset orange windows
      frameColor = isDark ? const Color(0xFFFED7AA) : const Color(0xFFC2410C);
      accentBorder = const Color(0xFFEA580C);
      buildingIcon = Icons.stars_rounded;
    }

    // 1. Soft Isometric Drop Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.32)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);
    canvas.drawOval(const Rect.fromLTWH(26, 114, 88, 26), shadowPaint);

    // 2. Isometric Coordinates
    const double ox = 70;
    const double oy = 120;
    const double dx = 36;
    const double dy = 18;
    const double height = 58;

    final bottomCenter = Offset(ox, oy);
    final bottomLeft = Offset(ox - dx, oy - dy);
    final bottomRight = Offset(ox + dx, oy - dy);
    final topCenter = Offset(ox, oy - height);
    final topLeft = Offset(ox - dx, oy - dy - height);
    final topRight = Offset(ox + dx, oy - dy - height);
    final roofApex = Offset(ox, oy - dy * 2 - height);

    // Left Wall
    final leftPath = Path()
      ..moveTo(bottomCenter.dx, bottomCenter.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(topLeft.dx, topLeft.dy)
      ..lineTo(topCenter.dx, topCenter.dy)
      ..close();
    canvas.drawPath(leftPath, Paint()..color = wallLeftColor);
    canvas.drawPath(
      leftPath,
      Paint()
        ..color = accentBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Right Wall
    final rightPath = Path()
      ..moveTo(bottomCenter.dx, bottomCenter.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(topCenter.dx, topCenter.dy)
      ..close();
    canvas.drawPath(rightPath, Paint()..color = wallRightColor);
    canvas.drawPath(
      rightPath,
      Paint()
        ..color = accentBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Roof Face
    final roofPath = Path()
      ..moveTo(topCenter.dx, topCenter.dy)
      ..lineTo(topLeft.dx, topLeft.dy)
      ..lineTo(roofApex.dx, roofApex.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..close();
    canvas.drawPath(roofPath, Paint()..color = roofColor);
    canvas.drawPath(
      roofPath,
      Paint()
        ..color = accentBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // 3. DRAW DETAILED WINDOWS ON LEFT WALL (3 Floors x 2 Windows)
    for (int floor = 0; floor < 3; floor++) {
      for (int col = 0; col < 2; col++) {
        final double tY = 0.16 + floor * 0.28;
        final double tX1 = col == 0 ? 0.16 : 0.56;
        final double tX2 = col == 0 ? 0.44 : 0.84;
        final double winH = 0.18;

        Offset pL(double u, double v) {
          final bX = ox - dx * u;
          final bY = oy - dy * u - height * v;
          return Offset(bX, bY);
        }

        final w1 = pL(tX1, tY);
        final w2 = pL(tX2, tY);
        final w3 = pL(tX2, tY + winH);
        final w4 = pL(tX1, tY + winH);

        final winPath = Path()
          ..moveTo(w1.dx, w1.dy)
          ..lineTo(w2.dx, w2.dy)
          ..lineTo(w3.dx, w3.dy)
          ..lineTo(w4.dx, w4.dy)
          ..close();

        canvas.drawPath(winPath, Paint()..color = windowGlowColor);
        canvas.drawPath(
          winPath,
          Paint()
            ..color = frameColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );

        final midTop = Offset((w3.dx + w4.dx) / 2, (w3.dy + w4.dy) / 2);
        final midBot = Offset((w1.dx + w2.dx) / 2, (w1.dy + w2.dy) / 2);
        canvas.drawLine(
          midTop,
          midBot,
          Paint()
            ..color = frameColor
            ..strokeWidth = 0.8,
        );
      }
    }

    // 4. DRAW DETAILED WINDOWS ON RIGHT WALL (Upper 2 Floors) + ENTRANCE DOOR
    for (int floor = 1; floor < 3; floor++) {
      for (int col = 0; col < 2; col++) {
        final double tY = 0.16 + floor * 0.28;
        final double tX1 = col == 0 ? 0.16 : 0.56;
        final double tX2 = col == 0 ? 0.44 : 0.84;
        final double winH = 0.18;

        Offset pR(double u, double v) {
          final bX = ox + dx * u;
          final bY = oy - dy * u - height * v;
          return Offset(bX, bY);
        }

        final w1 = pR(tX1, tY);
        final w2 = pR(tX2, tY);
        final w3 = pR(tX2, tY + winH);
        final w4 = pR(tX1, tY + winH);

        final winPath = Path()
          ..moveTo(w1.dx, w1.dy)
          ..lineTo(w2.dx, w2.dy)
          ..lineTo(w3.dx, w3.dy)
          ..lineTo(w4.dx, w4.dy)
          ..close();

        canvas.drawPath(winPath, Paint()..color = windowGlowColor);
        canvas.drawPath(
          winPath,
          Paint()
            ..color = frameColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );

        final midTop = Offset((w3.dx + w4.dx) / 2, (w3.dy + w4.dy) / 2);
        final midBot = Offset((w1.dx + w2.dx) / 2, (w1.dy + w2.dy) / 2);
        canvas.drawLine(
          midTop,
          midBot,
          Paint()
            ..color = frameColor
            ..strokeWidth = 0.8,
        );
      }
    }

    // Ground Floor Entrance Door on Right Wall
    Offset pDoor(double u, double v) {
      final bX = ox + dx * u;
      final bY = oy - dy * u - height * v;
      return Offset(bX, bY);
    }

    final d1 = pDoor(0.24, 0.04);
    final d2 = pDoor(0.76, 0.04);
    final d3 = pDoor(0.76, 0.28);
    final d4 = pDoor(0.24, 0.28);
    final doorPath = Path()
      ..moveTo(d1.dx, d1.dy)
      ..lineTo(d2.dx, d2.dy)
      ..lineTo(d3.dx, d3.dy)
      ..lineTo(d4.dx, d4.dy)
      ..close();
    canvas.drawPath(doorPath, Paint()..color = windowGlowColor.withOpacity(0.95));
    canvas.drawPath(
      doorPath,
      Paint()
        ..color = accentBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // 5. Floating 3D Badge with Icon Above the Roof
    final badgeCenter = Offset(ox, 18);
    final badgePaint = Paint()
      ..color = isDark ? const Color(0xFF0F172A) : Colors.white
      ..style = PaintingStyle.fill;
    final badgeBorder = Paint()
      ..color = accentBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(badgeCenter, 14, Paint()..color = Colors.black.withOpacity(0.25)..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4));
    canvas.drawCircle(badgeCenter, 13, badgePaint);
    canvas.drawCircle(badgeCenter, 13, badgeBorder);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(buildingIcon.codePoint),
      style: TextStyle(
        fontSize: 14,
        fontFamily: buildingIcon.fontFamily,
        package: buildingIcon.fontPackage,
        color: accentBorder,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(badgeCenter.dx - textPainter.width / 2, badgeCenter.dy - textPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(140, 160);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
    return BitmapDescriptor.fromBytes(uint8List);
  }

  Future<BitmapDescriptor> _generate3DUserPin({required bool isDark, required double heading}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 160, 190));

    const double cx = 80;
    const double groundY = 160;
    const double pinY = 56; // Floating high above ground!

    // 1. 3D Ground Shadow & Glowing Concentric Radar Target Rings
    final groundShadow = Paint()
      ..color = Colors.black.withOpacity(0.45)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7);
    canvas.drawOval(const Rect.fromLTWH(cx - 42, groundY - 16, 84, 32), groundShadow);

    final radarRing1 = Paint()
      ..color = const Color(0xFF0284C7).withOpacity(0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8;
    canvas.drawOval(const Rect.fromLTWH(cx - 32, groundY - 12, 64, 24), radarRing1);

    final radarRing2 = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawOval(const Rect.fromLTWH(cx - 50, groundY - 18, 100, 36), radarRing2);

    // Center Ground Target Core Dot
    canvas.drawOval(const Rect.fromLTWH(cx - 8, groundY - 4, 16, 8), Paint()..color = const Color(0xFF0284C7));

    // 2. 3D Vertical Holographic Light Elevation Pillar
    final stemGlow = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.45)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
    canvas.drawLine(const Offset(cx, groundY), const Offset(cx, pinY + 36), stemGlow);

    final stemPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(cx, groundY),
        const Offset(cx, pinY + 36),
        [
          const Color(0xFF0284C7).withOpacity(0.4),
          const Color(0xFF38BDF8),
          const Color(0xFFE0F2FE),
        ],
      )
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(cx, groundY), const Offset(cx, pinY + 36), stemPaint);

    // 3. 3D Elevated Faceted Pin Body
    final leftFacet = Path()
      ..moveTo(cx, pinY + 38)
      ..lineTo(cx - 26, pinY + 6)
      ..cubicTo(cx - 28, pinY - 16, cx - 14, pinY - 28, cx, pinY - 28)
      ..lineTo(cx, pinY + 38)
      ..close();

    final rightFacet = Path()
      ..moveTo(cx, pinY + 38)
      ..lineTo(cx + 26, pinY + 6)
      ..cubicTo(cx + 28, pinY - 16, cx + 14, pinY - 28, cx, pinY - 28)
      ..lineTo(cx, pinY + 38)
      ..close();

    // Shaded Left Facet
    canvas.drawPath(leftFacet, Paint()..color = const Color(0xFF0369A1));
    // Lit Right Facet
    canvas.drawPath(rightFacet, Paint()..color = const Color(0xFF0284C7));

    // Metallic Rim Stroke
    final borderPaint = Paint()
      ..color = const Color(0xFFE0F2FE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;
    canvas.drawPath(leftFacet, borderPaint);
    canvas.drawPath(rightFacet, borderPaint);

    // 4. Glossy Specular Top Highlight
    final highlightPath = Path()
      ..moveTo(cx - 16, pinY - 14)
      ..cubicTo(cx - 12, pinY - 24, cx + 8, pinY - 24, cx + 14, pinY - 16)
      ..cubicTo(cx + 6, pinY - 18, cx - 10, pinY - 18, cx - 16, pinY - 14)
      ..close();
    canvas.drawPath(highlightPath, Paint()..color = Colors.white.withOpacity(0.80));

    // 5. Central 3D Glowing Glass Lens Core
    final lensCenter = const Offset(cx, pinY);
    canvas.drawCircle(lensCenter, 15, Paint()..color = Colors.white);
    canvas.drawCircle(lensCenter, 12, Paint()..color = const Color(0xFF0F172A));
    canvas.drawCircle(lensCenter, 8, Paint()..color = const Color(0xFF38BDF8));
    canvas.drawCircle(lensCenter, 4, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(cx - 4, pinY - 4), 2.2, Paint()..color = Colors.white.withOpacity(0.95));

    final picture = recorder.endRecording();
    final img = await picture.toImage(160, 190);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
    return BitmapDescriptor.fromBytes(uint8List);
  }

  Future<BitmapDescriptor> _generate3DDestinationPin({required bool isDark}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 140, 160));

    const double cx = 70;
    const double groundY = 135;
    const double pinY = 46;

    // 1. 3D Ground Spotlight & Red Target Rings
    final groundShadow = Paint()
      ..color = Colors.black.withOpacity(0.40)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
    canvas.drawOval(const Rect.fromLTWH(cx - 36, groundY - 14, 72, 28), groundShadow);

    final radarRing1 = Paint()
      ..color = const Color(0xFFE11D48).withOpacity(0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawOval(const Rect.fromLTWH(cx - 30, groundY - 11, 60, 22), radarRing1);

    final radarRing2 = Paint()
      ..color = const Color(0xFFF43F5E).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawOval(const Rect.fromLTWH(cx - 44, groundY - 16, 88, 32), radarRing2);

    canvas.drawOval(const Rect.fromLTWH(cx - 7, groundY - 3.5, 14, 7), Paint()..color = const Color(0xFFE11D48));

    // 2. 3D Vertical Ruby Laser Stem
    final stemPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(cx, groundY),
        const Offset(cx, pinY + 32),
        [
          const Color(0xFFE11D48).withOpacity(0.35),
          const Color(0xFFFB7185).withOpacity(0.9),
          const Color(0xFFFFF1F2),
        ],
      )
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(cx, groundY), const Offset(cx, pinY + 30), stemPaint);

    // 3. 3D Faceted Ruby Pin Body
    final leftFacet = Path()
      ..moveTo(cx, pinY + 32)
      ..lineTo(cx - 22, pinY + 4)
      ..cubicTo(cx - 24, pinY - 14, cx - 12, pinY - 24, cx, pinY - 24)
      ..lineTo(cx, pinY + 32)
      ..close();

    final rightFacet = Path()
      ..moveTo(cx, pinY + 32)
      ..lineTo(cx + 22, pinY + 4)
      ..cubicTo(cx + 24, pinY - 14, cx + 12, pinY - 24, cx, pinY - 24)
      ..lineTo(cx, pinY + 32)
      ..close();

    canvas.drawPath(leftFacet, Paint()..color = const Color(0xFF9F1239)); // Shaded ruby
    canvas.drawPath(rightFacet, Paint()..color = const Color(0xFFE11D48)); // Lit crimson

    final borderPaint = Paint()
      ..color = const Color(0xFFFFF1F2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawPath(leftFacet, borderPaint);
    canvas.drawPath(rightFacet, borderPaint);

    final highlightPath = Path()
      ..moveTo(cx - 14, pinY - 12)
      ..cubicTo(cx - 10, pinY - 20, cx + 6, pinY - 20, cx + 12, pinY - 14)
      ..cubicTo(cx + 4, pinY - 16, cx - 8, pinY - 16, cx - 14, pinY - 12)
      ..close();
    canvas.drawPath(highlightPath, Paint()..color = Colors.white.withOpacity(0.8));

    // 4. Center Destination Flag Badge
    final lensCenter = const Offset(cx, pinY);
    canvas.drawCircle(lensCenter, 13, Paint()..color = Colors.white);
    canvas.drawCircle(lensCenter, 11, Paint()..color = const Color(0xFF881337));

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(0xe28e), // Icons.flag_rounded
      style: const TextStyle(
        fontSize: 14,
        fontFamily: 'MaterialIcons',
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(lensCenter.dx - textPainter.width / 2, lensCenter.dy - textPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(140, 160);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
    return BitmapDescriptor.fromBytes(uint8List);
  }

  void _toggle3DPerspective([bool? explicitValue]) {
    SoundService.playClick();
    
    // Guard: 3D perspective is disabled in Satellite imagery mode
    if (_currentMapType == MapType.hybrid) {
      final lang = SettingsService().selectedLanguage;
      final isTagalog = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
      TtsService().speak(isTagalog
          ? "Hindi magagamit ang 3D sa Satellite view. Lumipat sa Standard map."
          : "3D view is unavailable in Satellite mode. Switch to Standard map.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTagalog
                ? "Hindi magagamit ang 3D sa Satellite view (Lumipat sa Standard map)"
                : "3D view is unavailable in Satellite mode (Switch to Standard map)",
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _is3DPerspective = explicitValue ?? !_is3DPerspective;
    });

    if (_is3DPerspective) {
      _preload3DBuildingIcons();
      if (_accessibilityPOIs.isEmpty) {
        _fetchNearbyAccessibilityPOIs();
      }
    }

    final isDark = SettingsService().isDarkMode ||
        (SettingsService().selectedContrastTheme != 'Default' &&
            SettingsService().selectedContrastTheme != 'Black on White');
    _applyMapTheme(isDark);

    final targetTilt = _is3DPerspective ? 60.0 : 0.0;
    final targetZoom = _is3DPerspective ? 18.0 : 16.5;

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLocation,
          zoom: targetZoom,
          tilt: targetTilt,
          bearing: _is3DPerspective ? _currentHeading : 0.0,
        ),
      ),
    );

    final lang = SettingsService().selectedLanguage;
    final isTagalog = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
    TtsService().speak(_is3DPerspective
        ? (isTagalog ? "Naka-on ang 3D Box view." : "3D Box perspective mode enabled.")
        : (isTagalog ? "Naka-on ang 2D flat view." : "2D flat view enabled."));
  }

  // ── ELEVATED 3D ISOMETRIC BOX ARCHITECTURE MAP STYLES ──
  static const String _dark3DBoxMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#090D14"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#94A3B8"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#06080D"}, {"weight": 2.5}]},
  {"featureType": "landscape.man_made", "elementType": "geometry.fill", "stylers": [{"color": "#151A24"}]},
  {"featureType": "landscape.man_made", "elementType": "geometry.stroke", "stylers": [{"color": "#38BDF8"}, {"weight": 1.8}]},
  {"featureType": "landscape.natural", "elementType": "geometry.fill", "stylers": [{"color": "#064E3B"}]},
  {"featureType": "poi", "elementType": "geometry.fill", "stylers": [{"color": "#1E293B"}]},
  {"featureType": "poi.business", "elementType": "geometry.fill", "stylers": [{"color": "#1E3A8A"}]},
  {"featureType": "poi.business", "elementType": "geometry.stroke", "stylers": [{"color": "#F59E0B"}, {"weight": 1.6}]},
  {"featureType": "poi.medical", "elementType": "geometry.fill", "stylers": [{"color": "#831843"}]},
  {"featureType": "poi.medical", "elementType": "geometry.stroke", "stylers": [{"color": "#F43F5E"}, {"weight": 1.6}]},
  {"featureType": "poi.park", "elementType": "geometry.fill", "stylers": [{"color": "#065F46"}]},
  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#1E293B"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#0F172A"}, {"weight": 1.4}]},
  {"featureType": "road.highway", "elementType": "geometry.fill", "stylers": [{"color": "#334155"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#38BDF8"}, {"weight": 1.2}]},
  {"featureType": "transit", "elementType": "geometry.fill", "stylers": [{"color": "#164E63"}]},
  {"featureType": "water", "elementType": "geometry.fill", "stylers": [{"color": "#0369A1"}]}
]
''';

  static const String _light3DBoxMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#EAEFF7"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#1E293B"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#FFFFFF"}, {"weight": 3.0}]},
  {"featureType": "landscape.man_made", "elementType": "geometry.fill", "stylers": [{"color": "#CBD5E1"}]},
  {"featureType": "landscape.man_made", "elementType": "geometry.stroke", "stylers": [{"color": "#0284C7"}, {"weight": 2.0}]},
  {"featureType": "landscape.natural", "elementType": "geometry.fill", "stylers": [{"color": "#D1FAE5"}]},
  {"featureType": "poi", "elementType": "geometry.fill", "stylers": [{"color": "#BAE6FD"}]},
  {"featureType": "poi.business", "elementType": "geometry.fill", "stylers": [{"color": "#93C5FD"}]},
  {"featureType": "poi.business", "elementType": "geometry.stroke", "stylers": [{"color": "#1D4ED8"}, {"weight": 1.8}]},
  {"featureType": "poi.medical", "elementType": "geometry.fill", "stylers": [{"color": "#FBCFE8"}]},
  {"featureType": "poi.medical", "elementType": "geometry.stroke", "stylers": [{"color": "#DB2777"}, {"weight": 1.8}]},
  {"featureType": "poi.park", "elementType": "geometry.fill", "stylers": [{"color": "#A7F3D0"}]},
  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#FFFFFF"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#94A3B8"}, {"weight": 1.4}]},
  {"featureType": "road.highway", "elementType": "geometry.fill", "stylers": [{"color": "#FEF08A"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#F59E0B"}, {"weight": 1.5}]},
  {"featureType": "transit", "elementType": "geometry.fill", "stylers": [{"color": "#CFFAFE"}]},
  {"featureType": "water", "elementType": "geometry.fill", "stylers": [{"color": "#38BDF8"}]}
]
''';

  static const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#171717"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#171717"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
  {"featureType": "administrative.country", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
  {"featureType": "administrative.land_parcel", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#bdbdbd"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#111111"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
  {"featureType": "poi.park", "elementType": "labels.text.stroke", "stylers": [{"color": "#1b1b1b"}]},
  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#2c2c2c"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#373737"}]},
  {"featureType": "road.highway", "elementType": "geometry.fill", "stylers": [{"color": "#3c3c3c"}]},
  {"featureType": "road.highway.controlled_access", "elementType": "geometry", "stylers": [{"color": "#4e4e4e"}]},
  {"featureType": "road.local", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
  {"featureType": "transit", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3d3d3d"}]}
]
''';

  void _applyMapTheme(bool isDark) {
    if (_mapController == null) return;
    try {
      if (_currentMapType == MapType.hybrid) {
        _mapController?.setMapStyle(null);
        return;
      }

      if (_is3DPerspective) {
        _mapController?.setMapStyle(isDark ? _dark3DBoxMapStyle : _light3DBoxMapStyle);
      } else if (isDark) {
        _mapController?.setMapStyle(_darkMapStyle);
      } else {
        _mapController?.setMapStyle(null);
      }
    } catch (e) {
      debugPrint("Error updating map style: $e");
    }
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    final isDark = SettingsService().isDarkMode ||
        (SettingsService().selectedContrastTheme != 'Default' &&
            SettingsService().selectedContrastTheme != 'Black on White');
    _applyMapTheme(isDark);
    if (_is3DPerspective) {
      _preload3DBuildingIcons();
    }
    setState(() {});
  }

  LatLng? _lastPOIFetchLocation;

  Future<void> _fetchNearbyAccessibilityPOIs({bool forceRefresh = false}) async {
    if (_isLoadingAccessibilityPOIs) return;

    final lat = _currentLocation.latitude;
    final lng = _currentLocation.longitude;

    if (!forceRefresh && _lastPOIFetchLocation != null) {
      final distSinceLast = Geolocator.distanceBetween(
        _lastPOIFetchLocation!.latitude,
        _lastPOIFetchLocation!.longitude,
        lat,
        lng,
      );
      if (distSinceLast < 35 && _accessibilityPOIs.isNotEmpty) {
        return;
      }
    }

    setState(() => _isLoadingAccessibilityPOIs = true);
    _lastPOIFetchLocation = LatLng(lat, lng);

    final List<Map<String, dynamic>> fetchedPOIs = [];
    final apiKey = dotenv.env['GOOGLE_MAPS_KEY'] ?? '';
    const androidPackage = 'com.company.easylens';
    const androidCert = '449D1DCB363A578B7DE1E010286D8C0A90A40E57';
    final googleHeaders = {
      'X-Android-Package': androidPackage,
      'X-Android-Cert': androidCert,
    };

    void addPoiIfValid({
      required String name,
      required String type,
      required double pLat,
      required double pLng,
      required String desc,
    }) {
      if (name.trim().isEmpty) return;
      final double distM = Geolocator.distanceBetween(lat, lng, pLat, pLng);
      if (distM > 3000) return; // Within 3km radius

      final bool isDuplicate = fetchedPOIs.any((p) {
        final loc = p['latLng'] as LatLng;
        final d = Geolocator.distanceBetween(loc.latitude, loc.longitude, pLat, pLng);
        return d < 25 || (p['name'].toString().toLowerCase() == name.toLowerCase() && d < 80);
      });

      if (!isDuplicate) {
        fetchedPOIs.add({
          'name': name.trim(),
          'type': type,
          'latLng': LatLng(pLat, pLng),
          'distM': distM,
          'dist': distM < 1000 ? "${distM.round()} m" : "${(distM / 1000).toStringAsFixed(1)} km",
          'desc': desc,
        });
      }
    }

    // 1. Google Places API (Authentic Verified Places via keyword queries in parallel)
    if (apiKey.isNotEmpty) {
      final googleKeywords = [
        {'kw': 'hospital clinic pharmacy health center', 'type': 'hospital', 'desc': 'Healthcare facility & pharmacy station'},
        {'kw': 'bus stop station transit terminal', 'type': 'transit', 'desc': 'Accessible public transit boarding point'},
        {'kw': 'pedestrian crossing overpass bridge footbridge', 'type': 'crossing', 'desc': 'Safe pedestrian crosswalk & walkway'},
      ];

      await Future.wait(
        googleKeywords.map((item) async {
          try {
            final kw = item['kw']!;
            final defaultType = item['type']!;
            final defaultDesc = item['desc']!;
            final url = Uri.parse(
              'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
              '?location=$lat,$lng'
              '&radius=2000'
              '&keyword=${Uri.encodeComponent(kw)}'
              '&key=$apiKey'
            );
            final response = await http.get(url, headers: googleHeaders).timeout(const Duration(seconds: 4));
            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final results = data['results'] as List?;
              if (results != null) {
                for (final res in results) {
                  final pLat = (res['geometry']['location']['lat'] as num).toDouble();
                  final pLng = (res['geometry']['location']['lng'] as num).toDouble();
                  final String name = res['name']?.toString() ?? 'Nearby Point';
                  final types = (res['types'] as List?)?.map((e) => e.toString()).toList() ?? [];

                  String resolvedType = defaultType;
                  String resolvedDesc = defaultDesc;
                  if (types.any((t) => t.contains('transit') || t.contains('bus') || t.contains('station'))) {
                    resolvedType = 'transit';
                    resolvedDesc = 'Accessible public transit & boarding area';
                  } else if (types.any((t) => t.contains('hospital') || t.contains('pharmacy') || t.contains('health') || t.contains('doctor'))) {
                    resolvedType = 'hospital';
                    resolvedDesc = 'Medical facility & pharmacy center';
                  } else if (types.any((t) => t.contains('police') || t.contains('fire_station'))) {
                    resolvedType = 'hazard';
                    resolvedDesc = 'Public safety & emergency post';
                  }

                  addPoiIfValid(
                    name: name,
                    type: resolvedType,
                    pLat: pLat,
                    pLng: pLng,
                    desc: resolvedDesc,
                  );
                }
              }
            }
          } catch (e) {
            debugPrint("Google Places search error: $e");
          }
        }),
      );
    }

    // 2. OpenStreetMap Overpass API (Real-world physical crossings, ramps, and bus stops)
    try {
      final overpassUrl = Uri.parse(
        'https://overpass-api.de/api/interpreter?data='
        '[out:json][timeout:4];'
        '('
        'node["highway"="bus_stop"](around:1500,$lat,$lng);'
        'node["amenity"="pharmacy"](around:1500,$lat,$lng);'
        'node["amenity"="hospital"](around:1500,$lat,$lng);'
        'node["amenity"="clinic"](around:1500,$lat,$lng);'
        'node["highway"="crossing"](around:1500,$lat,$lng);'
        ');'
        'out body 20;'
      );
      final response = await http.get(overpassUrl).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final elements = data['elements'] as List?;
        if (elements != null) {
          for (final el in elements) {
            final double? pLat = (el['lat'] as num?)?.toDouble();
            final double? pLng = (el['lon'] as num?)?.toDouble();
            if (pLat == null || pLng == null) continue;

            final tags = el['tags'] as Map<String, dynamic>? ?? {};
            final String? nameTag = tags['name']?.toString();
            final String highway = tags['highway']?.toString() ?? '';
            final String amenity = tags['amenity']?.toString() ?? '';

            String type = 'crossing';
            String desc = 'Safe pedestrian crossing with tactile aids';
            String name = nameTag ?? 'Pedestrian Crossing';

            if (highway == 'bus_stop' || tags['public_transport'] != null) {
              type = 'transit';
              name = nameTag ?? 'Accessible Bus Stop';
              desc = 'Public transit waiting & boarding point';
            } else if (amenity == 'hospital' || amenity == 'clinic' || amenity == 'pharmacy') {
              type = 'hospital';
              name = nameTag ?? (amenity == 'pharmacy' ? 'Pharmacy' : 'Medical Clinic');
              desc = 'Healthcare facility & pharmacy';
            }

            addPoiIfValid(
              name: name,
              type: type,
              pLat: pLat,
              pLng: pLng,
              desc: desc,
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Overpass API error: $e");
    }

    // 3. OpenStreetMap Photon as secondary live fallback
    if (fetchedPOIs.length < 5) {
      try {
        final queries = [
          {'q': 'hospital', 'type': 'hospital', 'desc': 'Emergency healthcare facility'},
          {'q': 'pharmacy', 'type': 'hospital', 'desc': 'Pharmacy & medical station'},
          {'q': 'bus stop', 'type': 'transit', 'desc': 'Accessible transit waiting area'},
          {'q': 'station', 'type': 'transit', 'desc': 'Public transit station'},
        ];

        await Future.wait(
          queries.map((item) async {
            try {
              final q = item['q']!;
              final url = Uri.parse(
                'https://photon.komoot.io/api/?q=${Uri.encodeComponent(q)}&lat=$lat&lon=$lng&limit=4'
              );
              final response = await http.get(url).timeout(const Duration(seconds: 3));
              if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                final feats = data['features'] as List?;
                if (feats != null) {
                  for (final feat in feats) {
                    final props = feat['properties'] as Map<String, dynamic>? ?? {};
                    final coords = (feat['geometry'] as Map<String, dynamic>?)?['coordinates'] as List?;
                    if (coords != null && coords.length >= 2) {
                      final double pLng = (coords[0] as num).toDouble();
                      final double pLat = (coords[1] as num).toDouble();
                      final String? name = props['name']?.toString() ?? props['street']?.toString();
                      if (name != null && name.isNotEmpty) {
                        addPoiIfValid(
                          name: name,
                          type: item['type']!,
                          pLat: pLat,
                          pLng: pLng,
                          desc: item['desc']!,
                        );
                      }
                    }
                  }
                }
              }
            } catch (_) {}
          }),
        );
      } catch (e) {
        debugPrint("Photon fallback error: $e");
      }
    }

    // Sort exclusively by real distance from user's live position
    fetchedPOIs.sort((a, b) => (a['distM'] as double).compareTo(b['distM'] as double));

    if (mounted) {
      setState(() {
        _accessibilityPOIs = fetchedPOIs;
        _isLoadingAccessibilityPOIs = false;
      });
    }
  }

  void _showMapLayersPullDownSheet() {
    final lang = SettingsService().selectedLanguage;
    final isTagalog = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
    final isDark = SettingsService().isDarkMode ||
        (SettingsService().selectedContrastTheme != 'Default' &&
            SettingsService().selectedContrastTheme != 'Black on White');

    final Set<int> expandedSections = {0}; // Accessibility expanded by default

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final cardBg = AppColors.primaryBackground;
            final primaryText = AppColors.primaryText;
            final secondaryText = AppColors.textMuted;
            final tileBg = AppColors.lightBackground;
            final borderColor = AppColors.cardBorder;
            final unselectedBorder = AppColors.unselectedBorder;
            final actionBtnBg = AppColors.primaryButton;
            final actionBtnText = AppColors.primaryButtonText;

            Widget buildExpandableLayerCard({
              required int index,
              required IconData icon,
              required Color iconColor,
              required String title,
              required String subtitle,
              required bool isSwitchActive,
              required bool isSwitchEnabled,
              required ValueChanged<bool>? onSwitchChanged,
              required String badgeText,
              required List<Map<String, dynamic>> features,
            }) {
              final isExpanded = expandedSections.contains(index);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: tileBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSwitchActive ? primaryText : unselectedBorder,
                    width: isSwitchActive ? 1.8 : 1.0,
                  ),
                ),
                child: Column(
                  children: [
                    // Main Switch Tile with pull-down toggle
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        SoundService.playClick();
                        setModalState(() {
                          if (expandedSections.contains(index)) {
                            expandedSections.remove(index);
                          } else {
                            expandedSections.add(index);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSwitchActive ? iconColor.withOpacity(0.18) : unselectedBorder.withOpacity(0.25),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                color: isSwitchActive ? iconColor : secondaryText,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          title,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isSwitchEnabled ? primaryText : secondaryText,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                        size: 18,
                                        color: secondaryText,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: GoogleFonts.inter(fontSize: 11.5, color: secondaryText),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isSwitchActive,
                              activeColor: primaryText,
                              activeTrackColor: actionBtnBg.withOpacity(0.4),
                              onChanged: isSwitchEnabled ? onSwitchChanged : null,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expandable Definition & Functionalities Drawer
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: unselectedBorder.withOpacity(0.4), width: 1.0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (badgeText.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 10, top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: actionBtnBg.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: unselectedBorder, width: 1.0),
                                ),
                                child: Text(
                                  badgeText,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: primaryText,
                                  ),
                                ),
                              ),
                            ...features.map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2, right: 8),
                                    child: Icon(f['icon'] as IconData, size: 14, color: f['iconColor'] as Color? ?? primaryText),
                                  ),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.inter(fontSize: 11.5, color: secondaryText, height: 1.35),
                                        children: [
                                          TextSpan(
                                            text: "${f['label']}: ",
                                            style: TextStyle(fontWeight: FontWeight.bold, color: primaryText),
                                          ),
                                          TextSpan(text: f['desc'] as String),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                      crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 250),
                    ),
                  ],
                ),
              );
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.86,
              ),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: borderColor, width: 1.5),
                  left: BorderSide(color: borderColor, width: 1.5),
                  right: BorderSide(color: borderColor, width: 1.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowColor,
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pull-down handle bar & Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: unselectedBorder,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: actionBtnBg.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: unselectedBorder, width: 1.0),
                                ),
                                child: Icon(
                                  Icons.layers_rounded,
                                  size: 22,
                                  color: primaryText,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isTagalog ? 'Mga Opsyon sa Mapa' : 'Map Layers & Safety Options',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: primaryText,
                                      ),
                                    ),
                                    Text(
                                      isTagalog ? 'Pindutin ang card para makita ang mga detalye' : 'Tap any card to view functions & scan radius',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close_rounded, color: primaryText, size: 22),
                                onPressed: () => Navigator.pop(sheetContext),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, thickness: 1),

                    // Scrollable Layer Cards List
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Accessibility & Safety POIs (Index 0)
                            buildExpandableLayerCard(
                              index: 0,
                              icon: Icons.accessible_forward_rounded,
                              iconColor: const Color(0xFF10B981),
                              title: isTagalog ? 'Accessibility & Safety Layer' : 'Accessibility & Safety POIs',
                              subtitle: isTagalog
                                  ? 'Awtomatikong mag-plot ng bus stops, ramps, tawiran, at clinics'
                                  : 'Auto-plot transit stops, ramps, crosswalks & hazards',
                              isSwitchActive: _showAccessibilityOverlay,
                              isSwitchEnabled: true,
                              badgeText: isTagalog ? '📍 500m Live Proximity Scan • Dynamic POI Engine' : '📍 500m Live Proximity Scan • Dynamic POI Engine',
                              features: [
                                {
                                  'icon': Icons.radar_rounded,
                                  'label': isTagalog ? 'Radius ng Pag-scan' : 'Live Scan Radius',
                                  'desc': isTagalog
                                      ? 'Naglalaan ng 500-meter radar query sa paligid ng iyong GPS'
                                      : 'Actively queries real-world POIs within a 500m radius of your position',
                                },
                                {
                                  'icon': Icons.directions_bus_rounded,
                                  'label': isTagalog ? 'Mga Hintuan at Transit' : 'Transit Access',
                                  'desc': isTagalog
                                      ? 'Eksaktong mga bus stop, jeepney terminal, at istasyon ng tren'
                                      : 'Verified bus stops, jeepney loading zones & transit platforms',
                                },
                                {
                                  'icon': Icons.accessible_rounded,
                                  'label': isTagalog ? 'Ligtas na Tawiran' : 'Tactile & Ramps',
                                  'desc': isTagalog
                                      ? 'Mga may tactile paving, footbridge, at ramp para sa wheelchair'
                                      : 'Tactile paving crosswalks, wheelchair ramps & audio traffic signals',
                                },
                                {
                                  'icon': Icons.local_hospital_rounded,
                                  'label': isTagalog ? 'Kagipitan at Klinika' : 'Medical Care',
                                  'desc': isTagalog
                                      ? 'Malalapit na clinic, ospital, at 24/7 na botika'
                                      : 'Nearby community health centers, clinics & 24/7 pharmacies',
                                },
                                {
                                  'icon': Icons.volume_up_rounded,
                                  'label': isTagalog ? 'Boses na Gabay' : 'Voice Assistance',
                                  'desc': isTagalog
                                      ? 'Pindutin ang anumang marker sa mapa para marinig ang distansya at detalye'
                                      : 'Tap any POI pin on the map to hear its name, distance & safety details spoken aloud',
                                },
                              ],
                              onSwitchChanged: (val) {
                                SoundService.playClick();
                                setModalState(() {
                                  _showAccessibilityOverlay = val;
                                });
                                setState(() {
                                  _showAccessibilityOverlay = val;
                                });
                                if (val) {
                                  _fetchNearbyAccessibilityPOIs(forceRefresh: true);
                                  TtsService().speak(isTagalog
                                      ? "Naka-on ang accessibility at safety layer."
                                      : "Accessibility and safety layer enabled.");
                                } else {
                                  TtsService().speak(isTagalog
                                      ? "Naka-off ang accessibility layer."
                                      : "Accessibility layer disabled.");
                                }
                              },
                            ),

                            // 2. Satellite / Hybrid Mode (Index 1)
                            buildExpandableLayerCard(
                              index: 1,
                              icon: Icons.satellite_alt_rounded,
                              iconColor: const Color(0xFF0284C7),
                              title: isTagalog ? 'Satellite / Aerial View' : 'Satellite Imagery',
                              subtitle: isTagalog
                                  ? 'Tunay na kuha ng mapa mula sa itaas (naka-disable ang 3D)'
                                  : 'Real-world photographic satellite mode (disables 3D)',
                              isSwitchActive: _currentMapType == MapType.hybrid,
                              isSwitchEnabled: true,
                              badgeText: isTagalog ? '🛰️ High-Resolution Orbital Photography' : '🛰️ High-Resolution Orbital Photography',
                              features: [
                                {
                                  'icon': Icons.camera_alt_rounded,
                                  'label': isTagalog ? 'Tunay na Larawan' : 'Photographic View',
                                  'desc': isTagalog
                                      ? 'Tunay na kuha ng satellite sa kalsada, gusali, at kapaligiran'
                                      : 'True-to-life orbital satellite capture of roads, buildings & terrain',
                                },
                                {
                                  'icon': Icons.nature_rounded,
                                  'label': isTagalog ? 'Detalye sa Lupa' : 'Surface Terrain',
                                  'desc': isTagalog
                                      ? 'Ipinapakita ang mga puno, open parks, paradahan, at daanan'
                                      : 'Visualizes trees, parks, parking areas, walkways & real rooftops',
                                },
                                {
                                  'icon': Icons.visibility_off_rounded,
                                  'label': isTagalog ? '3D Incompatible' : '3D Incompatible',
                                  'desc': isTagalog
                                      ? 'Awtomatikong naka-off ang 3D Box view sa Satellite para malinaw ang kuha'
                                      : '3D Box perspective is automatically disabled in satellite mode to preserve clear aerial imagery',
                                },
                              ],
                              onSwitchChanged: (val) {
                                SoundService.playClick();
                                setModalState(() {
                                  _currentMapType = val ? MapType.hybrid : MapType.normal;
                                  _isNativeMapAvailable = !val;
                                  if (val) {
                                    _is3DPerspective = false;
                                  }
                                });
                                setState(() {
                                  _currentMapType = val ? MapType.hybrid : MapType.normal;
                                  _isNativeMapAvailable = !val;
                                  if (val) {
                                    _is3DPerspective = false;
                                  }
                                });
                                if (val) {
                                  _mapController?.animateCamera(
                                    CameraUpdate.newCameraPosition(
                                      CameraPosition(
                                        target: _currentLocation,
                                        zoom: 16.5,
                                        tilt: 0.0,
                                        bearing: 0.0,
                                      ),
                                    ),
                                  );
                                }
                                _applyMapTheme(isDark);
                                TtsService().speak(val
                                    ? (isTagalog ? "Inilipat sa satellite view. Naka-off ang 3D." : "Satellite view enabled. 3D mode disabled.")
                                    : (isTagalog ? "Inilipat sa karaniwang mapa." : "Standard vector map enabled."));
                              },
                            ),

                            // 3. 3D Architectural Box Perspective (Index 2)
                            Builder(
                              builder: (context) {
                                final isSatellite = _currentMapType == MapType.hybrid;
                                return buildExpandableLayerCard(
                                  index: 2,
                                  icon: Icons.view_in_ar_rounded,
                                  iconColor: const Color(0xFF0284C7),
                                  title: isTagalog ? '3D Box Perspective View' : '3D Box Perspective Mode',
                                  subtitle: isSatellite
                                      ? (isTagalog
                                          ? 'Hindi magagamit sa Satellite view (lumipat sa Standard mapa)'
                                          : 'Unavailable in Satellite view (switch to Standard map)')
                                      : (isTagalog
                                          ? 'Malinis na 3D geometric boxes & angled compass follow'
                                          : 'Clean minimalist 3D geometric boxes & compass follow'),
                                  isSwitchActive: isSatellite ? false : _is3DPerspective,
                                  isSwitchEnabled: !isSatellite,
                                  badgeText: isTagalog ? '📐 60° Tilted Box View • Dynamic Compass Follow' : '📐 60° Tilted Box View • Dynamic Compass Follow',
                                  features: [
                                    {
                                      'icon': Icons.architecture_rounded,
                                      'label': isTagalog ? '60° Isometric Angle' : '60° Isometric Angle',
                                      'desc': isTagalog
                                          ? 'Naka-tilt ang camera para mas madaling makita ang lalim at direksyon ng mga gusali'
                                          : 'Tilts the camera angle for an immersive 3D architectural city overview',
                                    },
                                    {
                                      'icon': Icons.explore_rounded,
                                      'label': isTagalog ? 'Pagsunod sa Direksyon' : 'Compass Heading Follow',
                                      'desc': isTagalog
                                          ? 'Awtomatikong umiikot ang mapa ayon sa direksyon ng iyong paglalakad'
                                          : 'Dynamically rotates map bearing to follow your physical walking orientation',
                                    },
                                    {
                                      'icon': Icons.location_on_rounded,
                                      'label': isTagalog ? '3D Holographic Pin' : 'Elevated 3D Pin',
                                      'desc': isTagalog
                                          ? 'Nakaangat na 3D crystal pin na may laser stem at radar target sa kalsada'
                                          : 'Elevated crystal gem pin with vertical light beam & ground radar rings',
                                    },
                                  ],
                                  onSwitchChanged: (val) {
                                    setModalState(() {
                                      _is3DPerspective = val;
                                    });
                                    _toggle3DPerspective(val);
                                  },
                                );
                              },
                            ),

                            // 4. Live Traffic Overlay (Index 3)
                            buildExpandableLayerCard(
                              index: 3,
                              icon: Icons.traffic_rounded,
                              iconColor: const Color(0xFFEF4444),
                              title: isTagalog ? 'Live Traffic Layer' : 'Real-Time Traffic',
                              subtitle: isTagalog
                                  ? 'Ipakita ang dami ng sasakyan sa daan'
                                  : 'Display live traffic congestion lines',
                              isSwitchActive: _showTraffic,
                              isSwitchEnabled: true,
                              badgeText: isTagalog ? '🚦 Live Traffic Congestion Heatmap' : '🚦 Live Traffic Congestion Heatmap',
                              features: [
                                {
                                  'icon': Icons.traffic_rounded,
                                  'label': isTagalog ? 'Daloy ng Trapiko' : 'Congestion Monitoring',
                                  'desc': isTagalog
                                      ? 'Ipinapakita ang real-time na bilis at daloy ng sasakyan sa mga kalsada'
                                      : 'Color-coded traffic congestion lines overlaid directly on roadways',
                                },
                                {
                                  'icon': Icons.circle,
                                  'iconColor': const Color(0xFF10B981),
                                  'label': isTagalog ? 'Berde / Green' : 'Green Flow',
                                  'desc': isTagalog ? 'Malinis at tuloy-tuloy na daloy ng sasakyan' : 'Free-flowing traffic with normal speeds',
                                },
                                {
                                  'icon': Icons.circle,
                                  'iconColor': const Color(0xFFF59E0B),
                                  'label': isTagalog ? 'Kahel / Orange' : 'Orange Flow',
                                  'desc': isTagalog ? 'Katamtamang dami at mabagal na daloy' : 'Moderate traffic density & slower speeds',
                                },
                                {
                                  'icon': Icons.circle,
                                  'iconColor': const Color(0xFFEF4444),
                                  'label': isTagalog ? 'Pula / Red' : 'Red Flow',
                                  'desc': isTagalog ? 'Mabigat na trapiko o nakatigil na sasakyan' : 'Heavy congestion, bumper-to-bumper delays & standstills',
                                },
                              ],
                              onSwitchChanged: (val) {
                                SoundService.playClick();
                                setModalState(() {
                                  _showTraffic = val;
                                });
                                setState(() {
                                  _showTraffic = val;
                                });
                                TtsService().speak(val
                                    ? (isTagalog ? "Naka-on ang traffic layer." : "Live traffic overlay enabled.")
                                    : (isTagalog ? "Naka-off ang traffic layer." : "Traffic overlay disabled."));
                              },
                            ),

                            const SizedBox(height: 6),

                            // 5. Recenter GPS Button
                            Container(
                              decoration: BoxDecoration(
                                color: actionBtnBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderColor, width: 1.0),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    SoundService.playClick();
                                    _mapController?.animateCamera(
                                      CameraUpdate.newCameraPosition(
                                        CameraPosition(
                                          target: _currentLocation,
                                          zoom: 16.0,
                                          tilt: _is3DPerspective ? 50.0 : 0.0,
                                        ),
                                      ),
                                    );
                                    TtsService().speak(isTagalog
                                        ? "Nakapokus na muli sa iyong kasalukuyang lokasyon."
                                        : "Recentered to your current GPS location.");
                                    Navigator.pop(sheetContext);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.my_location_rounded, color: actionBtnText, size: 20),
                                        const SizedBox(width: 10),
                                        Text(
                                          isTagalog ? 'I-recenter sa Aking Lokasyon' : 'Recenter to My Location',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: actionBtnText,
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
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  LatLng _currentLocation = const LatLng(15.1325, 120.5901); // Fallback coordinates
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _searchDebounceTimer;
  List<LatLng> _routePoints = [];
  bool _isFetchingRoute = false;

  bool _hasAnnouncedArrival = false;
  

  // Expanded Warning & Proximity Guidance Variables
  List<LatLng> _stepLocations = [];
  int _lastRerouteTime = 0;
  int _offRouteCounter = 0;
  int _lastTurnAlertTime = 0;
  int _lastProximityAlertTime = 0;
  int _lastGpsAlertTime = 0;
  int _lastTurnIndexAnnounced = -1;
  int _lastProximityIndexAnnounced = -1;
  double? _lastDynamicAnnouncedDistanceM;

  // HAU Location coordinates (Pampanga, PH)
  static const LatLng _hauLatLng = LatLng(15.1325, 120.5901);

  // Caching mechanism to limit Google Maps api calls — NOT static so stale data resets on widget rebuild
  final Map<String, List<Map<String, dynamic>>> _placesCache = {};


  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Map<String, dynamic>? _selectedPlace;
  Map<String, dynamic>? _pendingPlaceToConfirm;
  int _currentStepIndex = 0;

  void _updateSearchResults(List<Map<String, dynamic>> results) {
    setState(() {
      _searchResults = results;
    });
    SpeechNavigationNotifier.activeSearchResults = results;

    // ONLY animate camera to search results if user has actively typed a search query
    if (_searchController.text.trim().isNotEmpty && _mapController != null && results.isNotEmpty && _navState == 0) {
      try {
        final firstPos = results.first['latLng'] as LatLng?;
        if (firstPos != null) {
          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: firstPos,
                zoom: 16.0,
                tilt: _is3DPerspective ? 60.0 : 0.0,
              ),
            ),
          );
        }
      } catch (_) {}
    }
  }

  void _activateVoiceSearch() {
    NavigationVoiceAssistant.activateSearchAssistant(
      context: context,
      onQueryDiscovered: (query) async {
        if (mounted) {
          _searchController.text = query;
          return await _performSearch(query);
        }
        return [];
      },
      getSearchResults: () => _searchResults,
      onPlaceConfirmed: (place) {
        if (mounted) {
          _requestNavigationConfirmation(place);
        }
      },
    );
  }

  void _onVoiceSearchRequested() {
    final query = SpeechNavigationNotifier.searchPlaceNotifier.value;
    if (query != null && query.isNotEmpty && mounted) {
      _searchController.text = query;
      _performSearch(query);
    }
  }

  void _onVoiceSelectRequested() {
    final index = SpeechNavigationNotifier.selectResultNotifier.value;
    if (index != null && index >= 0 && index < _searchResults.length && mounted) {
      final place = _searchResults[index];
      _requestNavigationConfirmation(place);
    }
  }

  void _onVoiceConfirmRequested() {
    final place = SpeechNavigationNotifier.confirmPlaceNotifier.value;
    if (place != null && mounted) {
      _confirmPendingNavigation();
    }
  }

  void _onVoiceStopRouteRequested() {
    if (SpeechNavigationNotifier.stopRouteNotifier.value == true && mounted) {
      _cancelNavigation();
    }
  }

  Map<String, String> _calculateDistanceAndTime(LatLng destination) {
    final distMeters = Geolocator.distanceBetween(
      _currentLocation.latitude,
      _currentLocation.longitude,
      destination.latitude,
      destination.longitude,
    );
    final double kmVal = distMeters / 1000.0;
    
    int estMinutes = (kmVal * 12.0).round();
    if (estMinutes < 1) estMinutes = 1;

    String distStr;
    if (kmVal < 0.1) {
      distStr = "${distMeters.round()} m";
    } else {
      distStr = "${kmVal.toStringAsFixed(1)} km";
    }

    String timeStr = "$estMinutes min";
    if (estMinutes >= 60) {
      final hours = estMinutes ~/ 60;
      final mins = estMinutes % 60;
      timeStr = mins > 0 ? "$hours hr $mins min" : "$hours hr";
    }

    return {
      'dist': distStr,
      'time': timeStr,
    };
  }

  void _requestNavigationConfirmation(Map<String, dynamic> place) {
    _saveToRecentHistory(place);

    final lang = SettingsService().selectedLanguage;
    final isTagalog = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
    
    if (place['latLng'] is LatLng) {
      final calc = _calculateDistanceAndTime(place['latLng'] as LatLng);
      place['dist'] = calc['dist']!;
      place['time'] = calc['time']!;
    }

    setState(() {
      _pendingPlaceToConfirm = place;
    });

    final placeName = place['name'] as String;
    final prompt = isTagalog
        ? "Kumpirmahin ang paglakad patungo sa $placeName. Sabihin ang 'Oo', 'Kumpirmahin', o 'Sige' para simulan ang ruta, o 'Hindi' para kanselahin."
        : "Confirm navigation to $placeName? Say 'Yes', 'Confirm', or 'Search' to start guidance, or 'No' to cancel.";
    
    TtsService().speak(prompt);
  }

  void _confirmPendingNavigation() {
    if (_pendingPlaceToConfirm == null) return;
    final place = _pendingPlaceToConfirm!;
    setState(() {
      _pendingPlaceToConfirm = null;
    });
    _startGuidance(place);
  }

  void _cancelPendingNavigation() {
    final lang = SettingsService().selectedLanguage;
    final isTagalog = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
    setState(() {
      _pendingPlaceToConfirm = null;
    });
    TtsService().speak(isTagalog ? "Kinansela ang paghahanap ng ruta." : "Navigation setup cancelled.");
  }

  void _clearHazardAlert() {
    ActiveNavigationService().clearHazardAlert();
    if (mounted) setState(() {});
  }


  final _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _recentPlaces = [];

  Future<void> _saveToRecentHistory(Map<String, dynamic> place) async {
    final nameStr = (place['name'] as String? ?? '').trim();
    if (nameStr.isEmpty) return;

    final user = _firebaseService.currentUser;
    double lat = 0.0;
    double lng = 0.0;

    if (place['latLng'] is LatLng) {
      final l = place['latLng'] as LatLng;
      lat = l.latitude;
      lng = l.longitude;
    } else if (place['latitude'] != null && place['longitude'] != null) {
      lat = (place['latitude'] as num).toDouble();
      lng = (place['longitude'] as num).toDouble();
    }

    if (lat != 0.0 && lng != 0.0) {
      final calc = _calculateDistanceAndTime(LatLng(lat, lng));
      final addressStr = (place['address'] as String? ?? '').trim();
      final navData = {
        'name': nameStr,
        'address': addressStr,
        'dist': calc['dist']!,
        'time': calc['time']!,
        'latitude': lat,
        'longitude': lng,
        'steps': place['steps'] ?? [
          'Head toward $nameStr',
          'Follow directional signs',
          'Arrive at $nameStr'
        ],
      };
      
      // 1. Save to local device SharedPreferences + Firestore
      await _firebaseService.saveRecentNavigation(user?.uid ?? 'guest', navData);

      // 2. Save to Buddy's Long-Term RAG Journal Memory
      try {
        final journalEntry = addressStr.isNotEmpty
            ? "User navigated or searched for $nameStr ($addressStr). Distance: ${calc['dist']!}, Est Time: ${calc['time']!}."
            : "User navigated or searched for $nameStr. Distance: ${calc['dist']!}, Est Time: ${calc['time']!}.";
        
        await JournalService().appendToDailyJournal("Visited / Navigated Place", journalEntry);
        await JournalService().generateAndAddInsight("Frequent Navigation", "Visited place: $nameStr");
      } catch (e) {
        debugPrint("[BUDDY MEMORY SAVE ERROR] $e");
      }

      await _loadRecentNavigations();
    }
  }

  Future<void> _loadRecentNavigations() async {
    try {
      final user = _firebaseService.currentUser;
      final rawRecents = await _firebaseService.getRecentNavigations(user?.uid);
      final List<Map<String, dynamic>> parsed = [];
      
      for (final item in rawRecents) {
        double lat = 0.0;
        double lng = 0.0;
        if (item['latLng'] is LatLng) {
          final l = item['latLng'] as LatLng;
          lat = l.latitude;
          lng = l.longitude;
        } else if (item['latitude'] != null && item['longitude'] != null) {
          lat = (item['latitude'] as num).toDouble();
          lng = (item['longitude'] as num).toDouble();
        }

        if (lat != 0.0 && lng != 0.0) {
          final calc = _calculateDistanceAndTime(LatLng(lat, lng));
          parsed.add({
            'name': item['name'] ?? 'Recent Location',
            'address': item['address'] ?? '',
            'dist': calc['dist']!,
            'time': calc['time']!,
            'latLng': LatLng(lat, lng),
            'steps': item['steps'] ?? [
              'Head toward ${item['name']}',
              'Turn right onto closest main road',
              'Follow directional signs',
              'Arrive at ${item['name']}'
            ],
          });
        }
      }

      if (mounted) {
        setState(() {
          _recentPlaces = parsed.take(5).toList();
          if (_searchController.text.trim().isEmpty) {
            _searchResults = List.from(_recentPlaces);
            SpeechNavigationNotifier.activeSearchResults = _searchResults;
          }
        });

        if (_recentPlaces.isEmpty && _searchController.text.trim().isEmpty) {
          final res = await _getRealNearbyInitialPlaces();
          if (mounted && _searchController.text.trim().isEmpty) {
            setState(() {
              _searchResults = res.take(5).toList();
              SpeechNavigationNotifier.activeSearchResults = _searchResults;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading recent navigations: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    if (ActiveNavigationService().currentLocation != null) {
      _currentLocation = ActiveNavigationService().currentLocation!;
    }
    _searchResults = [];
    _getRealNearbyInitialPlaces().then((res) {
      if (mounted && _searchResults.isEmpty && _recentPlaces.isEmpty) {
        setState(() {
          _searchResults = res.take(5).toList();
          SpeechNavigationNotifier.activeSearchResults = _searchResults;
        });
      }
    });
    SpeechNavigationNotifier.activeSearchResults = _searchResults;
    _initializeLocationTracking();
    _loadRecentNavigations();
    _preload3DBuildingIcons();
    SpeechNavigationNotifier.searchPlaceNotifier.addListener(_onVoiceSearchRequested);
    SpeechNavigationNotifier.selectResultNotifier.addListener(_onVoiceSelectRequested);
    SpeechNavigationNotifier.confirmPlaceNotifier.addListener(_onVoiceConfirmRequested);
    SpeechNavigationNotifier.stopRouteNotifier.addListener(_onVoiceStopRouteRequested);
    SettingsService().addListener(_onSettingsChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {

      ScreenTutorialCard.showIfNeeded(
        context,
        tutorialKey: 'navigation',
        titleKey: 'tutorial_navigation_title',
        descriptionKey: 'tutorial_navigation_desc',
        mascotAsset: 'assets/mascots/03_loading.gif',
      );

      final activeNav = ActiveNavigationService();
      if (activeNav.isNavigating && activeNav.activePlace != null) {
        setState(() {
          _selectedPlace = Map<String, dynamic>.from(activeNav.activePlace!);
          _routePoints = List<LatLng>.from(activeNav.routePoints);
          _stepLocations = List<LatLng>.from(activeNav.stepLocations);
          _currentStepIndex = activeNav.currentStepIndex;
          _lastDynamicAnnouncedDistanceM = null;
          _navState = 1;
        });
        if (activeNav.destinationLocation != null) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(activeNav.destinationLocation!, 16.0),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    SpeechNavigationNotifier.searchPlaceNotifier.removeListener(_onVoiceSearchRequested);
    SpeechNavigationNotifier.selectResultNotifier.removeListener(_onVoiceSelectRequested);
    SpeechNavigationNotifier.confirmPlaceNotifier.removeListener(_onVoiceConfirmRequested);
    SpeechNavigationNotifier.stopRouteNotifier.removeListener(_onVoiceStopRouteRequested);
    SettingsService().removeListener(_onSettingsChanged);
    _searchController.dispose();
    _mapController?.dispose();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // Set up live GPS location tracking
  Future<void> _initializeLocationTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      // Step 1: Immediate 0ms last known position update
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && mounted) {
          setState(() {
            _currentLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
          });
          ActiveNavigationService().updateCurrentLocation(_currentLocation);
          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _currentLocation,
                zoom: _is3DPerspective ? 17.5 : 16.5,
                tilt: _is3DPerspective ? 60.0 : 0.0,
              ),
            ),
          );
        }
      } catch (_) {}

      // Step 2: Start continuous position stream IMMEDIATELY
      _positionStreamSubscription?.cancel();
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2, // update every 2 meters
        ),
      ).listen((Position position) {
        if (mounted) {
          final newLoc = LatLng(position.latitude, position.longitude);
          final double movedDistance = Geolocator.distanceBetween(
            _currentLocation.latitude,
            _currentLocation.longitude,
            newLoc.latitude,
            newLoc.longitude,
          );

          setState(() {
            _currentLocation = newLoc;
          });

          if (position.heading >= 0 && position.heading <= 360 && position.heading != 0.0) {
            _currentHeading = position.heading;
          }

          ActiveNavigationService().updateCurrentLocation(_currentLocation);

          // In 3D mode: dynamically follow user position and heading
          if (_is3DPerspective && _mapController != null) {
            final double bearing = (position.heading >= 0 && position.heading <= 360) ? position.heading : _currentHeading;
            _mapController?.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: _currentLocation,
                  zoom: 18.0,
                  tilt: 60.0,
                  bearing: bearing,
                ),
              ),
            );
          }

          // If accessibility POIs are active and user moved > 40m, dynamically refresh POIs
          if (_showAccessibilityOverlay && movedDistance > 40) {
            _fetchNearbyAccessibilityPOIs();
          }

          if (_searchController.text.trim().isEmpty) {
            _performSearch("");
          }

          if (_selectedPlace != null && _navState == 1) {
            if (!_is3DPerspective) {
              _mapController?.animateCamera(
                CameraUpdate.newLatLng(_currentLocation),
              );
            }
            _checkNavigationProgress(position);
          }
        }
      });

      // Step 3: High-accuracy position fetch
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 5),
      );
      
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        ActiveNavigationService().updateCurrentLocation(_currentLocation);
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _currentLocation,
              zoom: _is3DPerspective ? 17.5 : 16.5,
              tilt: _is3DPerspective ? 60.0 : 0.0,
            ),
          ),
        );
        if (_showAccessibilityOverlay) {
          _fetchNearbyAccessibilityPOIs(forceRefresh: true);
        }
        if (_searchController.text.trim().isEmpty) {
          _performSearch("");
        }
      }
    } catch (e) {
      print('Location tracking init error: $e');
    }
  }

  bool _isUserOffRoute() {
    if (_routePoints.isEmpty) return false;
    double minDistance = double.infinity;
    for (final point in _routePoints) {
      final d = Geolocator.distanceBetween(
        _currentLocation.latitude,
        _currentLocation.longitude,
        point.latitude,
        point.longitude,
      );
      if (d < minDistance) {
        minDistance = d;
      }
    }
    return minDistance > 50.0;
  }

  /// Checks how close the user is to the destination and the next step waypoint.
  /// Speaks a guidance prompt when within threshold, respecting tiered cooldowns
  /// and automatically handling off-route and weak GPS events.
  void _checkNavigationProgress(Position position) {
    if (_selectedPlace == null || _navState != 1) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final unit = SettingsService().selectedUnit;
    final steps = (_selectedPlace!['steps'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    final destination = _selectedPlace!['latLng'] as LatLng;

    // --- 1. Check GPS Accuracy ---
    if (position.accuracy > 25.0) {
      if (now - _lastGpsAlertTime > 20000) { // 20s cooldown
        _lastGpsAlertTime = now;
        TtsService().speak(
          SettingsService().selectedLanguage == 'Tagalog'
              ? 'Mahina ang signal ng GPS. Maaaring hindi tumpak ang gabay.'
              : 'GPS signal is weak. Guidance may be inaccurate.',
        );
      }
    }

    // --- 2. Check Off-Route & Auto-Reroute ---
    if (_isUserOffRoute()) {
      _offRouteCounter++;
      // Require 3 consecutive off-route ticks to confirm off-route to prevent GPS jumps
      if (_offRouteCounter >= 3 && (now - _lastRerouteTime > 15000)) {
        _lastRerouteTime = now;
        _offRouteCounter = 0;
        TtsService().speak(
          SettingsService().selectedLanguage == 'Tagalog'
              ? 'Naliligaw ka sa ruta. Muling kinakalkula ang direksyon.'
              : 'You are off-route. Recalculating path...',
        );
        _fetchRoadRoute();
        return;
      }
    } else {
      _offRouteCounter = 0;
    }

    // --- 3. Check distance to final destination ---
    final distToDestM = Geolocator.distanceBetween(
      _currentLocation.latitude,
      _currentLocation.longitude,
      destination.latitude,
      destination.longitude,
    );

    // Update real-time distance remaining on selected place & global status
    final dynamicDistStr = _formatDistance("${distToDestM.round()} m", unit);
    _selectedPlace!['dist'] = dynamicDistStr;
    ActiveNavigationService().updateProgress(
      currentStepText: _formatStep(steps[_currentStepIndex], unit),
      distanceRemaining: dynamicDistStr,
      timeRemaining: _selectedPlace!['time'] ?? '',
      currentLocation: _currentLocation,
      currentStepIndex: _currentStepIndex,
    );

    if (distToDestM < 20 && !_hasAnnouncedArrival) {
      _hasAnnouncedArrival = true;
      TtsService().speak(
        SettingsService().selectedLanguage == 'Tagalog'
            ? 'Nakarating ka na sa iyong patutunguhan, ${_selectedPlace!["name"]}. Magaling!'
            : 'You have arrived at your destination, ${_selectedPlace!["name"]}. Well done!',
      );
      ActiveNavigationService().triggerArrival();
      setState(() => _navState = 2);
      return;
    }

    if (distToDestM < 80 && !_hasAnnouncedArrival && _lastProximityIndexAnnounced != -999) {
      _lastProximityIndexAnnounced = -999;
      final approachDist = unit == 'Imperial'
          ? '${(distToDestM * 3.28084).round()} feet'
          : '${distToDestM.round()} meters';
      TtsService().speak(
        SettingsService().selectedLanguage == 'Tagalog'
            ? 'May $approachDist ka na lang bago makarating sa ${_selectedPlace!["name"]}. Malapit na!'
            : 'You are $approachDist away from ${_selectedPlace!["name"]}. Almost there!',
      );
      return;
    }

    // --- 4. Announce upcoming turns using step physical locations ---
    if (_currentStepIndex < steps.length && _currentStepIndex < _stepLocations.length) {
      final stepTarget = _stepLocations[_currentStepIndex];
      final rawStepText = _formatStep(steps[_currentStepIndex], unit);
      // Clean static embedded distances ("for 300 meters") so spoken cue matches real-time distance
      final cleanStepText = rawStepText.replaceAll(
        RegExp(r'\s+for\s+[\d.]+\s*(?:meters|meter|km|miles|mile|feet|foot|ft|m\b)', caseSensitive: false),
        '',
      ).trim();

      final distToStepM = Geolocator.distanceBetween(
        _currentLocation.latitude,
        _currentLocation.longitude,
        stepTarget.latitude,
        stepTarget.longitude,
      );

      // A2. Periodic 30m voice guidance update
      if (_lastDynamicAnnouncedDistanceM == null) {
        _lastDynamicAnnouncedDistanceM = distToStepM;
      } else {
        final diff = (_lastDynamicAnnouncedDistanceM! - distToStepM).abs();
        if (diff >= 30.0) {
          _lastDynamicAnnouncedDistanceM = distToStepM;
          final announceDist = unit == 'Imperial'
              ? '${(distToStepM * 3.28084).round()} feet'
              : '${distToStepM.round()} meters';
          final isTagalog = SettingsService().selectedLanguage == 'Tagalog';
          TtsService().speak(
            isTagalog
                ? 'Maglakad nang $announceDist, tapos $cleanStepText'
                : 'Walk for $announceDist, then $cleanStepText'
          );
        }
      }

      // A. Critical turn alert (within 20 meters): Auto-advance immediately and read the step
      if (distToStepM < 20) {
        if (_currentStepIndex < steps.length - 1) {
          setState(() {
            _currentStepIndex++;
            _lastDynamicAnnouncedDistanceM = null;
          });
          final nextStepText = _formatStep(steps[_currentStepIndex], unit);
          ActiveNavigationService().updateProgress(
            currentStepText: nextStepText,
            distanceRemaining: dynamicDistStr,
            timeRemaining: _selectedPlace!['time'] ?? '',
            currentLocation: _currentLocation,
            currentStepIndex: _currentStepIndex,
          );
          TtsService().speak(nextStepText);
        }
      } 
      else if (distToStepM < 60) {
        if (_lastTurnIndexAnnounced != _currentStepIndex || (now - _lastTurnAlertTime > 12000)) {
          _lastTurnAlertTime = now;
          _lastTurnIndexAnnounced = _currentStepIndex;
          final warnDist = unit == 'Imperial'
              ? '${(distToStepM * 3.28084).round()} feet'
              : '${distToStepM.round()} meters';
          TtsService().speak(
            SettingsService().selectedLanguage == 'Tagalog'
                ? 'Sa loob ng $warnDist, $cleanStepText'
                : 'In $warnDist, $cleanStepText',
          );
        }
      } 
      // C. Reminder (within 150 meters): Standard voice cue
      else if (distToStepM < 150) {
        if (_lastProximityIndexAnnounced != _currentStepIndex && (now - _lastProximityAlertTime > 20000)) {
          _lastProximityAlertTime = now;
          _lastProximityIndexAnnounced = _currentStepIndex;
          TtsService().speak(cleanStepText);
        }
      }
    }
  }

  Future<void> _fetchRoadRoute() async {
    if (_selectedPlace == null || _isFetchingRoute) return;
    _isFetchingRoute = true;
    final start = _currentLocation;
    final end = _selectedPlace!['latLng'] as LatLng;
    
    try {
      final url = Uri.parse(
        "https://router.project-osrm.org/route/v1/driving/"
        "${start.longitude},${start.latitude};${end.longitude},${end.latitude}"
        "?overview=full&geometries=geojson&steps=true"
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;
          final List<LatLng> points = coordinates.map((coord) {
            final double lon = coord[0].toDouble();
            final double lat = coord[1].toDouble();
            return LatLng(lat, lon);
          }).toList();
          
          final double distanceInMeters = (route['distance'] as num).toDouble();
          final double durationInSeconds = (route['duration'] as num).toDouble();

          final double kmVal = distanceInMeters / 1000.0;
          final String distStr = "${kmVal.toStringAsFixed(1)} km";
          final int minutes = (durationInSeconds / 60.0).round();
          final String timeStr = "$minutes min";

          // Parse dynamic steps from OSRM S01
          final List<String> parsedSteps = [];
          final List<LatLng> stepLocations = [];
          if (route['legs'] != null && route['legs'].isNotEmpty) {
            final leg = route['legs'][0];
            if (leg['steps'] != null && leg['steps'].isNotEmpty) {
              final stepsList = leg['steps'] as List;
              for (var step in stepsList) {
                final maneuver = step['maneuver'];
                String instruction = '';
                if (maneuver != null && maneuver['instruction'] != null) {
                  instruction = maneuver['instruction'] as String;
                } else {
                  final type = maneuver?['type'] ?? 'move';
                  final modifier = maneuver?['modifier'] ?? '';
                  final name = step['name'] ?? '';
                  instruction = "${type.replaceAll('_', ' ')} ${modifier.replaceAll('_', ' ')} ${name.isNotEmpty ? 'onto $name' : ''}".trim();
                }
                if (instruction.isNotEmpty) {
                  parsedSteps.add(instruction);
                  if (maneuver != null && maneuver['location'] != null) {
                    final locList = maneuver['location'] as List;
                    stepLocations.add(LatLng(locList[1].toDouble(), locList[0].toDouble()));
                  } else {
                    stepLocations.add(end);
                  }
                }
              }
            }
          }

          if (parsedSteps.isEmpty) {
            parsedSteps.addAll([
              'Head toward ${_selectedPlace!['name']}',
              'Turn right onto closest main road',
              'Follow directional signs',
              'Arrive at ${_selectedPlace!['name']}'
            ]);
            stepLocations.addAll([
              start,
              LatLng(start.latitude + (end.latitude - start.latitude) * 0.33, start.longitude + (end.longitude - start.longitude) * 0.33),
              LatLng(start.latitude + (end.latitude - start.latitude) * 0.66, start.longitude + (end.longitude - start.longitude) * 0.66),
              end,
            ]);
          }

          if (mounted) {
            setState(() {
              _routePoints = points;
              _stepLocations = stepLocations;
              _selectedPlace!['steps'] = parsedSteps;
              _selectedPlace!['dist'] = distStr;
              _selectedPlace!['time'] = timeStr;
            });
            ActiveNavigationService().startNavigation(
              destinationName: _selectedPlace!['name'],
              destinationLocation: end,
              routePoints: points,
              activePlace: _selectedPlace,
              stepLocations: stepLocations,
            );
            ActiveNavigationService().updateProgress(
              currentStepText: _selectedPlace!['steps'][_currentStepIndex.clamp(0, parsedSteps.length - 1)],
              distanceRemaining: distStr,
              timeRemaining: timeStr,
              currentLocation: start,
              currentStepIndex: _currentStepIndex,
            );
          }
        }
      }
    } catch (e) {
      print("OSRM route fetch error: $e");
      if (mounted) {
        final steps = (_selectedPlace != null && _selectedPlace!['steps'] != null) 
            ? List<String>.from(_selectedPlace!['steps'])
            : <String>[
                'Head toward ${_selectedPlace!['name']}',
                'Turn right onto closest main road',
                'Follow directional signs',
                'Arrive at ${_selectedPlace!['name']}'
              ];
        final List<LatLng> fallbackLocs = [];
        for (int i = 0; i < steps.length; i++) {
          final ratio = steps.length <= 1 ? 0.0 : i / (steps.length - 1);
          fallbackLocs.add(LatLng(
            start.latitude + (end.latitude - start.latitude) * ratio,
            start.longitude + (end.longitude - start.longitude) * ratio,
          ));
        }
        setState(() {
          _routePoints = [start, end];
          _stepLocations = fallbackLocs;
          if (_selectedPlace != null) {
            _selectedPlace!['steps'] = steps;
          }
        });
        ActiveNavigationService().startNavigation(
          destinationName: _selectedPlace!['name'],
          destinationLocation: end,
          routePoints: [start, end],
          activePlace: _selectedPlace,
          stepLocations: fallbackLocs,
        );
        ActiveNavigationService().updateProgress(
          currentStepText: _selectedPlace!['steps'][_currentStepIndex.clamp(0, _selectedPlace!['steps'].length - 1)],
          distanceRemaining: _selectedPlace!['dist'],
          timeRemaining: _selectedPlace!['time'],
          currentLocation: start,
          currentStepIndex: _currentStepIndex,
        );
      }
    } finally {
      _isFetchingRoute = false;
    }
  }

  void _onSearchChanged(String rawQuery) {
    _searchDebounceTimer?.cancel();
    if (rawQuery.trim().isEmpty) {
      if (_recentPlaces.isNotEmpty) {
        _updateSearchResults(List.from(_recentPlaces));
      } else {
        _performSearch(rawQuery);
      }
      return;
    }
    _searchDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      _performSearch(rawQuery);
    });
  }

  // Fetches real authentic nearby places from Photon API when search box is empty
  Future<List<Map<String, dynamic>>> _getRealNearbyInitialPlaces() async {
    final List<Map<String, dynamic>> places = [];
    try {
      final photonUrl = Uri.parse(
        'https://photon.komoot.io/api/'
        '?q=store'
        '&lat=${_currentLocation.latitude}'
        '&lon=${_currentLocation.longitude}'
        '&limit=10'
      );
      final response = await http.get(photonUrl).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List?;
        if (features != null) {
          for (final feat in features) {
            final props = feat['properties'] as Map<String, dynamic>? ?? {};
            final geom = feat['geometry'] as Map<String, dynamic>? ?? {};
            final coords = geom['coordinates'] as List?;
            if (coords == null || coords.length < 2) continue;

            final double lng = (coords[0] as num).toDouble();
            final double lat = (coords[1] as num).toDouble();
            final targetLatLng = LatLng(lat, lng);

            String rawName = props['name']?.toString() ?? '';
            if (rawName.trim().isEmpty) continue;

            final street = props['street']?.toString() ?? '';
            final locality = props['locality']?.toString() ?? props['district']?.toString() ?? props['suburb']?.toString() ?? '';
            final city = props['city']?.toString() ?? '';
            final state = props['state']?.toString() ?? '';

            final addrParts = [street, locality, city, state].where((s) => s.isNotEmpty).toList();
            final formattedAddress = addrParts.isNotEmpty ? addrParts.join(', ') : 'Nearby';

            if (places.any((p) => p['name'] == rawName || (p['latLng'] as LatLng).latitude == lat)) {
              continue;
            }

            final calc = _calculateDistanceAndTime(targetLatLng);
            final distMeters = Geolocator.distanceBetween(
              _currentLocation.latitude,
              _currentLocation.longitude,
              lat,
              lng,
            );

            places.add({
              'name': rawName,
              'address': formattedAddress,
              'dist': calc['dist']!,
              'time': calc['time']!,
              'distanceMeters': distMeters,
              'latLng': targetLatLng,
              'steps': [
                'Head toward $rawName',
                'Follow directional signs',
                'Arrive at $rawName'
              ]
            });
          }
        }
      }
    } catch (_) {}

    places.sort((a, b) => (a['distanceMeters'] as num).compareTo(b['distanceMeters'] as num));
    return places.take(5).toList();
  }

  // Live filtered search with authentic spatial API queries — NO SYNTHETIC/FAKE PLACES EVER
  Future<List<Map<String, dynamic>>> _performSearch(String rawQuery) async {
    if (rawQuery.trim().isEmpty) {
      List<Map<String, dynamic>> res = [];
      if (_recentPlaces.isNotEmpty) {
        res = List.from(_recentPlaces);
      } else {
        res = await _getRealNearbyInitialPlaces();
      }
      if (mounted) setState(() { _isSearching = false; });
      _updateSearchResults(res);
      return res;
    }

    if (mounted) setState(() { _isSearching = true; });

    // Refresh live GPS position immediately before sending search API requests
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _currentLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
        });
      }
    } catch (_) {}

    // Clean voice query prefixes
    String query = rawQuery.trim();
    final cleanReg = RegExp(
      r'^(?:navigate to|take me to|go to|look for|find|search for|nearest|malapit na|pumunta sa|hanapin ang|hanapin sa)\s+',
      caseSensitive: false,
    );
    while (cleanReg.hasMatch(query)) {
      query = query.replaceFirst(cleanReg, '').trim();
    }
    if (query.isEmpty) query = rawQuery.trim();

    // Brand query title normalization
    final lowerRaw = query.toLowerCase();
    if (lowerRaw.contains('jollib') || lowerRaw.contains('jolib')) {
      query = 'Jollibee';
    } else if (lowerRaw.contains('mcdonald') || lowerRaw.contains('mcdo')) {
      query = "McDonald's";
    } else if (lowerRaw.contains('starbuck')) {
      query = 'Starbucks';
    } else if (lowerRaw.contains('chowking') || lowerRaw.contains('choking')) {
      query = 'Chowking';
    }

    final lowercaseQuery = query.toLowerCase();

    // Check query cache
    if (_placesCache.containsKey(lowercaseQuery)) {
      final cached = _placesCache[lowercaseQuery]!;
      if (mounted) setState(() { _isSearching = false; });
      _updateSearchResults(cached);
      return cached;
    }

    final List<Map<String, dynamic>> mappedPlaces = [];

    final apiKey = dotenv.env['GOOGLE_MAPS_KEY'] ?? '';
    const androidPackage = 'com.company.easylens';
    const androidCert = '449D1DCB363A578B7DE1E010286D8C0A90A40E57';
    final googleHeaders = {
      'X-Android-Package': androidPackage,
      'X-Android-Cert': androidCert,
    };

    print('[EASYLENS SEARCH] query="$query" loc=${_currentLocation.latitude},${_currentLocation.longitude}');

    // 1. Google Places Text Search API (Official Google Maps Places — Authorized via Package + Cert)
    if (apiKey.isNotEmpty) {
      try {
        final googleTextUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/textsearch/json'
          '?query=${Uri.encodeComponent(query)}'
          '&location=${_currentLocation.latitude},${_currentLocation.longitude}'
          '&region=ph'
          '&key=$apiKey'
        );
        print('[EASYLENS GOOGLE TEXT] Querying: $googleTextUrl');
        final response = await http.get(googleTextUrl, headers: googleHeaders).timeout(const Duration(seconds: 4));
        print('[EASYLENS GOOGLE TEXT] HTTP ${response.statusCode}');
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final status = data['status'] ?? 'UNKNOWN';
          print('[EASYLENS GOOGLE TEXT] Status: $status, Results: ${(data['results'] as List?)?.length}');
          if (data['results'] != null && (data['results'] as List).isNotEmpty) {
            final List<dynamic> results = data['results'];
            for (final res in results) {
              final lat = (res['geometry']['location']['lat'] as num).toDouble();
              final lng = (res['geometry']['location']['lng'] as num).toDouble();
              String name = res['name'] as String;
              final formattedAddress = res['formatted_address'] ?? res['vicinity'] ?? '';
              final targetLatLng = LatLng(lat, lng);

              if (mappedPlaces.any((p) => p['name'] == name || (p['latLng'] as LatLng).latitude == lat)) {
                continue;
              }

              final calc = _calculateDistanceAndTime(targetLatLng);
              final distMeters = Geolocator.distanceBetween(
                _currentLocation.latitude,
                _currentLocation.longitude,
                lat,
                lng,
              );

              mappedPlaces.add({
                'name': name,
                'address': formattedAddress,
                'dist': calc['dist']!,
                'time': calc['time']!,
                'distanceMeters': distMeters,
                'latLng': targetLatLng,
                'steps': [
                  'Head toward $name',
                  'Follow directional signs',
                  'Arrive at $name'
                ]
              });
            }
          }
        }
      } catch (e) {
        print('[EASYLENS GOOGLE TEXT ERROR] $e');
      }
    }

    // 2. Google Places Nearby Search API (Ranked strictly by distance from live GPS)
    if (mappedPlaces.length < 5 && apiKey.isNotEmpty) {
      try {
        final nearbyUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?keyword=${Uri.encodeComponent(query)}'
          '&location=${_currentLocation.latitude},${_currentLocation.longitude}'
          '&rankby=distance'
          '&key=$apiKey'
        );
        print('[EASYLENS GOOGLE NEARBY] Querying: $nearbyUrl');
        final response = await http.get(nearbyUrl, headers: googleHeaders).timeout(const Duration(seconds: 4));
        print('[EASYLENS GOOGLE NEARBY] HTTP ${response.statusCode}');
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['results'] != null && (data['results'] as List).isNotEmpty) {
            final List<dynamic> results = data['results'];
            for (final res in results) {
              final lat = (res['geometry']['location']['lat'] as num).toDouble();
              final lng = (res['geometry']['location']['lng'] as num).toDouble();
              String name = res['name'] as String;
              final formattedAddress = res['vicinity'] ?? res['formatted_address'] ?? '';
              final targetLatLng = LatLng(lat, lng);

              if (mappedPlaces.any((p) => p['name'] == name || (p['latLng'] as LatLng).latitude == lat)) {
                continue;
              }

              final calc = _calculateDistanceAndTime(targetLatLng);
              final distMeters = Geolocator.distanceBetween(
                _currentLocation.latitude,
                _currentLocation.longitude,
                lat,
                lng,
              );

              mappedPlaces.add({
                'name': name,
                'address': formattedAddress,
                'dist': calc['dist']!,
                'time': calc['time']!,
                'distanceMeters': distMeters,
                'latLng': targetLatLng,
                'steps': [
                  'Head toward $name',
                  'Turn right onto main road',
                  'Arrive at $name'
                ]
              });
            }
          }
        }
      } catch (e) {
        print('[EASYLENS GOOGLE NEARBY ERROR] $e');
      }
    }

    // 3. Photon Real Spatial Search API (OpenStreetMap Engine — Secondary Fallback)
    if (mappedPlaces.length < 5) {
      try {
        final photonUrl = Uri.parse(
          'https://photon.komoot.io/api/'
          '?q=${Uri.encodeComponent(query)}'
          '&lat=${_currentLocation.latitude}'
          '&lon=${_currentLocation.longitude}'
          '&limit=15'
        );
        print('[EASYLENS PHOTON] Querying: $photonUrl');
        final response = await http.get(photonUrl).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final features = data['features'] as List?;
          if (features != null && features.isNotEmpty) {
            for (final feat in features) {
              final props = feat['properties'] as Map<String, dynamic>? ?? {};
              final geom = feat['geometry'] as Map<String, dynamic>? ?? {};
              final coords = geom['coordinates'] as List?;
              if (coords == null || coords.length < 2) continue;

              final double lng = (coords[0] as num).toDouble();
              final double lat = (coords[1] as num).toDouble();
              final targetLatLng = LatLng(lat, lng);

              String rawName = props['name']?.toString() ?? '';
              if (rawName.trim().isEmpty) continue;

              final street = props['street']?.toString() ?? '';
              final locality = props['locality']?.toString() ?? props['district']?.toString() ?? props['suburb']?.toString() ?? '';
              final city = props['city']?.toString() ?? '';
              final state = props['state']?.toString() ?? '';

              String displayName = rawName;
              if (locality.isNotEmpty && !displayName.toLowerCase().contains(locality.toLowerCase())) {
                displayName = '$rawName - $locality';
              } else if (city.isNotEmpty && !displayName.toLowerCase().contains(city.toLowerCase())) {
                displayName = '$rawName - $city';
              }

              final addrParts = [street, locality, city, state].where((s) => s.isNotEmpty).toList();
              final formattedAddress = addrParts.isNotEmpty ? addrParts.join(', ') : 'Nearby $displayName';

              if (mappedPlaces.any((p) => p['name'] == displayName || (p['latLng'] as LatLng).latitude == lat)) {
                continue;
              }

              final calc = _calculateDistanceAndTime(targetLatLng);
              final distMeters = Geolocator.distanceBetween(
                _currentLocation.latitude,
                _currentLocation.longitude,
                lat,
                lng,
              );

              mappedPlaces.add({
                'name': displayName,
                'address': formattedAddress,
                'dist': calc['dist']!,
                'time': calc['time']!,
                'distanceMeters': distMeters,
                'latLng': targetLatLng,
                'steps': [
                  'Head toward $displayName',
                  'Follow directional signs',
                  'Arrive at $displayName'
                ]
              });
            }
          }
        }
      } catch (e) {
        print('[EASYLENS PHOTON ERROR] $e');
      }
    }

    // 4. Smart Query Decomposition Fallback for multi-word location queries (e.g. "jollibee calulut")
    if (mappedPlaces.isEmpty && query.contains(' ')) {
      try {
        final tokens = query.split(' ').where((t) => t.trim().isNotEmpty).toList();
        String brandToken = '';
        String locationToken = '';

        for (int i = 0; i < tokens.length; i++) {
          final t = tokens[i].toLowerCase();
          if (t.contains('jollib') || t.contains('jolib')) {
            brandToken = 'Jollibee';
          } else if (t.contains('mcdonald') || t.contains('mcdo')) {
            brandToken = "McDonald's";
          } else if (t.contains('shakey')) {
            brandToken = "Shakey's";
          } else if (t.contains('starbuck')) {
            brandToken = 'Starbucks';
          } else if (t.contains('chowking')) {
            brandToken = 'Chowking';
          } else {
            if (locationToken.isNotEmpty) locationToken += ' ';
            locationToken += tokens[i];
          }
        }

        if (brandToken.isNotEmpty && locationToken.isNotEmpty) {
          print('[EASYLENS SMART SEARCH] Brand: "$brandToken", Location Modifier: "$locationToken"');
          // Geocode location modifier first
          final geoUrl = Uri.parse(
            'https://photon.komoot.io/api/'
            '?q=${Uri.encodeComponent(locationToken)}'
            '&lat=${_currentLocation.latitude}'
            '&lon=${_currentLocation.longitude}'
            '&limit=1'
          );
          final geoResp = await http.get(geoUrl).timeout(const Duration(seconds: 3));
          if (geoResp.statusCode == 200) {
            final geoData = jsonDecode(geoResp.body);
            final feats = geoData['features'] as List?;
            if (feats != null && feats.isNotEmpty) {
              final coords = feats[0]['geometry']['coordinates'] as List?;
              if (coords != null && coords.length >= 2) {
                final targetLat = (coords[1] as num).toDouble();
                final targetLng = (coords[0] as num).toDouble();

                // Now search brand centered at location modifier coordinates
                final brandUrl = Uri.parse(
                  'https://photon.komoot.io/api/'
                  '?q=${Uri.encodeComponent(brandToken)}'
                  '&lat=$targetLat'
                  '&lon=$targetLng'
                  '&limit=15'
                );
                print('[EASYLENS SMART SEARCH] Querying brand near location: $brandUrl');
                final brandResp = await http.get(brandUrl).timeout(const Duration(seconds: 3));
                if (brandResp.statusCode == 200) {
                  final brandData = jsonDecode(brandResp.body);
                  final brandFeats = brandData['features'] as List?;
                  if (brandFeats != null) {
                    for (final feat in brandFeats) {
                      final props = feat['properties'] as Map<String, dynamic>? ?? {};
                      final geom = feat['geometry'] as Map<String, dynamic>? ?? {};
                      final c = geom['coordinates'] as List?;
                      if (c == null || c.length < 2) continue;

                      final double pLng = (c[0] as num).toDouble();
                      final double pLat = (c[1] as num).toDouble();
                      final placeLatLng = LatLng(pLat, pLng);

                      String rawName = props['name']?.toString() ?? brandToken;
                      final street = props['street']?.toString() ?? '';
                      final locality = props['locality']?.toString() ?? props['district']?.toString() ?? locationToken;
                      final city = props['city']?.toString() ?? '';
                      final state = props['state']?.toString() ?? '';

                      String displayName = '$rawName - $locality';
                      final addrParts = [street, locality, city, state].where((s) => s.isNotEmpty).toList();
                      final formattedAddress = addrParts.isNotEmpty ? addrParts.join(', ') : '$brandToken in $locationToken';

                      final calc = _calculateDistanceAndTime(placeLatLng);
                      final distMeters = Geolocator.distanceBetween(
                        _currentLocation.latitude,
                        _currentLocation.longitude,
                        pLat,
                        pLng,
                      );

                      mappedPlaces.add({
                        'name': displayName,
                        'address': formattedAddress,
                        'dist': calc['dist']!,
                        'time': calc['time']!,
                        'distanceMeters': distMeters,
                        'latLng': placeLatLng,
                        'steps': [
                          'Head toward $displayName',
                          'Follow directional signs',
                          'Arrive at $displayName'
                        ]
                      });
                    }
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        print('[EASYLENS SMART SEARCH ERROR] $e');
      }
    }

    // Sort by physical distance ascending (NEAREST FIRST)
    mappedPlaces.sort((a, b) {
      final double distA = (a['distanceMeters'] as num?)?.toDouble() ?? 0.0;
      final double distB = (b['distanceMeters'] as num?)?.toDouble() ?? 0.0;
      return distA.compareTo(distB);
    });

    final List<Map<String, dynamic>> finalResults = mappedPlaces.take(5).toList();

    if (mounted) setState(() { _isSearching = false; });
    _placesCache[lowercaseQuery] = finalResults;
    _updateSearchResults(finalResults);
    return finalResults;
  }

  void _onFilterTap(String filter) {
    setState(() {
      _selectedFilter = filter;
      _searchController.text = filter;
    });
    _performSearch(filter);
  }

  void _startGuidance(Map<String, dynamic> place) {
    setState(() {
      _selectedPlace = place;
      _currentStepIndex = 0;
      _lastDynamicAnnouncedDistanceM = null;
      _hasAnnouncedArrival = false;
      _navState = 1;
    });
    _fetchRoadRoute();

    // Save recent navigation data locally and to Firestore (Max 5 items)
    _saveToRecentHistory(place);

    // Animate map camera to focus on selected location
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              _currentLocation.latitude < (place['latLng'] as LatLng).latitude
                  ? _currentLocation.latitude
                  : (place['latLng'] as LatLng).latitude,
              _currentLocation.longitude < (place['latLng'] as LatLng).longitude
                  ? _currentLocation.longitude
                  : (place['latLng'] as LatLng).longitude,
            ),
            northeast: LatLng(
              _currentLocation.latitude > (place['latLng'] as LatLng).latitude
                  ? _currentLocation.latitude
                  : (place['latLng'] as LatLng).latitude,
              _currentLocation.longitude > (place['latLng'] as LatLng).longitude
                  ? _currentLocation.longitude
                  : (place['latLng'] as LatLng).longitude,
            ),
          ),
          60.0, // padding
        ),
      );
    }

    // Speak initial direction with user configuration preference
    final firstDirection = (place['steps'] as List).isNotEmpty ? (place['steps'] as List)[0].toString() : '';
    final unit = SettingsService().selectedUnit;
    final formattedDist = _formatDistance(place['dist'] as String, unit);
    final formattedStep = _formatStep(firstDirection, unit);

    TtsService().speak(
      "Starting navigation guidance to ${place['name']}. Distance is $formattedDist, estimated time is ${place['time']}. $formattedStep.",
    );
  }

  void _nextStep() {
    if (_selectedPlace == null) return;
    final steps = (_selectedPlace!['steps'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    if (_currentStepIndex < steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      final unit = SettingsService().selectedUnit;
      final stepText = _formatStep(steps[_currentStepIndex], unit);
      TtsService().speak(stepText);
      ActiveNavigationService().updateProgress(
        currentStepText: stepText,
        distanceRemaining: _selectedPlace!['dist'],
        timeRemaining: _selectedPlace!['time'],
        currentLocation: _currentLocation,
        currentStepIndex: _currentStepIndex,
      );
    } else {
      if (_selectedPlace != null) {
        _saveToRecentHistory(_selectedPlace!);
      }
      setState(() {
        _navState = 2; // Arrived map view (Figma Screen 4)
      });
      TtsService().speak(
        "You have arrived at your destination, ${_selectedPlace!['name']}. Thank you for using EasyLens.",
      );
      ActiveNavigationService().triggerArrival();
    }
  }

  void _cancelNavigation() async {
    ActiveNavigationService().stopNavigation();
    setState(() {
      _navState = 0;
      _selectedPlace = null;
      _currentStepIndex = 0;
      _lastDynamicAnnouncedDistanceM = null;
      _hasAnnouncedArrival = false;
      _searchController.clear();
      _stepLocations = [];
      _lastRerouteTime = 0;
      _offRouteCounter = 0;
      _lastTurnAlertTime = 0;
      _lastProximityAlertTime = 0;
      _lastGpsAlertTime = 0;
      _lastTurnIndexAnnounced = -1;
      _lastProximityIndexAnnounced = -1;
    });

    await _loadRecentNavigations();

    if (_mapController != null) {
      try {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _currentLocation,
              zoom: 15.0,
            ),
          ),
        );
      } catch (e) {
        debugPrint("Map animateCamera error on cancel: $e");
      }
    }
  }

  void _onMapLongPress(LatLng position) {
    if (_navState == 1) return; // Prevent pinning while actively navigating

    // Calculate dynamic distance and time
    final distMeters = Geolocator.distanceBetween(
      _currentLocation.latitude,
      _currentLocation.longitude,
      position.latitude,
      position.longitude,
    );
    final double kmVal = distMeters / 1000.0;
    final String distStr = "${kmVal.toStringAsFixed(1)} km";
    final int estMinutes = (kmVal * 12.0).round().clamp(1, 120);

    final lang = SettingsService().selectedLanguage;
    final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');

    final pinnedPlace = {
      'name': 'Pinned Location',
      'address': 'Custom map destination',
      'dist': distStr,
      'time': '$estMinutes min',
      'latLng': position,
      'steps': isFilipino ? [
        'Tumungo patungong Pinned Location',
        'Kumanan sa pinakamalapit na pangunahing daan',
        'Sundin ang mga palatandaan sa direksyon',
        'Dumating sa Pinned Location'
      ] : [
        'Head toward Pinned Location',
        'Turn right onto closest main road',
        'Follow directional signs',
        'Arrive at Pinned Location'
      ]
    };

    _searchController.text = 'Pinned Location';

    // Animate map to pinned location
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(position),
    );

    _startGuidance(pinnedPlace);
  }

  String _getDynamicETA(String durationStr) {
    try {
      final int minutes = int.parse(durationStr.replaceAll(RegExp(r'[^0-9]'), ''));
      final targetTime = DateTime.now().add(Duration(minutes: minutes));
      final hour = targetTime.hour.toString().padLeft(2, '0');
      final minute = targetTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      final hour = DateTime.now().hour.toString().padLeft(2, '0');
      final minute = DateTime.now().minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = _navState == 0;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final lang = SettingsService().selectedLanguage;
        final isTagalog = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
        
        TtsService().speak(
          isTagalog
              ? "Sigurado ka bang nais mong lumabas? Mananatiling aktibo ang iyong nabigasyon sa background."
              : "Are you sure you want to exit? Your navigation will remain active in the background."
        );
        
        final action = await showDialog<String>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                isTagalog ? "Aktibong Nabigasyon" : "Active Navigation",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              content: Text(
                isTagalog
                    ? "Nais mo bang lumabas at panatilihin ang nabigasyon, o ganap na ihinto ito?"
                    : "Do you want to exit and keep navigation active, or stop it entirely?",
                style: GoogleFonts.inter(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop('keep'),
                  child: Text(
                    isTagalog ? "Ipagpatuloy sa Background" : "Keep in Background",
                    style: GoogleFonts.inter(color: const Color(0xFF002663), fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop('stop'),
                  child: Text(
                    isTagalog ? "Ihinto" : "Stop Navigation",
                    style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop('cancel'),
                  child: Text(
                    isTagalog ? "Ipagpatuloy Dito" : "Cancel",
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                ),
              ],
            );
          },
        );
        
        if (!context.mounted) return;
        
        if (action == 'stop') {
          _cancelNavigation();
        }
      },
      child: ListenableBuilder(
        listenable: SettingsService(),
        builder: (context, _) {
          final isDark = SettingsService().isDarkMode ||
              (SettingsService().selectedContrastTheme != 'Default' &&
                  SettingsService().selectedContrastTheme != 'Black on White');
          final isDefaultTheme = SettingsService().selectedContrastTheme == 'Default' && !SettingsService().isDarkMode;
          return Scaffold(
            backgroundColor: isDefaultTheme ? const Color(0xFFE2E8F0) : AppColors.primaryBackground,
            body: Stack(
              fit: StackFit.expand,
              children: [
          // ── DYNAMIC GOOGLE MAPS INTERACTIVE OVERLAY ──
          Positioned.fill(
            child: SizedBox.expand(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentLocation,
                  zoom: _is3DPerspective ? 17.5 : 16.5,
                  tilt: _is3DPerspective ? 60.0 : 0.0,
                ),
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                myLocationEnabled: false, // Prevents native SecurityException crash on Android
                mapToolbarEnabled: false,
                compassEnabled: false,
                tiltGesturesEnabled: true,
                rotateGesturesEnabled: true,
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,
                buildingsEnabled: true,
                trafficEnabled: _showTraffic,
                mapType: _currentMapType,
                markers: _getMapMarkers(),
                polylines: _getMapPolylines(),
                onTap: _onMapLongPress,
                onLongPress: _onMapLongPress,
                onMapCreated: (controller) {
                  _mapController = controller;
                  _applyMapTheme(isDark);
                  try {
                    _mapController?.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: _currentLocation,
                          zoom: _is3DPerspective ? 17.5 : 16.5,
                          tilt: _is3DPerspective ? 60.0 : 0.0,
                        ),
                      ),
                    );
                  } catch (_) {}
                },
              ),
            ),
          ),



          // ── FIGMA CUSTOM APPBAR ──
          Positioned(
            top: 16,
            left: 24,
            right: 24,
            child: SafeArea(
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        AppRoute.to(const EmergencyScreen()),
                      );
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
                      color: AppColors.primaryBackground,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowColor,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Map Layers & Safety Options (Pull Down)',
                          icon: Icon(
                            _showAccessibilityOverlay
                                ? Icons.layers_rounded
                                : (_currentMapType == MapType.hybrid ? Icons.satellite_alt_rounded : Icons.map_outlined),
                            size: 20,
                            color: (_showAccessibilityOverlay || _currentMapType == MapType.hybrid || _is3DPerspective || _showTraffic)
                                ? AppColors.primaryButton
                                : AppColors.primaryText,
                          ),
                          onPressed: () {
                            SoundService.playClick();
                            _showMapLayersPullDownSheet();
                          },
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        IconButton(
                          icon: Icon(Icons.notifications_none, size: 20, color: AppColors.primaryText),
                          onPressed: () {
                            SoundService.playClick();
                            Navigator.push(context, AppRoute.to(const NotificationsScreen()));
                          },
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        IconButton(
                          icon: Icon(Icons.people_outline, size: 20, color: AppColors.primaryText),
                          onPressed: () {
                            SoundService.playClick();
                            Navigator.push(context, AppRoute.to(const ContactsScreen()));
                          },
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        IconButton(
                          icon: Icon(Icons.settings_outlined, size: 20, color: AppColors.primaryText),
                          onPressed: () {
                            SoundService.playClick();
                            Navigator.push(context, AppRoute.to(const SettingsScreen()));
                          },
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── CRITICAL DANGER / HAZARD OVERLAY ──
          ListenableBuilder(
            listenable: ActiveNavigationService(),
            builder: (context, child) {
              if (!ActiveNavigationService().isHazardActive) {
                return const SizedBox.shrink();
              }
              return Positioned(
                top: 80,
                left: 12,
                right: 12,
                child: SafeArea(
                  child: CriticalDangerOverlay(
                    severity: ActiveNavigationService().hazardSeverity,
                    title: ActiveNavigationService().activeHazardName,
                    message: ActiveNavigationService().activeHazardMessage,
                    hazardName: ActiveNavigationService().activeHazardName,
                    onDismiss: _clearHazardAlert,
                    onReannounce: () {
                      TtsService().speak(ActiveNavigationService().activeHazardMessage);
                    },
                    onEmergencyCall: () {
                      Navigator.push(context, AppRoute.to(const EmergencyScreen()));
                    },
                  ),
                ),
              );
            },
          ),

          // ── ELEVATED 3D WALKING HUD PILL (WHEN 3D IS ACTIVE) ──
          if (_is3DPerspective && _currentMapType != MapType.hybrid)
            Positioned(
              top: 85,
              left: 24,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.92) : Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withOpacity(0.6),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.35 : 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF38BDF8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '3D Box Architecture • Follow',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── FLOATING QUICK MAP ACTIONS HUD (3D / 2D TILT, RECENTER GPS) ──
          Positioned(
            right: 20,
            top: 85,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. 3D / 2D Perspective Toggle Button
                  GestureDetector(
                    onTap: _toggle3DPerspective,
                    child: Opacity(
                      opacity: _currentMapType == MapType.hybrid ? 0.45 : 1.0,
                      child: Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _is3DPerspective && _currentMapType != MapType.hybrid
                                ? const Color(0xFF38BDF8)
                                : (isDark ? Colors.white12 : Colors.black.withOpacity(0.08)),
                            width: _is3DPerspective && _currentMapType != MapType.hybrid ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _currentMapType == MapType.hybrid
                              ? '2D'
                              : (_is3DPerspective ? '3D' : '2D'),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _is3DPerspective && _currentMapType != MapType.hybrid
                                ? const Color(0xFF38BDF8)
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 2. Recenter GPS Button
                  GestureDetector(
                    onTap: () {
                      SoundService.playClick();
                      _mapController?.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: _currentLocation,
                            zoom: _is3DPerspective ? 17.5 : 16.5,
                            tilt: _is3DPerspective ? 60.0 : 0.0,
                          ),
                        ),
                      );
                      final lang = SettingsService().selectedLanguage;
                      final isTagalog = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
                      TtsService().speak(isTagalog
                          ? "Nakapokus na muli sa iyong kasalukuyang lokasyon."
                          : "Recentered to your current location.");
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.my_location_rounded,
                        size: 20,
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF002663),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── FIGMA SLIDING CARD OVERLAYS ──
          Positioned.fill(
            child: _buildDraggableCardOverlay(),
          ),

          // ── SPEECH NAVIGATION DESTINATION CONFIRMATION CARD OVERLAY ──
          Positioned.fill(
            child: _buildNavigationConfirmationCardOverlay(),
          ),

        ],
      ),
    );
        },
      ),
    );
  }

  /// Interactive Confirmation Card Dialog Overlay for Hands-Free Speech Navigation
  Widget _buildNavigationConfirmationCardOverlay() {
    if (_pendingPlaceToConfirm == null) return const SizedBox.shrink();

    final settings = SettingsService();
    final isTagalog = settings.selectedLanguage.toLowerCase().contains('tagalog') ||
        settings.selectedLanguage.toLowerCase().contains('filipino');

    final place = _pendingPlaceToConfirm!;
    final name = place['name'] as String;
    final address = place['address'] as String? ?? '';
    
    String dist = place['dist'] as String? ?? '';
    String time = place['time'] as String? ?? '';
    if (place['latLng'] is LatLng) {
      final calc = _calculateDistanceAndTime(place['latLng'] as LatLng);
      dist = calc['dist']!;
      time = calc['time']!;
    }

    final bgColor = AppColors.primaryBackground;
    final textColor = AppColors.primaryText;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.cardBorder,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Mascot or Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryButton.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.navigation_rounded, color: AppColors.primaryButton, size: 32),
              ),
              const SizedBox(height: 14),

              Text(
                isTagalog ? 'Kumpirmahin ang Ruta' : 'Confirm Destination',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryButton == Colors.white ? Colors.white : AppColors.primaryButton,
                ),
              ),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  address,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Distance & Time pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryButton.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${_formatDistance(dist, SettingsService().selectedUnit)} • $time',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Voice prompt instruction text (Only show if Speech Navigation setting is enabled)
              if (SettingsService().voiceNavigationEnabled) ...[
                Text(
                  isTagalog
                      ? "Sabihin ang 'Oo', 'Kumpirmahin', o 'Sige' para magpatuloy, o 'Hindi' / 'Kanselahin'."
                      : "Say 'Yes', 'Confirm', or 'Search' to proceed, or 'No' / 'Cancel'.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),
              ] else
                const SizedBox(height: 12),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelPendingNavigation,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(color: Colors.red, width: 1.5),
                      ),
                      child: Text(
                        isTagalog ? 'Kanselahin' : 'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmPendingNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryButton,
                        foregroundColor: AppColors.primaryButtonText,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        isTagalog ? 'Simulan' : 'Start',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  // ── MAP MARKERS GENERATION ──
  Set<Marker> _getMapMarkers() {
    final isDark = SettingsService().isDarkMode ||
        (SettingsService().selectedContrastTheme != 'Default' &&
            SettingsService().selectedContrastTheme != 'Black on White');

    final bool is3DActive = _is3DPerspective && _currentMapType != MapType.hybrid;

    final cachedUserPin = isDark ? _staticUser3DPinDark : _staticUser3DPinLight;
    final userIcon = (is3DActive && (_userLocation3DPin != null || cachedUserPin != null))
        ? (_userLocation3DPin ?? cachedUserPin!)
        : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

    final Set<Marker> markers = {
      Marker(
        markerId: MarkerId('current_loc_${is3DActive ? "3d" : "2d"}_${userIcon.hashCode}'),
        position: _currentLocation,
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: userIcon,
        anchor: is3DActive ? const Offset(0.5, 0.8421) : const Offset(0.5, 1.0),
      )
    };

    // ── ACCESSIBILITY & SAFETY INFRASTRUCTURE PINS ──
    if (_showAccessibilityOverlay && _accessibilityPOIs.isNotEmpty) {
      for (int i = 0; i < _accessibilityPOIs.length; i++) {
        final poi = _accessibilityPOIs[i];
        final latLng = poi['latLng'] as LatLng?;
        if (latLng == null) continue;

        final type = poi['type'] as String? ?? 'crossing';
        BitmapDescriptor markerIcon;

        if (is3DActive && (_building3DMarkerCache.containsKey('${type}_$isDark') || _staticBuilding3DMarkerCache.containsKey('${type}_$isDark'))) {
          markerIcon = _building3DMarkerCache['${type}_$isDark'] ?? _staticBuilding3DMarkerCache['${type}_$isDark']!;
        } else {
          double markerHue = BitmapDescriptor.hueCyan;
          if (type == 'hospital') {
            markerHue = BitmapDescriptor.hueRose;
          } else if (type == 'crossing') {
            markerHue = BitmapDescriptor.hueGreen;
          } else if (type == 'hazard') {
            markerHue = BitmapDescriptor.hueOrange;
          }
          markerIcon = BitmapDescriptor.defaultMarkerWithHue(markerHue);
        }

        markers.add(
          Marker(
            markerId: MarkerId('acc_poi_${i}_${is3DActive ? "3d" : "2d"}_${markerIcon.hashCode}'),
            position: latLng,
            icon: markerIcon,
            anchor: is3DActive ? const Offset(0.5, 0.85) : const Offset(0.5, 1.0),
            infoWindow: InfoWindow(
              title: poi['name'] as String? ?? 'Accessibility Point',
              snippet: "${poi['dist']} • ${poi['desc']}",
            ),
            onTap: () {
              final name = poi['name'] as String? ?? 'Accessibility Point';
              final dist = poi['dist'] as String? ?? '';
              final desc = poi['desc'] as String? ?? '';
              TtsService().speak("$name, $dist away. $desc");
            },
          ),
        );
      }
    }

    if (_selectedPlace != null) {
      final cachedDestPin = isDark ? _staticDest3DPinDark : _staticDest3DPinLight;
      final destIcon = (is3DActive && (_destination3DPin != null || cachedDestPin != null))
          ? (_destination3DPin ?? cachedDestPin!)
          : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

      markers.add(
        Marker(
          markerId: MarkerId('destination_${is3DActive ? "3d" : "2d"}_${destIcon.hashCode}'),
          position: _selectedPlace!['latLng'] as LatLng,
          icon: destIcon,
          anchor: is3DActive ? const Offset(0.5, 0.8421) : const Offset(0.5, 1.0),
          infoWindow: InfoWindow(title: _selectedPlace!['name'] as String),
        ),
      );
    } else if (_searchController.text.trim().isNotEmpty && _searchResults.isNotEmpty) {
      for (int i = 0; i < _searchResults.length && i < 5; i++) {
        final place = _searchResults[i];
        final latLng = place['latLng'] as LatLng?;
        if (latLng != null) {
          final styleKey = 'style_${i % 8}';
          final storeIcon = (is3DActive && (_building3DMarkerCache.containsKey('${styleKey}_$isDark') || _staticBuilding3DMarkerCache.containsKey('${styleKey}_$isDark')))
              ? (_building3DMarkerCache['${styleKey}_$isDark'] ?? _staticBuilding3DMarkerCache['${styleKey}_$isDark']!)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

          markers.add(
            Marker(
              markerId: MarkerId('search_res_${i}_${is3DActive ? "3d" : "2d"}_${storeIcon.hashCode}'),
              position: latLng,
              icon: storeIcon,
              anchor: is3DActive ? const Offset(0.5, 0.85) : const Offset(0.5, 1.0),
              infoWindow: InfoWindow(
                title: place['name'] as String? ?? 'Nearby Place',
                snippet: place['dist'] as String? ?? '',
              ),
            ),
          );
        }
      }
    }
    return markers;
  }

  // ── MAP POLYLINES GENERATION (DOTTED DIRECTIVE ROUTE) ──
  Set<Polyline> _getMapPolylines() {
    if (_selectedPlace == null) return {};
    final isDark = SettingsService().isDarkMode ||
        (SettingsService().selectedContrastTheme != 'Default' &&
            SettingsService().selectedContrastTheme != 'Black on White');
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        color: isDark ? const Color(0xFF38BDF8) : Colors.blue.shade800,
        width: 6,
        patterns: [PatternItem.dot, PatternItem.gap(10)],
        points: _routePoints.isNotEmpty
            ? _routePoints
            : [
                _currentLocation,
                _selectedPlace!['latLng'] as LatLng,
              ],
      )
    };
  }

  // ── DRAGGABLE BOTTOM SHEET OVERLAY ──
  Widget _buildDraggableCardOverlay() {
    if (_pendingPlaceToConfirm != null) return const SizedBox.shrink();

    double initialSize = 0.55;
    double minSize = 0.30;
    double maxSize = 0.92;

    if (_navState == 1) {
      initialSize = 0.65;
      minSize = 0.5;
      maxSize = 0.9;
    } else if (_navState == 2) {
      initialSize = 0.52;
      minSize = 0.35;
      maxSize = 0.90;
    }

    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.primaryBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              )
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 110),
              child: _buildCardContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardContent() {
    switch (_navState) {
      case 0:
        return _buildInitialSearchContent();
      case 1:
        return _buildGuidelineStepContent();
      case 2:
        return _buildFullMapDirectionContent();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── OVERLAY CONTENT 1: Search & Filter ──────────────────────────────
  Widget _buildInitialSearchContent() {
    final lang = SettingsService().selectedLanguage;
    final isTagalog = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag indicator line
        Center(
          child: Container(
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.primaryText.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Search bar S01
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          onSubmitted: (val) => _performSearch(val),
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.primaryText),
          decoration: InputDecoration(
            hintText: TranslationService.translate('Where to?', lang),
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
            prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 22),
            suffixIcon: IconButton(
              icon: Icon(Icons.mic, color: AppColors.primaryButton, size: 22),
              tooltip: isTagalog ? "Magsalita para maghanap" : "Voice search",
              onPressed: _activateVoiceSearch,
            ),
            filled: true,
            fillColor: AppColors.lightBackground,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.3), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.3), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Filter shortcuts
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: FilterChip(
                  label: Text(TranslationService.translate(filter, lang)),
                  selected: isSelected,
                  onSelected: (_) => _onFilterTap(filter),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppColors.primaryButtonText : AppColors.primaryText,
                  ),
                  backgroundColor: AppColors.lightBackground,
                  selectedColor: AppColors.primaryButton,
                  checkmarkColor: AppColors.primaryButtonText,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),
        Text(
          _isSearching 
            ? TranslationService.translate('SEARCHING...', lang)
            : (_searchController.text.trim().isNotEmpty 
              ? TranslationService.translate('RESULTS', lang) 
              : TranslationService.translate('RECENT', lang)),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),

        // Loading spinner while searching
        if (_isSearching)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primaryButton,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Searching nearby places...',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          )
        // No results message
        else if (_searchResults.isEmpty && _searchController.text.trim().isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.location_off, color: AppColors.textMuted, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    'No places found for "${_searchController.text.trim()}"',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check your Google Maps API key or internet connection',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted.withValues(alpha: 0.6)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        // Results list
        else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _searchResults.length > 5 ? 5 : _searchResults.length,
          separatorBuilder: (_, __) => Divider(height: 16, color: AppColors.cardBorder.withValues(alpha: 0.2)),
          itemBuilder: (context, index) {
            final place = _searchResults[index];
            String placeDist = place['dist'] as String;
            String placeTime = place['time'] as String;
            if (place['latLng'] is LatLng) {
              final calc = _calculateDistanceAndTime(place['latLng'] as LatLng);
              placeDist = calc['dist']!;
              placeTime = calc['time']!;
            }

            return Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                tileColor: Colors.transparent,
                selectedTileColor: Colors.transparent,
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryButton.withValues(alpha: 0.12),
                  radius: 20,
                  child: Icon(Icons.access_time, color: AppColors.primaryButton, size: 20),
                ),
                title: Text(
                  place['name'] as String,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryText),
                ),
                subtitle: Text(
                  place['address'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                ),
                trailing: Text(
                  '${_formatDistance(placeDist, SettingsService().selectedUnit)} • $placeTime',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryText),
                ),
                onTap: () => _requestNavigationConfirmation(place),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── OVERLAY CONTENT 2: Active Guideline Steps ────────────────────────
  Widget _buildGuidelineStepContent() {
    if (_selectedPlace == null) return const SizedBox.shrink();
    final lang = SettingsService().selectedLanguage;
    final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
    final steps = (_selectedPlace!['steps'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    final stepText = steps[_currentStepIndex];

    return Column(
      children: [
        Center(
          child: Container(
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.cardBorder.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Text(
          _getDynamicETA(_selectedPlace!['time'] as String),
          style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primaryText),
        ),
        const SizedBox(height: 4),
        Text(
          '${_formatDistance(_selectedPlace!['dist'] as String, SettingsService().selectedUnit)} • ${_selectedPlace!['time']}',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Divider(height: 32, color: AppColors.cardBorder.withValues(alpha: 0.3)),

        Text(
          isFilipino ? 'Papunta sa ${_selectedPlace!['address']}' : 'To ${_selectedPlace!['address']}',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.primaryText.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 48,
                color: AppColors.primaryButton,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _formatStep(stepText, SettingsService().selectedUnit),
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Custom Slider with Red Pin Indicator
        LayoutBuilder(
          builder: (context, constraints) {
            final double currentProgress = (_currentStepIndex + 1) / steps.length;
            return Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 6,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  height: 6,
                  width: constraints.maxWidth * currentProgress,
                  decoration: BoxDecoration(
                    color: AppColors.primaryButton,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Positioned(
                  left: (constraints.maxWidth * currentProgress) - 10,
                  child: Icon(Icons.arrow_right_alt, color: AppColors.primaryButton, size: 24),
                ),
                const Positioned(
                  right: 0,
                  child: Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 26,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // ── HAZARD WARNING SYSTEM PANEL ──
        _buildHazardTestPanel(),

        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade500,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  onPressed: _cancelNavigation,
                  child: Text(
                    TranslationService.translate('Stop', lang),
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryButton,
                    foregroundColor: AppColors.primaryButtonText,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  onPressed: _nextStep,
                  child: Text(
                    TranslationService.translate('Next', lang),
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHazardTestPanel() {
    return ListenableBuilder(
      listenable: ActiveNavigationService(),
      builder: (context, child) {
        final navService = ActiveNavigationService();
        final isHazard = navService.isHazardActive;
        final isTagalog = SettingsService().selectedLanguage.toLowerCase().contains('tagalog');
        final isDark = SettingsService().isDarkMode || SettingsService().selectedContrastTheme != 'Default';

        final isCritical = navService.hazardSeverity == HazardSeverity.critical;
        final isCaution = navService.hazardSeverity == HazardSeverity.caution;
        final isDoorOrSafe = navService.hazardSeverity == HazardSeverity.safe ||
            navService.activeHazardName.toLowerCase().contains('door');

        final Color cardBg = isHazard
            ? (isCritical
                ? (isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50)
                : (isCaution
                    ? (isDark ? Colors.orange.shade900.withValues(alpha: 0.3) : Colors.orange.shade50)
                    : (isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50)))
            : (isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50);

        final Color borderColor = isHazard
            ? (isCritical
                ? Colors.red.shade400
                : (isCaution
                    ? Colors.orange.shade400
                    : Colors.green.shade400))
            : AppColors.cardBorder.withValues(alpha: 0.4);

        final Color iconColor = isHazard
            ? (isCritical
                ? Colors.red.shade400
                : (isCaution
                    ? Colors.orange.shade400
                    : Colors.green.shade600))
            : AppColors.primaryButton;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: isHazard
                ? [
                    BoxShadow(
                      color: (isCritical
                              ? Colors.red
                              : (isCaution ? Colors.orange : Colors.green))
                          .withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Icon(
                    isHazard
                        ? (isDoorOrSafe ? Icons.door_front_door_outlined : Icons.warning_amber_rounded)
                        : Icons.shield_outlined,
                    size: 20,
                    color: iconColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isHazard && isDoorOrSafe
                        ? (isTagalog ? "IMPORMASYON SA PINTO" : "DOOR APPROACH NOTICE")
                        : (isTagalog ? "SISTEMA NG BABALA SA PANGANIB" : "HAZARD WARNING SYSTEM"),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isHazard
                          ? (isDoorOrSafe
                              ? Colors.green.shade900.withValues(alpha: 0.3)
                              : (isCritical
                                  ? Colors.red.shade900.withValues(alpha: 0.3)
                                  : Colors.orange.shade900.withValues(alpha: 0.3)))
                          : Colors.green.shade900.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isHazard
                            ? (isDoorOrSafe
                                ? Colors.green.shade400
                                : (isCritical ? Colors.red.shade400 : Colors.orange.shade400))
                            : Colors.green.shade400,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isHazard
                                ? (isDoorOrSafe
                                    ? Colors.green
                                    : (isCritical ? Colors.red : Colors.orange))
                                : Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isHazard
                              ? (isDoorOrSafe ? (isTagalog ? "PINTO" : "NOTICE") : (isCritical ? "DANGER" : "WARNING"))
                              : "ACTIVE",
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isHazard
                                ? (isDoorOrSafe
                                    ? Colors.green.shade400
                                    : (isCritical ? Colors.red.shade400 : Colors.orange.shade400))
                                : Colors.green.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Dynamic Body Content
              if (isHazard) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isCritical
                            ? Colors.red.shade900.withValues(alpha: 0.4)
                            : (isCaution
                                ? Colors.orange.shade900.withValues(alpha: 0.4)
                                : Colors.green.shade900.withValues(alpha: 0.4)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDoorOrSafe
                            ? Icons.door_front_door_outlined
                            : (isCritical
                                ? Icons.report_problem_rounded
                                : Icons.warning_amber_rounded),
                        color: isCritical
                            ? Colors.red.shade300
                            : (isCaution
                                ? Colors.orange.shade300
                                : (isDark ? Colors.green.shade300 : Colors.green.shade700)),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            navService.activeHazardName.isNotEmpty
                                ? navService.activeHazardName
                                : (isDoorOrSafe ? "Door Approaching" : "Hazard Detected"),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isCritical
                                  ? Colors.red.shade300
                                  : (isCaution
                                      ? Colors.orange.shade300
                                      : (isDark ? Colors.green.shade300 : Colors.green.shade800)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            navService.activeHazardMessage.isNotEmpty
                                ? navService.activeHazardMessage
                                : (isDoorOrSafe
                                    ? "Notice: You are approaching a door."
                                    : "Caution! An obstacle has been detected in your navigation path."),
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: isCritical
                                  ? Colors.red.shade800
                                  : (isCaution
                                      ? Colors.orange.shade800
                                      : (isDark ? Colors.green.shade100 : Colors.green.shade900)),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Directional Avoidance Guidance Strip (only for hazardous obstacles) ──
                if (!isDoorOrSafe &&
                    navService.avoidanceDirection.isNotEmpty &&
                    navService.avoidanceDirection != 'center') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: navService.avoidanceDirection == 'left'
                            ? [const Color(0xFF1565C0), const Color(0xFF42A5F5)]
                            : [const Color(0xFF42A5F5), const Color(0xFF1565C0)],
                        begin: navService.avoidanceDirection == 'left'
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        end: navService.avoidanceDirection == 'left'
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (navService.avoidanceDirection == 'left') ...[
                          const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                        ],
                        Icon(
                          navService.avoidanceDirection == 'left'
                              ? Icons.turn_left_rounded
                              : Icons.turn_right_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isTagalog
                              ? (navService.avoidanceDirection == 'left'
                                  ? "LUMIPAT SA KALIWA"
                                  : "LUMIPAT SA KANAN")
                              : (navService.avoidanceDirection == 'left'
                                  ? "MOVE TO YOUR LEFT"
                                  : "MOVE TO YOUR RIGHT"),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (navService.avoidanceDirection == 'right') ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                        ],
                      ],
                    ),
                  ),
                ] else if (!isDoorOrSafe && navService.avoidanceDirection == 'center') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.pan_tool_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          isTagalog ? "HUMINTO AT TUMABI" : "STOP & STEP ASIDE",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isCritical
                          ? Colors.red.shade900
                          : (isCaution ? Colors.orange.shade900 : Colors.green.shade900),
                      side: BorderSide(
                        color: isCritical
                            ? Colors.red.shade300
                            : (isCaution ? Colors.orange.shade300 : Colors.green.shade400),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _clearHazardAlert,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(
                      isTagalog ? "I-dismiss" : "Dismiss Warning",
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green.shade700,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTagalog ? "Ligtas ang Daan • AI Monitoring" : "Path Clear • AI Radar Active",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isTagalog
                                ? "Kasalukuyang sinusuri ang iyong paligid para sa anumang panganib."
                                : "Real-time AI vision is actively scanning your path for hazards.",
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }


  // ── OVERLAY CONTENT 3: Final Map view (Destination Arrived) ────────
  Widget _buildFullMapDirectionContent() {
    if (_selectedPlace == null) return _buildInitialSearchContent();
    final lang = SettingsService().selectedLanguage;
    final isTagalog = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
    final placeName = _selectedPlace!['name'] as String? ?? (isTagalog ? 'Patutunguhan' : 'Destination');
    final placeAddr = _selectedPlace!['address'] as String? ?? '';
    final isDark = SettingsService().isDarkMode || (SettingsService().selectedContrastTheme != 'Default' && SettingsService().selectedContrastTheme != 'Black on White');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Container(
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.primaryText.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Success Icon Badge
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? const Color(0xFF10B981).withValues(alpha: 0.2)
                : const Color(0xFFD1FAE5),
            border: Border.all(
              color: isDark ? const Color(0xFF34D399) : const Color(0xFF10B981),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.check_circle_rounded,
            color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
            size: 32,
          ),
        ),
        const SizedBox(height: 12),

        // Arrived Headline
        Text(
          isTagalog ? 'Nakarating Ka Na!' : 'You Have Arrived!',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 6),

        // Destination Name
        Text(
          placeName,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        if (placeAddr.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              placeAddr,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.3,
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Reached Status Badge (High contrast in Default & Dark themes)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF065F46).withValues(alpha: 0.4)
                : const Color(0xFFD1FAE5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF34D399) : const Color(0xFF10B981),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isTagalog ? '0 m • Nakarating Na' : '0 m • Destination Reached',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Done Action Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryButton,
              foregroundColor: AppColors.primaryButtonText,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            ),
            onPressed: _cancelNavigation,
            child: Text(
              TranslationService.translate('Done', lang),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
