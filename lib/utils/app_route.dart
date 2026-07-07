import 'package:flutter/material.dart';

/// Central route builder with a premium slide-up + fade transition.
/// Use [AppRoute.to] everywhere instead of MaterialPageRoute.
class AppRoute {
  AppRoute._();

  static PageRouteBuilder<T> to<T>(Widget screen) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slide up from 6% below + fade in
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

        // Outgoing screen scales down very slightly and fades
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
}
