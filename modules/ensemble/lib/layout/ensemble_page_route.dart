import 'package:flutter/material.dart';

/// Route transition animations supported by Ensemble navigation.
enum PageTransitionType {
  /// Uses Flutter's platform/theme page transition for the route.
  theme,
  /// Fades the new page in without directional movement.
  fade,
  /// Slides the new page in from the right edge.
  rightToLeft,
  /// Slides the new page in from the left edge.
  leftToRight,
  /// Slides the new page in from the top edge.
  topToBottom,
  /// Slides the new page in from the bottom edge.
  bottomToTop,
  /// Scales the new page in around the configured alignment.
  scale,
  /// Rotates the new page into view during the transition.
  rotate,
  /// Reveals the new page by animating its size.
  size,
  /// Slides from right to left while fading in.
  rightToLeftWithFade,
  /// Slides from left to right while fading in.
  leftToRightWithFade,
  /// Uses a left-to-right motion for the pop transition.
  leftToRightPop,
  /// Uses a right-to-left motion for the pop transition.
  rightToLeftPop,
  /// Uses a top-to-bottom motion for the pop transition.
  topToBottomPop,
  /// Uses a bottom-to-top motion for the pop transition.
  bottomToTopPop,
}

/// Parses YAML transition names into [PageTransitionType] values.
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

/// Page route builder that presents a screen without transition animation.
class EnsemblePageRouteNoTransitionBuilder extends PageRouteBuilder {
  /// Creates a [EnsemblePageRouteNoTransitionBuilder] object.
  EnsemblePageRouteNoTransitionBuilder({
    required Widget screenWidget,
    RouteSettings? settings,
  })
      : super(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => screenWidget,
        );
}

/// Page route builder that applies Ensemble-configured transition animations.
class EnsemblePageRouteBuilder<T> extends PageRouteBuilder<T> {
  /// Widget displayed by the generated page route.
  final Widget child;
  /// Flutter transition builder used for theme-matching transitions.
  final PageTransitionsBuilder matchingBuilder;

  /// Selected transition animation for this route.
  final PageTransitionType transitionType;
  /// Animation curve applied to the route transition.
  final Curve curve;
  /// Screen alignment used to position the visual element.
  final Alignment alignment;
  /// Duration in seconds or milliseconds for a timed visual or media operation.
  final Duration duration;
  /// Duration used when the route is popped.
  final Duration reverseDuration;
  /// Build context used to find the active Ensemble scope.
  final BuildContext? context;
  /// Whether the route should capture inherited themes from the source context.
  final bool inheritTheme;

  /// Creates a [EnsemblePageRouteBuilder] object.
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
    // This field is retained for API compatibility; transitions are selected in
    // buildTransitions below. Use a stable builder so pub.dev analysis passes
    // across Flutter SDK versions.
    this.matchingBuilder = const FadeUpwardsPageTransitionsBuilder(),
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
