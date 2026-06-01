import 'package:ensemble/widget/progress_indicator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

void main() {
  testWidgets('cancels countdown timers on dispose without post-unmount errors',
      (tester) async {
    final widget = EnsembleProgressIndicator();
    widget.controller.countdown = 2;

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(widget));
    await tester.pump();

    await tester.pumpWidget(
        TestUtils.wrapTestWidgetWithScope(const SizedBox.shrink()));
    await tester.pump();

    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('countdown completes and reaches full progress when mounted',
      (tester) async {
    final widget = EnsembleProgressIndicator();
    widget.controller.countdown = 1;

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(widget));
    await tester.pump();

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 200));

    expect(widget.controller.value, 1);
  });
}
