import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

extension CardAnimations on Widget {
  Widget fadeInSlideUp({
    Duration delay = const Duration(milliseconds: 0),
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return animate()
        .fadeIn(duration: duration, delay: delay)
        .slideY(begin: 0.3, end: 0, duration: duration, delay: delay);
  }

  Widget scaleIn({
    Duration delay = const Duration(milliseconds: 0),
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return animate()
        .scale(
          delay: delay,
          duration: duration,
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
          curve: Curves.easeOutCubic,
        )
        .fadeIn(delay: delay, duration: duration);
  }

  Widget staggerFadeIn({
    required int index,
    Duration baseDelay = const Duration(milliseconds: 0),
    Duration itemDelay = const Duration(milliseconds: 100),
  }) {
    return animate()
        .fadeIn(
          delay: baseDelay + (itemDelay * index),
          duration: const Duration(milliseconds: 400),
        )
        .slideY(
          begin: 0.2,
          end: 0,
          delay: baseDelay + (itemDelay * index),
          duration: const Duration(milliseconds: 400),
        );
  }
}

