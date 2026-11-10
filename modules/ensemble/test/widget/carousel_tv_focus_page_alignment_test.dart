import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/layout/scroll_view.dart' as ensemble_layout;
import 'package:ensemble/widget/carousel.dart' as ensemble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'test_utils.dart';

/// TV focus scrolling must never drive a page-snapping [PageView].
///
/// On TV, `_TapEnabledWrapper` reveals a newly focused item that is not fully
/// visible by centering it inside its nearest horizontal scrollable. Inside a
/// carousel slide that scrollable is the carousel's own `PageView`, whose
/// position accepts any pixel value for *programmatic* scrolls (page snapping
/// only constrains user drags and whole-page `animateToPage` calls). The
/// focus-derived target is therefore not a page:
///
///  * focus landing on a control of a slide that is not displayed moves the
///    carousel to a different page, and
///  * focus landing on a slide *while it is animating in* cancels that slide
///    change and reverts the carousel to the previous slide (the "hero does not
///    respond to focus" defect).
///
/// These tests pin the numeric invariant: a focus change must not move the
/// pager, an in-flight slide change must complete, and the reported index must
/// match the page actually displayed.
void main() {
  setUp(() => Device.debugOverrideIsTV(true));
  tearDown(() => Device.debugOverrideIsTV(null));

  /// A slide holding one focusable control the shape of the app's hero button:
  /// a small pill at the slide's trailing edge ([alignEnd]) or at [leftInset]
  /// from the slide's leading edge.
  String slideTemplate({
    bool alignEnd = false,
    int leftInset = 51,
    bool keepVisible = false,
    bool fixedFocusScroll = false,
  }) =>
      '''
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
            mainAxis: ${alignEnd ? 'end' : 'start'}
            padding: 0 0 0 $leftInset
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
                    order: \${idx}${keepVisible ? '\n                    scrollMode: keepVisible' : ''}${fixedFocusScroll ? '\n                    fixedFocusScroll: true\n                    fixedFocusOffset: 120' : ''}
                children:
                  - Text:
                      text: '\${item}'
''';

  ensemble.Carousel makeCarousel({
    required YamlMap itemTemplate,
    String layout = 'single',
    double? singleItemWidthRatio,
    bool interceptHorizontalNav = true,
    bool enableLoop = false,
    bool autoplay = false,
    int? autoplayInterval,
  }) {
    final carousel = ensemble.Carousel();
    carousel.setProperty('layout', layout);
    carousel.setProperty('height', 400);
    if (singleItemWidthRatio != null) {
      carousel.setProperty('singleItemWidthRatio', singleItemWidthRatio);
    }
    carousel.setProperty('enableLoop', enableLoop);
    carousel.setProperty('autoplay', autoplay);
    if (autoplayInterval != null) {
      carousel.setProperty('autoplayInterval', autoplayInterval);
    }
    carousel.setProperty('tvOptions', {
      'interceptHorizontalNav': interceptHorizontalNav,
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

  /// The first horizontal scrollable that is NOT a pager (an ordinary lane).
  ScrollableState nonPagerScrollable(WidgetTester tester) {
    for (final element in find.byType(Scrollable).evaluate()) {
      final state = (element as StatefulElement).state;
      if (state is ScrollableState &&
          state.position is! PageMetrics &&
          (state.axisDirection == AxisDirection.left ||
              state.axisDirection == AxisDirection.right)) {
        return state;
      }
    }
    throw StateError('no horizontal lane found');
  }

  /// The focus node of the `_TapEnabledWrapper` wrapping the control labelled
  /// [text].
  FocusNode controlFocusNode(WidgetTester tester, String text) {
    final inkWells = find.ancestor(
      of: find.text(text),
      matching: find.byType(InkWell),
    );
    return tester
        .widgetList<InkWell>(inkWells)
        .firstWhere((inkWell) => inkWell.focusNode != null)
        .focusNode!;
  }

  double displayedPage(ScrollableState pager) =>
      (pager.position as PageMetrics).page!;

  /// Distance of the displayed page from the nearest page boundary.
  double pageAlignmentError(ScrollableState pager) {
    final page = displayedPage(pager);
    return (page - page.roundToDouble()).abs();
  }

  testWidgets('focus reveal moves an idle page-snapping pager by one page',
      (tester) async {
    useTestViewport(tester);

    // A 0.8 viewport fraction keeps the neighbouring slide built while page 0
    // is the one displayed.
    final carousel = makeCarousel(
      itemTemplate: loadYaml(slideTemplate(alignEnd: true)),
      singleItemWidthRatio: 0.8,
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
    expect(pager.position is PageMetrics, isTrue);
    expect(pager.position.pixels, 0);
    expect(pageAlignmentError(pager), lessThan(1e-6));
    expect(find.text('first'), findsOneWidget);

    // An idle pager should reveal a focused neighbouring slide by a whole page.
    controlFocusNode(tester, 'second').requestFocus();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(displayedPage(pager), 1,
        reason: 'focus gain must reveal the off-screen slide');
    expect(pageAlignmentError(pager), lessThan(1e-6),
        reason: 'the pager must stay on a page boundary');
    final box = controlFocusNode(tester, 'second').context!.findRenderObject()!
        as RenderBox;
    expect(box.localToGlobal(Offset.zero).dx + box.size.width,
        lessThanOrEqualTo(1280));
  });

  testWidgets(
      'D-pad onto a peeking slide without interceptHorizontalNav reveals it '
      'on a page boundary', (tester) async {
    useTestViewport(tester);
    final carousel = makeCarousel(
      itemTemplate: loadYaml(slideTemplate()),
      singleItemWidthRatio: 0.8,
      interceptHorizontalNav: false,
    );
    await tester.pumpWidget(host(SizedBox(
      width: 1280,
      height: 400,
      child: carousel,
    )));
    await tester.pump();
    await tester.pump();

    final pager = pagerScrollable(tester);
    controlFocusNode(tester, 'first').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    final secondControl = controlFocusNode(tester, 'second');
    expect(secondControl.hasPrimaryFocus, isTrue);
    final box = secondControl.context!.findRenderObject()! as RenderBox;
    final left = box.localToGlobal(Offset.zero).dx;
    expect(left, greaterThanOrEqualTo(0));
    expect(left + box.size.width, lessThanOrEqualTo(1280),
        reason: 'the focused control must be on screen');
    expect(displayedPage(pager), 1,
        reason: 'focus scrolling must reveal the slide by a whole page');
    expect(pageAlignmentError(pager), lessThan(1e-6),
        reason: 'the pager must still settle on a page boundary');
  });

  testWidgets(
      're-entering the hero while a slide change is in flight keeps page and '
      'index in sync', (tester) async {
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
    final startPage = displayedPage(pager);
    final heroControl = controlFocusNode(tester, 'first');
    final outsideNode = Focus.maybeOf(tester.element(find.text('outside')));
    expect(outsideNode, isNotNull);

    heroControl.requestFocus();
    await tester.pump();
    await tester.pump();

    // D-pad slide change: the framework animates to the next slide and restores
    // focus to the incoming slide while that slide is still moving.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 180));

    // Focus leaves the hero and comes straight back mid-slide (the DOWN/UP
    // sequence that reproduces the defect on the device).
    outsideNode!.requestFocus();
    await tester.pump();
    heroControl.requestFocus();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(pageAlignmentError(pager), lessThan(1e-6),
        reason: 'the pager must settle on a page boundary');
    expect(displayedPage(pager), closeTo(startPage + 1, 1e-6),
        reason: 'the in-flight slide change must complete');
    expect(carousel.controller.currentIndex, 1,
        reason: 'the reported slide must match the displayed page');
  });

  testWidgets(
      'focus returning to the hero mid-autoplay lets the slide change finish',
      (tester) async {
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
    final startPage = displayedPage(pager);
    final heroControl = controlFocusNode(tester, 'first');
    final outsideNode = Focus.maybeOf(tester.element(find.text('outside')))!;

    // Focus on the hero pauses autoplay; leaving resumes it.
    heroControl.requestFocus();
    await tester.pump();
    await tester.pump();
    outsideNode.requestFocus();
    await tester.pump();
    await tester.pump();

    // Autoplay ticks and starts animating the next slide.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 150));

    // Focus returns to the hero while that slide is still moving.
    heroControl.requestFocus();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(pageAlignmentError(pager), lessThan(1e-6),
        reason: 'the pager must settle on a page boundary');
    expect(displayedPage(pager), closeTo(startPage + 1, 1e-6),
        reason: 'the autoplay slide change must not be cancelled');
    expect(carousel.controller.currentIndex, 1,
        reason: 'the reported slide must match the displayed page');
  });

  testWidgets('keepVisible reveals an off-screen slide on a page boundary',
      (tester) async {
    useTestViewport(tester);

    final carousel = makeCarousel(
      itemTemplate: loadYaml(slideTemplate(alignEnd: true, keepVisible: true)),
      singleItemWidthRatio: 0.8,
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
    controlFocusNode(tester, 'second').requestFocus();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(displayedPage(pager), 1);
    expect(pageAlignmentError(pager), lessThan(1e-6));
  });

  testWidgets('fixedFocusScroll reveals through an idle snapping pager',
      (tester) async {
    useTestViewport(tester);
    final carousel = makeCarousel(
      itemTemplate: loadYaml(slideTemplate(fixedFocusScroll: true)),
      singleItemWidthRatio: 0.8,
    );
    await tester.pumpWidget(host(SizedBox(
      width: 1280,
      height: 400,
      child: carousel,
    )));
    await tester.pump();
    await tester.pump();
    final pager = pagerScrollable(tester);
    controlFocusNode(tester, 'second').requestFocus();
    await tester.pumpAndSettle();
    expect(controlFocusNode(tester, 'second').hasPrimaryFocus, isTrue);
    expect(displayedPage(pager), 1);
    expect(pageAlignmentError(pager), lessThan(1e-6));
  });

  testWidgets('snapping ScrollView reveals an off-screen focused item',
      (tester) async {
    useTestViewport(tester);
    final scrollView = ensemble_layout.ScrollView();
    scrollView.setProperty('viewportFraction', 0.8);
    scrollView.setItemTemplate(loadYaml(slideTemplate()));
    await tester.pumpWidget(host(SizedBox(
      width: 1280,
      height: 400,
      child: scrollView,
    )));
    await tester.pump();
    await tester.pump();
    final pager = pagerScrollable(tester);
    controlFocusNode(tester, 'first').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    final second = controlFocusNode(tester, 'second');
    expect(second.hasPrimaryFocus, isTrue);
    expect(displayedPage(pager), 1);
    expect(pageAlignmentError(pager), lessThan(1e-6));
    final box = second.context!.findRenderObject()! as RenderBox;
    expect(box.localToGlobal(Offset.zero).dx + box.size.width,
        lessThanOrEqualTo(1280));
  });

  testWidgets(
      'keepVisible skips a pager but reveals through an outer horizontal lane',
      (tester) async {
    useTestViewport(tester);

    final carousel = makeCarousel(
      itemTemplate: loadYaml(slideTemplate(keepVisible: true)),
    );
    await tester.pumpWidget(host(SizedBox(
      height: 400,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          const SizedBox(width: 1200),
          SizedBox(width: 1280, height: 400, child: carousel),
        ]),
      ),
    )));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    final pager = pagerScrollable(tester);
    final lane = nonPagerScrollable(tester);
    expect(pager.position.pixels, 0);
    expect(lane.position.pixels, 0);

    controlFocusNode(tester, 'first').requestFocus();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(pager.position.pixels, 0,
        reason: 'keepVisible must not move the page-snapping pager');
    expect(pageAlignmentError(pager), lessThan(1e-6));
    expect(lane.position.pixels, greaterThan(0),
        reason: 'keepVisible must reveal the pager through its outer lane');
  });

  testWidgets(
      'keepVisible skips a pager but reveals through an outer vertical page',
      (tester) async {
    useTestViewport(tester);

    final carousel = makeCarousel(
      itemTemplate: loadYaml(slideTemplate(keepVisible: true)),
    );
    final verticalController = ScrollController();
    addTearDown(verticalController.dispose);
    await tester.pumpWidget(host(SingleChildScrollView(
      controller: verticalController,
      child: Column(children: [
        const SizedBox(height: 700),
        SizedBox(width: 1280, height: 400, child: carousel),
      ]),
    )));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    final pager = pagerScrollable(tester);
    expect(pager.position.pixels, 0);
    expect(verticalController.offset, 0);

    controlFocusNode(tester, 'first').requestFocus();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(pager.position.pixels, 0,
        reason: 'keepVisible must not move the page-snapping pager');
    expect(pageAlignmentError(pager), lessThan(1e-6));
    expect(verticalController.offset, greaterThan(0),
        reason: 'keepVisible must reveal the pager through the outer page');
  });

  testWidgets(
      'an enclosing non-paging lane still reveals the item while the pager '
      'stays aligned', (tester) async {
    useTestViewport(tester);

    final carousel = makeCarousel(itemTemplate: loadYaml(slideTemplate()));
    // The carousel sits past the lane's viewport, so the focused control is
    // outside the lane while still inside the page that shows it.
    await tester.pumpWidget(host(SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        const SizedBox(width: 1200),
        SizedBox(width: 1280, height: 400, child: carousel),
      ]),
    )));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    final pager = pagerScrollable(tester);
    final lane = nonPagerScrollable(tester);
    expect(lane.position.pixels, 0);

    controlFocusNode(tester, 'first').requestFocus();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(pager.position.pixels, 0,
        reason: 'the pager is not a focus-scroll target');
    expect(pageAlignmentError(pager), lessThan(1e-6));
    expect(lane.position.pixels, greaterThan(0),
        reason: 'an ordinary horizontal lane must still reveal the item');
  });

  testWidgets(
      'fixedFocusScroll skips a pager and reveals through an outer lane',
      (tester) async {
    useTestViewport(tester);

    final carousel = makeCarousel(
      itemTemplate: loadYaml(slideTemplate(fixedFocusScroll: true)),
    );
    await tester.pumpWidget(host(SizedBox(
      height: 400,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          const SizedBox(width: 900),
          SizedBox(width: 1280, height: 400, child: carousel),
          const SizedBox(width: 900),
        ]),
      ),
    )));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    final pager = pagerScrollable(tester);
    final lane = nonPagerScrollable(tester);
    controlFocusNode(tester, 'first').requestFocus();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(pager.position.pixels, 0,
        reason: 'fixedFocusScroll must not move the page-snapping pager');
    expect(pageAlignmentError(pager), lessThan(1e-6));
    expect(lane.position.pixels, closeTo(831, 5),
        reason: 'fixedFocusScroll must reveal through the outer lane');
  });

  testWidgets(
      'an enclosing vertical scrollable still reveals the item inside a pager',
      (tester) async {
    useTestViewport(tester);

    final carousel = makeCarousel(itemTemplate: loadYaml(slideTemplate()));
    final verticalController = ScrollController();
    addTearDown(verticalController.dispose);
    await tester.pumpWidget(host(SingleChildScrollView(
      controller: verticalController,
      child: Column(children: [
        const SizedBox(height: 700),
        SizedBox(width: 1280, height: 400, child: carousel),
      ]),
    )));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    final pager = pagerScrollable(tester);
    expect(verticalController.offset, 0);

    controlFocusNode(tester, 'first').requestFocus();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(pager.position.pixels, 0);
    expect(pageAlignmentError(pager), lessThan(1e-6));
    expect(verticalController.offset, greaterThan(0),
        reason: 'vertical reveal must keep working inside a carousel slide');
  });

  testWidgets(
      'a non-page-snapping pager (multi-view carousel) still reveals the '
      'focused item', (tester) async {
    useTestViewport(tester);

    final carousel = makeCarousel(
      itemTemplate: loadYaml(slideTemplate(leftInset: 460)),
      layout: 'multiple',
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
    expect(pager.position.pixels, 0);

    controlFocusNode(tester, 'second').requestFocus();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(pager.position.pixels, greaterThan(0),
        reason: 'without page snapping a pixel reveal is still valid');
  });

  testWidgets('repeated D-pad navigation and looping stay on page boundaries',
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
    final startPage = displayedPage(pager);
    controlFocusNode(tester, 'first').requestFocus();
    await tester.pump();
    await tester.pump();

    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(key);
      await tester.pump();
      await tester.sendKeyUpEvent(key);
      await tester.pumpAndSettle();
    }

    // Forward through the loop point (0 -> 1 -> 2 -> 0).
    for (var i = 1; i <= 3; i++) {
      await press(LogicalKeyboardKey.arrowRight);
      expect(tester.takeException(), isNull);
      expect(pageAlignmentError(pager), lessThan(1e-6),
          reason: 'pager must stay on a page boundary after D-pad forward');
      expect(displayedPage(pager), closeTo(startPage + i, 1e-6),
          reason: 'D-pad forward must advance exactly one slide');
      expect(carousel.controller.currentIndex, i % 3);
    }

    // And back again.
    for (var i = 1; i <= 2; i++) {
      await press(LogicalKeyboardKey.arrowLeft);
      expect(tester.takeException(), isNull);
      expect(pageAlignmentError(pager), lessThan(1e-6),
          reason: 'pager must stay on a page boundary after D-pad back');
      expect(displayedPage(pager), closeTo(startPage + 3 - i, 1e-6),
          reason: 'D-pad back must step back exactly one slide');
    }
  });
  testWidgets(
      'D-pad onto a peeking slide inside a horizontal lane moves only the '
      'pager, keeping focus on screen', (tester) async {
    useTestViewport(tester);

    final carousel = makeCarousel(
      itemTemplate: loadYaml(slideTemplate()),
      singleItemWidthRatio: 0.8,
      interceptHorizontalNav: false,
    );
    await tester.pumpWidget(host(SizedBox(
      height: 400,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          const SizedBox(width: 300),
          SizedBox(width: 1280, height: 400, child: carousel),
          const SizedBox(width: 900),
        ]),
      ),
    )));
    await tester.pump();
    await tester.pump();

    final pager = pagerScrollable(tester);
    controlFocusNode(tester, 'first').requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    final secondControl = controlFocusNode(tester, 'second');
    expect(secondControl.hasPrimaryFocus, isTrue);
    final box = secondControl.context!.findRenderObject()! as RenderBox;
    final left = box.localToGlobal(Offset.zero).dx;
    expect(left, greaterThanOrEqualTo(0),
        reason: 'the pager move and the lane scroll must not both apply');
    expect(left + box.size.width, lessThanOrEqualTo(1280));
    expect(displayedPage(pager), 1);
    expect(pageAlignmentError(pager), lessThan(1e-6));
  });
}
