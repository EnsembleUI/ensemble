import 'package:ensemble/widget/progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

void main() {
  testWidgets('cancels countdown timers when removed from tree', (tester) async {
    final widget = EnsembleProgressIndicator();
    widget.setProperty('countdown', 2);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(widget));
    await tester.pump();

    await tester.pumpWidget(TestUtils.wrapTestWidget(const SizedBox.shrink()));
    await tester.pump();

    // Advance well past the countdown; leaked timers would call setState off-tree.
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('countdown updates progress after periodic tick', (tester) async {
    final widget = EnsembleProgressIndicator();
    widget.setProperty('countdown', 2);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(widget));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 150));
    expect(widget.controller.value, isNotNull);
    expect(widget.controller.value, greaterThan(0));
  });
}
