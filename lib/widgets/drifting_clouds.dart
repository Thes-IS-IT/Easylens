import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Fluffy, aesthetic cloud data model for continuous right-to-left drifting.
class _CloudModel {
  double progress; // 0.0 (Right edge) to 1.0 (Left edge)
  final double speed; // Progress increment per second
  final double yOffset; // Vertical offset in pixels
  final double scale;
  final double opacity;
  final Color tintColor;

  _CloudModel({
    required this.progress,
    required this.speed,
    required this.yOffset,
    required this.scale,
    required this.opacity,
    required this.tintColor,
  });
}

/// DriftingCloudsWidget creates animated, semi-transparent grey clouds
/// that move and loop continuously from Right to Left across the top header.
/// Overlays gracefully over the text and mascot, and smoothly fades out on login success.
class DriftingCloudsWidget extends StatefulWidget {
  final bool isVisible;
  final double height;

  const DriftingCloudsWidget({
    super.key,
    this.isVisible = true,
    this.height = 260.0,
  });

  @override
  State<DriftingCloudsWidget> createState() => _DriftingCloudsWidgetState();
}

class _DriftingCloudsWidgetState extends State<DriftingCloudsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  DateTime _lastTime = DateTime.now();

  late final List<_CloudModel> _clouds;

  @override
  void initState() {
    super.initState();

    // 4 diverse, organic grey clouds with staggered starting points and speeds
    _clouds = [
      _CloudModel(
        progress: 0.10, // Near right/center
        speed: 0.032,
        yOffset: 18.0,
        scale: 1.15,
        opacity: 0.38,
        tintColor: const Color(0xFF94A3B8), // Slate grey
      ),
      _CloudModel(
        progress: 0.55, // Mid-screen
        speed: 0.045,
        yOffset: 55.0,
        scale: 0.85,
        opacity: 0.30,
        tintColor: const Color(0xFF64748B), // Medium cool grey
      ),
      _CloudModel(
        progress: 0.80, // Near left
        speed: 0.024,
        yOffset: 95.0,
        scale: 1.35,
        opacity: 0.34,
        tintColor: const Color(0xFFA0AEC0), // Soft fog grey
      ),
      _CloudModel(
        progress: 0.35,
        speed: 0.038,
        yOffset: 38.0,
        scale: 0.70,
        opacity: 0.25,
        tintColor: const Color(0xFFCBD5E1), // Light silver grey
      ),
    ];

    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _ticker.addListener(_updateClouds);
    _lastTime = DateTime.now();
  }

  void _updateClouds() {
    final now = DateTime.now();
    final dt = now.difference(_lastTime).inMicroseconds / 1000000.0;
    _lastTime = now;

    if (!mounted || !widget.isVisible) return;

    setState(() {
      for (final cloud in _clouds) {
        cloud.progress += cloud.speed * dt;
        if (cloud.progress >= 1.0) {
          cloud.progress -= 1.0; // Loop seamlessly back to the right
        }
      }
    });
  }

  @override
  void dispose() {
    _ticker.removeListener(_updateClouds);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      child: IgnorePointer(
        child: SizedBox(
          width: double.infinity,
          height: widget.height,
          child: CustomPaint(
            painter: _CloudPainter(clouds: _clouds),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter rendering smooth, puffy grey cloud clusters with soft volume shading
class _CloudPainter extends CustomPainter {
  final List<_CloudModel> clouds;

  _CloudPainter({required this.clouds});

  @override
  void paint(Canvas canvas, Size size) {
    for (final cloud in clouds) {
      final cloudWidth = 160.0 * cloud.scale;
      // Moving from Right to Left:
      // progress == 0.0 -> x is off-screen on the right (size.width + cloudWidth)
      // progress == 1.0 -> x is off-screen on the left (-cloudWidth)
      final totalDistance = size.width + cloudWidth * 2;
      final x = size.width + cloudWidth - (cloud.progress * totalDistance);
      final y = cloud.yOffset;

      _drawSingleCloud(
        canvas,
        Offset(x, y),
        cloud.scale,
        cloud.opacity,
        cloud.tintColor,
      );
    }
  }

  void _drawSingleCloud(
    Canvas canvas,
    Offset position,
    double scale,
    double opacity,
    Color tintColor,
  ) {
    final paint = Paint()
      ..color = tintColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.45)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    final cx = position.dx;
    final cy = position.dy;

    // Cloud Cluster Geometry (Puffy overlapping circles)
    final rCenter = 28.0 * scale;
    final rLeft = 20.0 * scale;
    final rRight = 22.0 * scale;
    final rFarLeft = 14.0 * scale;
    final rFarRight = 16.0 * scale;

    // 1. Base Grey Cloud Body
    canvas.drawCircle(Offset(cx, cy), rCenter, paint);
    canvas.drawCircle(Offset(cx - 22 * scale, cy + 6 * scale), rLeft, paint);
    canvas.drawCircle(Offset(cx + 24 * scale, cy + 5 * scale), rRight, paint);
    canvas.drawCircle(Offset(cx - 40 * scale, cy + 12 * scale), rFarLeft, paint);
    canvas.drawCircle(Offset(cx + 42 * scale, cy + 10 * scale), rFarRight, paint);

    // Pill base connecting puffs smoothly
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy + 12 * scale),
        width: 90 * scale,
        height: 24 * scale,
      ),
      Radius.circular(12 * scale),
    );
    canvas.drawRRect(rect, paint);

    // 2. Soft Upper Sunlight Reflection / Fluff Rim
    canvas.drawCircle(Offset(cx - 4 * scale, cy - 6 * scale), rCenter * 0.65, highlightPaint);
    canvas.drawCircle(Offset(cx - 22 * scale, cy), rLeft * 0.6, highlightPaint);
    canvas.drawCircle(Offset(cx + 20 * scale, cy), rRight * 0.6, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) => true;
}
