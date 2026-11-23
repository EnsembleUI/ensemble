import 'dart:typed_data';

import 'package:ensemble/framework/tv/apple_tv.dart';
import 'package:ensemble/framework/tv/apple_tv_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Apple TV scrolling must match Android TV: lists clamp, and the tvOS focus
/// engine can't move them through semantics actions (it did, in 0.5 px steps,
/// on a Sports lane: a visible jerk). Other platforms keep their default.

class _Lane {
  _Lane(this.controller, this.cards);
  final ScrollController controller;
  final List<GlobalKey> cards;
}

/// A page with one horizontal lane of labelled cards, under [behavior]
/// (what EnsembleApp passes to its MaterialApp).
Future<_Lane> _pumpLane(
  WidgetTester tester, {
  ScrollBehavior? behavior,
  ScrollPhysics? physics,
  int cards = 12,
  bool external = false,
}) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  final keys = [for (var i = 0; i < cards; i++) GlobalKey()];
  // An external screen sits on the host app's navigator: the host's
  // MaterialApp has no Ensemble scroll behavior, and Ensemble wraps the
  // screen itself.
  Widget screen(Widget body) =>
      external ? withAppleTVScrollBehavior(body) : body;
  await tester.pumpWidget(MaterialApp(
    scrollBehavior: external ? null : behavior,
    home: screen(Scaffold(
      body: SizedBox(
        height: 200,
        child: ListView(
          controller: controller,
          physics: physics,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 48),
          children: [
            for (var i = 0; i < cards; i++)
              SizedBox(
                key: keys[i],
                width: 215,
                child: Text('card $i'),
              ),
          ],
        ),
      ),
    )),
  ));
  return _Lane(controller, keys);
}

SemanticsOwner _owner(WidgetTester tester) =>
    tester.binding.renderViews.first.owner!.semanticsOwner!;

/// Ids of nodes that offer [action].
List<int> _nodesWith(WidgetTester tester, SemanticsAction action) {
  final ids = <int>[];
  void visit(SemanticsNode node) {
    if (node.getSemanticsData().hasAction(action)) ids.add(node.id);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(_owner(tester).rootSemanticsNode!);
  return ids;
}

/// What the tvOS focus engine does: ask a scrollable to jump to an offset.
Future<void> _engineScrollToOffset(WidgetTester tester, double x) async {
  for (final id in _nodesWith(tester, SemanticsAction.scrollToOffset)) {
    _owner(tester).performAction(
      id,
      SemanticsAction.scrollToOffset,
      Float64List.fromList([x, 0]),
    );
  }
  await tester.pumpAndSettle();
}

/// What the tvOS focus engine does: ask for a node to be brought on screen.
Future<void> _engineShowOnScreen(WidgetTester tester, String label) async {
  final node = tester.getSemantics(find.text(label));
  _owner(tester).performAction(node.id, SemanticsAction.showOnScreen);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => debugIsAppleTVOverride = null);

  group('Apple TV', () {
    setUp(() => debugIsAppleTVOverride = true);

    test('Ensemble apps get the Apple TV scroll behavior', () {
      expect(appleTVScrollBehavior, isA<AppleTVScrollBehavior>());
    });

    testWidgets('lists clamp instead of bouncing', (tester) async {
      final lane = await _pumpLane(tester, behavior: appleTVScrollBehavior);
      final position = lane.controller.position;

      // Clamping stops an overshoot past the end; bouncing returns 0.
      final overshoot = position.physics.applyBoundaryConditions(
        position,
        position.maxScrollExtent + 50,
      );
      expect(overshoot, 50);
    });

    testWidgets('the focus engine gets no scroll action on a lane',
        (tester) async {
      final handle = tester.ensureSemantics();
      final lane = await _pumpLane(tester, behavior: appleTVScrollBehavior);

      expect(lane.controller.position.physics.allowImplicitScrolling, isFalse);
      expect(_nodesWith(tester, SemanticsAction.scrollToOffset), isEmpty);
      handle.dispose();
    });

    testWidgets('a focus-engine scroll request does not move the lane',
        (tester) async {
      // The jerk: the engine jumped a lane in small steps.
      final handle = tester.ensureSemantics();
      final lane = await _pumpLane(tester, behavior: appleTVScrollBehavior);

      await _engineScrollToOffset(tester, 300);

      expect(lane.controller.offset, 0);
      handle.dispose();
    });

    testWidgets('a focus-engine show-on-screen does not move the lane',
        (tester) async {
      final handle = tester.ensureSemantics();
      final lane = await _pumpLane(tester, behavior: appleTVScrollBehavior);

      await _engineShowOnScreen(tester, 'card 3');

      expect(lane.controller.offset, 0);
      handle.dispose();
    });

    testWidgets('Ensemble can still scroll the lane itself', (tester) async {
      final lane = await _pumpLane(tester, behavior: appleTVScrollBehavior);

      await Scrollable.ensureVisible(lane.cards[3].currentContext!);
      await tester.pumpAndSettle();
      expect(lane.controller.offset, greaterThan(0));

      lane.controller.jumpTo(100);
      expect(lane.controller.offset, 100);
    });

    testWidgets('lists with their own physics are covered too', (tester) async {
      final handle = tester.ensureSemantics();
      final lane = await _pumpLane(
        tester,
        behavior: appleTVScrollBehavior,
        physics: appleTVScrollPhysics(const AlwaysScrollableScrollPhysics()),
      );
      final physics = lane.controller.position.physics;

      expect(physics.allowImplicitScrolling, isFalse);
      expect(physics.allowUserScrolling, isTrue);
      expect(_nodesWith(tester, SemanticsAction.scrollToOffset), isEmpty);
      handle.dispose();
    });

    testWidgets('with VoiceOver on, the system can still scroll lists',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final handle = tester.ensureSemantics();
      final lane = await _pumpLane(tester, behavior: appleTVScrollBehavior);

      expect(lane.controller.position.physics.allowImplicitScrolling, isTrue);
      await _engineScrollToOffset(tester, 300);
      expect(lane.controller.offset, 300);
      handle.dispose();
    });

    testWidgets('screens on the host app\'s navigator are covered too',
        (tester) async {
      // Sports' tournament page (asExternal): the engine jumped its list to
      // twice its scroll range.
      final handle = tester.ensureSemantics();
      final lane = await _pumpLane(tester, external: true);
      final physics = lane.controller.position.physics;

      expect(physics.allowImplicitScrolling, isFalse);
      expect(
          physics.applyBoundaryConditions(lane.controller.position,
              lane.controller.position.maxScrollExtent + 50),
          50);
      await _engineScrollToOffset(tester, 300);
      expect(lane.controller.offset, 0);
      handle.dispose();
    });

    test('no physics stays null so the app default applies', () {
      expect(appleTVScrollPhysics(null), isNull);
    });
  });

  group('Android TV and other platforms', () {
    setUp(() => debugIsAppleTVOverride = false);

    test('no scroll behavior is set, so the platform default applies', () {
      expect(appleTVScrollBehavior, isNull);
    });

    test('explicit physics are returned unchanged', () {
      const physics = AlwaysScrollableScrollPhysics();
      expect(identical(appleTVScrollPhysics(physics), physics), isTrue);
    });

    testWidgets('lists keep the platform default, including accessibility',
        (tester) async {
      final handle = tester.ensureSemantics();
      final lane = await _pumpLane(tester, behavior: appleTVScrollBehavior);

      expect(lane.controller.position.physics.allowImplicitScrolling, isTrue);
      expect(_nodesWith(tester, SemanticsAction.scrollToOffset), isNotEmpty);
      // TalkBack must still be able to scroll lanes.
      await _engineScrollToOffset(tester, 300);
      expect(lane.controller.offset, 300);
      handle.dispose();
    });

    testWidgets('screens on the host app\'s navigator are unchanged',
        (tester) async {
      final handle = tester.ensureSemantics();
      final lane = await _pumpLane(tester, external: true);

      expect(lane.controller.position.physics.allowImplicitScrolling, isTrue);
      await _engineScrollToOffset(tester, 300);
      expect(lane.controller.offset, 300);
      handle.dispose();
    });

    testWidgets('show-on-screen still scrolls the lane, as today',
        (tester) async {
      final handle = tester.ensureSemantics();
      final lane = await _pumpLane(tester, behavior: appleTVScrollBehavior);

      await _engineShowOnScreen(tester, 'card 3');

      expect(lane.controller.offset, greaterThan(0));
      handle.dispose();
    });
  });
}
