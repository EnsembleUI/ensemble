import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/widget/carousel.dart' as ensemble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'test_utils.dart';

/// Focus that enters the hero after `onPageChanged` (which fires mid-animation)
/// used to stay on the slide that just moved away. It must land on the slide
/// that is on screen once the page settles.
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

  ensemble.Carousel makeCarousel() {
    final carousel = ensemble.Carousel();
    carousel.setProperty('layout', 'single');
    carousel.setProperty('height', 400);
    carousel.setProperty('tvOptions', {
      'interceptHorizontalNav': true,
      'restoreFocusOnPageChange': true,
    });
    carousel.initChildren(itemTemplate: loadYaml(slideTemplate()));
    return carousel;
  }

  bool controlHasFocus(WidgetTester tester, String label) {
    final nodes = find.ancestor(
      of: find.text(label),
      matching: find.byType(InkWell),
    );
    return tester
        .widgetList<InkWell>(nodes)
        .any((inkWell) => inkWell.focusNode?.hasFocus == true);
  }

  void focusControl(WidgetTester tester, String label) {
    final nodes = find.ancestor(
      of: find.text(label),
      matching: find.byType(InkWell),
    );
    tester
        .widgetList<InkWell>(nodes)
        .firstWhere((inkWell) => inkWell.focusNode != null)
        .focusNode!
        .requestFocus();
  }

  testWidgets('focus entering mid animation lands on the current slide',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final carousel = makeCarousel();
    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(Builder(
      builder: (context) {
        DataScopeWidget.getScope(context)!
            .dataContext
            .addDataContextById('items', const ['first', 'second', 'third']);
        return SizedBox(width: 1280, height: 400, child: carousel);
      },
    )));
    await tester.pump();
    await tester.pump();

    // Start a slide change with focus outside the carousel.
    carousel.methods()['next']!();
    await tester.pump();
    // Past the halfway point: onPageChanged already fired, focus is still out.
    await tester.pump(const Duration(milliseconds: 200));

    // Focus arrives on the outgoing slide mid-animation.
    focusControl(tester, 'first');
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controlHasFocus(tester, 'second'), isTrue,
        reason: 'focus must follow the slide that is on screen');
    expect(controlHasFocus(tester, 'first'), isFalse,
        reason: 'focus must not stay on the slide that moved away');
  });

  testWidgets('D-pad navigation still restores focus exactly once',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final carousel = makeCarousel();
    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(Builder(
      builder: (context) {
        DataScopeWidget.getScope(context)!
            .dataContext
            .addDataContextById('items', const ['first', 'second', 'third']);
        return SizedBox(width: 1280, height: 400, child: carousel);
      },
    )));
    await tester.pump();
    await tester.pump();

    focusControl(tester, 'first');
    await tester.pump();

    // D-pad navigation already restores focus; the settle pass must not move
    // it a second time.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controlHasFocus(tester, 'second'), isTrue);
    expect(controlHasFocus(tester, 'third'), isFalse,
        reason: 'the settle pass must not skip a slide');
  });
}
