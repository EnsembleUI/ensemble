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

  /// Like a carousel indicator: every parent build creates a new widget
  /// (and controller) for the same surviving State.
  Future<StateSetter> pumpRebuilding(WidgetTester tester,
      {int? countdown}) async {
    late StateSetter rebuild;
    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
        StatefulBuilder(builder: (context, setState) {
      rebuild = setState;
      final widget = EnsembleProgressIndicator()
        ..setProperty('display', 'linear');
      if (countdown != null) widget.setProperty('countdown', countdown);
      return widget;
    })));
    return rebuild;
  }

  double? barValue(WidgetTester tester) => tester
      .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
      .value;

  testWidgets('countdown starts at 0 instead of indeterminate', (tester) async {
    await pumpRebuilding(tester, countdown: 2);
    expect(barValue(tester), 0);
  });

  testWidgets('parent rebuild mid-countdown keeps the progress',
      (tester) async {
    final rebuild = await pumpRebuilding(tester, countdown: 2);
    await tester.pump(const Duration(milliseconds: 550));
    final before = barValue(tester)!;
    expect(before, greaterThan(0));

    rebuild(() {});
    await tester.pump();
    expect(barValue(tester), before);
  });

  testWidgets('parent rebuild after the countdown keeps a full bar',
      (tester) async {
    final rebuild = await pumpRebuilding(tester, countdown: 1);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(barValue(tester), 1);

    rebuild(() {});
    await tester.pump();
    expect(barValue(tester), 1);
  });

  testWidgets('without countdown or value the bar stays indeterminate',
      (tester) async {
    final rebuild = await pumpRebuilding(tester);
    expect(barValue(tester), isNull);
    rebuild(() {});
    await tester.pump();
    expect(barValue(tester), isNull);
  });
}
