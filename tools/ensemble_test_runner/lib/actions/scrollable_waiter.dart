import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finds a scrollable that may be created by a preceding application action.
///
/// Keeping the polling policy here gives action execution one place to handle
/// delayed scrollable creation while preserving the executor's public API.
class ScrollableWaiter {
  final WidgetTester tester;
  final TestExecutionConfig config;

  const ScrollableWaiter({
    required this.tester,
    required this.config,
  });

  Future<Finder> wait({
    String? scrollableId,
    required int timeoutMs,
  }) async {
    final scrollables = scrollableId == null || scrollableId.isEmpty
        ? find.byType(Scrollable)
        : find.descendant(
            of: find.byKey(ValueKey(scrollableId)),
            matching: find.byType(Scrollable),
          );
    final stopwatch = Stopwatch()..start();
    while (scrollables.evaluate().isEmpty &&
        stopwatch.elapsedMilliseconds < timeoutMs) {
      final remainingMs = timeoutMs - stopwatch.elapsedMilliseconds;
      final pollMs = config.waitPollInterval.inMilliseconds;
      await tester.pump(Duration(
        milliseconds: remainingMs < pollMs ? remainingMs : pollMs,
      ));
    }
    if (scrollables.evaluate().isEmpty) {
      throw EnsembleTestFailure(
        'Timed out after ${timeoutMs}ms waiting for a scrollable to appear',
      );
    }
    return scrollableId == null || scrollableId.isEmpty
        ? find.byType(Scrollable).first
        : scrollables;
  }
}
