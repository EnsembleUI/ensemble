import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/widget/carousel.dart' as ensemble;
import 'package:ensemble/widget/custom_widget/custom_widget_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'test_utils.dart';

/// A rebuilt custom widget gets a fresh Carousel controller, while the state
/// (and the slider controller attached to it) survives.
void main() {
  setUp(() => Device.debugOverrideIsTV(true));
  tearDown(() => Device.debugOverrideIsTV(null));

  String carouselWidget({bool autoplay = false, bool buildOnDemand = false}) => '''
body:
  Carousel:
    layout: single
    height: 400
    enableLoop: true
    buildOnDemand: $buildOnDemand
    buildOnDemandLength: 2
    autoplay: $autoplay
    autoplayInterval: 1
    styles:
      tvOptions:
        interceptHorizontalNav: true
        restoreFocusOnPageChange: true
    item-template:
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

  ensemble.Carousel carouselOf(WidgetTester tester) =>
      tester.widget<ensemble.Carousel>(find.byType(ensemble.Carousel));

  /// Builds the custom widget tree twice; the second call rebuilds the same
  /// elements with a new CustomWidget/Carousel/controller.
  Widget tree({bool autoplay = false, bool buildOnDemand = false}) {
    final customWidgets = {
      'HeroCarousel': loadYaml(carouselWidget(
          autoplay: autoplay, buildOnDemand: buildOnDemand)),
    };
    final model = ViewUtil.buildModel(
      loadYaml('HeroCarousel: {}'),
      customWidgets,
    ) as CustomWidgetModel;

    return TestUtils.wrapTestWidgetWithScope(Builder(builder: (context) {
      final scope = DataScopeWidget.getScope(context)!;
      scope.dataContext
          .addDataContextById('items', const ['first', 'second', 'third']);
      return SizedBox(
        width: 1280,
        height: 400,
        child: scope.buildWidget(model),
      );
    }));
  }

  void useTestViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  ScrollableState pagerScrollable(WidgetTester tester) {
    for (final element in find.byType(Scrollable).evaluate()) {
      final state = (element as StatefulElement).state;
      if (state is ScrollableState && state.position is PageMetrics) {
        return state;
      }
    }
    throw StateError('carousel PageView is not scrollable');
  }

  double displayedPage(WidgetTester tester) =>
      (pagerScrollable(tester).position as PageMetrics).page!;

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

  bool focusInsideCarousel(WidgetTester tester) {
    final primary = FocusManager.instance.primaryFocus;
    final context = primary?.context;
    if (context == null) return false;
    final carouselElement = tester.element(find.byType(ensemble.Carousel));
    var found = false;
    (context as Element).visitAncestorElements((candidate) {
      if (candidate == carouselElement) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  Future<void> tapKey(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyUpEvent(key);
  }

  testWidgets('D-pad navigation survives a custom widget rebuild',
      (tester) async {
    useTestViewport(tester);

    await tester.pumpWidget(tree());
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    final startPage = displayedPage(tester);
    focusFirstControl(tester);
    await tester.pump();

    await tapKey(tester, LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(displayedPage(tester), closeTo(startPage + 1, 1e-6));
    expect(carouselOf(tester).controller.currentIndex, 1);

    // Rebuild: new Carousel widget and controller, same CarouselState.
    await tester.pumpWidget(tree());
    await tester.pump();
    expect(tester.takeException(), isNull);

    expect(carouselOf(tester).controller.currentIndex, 1,
        reason: 'the published slide must survive the rebuild');
    expect(displayedPage(tester), closeTo(startPage + 1, 1e-6),
        reason: 'the rebuild must not move the pager');
    expect(focusInsideCarousel(tester), isTrue,
        reason: 'focus must stay inside the rebuilt carousel');

    await tapKey(tester, LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(displayedPage(tester), closeTo(startPage + 2, 1e-6));
    expect(carouselOf(tester).controller.currentIndex, 2);

    await tapKey(tester, LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(displayedPage(tester), closeTo(startPage + 1, 1e-6));
    expect(carouselOf(tester).controller.currentIndex, 1);
  });

  testWidgets('on-demand carousel methods survive a custom widget rebuild',
      (tester) async {
    useTestViewport(tester);
    await tester.pumpWidget(tree(buildOnDemand: true));
    await tester.pump();
    await tester.pump();
    final startPage = displayedPage(tester);

    await tester.pumpWidget(tree(buildOnDemand: true));
    await tester.pump();
    carouselOf(tester).methods()['next']!();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(displayedPage(tester), closeTo(startPage + 1, 1e-6));
    expect(carouselOf(tester).controller.currentIndex, 1);
  });

  testWidgets('autoplay keeps advancing after a custom widget rebuild',
      (tester) async {
    useTestViewport(tester);

    Future<void> pumpAutoplay() async {
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    await tester.pumpWidget(tree(autoplay: true));
    await tester.pump();
    await pumpAutoplay();
    expect(tester.takeException(), isNull);
    final before = carouselOf(tester).controller.currentIndex;
    expect(before, isNot(0));

    await tester.pumpWidget(tree(autoplay: true));
    await tester.pump();
    await pumpAutoplay();
    expect(tester.takeException(), isNull);
    expect(carouselOf(tester).controller.currentIndex, isNot(before),
        reason: 'autoplay must keep advancing after the rebuild');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
