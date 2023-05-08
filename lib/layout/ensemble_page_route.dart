import 'package:flutter/material.dart';

enum PageTransitionType {
  theme,
  fade,
  rightToLeft,
  leftToRight,
  topToBottom,
  bottomToTop,
  scale,
  rotate,
  size,
  rightToLeftWithFade,
  leftToRightWithFade,
  leftToRightPop,
  rightToLeftPop,
  topToBottomPop,
  bottomToTopPop,
}

extension PageTransitionTypeX on PageTransitionType {
  static PageTransitionType? fromString(String? name) {
    if (name == null) return PageTransitionType.theme;
    switch (name) {
      case 'theme':
        return PageTransitionType.theme;
      case 'fade':
        return PageTransitionType.fade;
      case 'rightToLeft':
        return PageTransitionType.rightToLeft;
      case 'leftToRight':
        return PageTransitionType.leftToRight;
      case 'topToBottom':
        return PageTransitionType.topToBottom;
      case 'bottomToTop':
        return PageTransitionType.bottomToTop;
      case 'scale':
        return PageTransitionType.scale;
      case 'rotate':
        return PageTransitionType.rotate;
      case 'size':
        return PageTransitionType.size;
      case 'rightToLeftWithFade':
        return PageTransitionType.rightToLeftWithFade;
      case 'leftToRightWithFade':
        return PageTransitionType.leftToRightWithFade;
      case 'leftToRightPop':
        return PageTransitionType.leftToRightPop;
      case 'rightToLeftPop':
        return PageTransitionType.rightToLeftPop;
      case 'topToBottomPop':
        return PageTransitionType.topToBottomPop;
      case 'bottomToTopPop':
        return PageTransitionType.bottomToTopPop;
      default:
        return null;
    }
  }
}

class EnsemblePageRouteNoTransitionBuilder extends PageRouteBuilder {
  EnsemblePageRouteNoTransitionBuilder({required Widget screenWidget})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => screenWidget,
        );
}

class EnsemblePageRouteBuilder<T> extends PageRouteBuilder<T> {
  final Widget child;
  final PageTransitionsBuilder matchingBuilder;

  final PageTransitionType transitionType;
  final Curve curve;
  final Alignment alignment;
  final Duration duration;
  final Duration reverseDuration;
  final BuildContext? context;
  final bool inheritTheme;

  EnsemblePageRouteBuilder({
    Key? key,
    required this.child,
    required this.transitionType,
    this.context,
    this.inheritTheme = false,
    this.curve = Curves.linear,
    required this.alignment,
    this.duration = const Duration(milliseconds: 200),
    this.reverseDuration = const Duration(milliseconds: 200),
    super.fullscreenDialog = false,
    super.opaque = false,
    super.barrierColor,
    super.barrierDismissible,
    this.matchingBuilder = const CupertinoPageTransitionsBuilder(),
    RouteSettings? settings,
  }) : super(
          pageBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation) {
            return inheritTheme
                ? InheritedTheme.captureAll(context, child)
                : child;
          },
          settings: settings,
          maintainState: true,
        );

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration => reverseDuration;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    switch (transitionType) {
      case PageTransitionType.theme:
        return Theme.of(context).pageTransitionsTheme.buildTransitions(
            this, context, animation, secondaryAnimation, child);

      case PageTransitionType.fade:
        return FadeTransition(opacity: animation, child: child);

      case PageTransitionType.rightToLeft:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );

      case PageTransitionType.leftToRight:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );

      case PageTransitionType.topToBottom:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );

      case PageTransitionType.bottomToTop:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );

      case PageTransitionType.scale:
        return ScaleTransition(
          alignment: alignment,
          scale: CurvedAnimation(
            parent: animation,
            curve: Interval(0.00, 0.50, curve: curve),
          ),
          child: child,
        );

      case PageTransitionType.rotate:
        return RotationTransition(
          alignment: alignment,
          turns: animation,
          child: ScaleTransition(
            alignment: alignment,
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
        );

      case PageTransitionType.size:
        return Align(
          alignment: alignment,
          child: SizeTransition(
            sizeFactor: CurvedAnimation(parent: animation, curve: curve),
            child: child,
          ),
        );

      case PageTransitionType.rightToLeftWithFade:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                      .animate(animation),
              child: child,
            ),
          ),
        );

      case PageTransitionType.leftToRightWithFade:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: curve),
          ),
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
                      .animate(animation),
              child: child,
            ),
          ),
        );

      default:
        return FadeTransition(opacity: animation, child: child);
    }
  }
}
