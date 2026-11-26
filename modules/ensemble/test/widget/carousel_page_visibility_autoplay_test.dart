import 'package:carousel_slider/carousel_slider.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/widget/carousel.dart' as ensemble;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'test_utils.dart';

/// Autoplay must stop while a route on an enclosing navigator covers the page.
void main() {
  setUp(() => Device.debugOverrideIsTV(true));
  tearDown(() => Device.debugOverrideIsTV(null));

  String slideTemplate() => '''
data: \${items}
name: item
indexId: idx
template:
  Row:
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

  ensemble.Carousel makeCarousel({bool pauseOnFocus = false}) {
    final carousel = ensemble.Carousel();
    carousel.setProperty('layout', 'single');
    carousel.setProperty('height', 400);
    carousel.setProperty('autoplay', true);
    carousel.setProperty('autoplayInterval', 1);
    carousel.setProperty('enableLoop', true);
    carousel.setProperty('tvOptions', {
      'interceptHorizontalNav': true,
      'restoreFocusOnPageChange': true,
      'pauseAutoplayOnFocus': pauseOnFocus,
    });
    carousel.initChildren(itemTemplate: loadYaml(slideTemplate()));
    return carousel;
  }

  Widget buildTree(
    Widget carousel,
    GlobalKey<NavigatorState> outerKey, {
    FocusNode? outsideFocus,
  }) {
    return MaterialApp(
      navigatorKey: outerKey,
      home: TestUtils.wrapTestWidgetWithScope(Builder(builder: (context) {
        DataScopeWidget.getScope(context)!
            .dataContext
            .addDataContextById('items', const ['first', 'second', 'third']);
        return Column(children: [
          if (outsideFocus != null)
            TextButton(
              focusNode: outsideFocus,
              onPressed: () {},
              child: const Text('outside'),
            ),
          SizedBox(width: 1280, height: 400, child: carousel),
        ]);
      })),
    );
  }

  void useTestViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  CarouselSliderState sliderState(WidgetTester tester) =>
      tester.state<CarouselSliderState>(find.byType(CarouselSlider));

  int currentIndex(WidgetTester tester) => tester
      .state<ensemble.CarouselState>(find.byType(ensemble.Carousel))
      .widget
      .controller
      .currentIndex;

  /// Advances the test clock in small frames so timers and page animations run.
  Future<void> advance(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('autoplay pauses while an enclosing route covers the page',
      (tester) async {
    useTestViewport(tester);
    final outerKey = GlobalKey<NavigatorState>();
    final carousel = makeCarousel();

    await tester.pumpWidget(buildTree(carousel, outerKey));
    await tester.pump();
    await tester.pump();

    expect(sliderState(tester).timer, isNotNull);
    await advance(tester, 2);
    final beforeCover = currentIndex(tester);
    expect(beforeCover, isNot(0), reason: 'autoplay runs while visible');

    outerKey.currentState!.push(PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (_, __, ___) => const Scaffold(body: Text('detail')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(sliderState(tester).timer, isNull,
        reason: 'covering route stops autoplay');
    final indexWhenCovered = currentIndex(tester);
    await advance(tester, 2);
    expect(currentIndex(tester), indexWhenCovered,
        reason: 'no slide change while covered');

    // An imperative call must not override route visibility.
    carousel.methods()['startAutoplay']!();
    await tester.pump();
    expect(sliderState(tester).timer, isNull,
        reason: 'startAutoplay cannot restart a covered carousel');
    await advance(tester, 2);
    expect(currentIndex(tester), indexWhenCovered);

    outerKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(sliderState(tester).timer, isNotNull,
        reason: 'autoplay resumes when the page is visible again');
    final beforeResume = currentIndex(tester);
    await advance(tester, 2);
    expect(currentIndex(tester), isNot(beforeResume));

    // Manual controls still work on a visible page.
    carousel.methods()['stopAutoplay']!();
    await tester.pump();
    expect(sliderState(tester).timer, isNull);
    carousel.methods()['startAutoplay']!();
    await tester.pump();
    expect(sliderState(tester).timer, isNotNull);
  });

  testWidgets('focus returns to the slide control after the covering route pops',
      (tester) async {
    useTestViewport(tester);
    final outerKey = GlobalKey<NavigatorState>();
    final carousel = makeCarousel();

    await tester.pumpWidget(buildTree(carousel, outerKey));
    await tester.pump();
    await tester.pump();

    final slideFocus = tester
        .widgetList<InkWell>(find.ancestor(
          of: find.text('first'),
          matching: find.byType(InkWell),
        ))
        .firstWhere((inkWell) => inkWell.focusNode != null)
        .focusNode!;
    slideFocus.requestFocus();
    await tester.pump();
    expect(slideFocus.hasFocus, isTrue);

    outerKey.currentState!.push(PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (_, __, ___) => const Scaffold(body: Text('detail')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(slideFocus.hasFocus, isFalse);
    // Longer than autoplayInterval: the slide must not move while covered.
    await advance(tester, 3);

    outerKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(slideFocus.hasFocus, isTrue,
        reason: 'back navigation must restore focus to the slide control');
    expect(sliderState(tester).timer, isNotNull);
  });

  testWidgets('pauseAutoplayOnFocus still pauses and resumes autoplay',
      (tester) async {
    useTestViewport(tester);
    final outerKey = GlobalKey<NavigatorState>();
    final outsideFocus = FocusNode();
    addTearDown(outsideFocus.dispose);
    final carousel = makeCarousel(pauseOnFocus: true);

    await tester.pumpWidget(
        buildTree(carousel, outerKey, outsideFocus: outsideFocus));
    await tester.pump();
    await tester.pump();

    final focusNode = tester
        .widgetList<InkWell>(find.ancestor(
          of: find.text('first'),
          matching: find.byType(InkWell),
        ))
        .firstWhere((inkWell) => inkWell.focusNode != null)
        .focusNode!;
    focusNode.requestFocus();
    await tester.pump();
    await tester.pump();

    expect(sliderState(tester).timer, isNull,
        reason: 'pauseAutoplayOnFocus pauses while focused');

    outsideFocus.requestFocus();
    await tester.pump();
    await tester.pump();

    expect(sliderState(tester).timer, isNotNull,
        reason: 'autoplay resumes when the carousel loses focus');
  });
}
