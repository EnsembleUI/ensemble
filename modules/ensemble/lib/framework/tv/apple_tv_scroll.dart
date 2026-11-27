import 'package:ensemble/framework/tv/apple_tv.dart';
import 'package:flutter/material.dart';

// Scrolling on Apple TV differs from Android TV in two ways:
//
// 1. The tvOS focus engine scrolls lists by itself. flutter-tvos draws the
//    focus ring from the semantics tree, so semantics is on even without
//    VoiceOver. With semantics on, every scrollable whose physics allow
//    implicit scrolling gets a `scrollToOffset` semantics action, which jumps
//    the list (`position.jumpTo`), and `showOnScreen` may scroll it too. The
//    focus engine uses them while Ensemble's TV focus code is scrolling the
//    same list. Measured on a Sports lane that can scroll 5 px: the engine
//    moved it 11 times in 0.5 px steps, which shows as a jerk. Android TV
//    has no semantics unless TalkBack is on, so it never happens there.
//    Turning implicit scrolling off removes both. Explicit scrolling
//    (`ensureVisible`, `animateTo`) doesn't check the flag, so Ensemble's own
//    focus scrolling is unaffected.
//
// 2. Apple TV reports itself as iOS, so lists get bouncing physics. Bouncing
//    never limits the position, so an animation can overshoot an end and then
//    spring back. Android TV gets clamping physics, which TV focus scrolling
//    is built for.
//
// When VoiceOver is on, it does need to scroll lists itself, so implicit
// scrolling stays on in that case.

/// Physics that stop the tvOS focus engine from scrolling a list, unless
/// VoiceOver is on. Everything else comes from [parent].
class AppleTVScrollPhysics extends ScrollPhysics {
  const AppleTVScrollPhysics({super.parent});

  @override
  AppleTVScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      AppleTVScrollPhysics(parent: buildParent(ancestor));

  @override
  bool get allowImplicitScrolling => WidgetsBinding
      .instance.platformDispatcher.accessibilityFeatures.accessibleNavigation;
}

/// Default scroll behavior for Ensemble on Apple TV: clamping like Android
/// TV, and no focus-engine scrolling (see [AppleTVScrollPhysics]).
class AppleTVScrollBehavior extends MaterialScrollBehavior {
  const AppleTVScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const AppleTVScrollPhysics(parent: ClampingScrollPhysics());
}

/// The scroll behavior for Ensemble's apps: [AppleTVScrollBehavior] on Apple
/// TV, null (the platform default) elsewhere.
ScrollBehavior? get appleTVScrollBehavior =>
    isAppleTV ? const AppleTVScrollBehavior() : null;

/// For scrollables that set their own [physics]: those replace the default
/// from [AppleTVScrollBehavior], so wrap them to keep the focus engine out.
/// Returns [physics] unchanged outside Apple TV, and null stays null so the
/// default applies.
ScrollPhysics? appleTVScrollPhysics(ScrollPhysics? physics) =>
    isAppleTV && physics != null
        ? AppleTVScrollPhysics(parent: physics)
        : physics;

/// Applies [AppleTVScrollBehavior] to [child] on Apple TV. For screens pushed
/// on the host app's navigator (`asExternal`): they are outside Ensemble's
/// MaterialApp, so they don't get its scroll behavior. Returns [child]
/// unchanged elsewhere.
Widget withAppleTVScrollBehavior(Widget child) => isAppleTV
    ? ScrollConfiguration(behavior: const AppleTVScrollBehavior(), child: child)
    : child;
