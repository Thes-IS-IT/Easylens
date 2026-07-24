import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Central route builder providing standard and custom epic transitions.
/// - [AppRoute.to]: Standard slide-up + fade transition
/// - [AppRoute.splitDoor]: Double-door opening split transition (for SignUp / Account Creation)
/// - [AppRoute.rocketLaunch]: Thruster fire rocket launch-off transition (for Login / Dashboard entry)
class AppRoute {
  AppRoute._();

  /// Standard slide-up + fade page route builder.
  static PageRouteBuilder<T> to<T>(Widget screen) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.0, 0.06),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));

        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
        ));

        final scaleOutAnimation = Tween<double>(
          begin: 1.0,
          end: 0.96,
        ).animate(CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeInCubic,
        ));

        final fadeOutAnimation = Tween<double>(
          begin: 1.0,
          end: 0.85,
        ).animate(CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeIn,
        ));

        return FadeTransition(
          opacity: fadeOutAnimation,
          child: ScaleTransition(
            scale: scaleOutAnimation,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(
                position: slideAnimation,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  /// 🚪 EPIC DOUBLE-DOOR SPLIT TRANSITION
  /// Used when navigating to Account Creation / SignUp.
  /// The screen splits down the center like double doors sliding open,
  /// revealing the incoming screen with a neon golden beam opening in the middle!
  static PageRouteBuilder<T> splitDoor<T>(Widget screen) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 750),
      reverseTransitionDuration: const Duration(milliseconds: 550),
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Curve for opening doors
        final doorCurve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        );

        // Slide left door panel to left (-1.0 offset)
        final leftDoorSlide = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-1.0, 0.0),
        ).animate(doorCurve);

        // Slide right door panel to right (+1.0 offset)
        final rightDoorSlide = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(1.0, 0.0),
        ).animate(doorCurve);

        // Incoming screen zooms in from center
        final incomingScale = Tween<double>(
          begin: 0.85,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
        ));

        final incomingFade = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: const Interval(0.15, 0.8, curve: Curves.easeIn),
        ));

        // Light beam width expands in center
        final beamOpacity = Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
        ));

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Incoming Screen (zooming in behind the opening doors)
            FadeTransition(
              opacity: incomingFade,
              child: ScaleTransition(
                scale: incomingScale,
                child: child,
              ),
            ),

            // 2. Left Door Panel (slides Left)
            SlideTransition(
              position: leftDoorSlide,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.5,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F2042),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFFFD700),
                          blurRadius: 15,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF001233),
                                  const Color(0xFF0A2540),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                        ),
                        // Metallic vertical seam border
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            width: 3,
                            color: const Color(0xFFFFD700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Right Door Panel (slides Right)
            SlideTransition(
              position: rightDoorSlide,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 0.5,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F2042),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFFFD700),
                          blurRadius: 15,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF0A2540),
                                  const Color(0xFF001233),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                        ),
                        // Metallic vertical seam border
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 3,
                            color: const Color(0xFFFFD700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 4. Center Glowing Seam Laser Flare
            Positioned.fill(
              child: FadeTransition(
                opacity: beamOpacity,
                child: Center(
                  child: Container(
                    width: 4,
                    height: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFFFD700),
                          blurRadius: 25,
                          spreadRadius: 10,
                        ),
                        BoxShadow(
                          color: Color(0xFF3B82F6),
                          blurRadius: 40,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 🚀 EPIC ROCKET LAUNCH-OFF TRANSITION WITH ANIMATED FIRE
  /// Used upon successful Login or Dashboard entry.
  /// The outgoing screen shakes, ignites thrusters with real-time animated fire,
  /// and launches off vertically into space as the incoming dashboard arrives!
  static PageRouteBuilder<T> rocketLaunch<T>(Widget screen) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 950),
      reverseTransitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Rocket launch acceleration curve
        final launchCurve = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.15, 1.0, curve: Curves.easeInCubic),
        );

        // Incoming screen warp scale
        final incomingScale = Tween<double>(
          begin: 0.70,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
        ));

        final incomingFade = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: const Interval(0.25, 0.75, curve: Curves.easeIn),
        ));

        // Screen launch upward movement
        final launchSlide = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0.0, -1.4),
        ).animate(launchCurve);

        // Fire & Thruster opacity control
        final fireOpacity = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: const Interval(0.05, 0.4, curve: Curves.easeIn),
        ));

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Incoming Destination Screen (Dashboard)
            FadeTransition(
              opacity: incomingFade,
              child: ScaleTransition(
                scale: incomingScale,
                child: child,
              ),
            ),

            // 2. Animated Thruster Fire Canvas Overlay
            AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final rumbleOffset = math.sin(animation.value * 50) * (1.0 - animation.value) * 6.0;
                return Positioned.fill(
                  child: SlideTransition(
                    position: launchSlide,
                    child: Transform.translate(
                      offset: Offset(rumbleOffset, 0),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Top/Main launching content card simulation
                          Positioned.fill(
                            child: FadeTransition(
                              opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
                                ),
                              ),
                              child: Container(
                                color: Colors.transparent,
                              ),
                            ),
                          ),

                          // Bottom Thruster Flame Exhaust
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: -180,
                            height: 320,
                            child: FadeTransition(
                              opacity: fireOpacity,
                              child: CustomPaint(
                                painter: _RocketFirePainter(progress: animation.value),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// CustomPainter that renders animated thruster flames, fiery sparks, glowing embers,
/// and intense launch exhaust for the rocket launch transition.
class _RocketFirePainter extends CustomPainter {
  final double progress;

  _RocketFirePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, 40);
    final width = size.width;

    // 1. Intense Outer Golden Blast Radial Glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD700).withValues(alpha: 0.9),
          const Color(0xFFFF5722).withValues(alpha: 0.7),
          const Color(0xFFFF1744).withValues(alpha: 0.4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: width * 0.7));
    canvas.drawCircle(center, width * 0.65, glowPaint);

    // 2. Thruster Flame Cones
    final rand = math.Random((progress * 100).toInt());
    final flicker = math.sin(progress * math.pi * 20) * 12.0;

    // Central Flame Cone
    final mainFlamePath = Path()
      ..moveTo(center.dx - 90, 0)
      ..quadraticBezierTo(center.dx - 45, 120 + flicker, center.dx, 260 + flicker * 1.5)
      ..quadraticBezierTo(center.dx + 45, 120 + flicker, center.dx + 90, 0)
      ..close();

    final mainFlamePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFFFEA00),
          Color(0xFFFF6D00),
          Color(0xFFD50000),
          Colors.transparent,
        ],
        stops: [0.0, 0.2, 0.5, 0.85, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, width, 280));
    canvas.drawPath(mainFlamePath, mainFlamePaint);

    // Side Booster Flames (Left & Right)
    for (int i = -1; i <= 1; i += 2) {
      final sideX = center.dx + (i * width * 0.28);
      final sideFlamePath = Path()
        ..moveTo(sideX - 40, 0)
        ..quadraticBezierTo(sideX, 90 + flicker, sideX + 40, 0)
        ..close();

      final sideFlamePaint = Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFAB00),
            Color(0xFFFF3D00),
            Colors.transparent,
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(sideX - 40, 0, 80, 180));
      canvas.drawPath(sideFlamePath, sideFlamePaint);
    }

    // 3. Flying Spark Particles & Embers
    final sparkPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 35; i++) {
      final sparkX = center.dx + (rand.nextDouble() - 0.5) * width * 0.8;
      final sparkY = 50 + rand.nextDouble() * 220 + (progress * 100);
      final sparkRadius = 2.0 + rand.nextDouble() * 4.5;
      final sparkAlpha = (1.0 - (sparkY / 300)).clamp(0.0, 1.0);

      sparkPaint.color = i % 2 == 0
          ? Color(0xFFFFD700).withValues(alpha: sparkAlpha)
          : Color(0xFFFF3D00).withValues(alpha: sparkAlpha);

      canvas.drawCircle(Offset(sparkX, sparkY), sparkRadius, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RocketFirePainter oldDelegate) => true;
}
