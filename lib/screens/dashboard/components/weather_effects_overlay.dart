import 'dart:math';
import 'package:flutter/material.dart';
import '../../../services/weather_service.dart';

/// Weather effect type determined from WMO weather codes.
enum WeatherEffect { snow, rain, lightning }

/// A full-screen overlay that displays weather-reactive particle effects
/// for 5 seconds on app start, then fades out over 800ms.
///
/// Uses [CustomPainter] for GPU-accelerated rendering — zero widget overhead.
class WeatherEffectsOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const WeatherEffectsOverlay({super.key, required this.onComplete});

  @override
  State<WeatherEffectsOverlay> createState() => _WeatherEffectsOverlayState();
}

class _WeatherEffectsOverlayState extends State<WeatherEffectsOverlay>
    with TickerProviderStateMixin {
  late AnimationController _particleController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  WeatherEffect _effect = WeatherEffect.snow;
  List<_Particle> _particles = [];
  final _random = Random();
  bool _isInitialized = false;

  // Lightning state
  double _lightningOpacity = 0.0;
  int _lightningFlashCount = 0;

  @override
  void initState() {
    super.initState();

    _particleController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.value = 1.0;

    _initWeatherEffect();
  }

  Future<void> _initWeatherEffect() async {
    // Ensure weather is fetched
    if (WeatherService().weatherCode == null) {
      await WeatherService().fetchWeather();
    }

    if (!mounted) return;

    _effect = _determineEffect();
    _generateParticles();

    setState(() {
      _isInitialized = true;
    });

    _particleController.addListener(_onTick);
    _particleController.forward().then((_) {
      if (mounted) {
        _fadeController.reverse().then((_) {
          if (mounted) widget.onComplete();
        });
      }
    });
  }

  @override
  void dispose() {
    _particleController.removeListener(_onTick);
    _particleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  WeatherEffect _determineEffect() {
    final code = WeatherService().weatherCode;
    final temp = WeatherService().currentTemp;

    // 1. Lightning: Thunderstorms (WMO 95, 96, 99)
    if (code == 95 || code == 96 || code == 99) {
      print('[WeatherEffect] Selected LIGHTNING effect for weather code $code');
      return WeatherEffect.lightning;
    }

    // 2. Rain: Rain (61-67), Rain Showers (80-82)
    if (code != null && ((code >= 61 && code <= 67) || (code >= 80 && code <= 82))) {
      print('[WeatherEffect] Selected RAIN effect for weather code $code');
      return WeatherEffect.rain;
    }

    // 3. Snow / Cold / Drizzle / Fog: Drizzle (51-57), Fog (45, 48), Snow (71-77), Snow Showers (85-86)
    if (code != null && ((code >= 51 && code <= 57) ||
        code == 45 || code == 48 ||
        (code >= 71 && code <= 77) ||
        (code >= 85 && code <= 86))) {
      print('[WeatherEffect] Selected SNOW/COLD effect for weather code $code');
      return WeatherEffect.snow;
    }

    // 4. Clear / Clouds (0-3) or unknown code: choose effect based on temperature
    if (temp != null && temp > 28) {
      print('[WeatherEffect] Selected RAIN effect (high temp $temp°C) for weather code $code');
      return WeatherEffect.rain;
    }
    print('[WeatherEffect] Selected SNOW/COLD effect for weather code $code (temp: $temp°C)');
    return WeatherEffect.snow;
  }

  void _generateParticles() {
    if (_effect == WeatherEffect.lightning) return;
    final count = _effect == WeatherEffect.snow ? 55 : 75;
    _particles = List.generate(count, (_) => _createParticle());
  }

  _Particle _createParticle() {
    switch (_effect) {
      case WeatherEffect.snow:
        return _Particle(
          x: _random.nextDouble(),
          y: _random.nextDouble() * 1.2 - 0.2,
          speed: 0.02 + _random.nextDouble() * 0.04,
          size: 4.0 + _random.nextDouble() * 7.0, // High visibility size
          wobble: _random.nextDouble() * 2 * pi,
          opacity: 0.6 + _random.nextDouble() * 0.4,
          colorIndex: _random.nextInt(3),
        );
      case WeatherEffect.rain:
        return _Particle(
          x: _random.nextDouble() * 1.3 - 0.15,
          y: _random.nextDouble() * 1.2 - 0.3,
          speed: 0.09 + _random.nextDouble() * 0.11,
          size: 16.0 + _random.nextDouble() * 24.0, // Bold line length
          wobble: 1.5 + _random.nextDouble() * 1.0,  // Stroke width
          opacity: 0.4 + _random.nextDouble() * 0.5,
          colorIndex: _random.nextInt(2),
        );
      default:
        return _Particle(x: 0, y: 0, speed: 0, size: 0, wobble: 0, opacity: 0, colorIndex: 0);
    }
  }

  void _onTick() {
    if (!mounted) return;

    const dt = 0.016; // ~60fps frame delta

    // Update particles
    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      p.y += p.speed * dt * 10;

      if (_effect == WeatherEffect.snow) {
        p.wobble += dt * 2;
        p.x += sin(p.wobble) * 0.0015;
      } else if (_effect == WeatherEffect.rain) {
        p.x += p.speed * dt * 1.5;
      }

      // Reset when off-screen
      if (p.y > 1.15 || p.x > 1.2) {
        _particles[i] = _createParticle();
        _particles[i].y = -0.08;
        if (_effect == WeatherEffect.rain) {
          _particles[i].x = _random.nextDouble() * 1.3 - 0.15;
        }
      }
    }

    // Lightning flash logic
    if (_effect == WeatherEffect.lightning) {
      final progress = _particleController.value;
      final flashPoints = [0.10, 0.32, 0.58];
      for (int i = 0; i < flashPoints.length; i++) {
        final fp = flashPoints[i];
        if (progress >= fp && progress <= fp + 0.04 && _lightningFlashCount <= i) {
          _lightningOpacity = 0.90;
          _lightningFlashCount = i + 1;
        }
      }
      if (_lightningOpacity > 0) {
        _lightningOpacity = (_lightningOpacity - dt * 3.5).clamp(0.0, 1.0);
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const SizedBox.shrink();

    return IgnorePointer(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // Frost / Atmosphere vignette border
            if (_effect == WeatherEffect.snow)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.95,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF60A5FA).withOpacity(0.08),
                        const Color(0xFF38BDF8).withOpacity(0.22),
                      ],
                      stops: const [0.5, 0.85, 1.0],
                    ),
                  ),
                ),
              ),

            if (_effect == WeatherEffect.rain)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.95,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF1E293B).withOpacity(0.12),
                        const Color(0xFF0F172A).withOpacity(0.25),
                      ],
                      stops: const [0.5, 0.85, 1.0],
                    ),
                  ),
                ),
              ),

            // Particle layer (snow or rain)
            if (_effect == WeatherEffect.snow || _effect == WeatherEffect.rain)
              Positioned.fill(
                child: CustomPaint(
                  painter: _WeatherParticlePainter(
                    particles: _particles,
                    effect: _effect,
                  ),
                ),
              ),

            // Lightning flash layer
            if (_effect == WeatherEffect.lightning && _lightningOpacity > 0)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(_lightningOpacity),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// GPU-accelerated particle painter — draws all particles with high contrast.
class _WeatherParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final WeatherEffect effect;

  const _WeatherParticlePainter({required this.particles, required this.effect});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final px = p.x * size.width;
      final py = p.y * size.height;

      if (effect == WeatherEffect.snow) {
        // High visibility snow: Soft ice-blue outer glow + crisp white core
        final outerColor = p.colorIndex == 0
            ? const Color(0xFF38BDF8) // Vibrant sky blue
            : (p.colorIndex == 1 ? const Color(0xFF60A5FA) : const Color(0xFF93C5FD));

        // Outer glow/shadow for contrast on light backgrounds
        final shadowPaint = Paint()
          ..color = outerColor.withOpacity(p.opacity * 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
        canvas.drawCircle(Offset(px, py), p.size * 0.9, shadowPaint);

        // Core flake
        final corePaint = Paint()
          ..color = Colors.white.withOpacity(p.opacity)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(px, py), p.size / 2, corePaint);
      } else if (effect == WeatherEffect.rain) {
        // High visibility rain streaks
        final rainColor = p.colorIndex == 0
            ? const Color(0xFF0284C7) // Deep sky blue
            : const Color(0xFF38BDF8); // Bright cyan blue

        // Shadow line for contrast on light background
        final shadowPaint = Paint()
          ..color = const Color(0xFF0F172A).withOpacity(p.opacity * 0.4)
          ..strokeWidth = p.wobble + 1.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(px + 1, py + 1),
          Offset(px + p.size * 0.3 + 1, py + p.size + 1),
          shadowPaint,
        );

        // Main rain streak
        final paint = Paint()
          ..color = rainColor.withOpacity(p.opacity)
          ..strokeWidth = p.wobble
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(px, py),
          Offset(px + p.size * 0.3, py + p.size),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WeatherParticlePainter oldDelegate) => true;
}

/// Simple particle data class.
class _Particle {
  double x;
  double y;
  double speed;
  double size;
  double wobble;
  double opacity;
  int colorIndex;

  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.wobble,
    required this.opacity,
    required this.colorIndex,
  });
}
