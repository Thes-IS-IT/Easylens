import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../constants/colors.dart';

/// Interactive 3D Gyroscopic Logo Widget for Buddy.
/// Responds to physical device tilt (gyroscope/accelerometer) and finger touch pan
/// with smooth 3D perspective rotation, dynamic specular glare, and responsive parallax shadow.
class Gyro3dLogo extends StatefulWidget {
  final double size;
  final String imageAsset;
  final VoidCallback? onTap;

  const Gyro3dLogo({
    super.key,
    this.size = 170.0,
    this.imageAsset = 'assets/mascots/app_logo.png',
    this.onTap,
  });

  @override
  State<Gyro3dLogo> createState() => _Gyro3dLogoState();
}

class _Gyro3dLogoState extends State<Gyro3dLogo> with SingleTickerProviderStateMixin {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  late AnimationController _tickerController;

  // Normalized tilt angles (-1.0 to 1.0)
  double _targetTiltX = 0.0;
  double _targetTiltY = 0.0;
  double _currentTiltX = 0.0;
  double _currentTiltY = 0.0;

  bool _isUserDragging = false;
  double _idlePhase = 0.0;

  @override
  void initState() {
    super.initState();

    // 1. Setup smooth 60fps interpolation ticker
    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _tickerController.addListener(_onTick);

    // 2. Subscribe to accelerometer for natural phone tilt detection
    _startSensorListener();
  }

  void _startSensorListener() {
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (AccelerometerEvent event) {
          if (_isUserDragging || !mounted) return;
          // Normal phone orientation:
          // event.x is roll (-9.8 to 9.8) -> tilts Y axis
          // event.y is pitch (9.8 when flat, ~5 when held at 45 deg, 0 when vertical)
          final roll = (event.x / 5.0).clamp(-1.0, 1.0);
          final pitch = ((event.y - 5.0) / 5.0).clamp(-1.0, 1.0);

          setState(() {
            _targetTiltX = roll;
            _targetTiltY = -pitch;
          });
        },
        onError: (_) {
          // Graceful fallback for devices/simulators without accelerometer
        },
        cancelOnError: false,
      );
    } catch (_) {}
  }

  void _onTick() {
    if (!mounted) return;

    // Subtle natural breathing if phone is completely stationary
    _idlePhase += 0.03;
    final idleOffsetX = math.sin(_idlePhase) * 0.08;
    final idleOffsetY = math.cos(_idlePhase * 0.8) * 0.08;

    final targetX = _targetTiltX + (_isUserDragging ? 0 : idleOffsetX);
    final targetY = _targetTiltY + (_isUserDragging ? 0 : idleOffsetY);

    // Exponential smoothing filter (alpha = 0.14) for liquid-smooth response
    const alpha = 0.14;
    final newX = _currentTiltX + (targetX - _currentTiltX) * alpha;
    final newY = _currentTiltY + (targetY - _currentTiltY) * alpha;

    if ((newX - _currentTiltX).abs() > 0.0005 || (newY - _currentTiltY).abs() > 0.0005) {
      setState(() {
        _currentTiltX = newX;
        _currentTiltY = newY;
      });
    }
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _tickerController.removeListener(_onTick);
    _tickerController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _isUserDragging = true;
    final half = widget.size / 2;
    final localX = (details.localPosition.dx - half) / half;
    final localY = (details.localPosition.dy - half) / half;

    setState(() {
      _targetTiltX = localX.clamp(-1.0, 1.0);
      _targetTiltY = -localY.clamp(-1.0, 1.0);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _isUserDragging = false;
    setState(() {
      _targetTiltX = 0.0;
      _targetTiltY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final rotY = _currentTiltX * 0.32; // Maximum ~18 degrees tilt
    final rotX = -_currentTiltY * 0.32;
    final parallaxX = _currentTiltX * 10.0;
    final parallaxY = _currentTiltY * 10.0;

    return GestureDetector(
      onTap: widget.onTap,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Center(
        child: SizedBox(
          width: size + 30,
          height: size + 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Dynamic 3D Perspective Container
              Transform(
                alignment: FractionalOffset.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0014) // Depth perspective
                  ..rotateX(rotX)
                  ..rotateY(rotY)
                  ..translate(parallaxX, -parallaxY, 0.0),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0F3E8F), // Premium Royal Blue
                        Color(0xFF001F52), // Deep Navy
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32.0),
                    boxShadow: [
                      // Deep ground shadow moving dynamically opposite to tilt
                      BoxShadow(
                        color: AppColors.primaryText.withValues(alpha: 0.22),
                        blurRadius: 26.0 + (_currentTiltX.abs() + _currentTiltY.abs()) * 8.0,
                        offset: Offset(-_currentTiltX * 22.0, 14.0 - _currentTiltY * 18.0),
                      ),
                      // Soft ambient aura
                      BoxShadow(
                        color: const Color(0xFF1E40AF).withValues(alpha: 0.25),
                        blurRadius: 18.0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Mascot App Logo
                      Image.asset(
                        widget.imageAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (context, err, st) => const Icon(
                          Icons.pets,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),

                      // 2. Dynamic Specular Light Glare Sweep
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment(
                                  -_currentTiltX * 1.6,
                                  -_currentTiltY * 1.6,
                                ),
                                radius: 0.9,
                                colors: [
                                  Colors.white.withValues(alpha: 0.35),
                                  Colors.white.withValues(alpha: 0.08),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.45, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 3. Subtle Glass Edge Rim Light
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32.0),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 1.2,
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
      ),
    );
  }
}
