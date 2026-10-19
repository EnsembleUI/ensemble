import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/widget/carousel.dart' as ensemble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'test_utils.dart';

/// Rapid D-pad navigation on TV must always move the carousel in the direction
/// of the pressed key, including at the loop boundary.
///
/// Ensemble publishes the reported slide index from `onPageChanged`, which the
/// pager fires while the previous slide is still animating (at the page's
/// halfway point). A press arriving in that window used to be routed through
/// `animateToPage(0)` / `animateToPage(last)`: `carousel_slider` resolves an
/// absolute target from the *fractional* physical page (`page.toInt()`) plus a
/// closest-route search, so the wrap to the first slide could animate
/// backwards through the slide that was already passed (device trace: one RIGHT
/// press at the loop point producing the index sequence 2 -> 1 -> 0).
///
/// `nextPage()` / `previousPage()` derive their target from `page.round() +- 1`
/// and therefore always step in the requested direction, whatever the pager is
/// doing when the press arrives.
void main() {
  setUp(() => Device.debugOverrideIsTV(true));
  tearDown(() => Device.debugOverrideIsTV(null));

  /// A slide with one focusable control, the shape of the app's hero button.
  String slideTemplate() => '''
data: \${items}
name: item
indexId: idx
template:
  Stack:
    styles:
      height: 400
      alignChildren: topLeft
    children:
      - Row:
          styles:
            mainAxis: start
            padding: 0 0 0 51
          children:
            - Row:
                id: slideControl
                onTap:
                  navigateBack:
                styles:
                  width: 260
                  height: 60
                  tvOptions:
                    row: 0
                    order: \${idx}
                children:
                  - Text:
                      text: '\${item}'
''';

  ensemble.Carousel makeCarousel({
    required YamlMap itemTemplate,
    String layout = 'single',
    bool enableLoop = false,
    bool autoplay = false,
    int? autoplayInterval,
  }) {
    final carousel = ensemble.Carousel();
    carousel.setProperty('layout', layout);
    carousel.setProperty('height', 400);
    carousel.setProperty('enableLoop', enableLoop);
    carousel.setProperty('autoplay', autoplay);
    if (autoplayInterval != null) {
      carousel.setProperty('autoplayInterval', autoplayInterval);
    }
    carousel.setProperty('tvOptions', {
      'interceptHorizontalNav': true,
      'pauseAutoplayOnFocus': true,
      'restoreFocusOnPageChange': true,
    });
    carousel.initChildren(itemTemplate: itemTemplate);
    return carousel;
  }

  Widget host(Widget child) =>
      TestUtils.wrapTestWidgetWithScope(Builder(builder: (context) {
        DataScopeWidget.getScope(context)!
            .dataContext
            .addDataContextById('items', const ['first', 'second', 'third']);
        return child;
      }));

  void useTestViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// The carousel's own `PageView` scrollable, identified by its page metrics.
  ScrollableState pagerScrollable(WidgetTester tester) {
    for (final element in find.byType(Scrollable).evaluate()) {
      final state = (element as StatefulElement).state;
      if (state is ScrollableState && state.position is PageMetrics) {
        return state;
      }
    }
    throw StateError('carousel PageView is not scrollable');
  }

  double displayedPage(ScrollableState pager) =>
      (pager.position as PageMetrics).page!;

  double pageAlignmentError(ScrollableState pager) {
    final page = displayedPage(pager);
    return (page - page.roundToDouble()).abs();
  }

  /// Frames whose page sample moved against the requested direction.
  int stepsAgainst(List<double> samples, {required bool forward}) {
    var count = 0;
    for (var i = 1; i < samples.length; i++) {
      final delta = samples[i] - samples[i - 1];
      if (forward ? delta < -1e-6 : delta > 1e-6) count++;
    }
    return count;
  }

  /// Focus a slide control, as the app does when the hero is reached.
  void focusFirstControl(WidgetTester tester) {
    final nodes = find.ancestor(
      of: find.text('first'),
      matching: find.byType(InkWell),
    );
    tester
        .widgetList<InkWell>(nodes)
        .firstWhere((inkWell) => inkWell.focusNode != null)
        .focusNode!
        .requestFocus();
  }

  bool _isDescendantOf(Element element, Element ancestor) {
    var found = false;
    element.visitAncestorElements((candidate) {
      if (candidate == ancestor) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  /// True while focus is still inside the carousel (focus restoration must not
  /// push focus out of the hero).
  bool focusInsideCarousel(WidgetTester tester) {
    final primary = FocusManager.instance.primaryFocus;
    final context = primary?.context;
    if (context == null) return false;
    final carouselElement = tester.element(find.byType(ensemble.Carousel));
    return _isDescendantOf(context as Element, carouselElement);
  }

  /// Presses a D-pad key without letting the previous animation settle.
  Future<void> tapKey(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyUpEvent(key);
  }

  /// Samples the displayed page every 8 ms of animation time.
  Future<List<double>> pumpFrames(
      WidgetTester tester, ScrollableState pager, int frames) async {
    final samples = <double>[];
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 8));
      samples.add(displayedPage(pager));
    }
    return samples;
  }

  /// Device spacing: each press lands in the tail of the previous 300 ms slide
  /// animation (~288 ms of sampled frames per press).
  const framesPerPress = 36;

  /// The logical slide a page maps to, using the same mapping as the package.
  int logicalIndexForPage(double page, int firstPage) =>
      ((page.round() - firstPage) % 3 + 3) % 3;

  testWidgets('rapid D-pad RIGHT at the loop point never moves the pager '
      'backwards', (tester) async {
    useTestViewport(tester);

    final carousel = makeCarousel(
      itemTemplate: loadYaml(slideTemplate()),
      enableLoop: true,
    );
    await tester.pumpWidget(host(SizedBox(
      width: 1280,
      height: 400,
      child: carousel,
    )));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    final pager = pagerScrollable(tester);
    final startPage = displayedPage(pager).round();
    focusFirstControl(tester);
    await tester.pump();
    await tester.pump();

    // Five separate presses; presses 3 and 5 cross the loop point.
    var previousIndex = carousel.controller.currentIndex;
    var reportedSteps = 0;
    for (var press = 1; press <= 5; press++) {
      await tapKey(tester, LogicalKeyboardKey.arrowRight);
      final samples = await pumpFrames(tester, pager, framesPerPress);

      expect(tester.takeException(), isNull);
      expect(stepsAgainst(samples, forward: true), 0,
          reason: 'RIGHT press $press must never move the pager backwards '
              '(page samples: $samples)');
      expect(displayedPage(pager), greaterThanOrEqualTo(samples.first),
          reason: 'RIGHT press $press must not move the pager back');

      // The reported slide must never step backwards either: a wrap reports
      // 2 -> 0, never 2 -> 1 (the defect).
      final reported = carousel.controller.currentIndex;
      final delta = (reported - previousIndex + 3) % 3;
      expect(delta, isNot(2),
          reason: 'RIGHT press $press reported a backwards slide step '
              '($previousIndex -> $reported)');
      if (delta != 0) reportedSteps++;
      previousIndex = reported;
    }

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(pageAlignmentError(pager), lessThan(1e-6),
        reason: 'the pager must settle on a page boundary');
    expect(displayedPage(pager), closeTo(startPage + reportedSteps, 1e-6),
        reason: 'the settled page must match the accepted slide steps');
    expect(carousel.controller.currentIndex,
        logicalIndexForPage(displayedPage(pager), startPage),
        reason: 'the reported slide must match the displayed page');
  });

  testWidgets('rapid D-pad LEFT at the loop point never moves the pager '
      'forwards', (tester) async {
    useTestViewport(tester);

    final carousel = makeCarousel(
      itemTemplate: loadYaml(slideTemplate()),
      enableLoop: true,
    );
    await tester.pumpWidget(host(SizedBox(
      width: 1280,
      height: 400,
      child: carousel,
    )));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    final pager = pagerScrollable(tester);
    final startPage = displayedPage(pager).round();
    focusFirstControl(tester);
    await tester.pump();
    await tester.pump();

    var previousIndex = carousel.controller.currentIndex;
    var reportedSteps = 0;
    for (var press = 1; press <= 5; press++) {
      await tapKey(tester, LogicalKeyboardKey.arrowLeft);
      final samples = await pumpFrames(tester, pager, framesPerPress);

      expect(tester.takeException(), isNull);
      expect(stepsAgainst(samples, forward: false), 0,
          reason: 'LEFT press $press must never move the pager forwards '
              '(page samples: $samples)');

      final reported = carousel.controller.currentIndex;
      final delta = (previousIndex - reported + 3) % 3;
      expect(delta, isNot(2),
          reason: 'LEFT press $press reported a forward slide step '
              '($previousIndex -> $reported)');
      if (delta != 0) reportedSteps++;
      previousIndex = reported;
    }

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(pageAlignmentError(pager), lessThan(1e-6),
        reason: 'the pager must settle on a page boundary');
    expect(displayedPage(pager), closeTo(startPage - reportedSteps, 1e-6),
        reason: 'the settled page must match the accepted slide steps');
  });

  testWidgets('five well paced RIGHT presses cross the loop point and advance '
      'exactly five slides', (tester) async {
    useTestViewport(tester);

    final carousel = makeCarousel(
      itemTemplate: loadYaml(slideTemplate()),
      enableLoop: true,
    );
    await tester.pumpWidget(host(SizedBox(
      width: 1280,
      height: 400,
      child: carousel,
    )));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    final pager = pagerScrollable(tester);
    final startPage = displayedPage(pager);
    focusFirstControl(tester);
    await tester.pump();
    await tester.pump();

    // Each animation completes before the next key (device pacing, and the
    // original trace shows every press reaching the carousel in this case).
    for (var press = 1; press <= 5; press++) {
      await tapKey(tester, LogicalKeyboardKey.arrowRight);
      final samples = await pumpFrames(tester, pager, 50);
      expect(tester.takeException(), isNull);
      expect(stepsAgainst(samples, forward: true), 0);
      expect(displayedPage(pager), closeTo(startPage + press, 1e-6),
          reason: 'a settled wrap must still advance exactly one slide');
      expect(carousel.controller.currentIndex, press % 3);
    }

    // And back through the left boundary.
    for (var press = 1; press <= 3; press++) {
      await tapKey(tester, LogicalKeyboardKey.arrowLeft);
      final samples = await pumpFrames(tester, pager, 50);
      expect(tester.takeException(), isNull);
      expect(stepsAgainst(samples, forward: false), 0);
      expect(displayedPage(pager), closeTo(startPage + 5 - press, 1e-6));
    }
  });

  testWidgets('alternating RIGHT/LEFT keeps the direction of each press',
      (tester) async {
    useTestViewport(tester);

    final carousel = makeCarousel(
      itemTemplate: loadYaml(slideTemplate()),
      enableLoop: true,
    );
    await tester.pumpWidget(host(SizedBox(
      width: 1280,
      height: 400,
      child: carousel,
    )));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    final pager = pagerScrollable(tester);
    focusFirstControl(tester);
    await tester.pump();
    await tester.pump();

    const keys = [
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowLeft,
    ];
    var previousIndex = carousel.controller.currentIndex;
    for (var i = 0; i < keys.length; i++) {
      final isRight = keys[i] == LogicalKeyboardKey.arrowRight;
      await tapKey(tester, keys[i]);
      await pumpFrames(tester, pager, 31); // ~248 ms
      expect(tester.takeException(), isNull);

      // Focus traversal may consume a press before it reaches the carousel, so
      // the reported index may repeat; it must never step against the press.
      final reported = carousel.controller.currentIndex;
      final backwards = (previousIndex - reported + 3) % 3 == 1;
      final forwards = (reported - previousIndex + 3) % 3 == 1;
      expect(isRight ? !backwards : !forwards, isTrue,
          reason: 'press $i must not report a step against its direction '
              '($previousIndex -> $reported)');
      previousIndex = reported;
    }

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(pageAlignmentError(pager), lessThan(1e-6),
        reason: 'the pager must settle on a page boundary');
    expect(carousel.controller.currentIndex,
        logicalIndexForPage(displayedPage(pager), 10000),
        reason: 'the reported slide must match the displayed page');
  });

  testWidgets('non-loop carousel stops at the last slide and still advances '
      'before it', (tester) async {
    useTestViewport(tester);

    final carousel = makeCarousel(itemTemplate: loadYaml(slideTemplate()));
    await tester.pumpWidget(host(SizedBox(
      width: 1280,
      height: 400,
      child: carousel,
    )));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    final pager = pagerScrollable(tester);
    final startPage = displayedPage(pager);
    focusFirstControl(tester);
    await tester.pump();
    await tester.pump();

    for (var press = 1; press <= 2; press++) {
      await tapKey(tester, LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(displayedPage(pager), closeTo(startPage + press, 1e-6));
      expect(carousel.controller.currentIndex, press);
    }

    // At the last slide a finite carousel must not move (or throw).
    final lastPage = displayedPage(pager);
    await tapKey(tester, LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(displayedPage(pager), closeTo(lastPage, 1e-6),
        reason: 'a non-looping carousel must stay on its last slide');
    expect(carousel.controller.currentIndex, 2);
  });

  testWidgets('rapid presses keep focus inside the hero', (tester) async {
    useTestViewport(tester);

    final carousel = makeCarousel(
      itemTemplate: loadYaml(slideTemplate()),
      enableLoop: true,
    );
    await tester.pumpWidget(host(Column(children: [
      SizedBox(width: 1280, height: 400, child: carousel),
      ElevatedButton(onPressed: () {}, child: const Text('outside')),
    ])));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    final pager = pagerScrollable(tester);
    focusFirstControl(tester);
    await tester.pump();
    await tester.pump();
    expect(focusInsideCarousel(tester), isTrue);

    for (var press = 1; press <= 4; press++) {
      await tapKey(tester, LogicalKeyboardKey.arrowRight);
      final samples = await pumpFrames(tester, pager, framesPerPress);
      expect(tester.takeException(), isNull);
      expect(stepsAgainst(samples, forward: true), 0,
          reason: 'RIGHT press $press must not move the pager backwards');
      expect(focusInsideCarousel(tester), isTrue,
          reason: 'focus restoration must keep focus on the incoming slide');
    }

    await tester.pumpAndSettle();
    expect(focusInsideCarousel(tester), isTrue);
  });

  testWidgets('rapid presses with autoplay configured stay forward-only and '
      'keep autoplay paused while focused', (tester) async {
    useTestViewport(tester);

    final carousel = makeCarousel(
      itemTemplate: loadYaml(slideTemplate()),
      enableLoop: true,
      autoplay: true,
      autoplayInterval: 5,
    );
    await tester.pumpWidget(host(Column(children: [
      SizedBox(width: 1280, height: 400, child: carousel),
      ElevatedButton(onPressed: () {}, child: const Text('outside')),
    ])));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    final pager = pagerScrollable(tester);
    focusFirstControl(tester);
    await tester.pump();
    await tester.pump();

    for (var press = 1; press <= 3; press++) {
      await tapKey(tester, LogicalKeyboardKey.arrowRight);
      final samples = await pumpFrames(tester, pager, framesPerPress);
      expect(tester.takeException(), isNull);
      expect(stepsAgainst(samples, forward: true), 0,
          reason: 'RIGHT press $press must not move the pager backwards');
    }

    // pauseAutoplayOnFocus: no movement while the hero holds focus.
    final focusedPage = displayedPage(pager);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(displayedPage(pager), closeTo(focusedPage, 1e-6),
        reason: 'autoplay must stay paused while the hero has focus');
  });

  testWidgets('rapid presses on a multi-view carousel never move the pager '
      'backwards', (tester) async {
    useTestViewport(tester);

    // A multi-view carousel (pageSnapping: false) keeps several slides
    // visible, so some D-pad presses move focus between them and only a later
    // press reaches the carousel's own horizontal handler. The invariant that
    // matters for this fix is that the pager is never dragged backwards and
    // that focus stays inside the carousel.
    final carousel = makeCarousel(
      itemTemplate: loadYaml(slideTemplate()),
      layout: 'multiple',
      enableLoop: true,
    );
    await tester.pumpWidget(host(SizedBox(
      width: 1280,
      height: 400,
      child: carousel,
    )));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    final pager = pagerScrollable(tester);
    focusFirstControl(tester);
    await tester.pump();
    await tester.pump();

    for (var press = 1; press <= 6; press++) {
      await tapKey(tester, LogicalKeyboardKey.arrowRight);
      final samples = await pumpFrames(tester, pager, framesPerPress);
      expect(tester.takeException(), isNull);
      expect(stepsAgainst(samples, forward: true), 0,
          reason: 'RIGHT press $press must not move the pager backwards');
      expect(focusInsideCarousel(tester), isTrue,
          reason: 'RIGHT press $press must keep focus inside the carousel');
    }

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
