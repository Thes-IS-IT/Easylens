import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../services/active_navigation_service.dart';

class ConfettiOverlay extends StatefulWidget {
  final Widget child;

  const ConfettiOverlay({super.key, required this.child});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> {
  late ConfettiController _confettiController;
  bool _previousHasArrived = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    ActiveNavigationService().addListener(_onNavigationStateChanged);
  }

  @override
  void dispose() {
    ActiveNavigationService().removeListener(_onNavigationStateChanged);
    _confettiController.dispose();
    super.dispose();
  }

  void _onNavigationStateChanged() {
    final hasArrived = ActiveNavigationService().hasArrived;
    if (hasArrived && !_previousHasArrived) {
      // Trigger confetti
      _confettiController.play();
    }
    _previousHasArrived = hasArrived;
  }

  Path _drawStar(Size size) {
    // Method to convert degree to radians
    double degToRad(double deg) => deg * (pi / 180.0);

    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * cos(step),
          halfWidth + externalRadius * sin(step));
      path.lineTo(halfWidth + internalRadius * cos(step + halfDegreesPerStep),
          halfWidth + internalRadius * sin(step + halfDegreesPerStep));
    }
    path.close();
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2, // blast downwards
            maxBlastForce: 20,
            minBlastForce: 5,
            emissionFrequency: 0.05,
            numberOfParticles: 50,
            gravity: 0.1,
            createParticlePath: _drawStar, // define a custom shape/path.
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple
            ], 
          ),
        ),
      ],
    );
  }
}
