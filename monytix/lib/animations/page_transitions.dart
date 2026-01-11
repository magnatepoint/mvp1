import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../utils/platform_utils.dart';

class PremiumPageTransitions {
  static PageRouteBuilder<T> fadeTransition<T extends Object?>(
    Widget page,
  ) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  static PageRouteBuilder<T> slideTransition<T extends Object?>(
    Widget page, {
    Offset begin = const Offset(1.0, 0.0),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: begin,
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
        );

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  static PageRoute<T> platformTransition<T extends Object?>(
    Widget page,
  ) {
    if (PlatformUtils.isIOS) {
      return CupertinoPageRoute<T>(builder: (_) => page);
    } else {
      return MaterialPageRoute<T>(
        builder: (_) => page,
        settings: RouteSettings(name: page.toStringShort()),
      );
    }
  }
}

