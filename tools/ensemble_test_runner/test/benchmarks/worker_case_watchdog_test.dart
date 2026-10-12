import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import '../../tool/benchmarks/worker_case_watchdog.dart';

void main() {
  group('BenchmarkWorkerCaseWatchdog', () {
    test('starts its deadline when a case marker arrives', () async {
      final expired = Completer<String>();
      final watchdog = BenchmarkWorkerCaseWatchdog(
        timeout: const Duration(milliseconds: 10),
        markerPrefix: 'BENCH:',
        onTimeout: expired.complete,
      );
      addTearDown(watchdog.dispose);

      watchdog.observeLine('compiler output');
      expect(watchdog.currentCase, isNull);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(watchdog.timedOutCase, isNull);

      watchdog.observeLine('BENCH:case:slow-setup');
      expect(await expired.future, 'slow-setup');
      expect(watchdog.timedOutCase, 'slow-setup');
    });

    test('a later case gets a fresh deadline', () async {
      final expired = Completer<String>();
      final watchdog = BenchmarkWorkerCaseWatchdog(
        timeout: const Duration(milliseconds: 30),
        markerPrefix: 'BENCH:',
        onTimeout: expired.complete,
      );
      addTearDown(watchdog.dispose);

      watchdog.observeLine('BENCH:case:first');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      watchdog.observeLine('BENCH:case:second');
      expect(watchdog.currentCase, 'second');
      expect(watchdog.timedOutCase, isNull);
      expect(await expired.future, 'second');
      expect(watchdog.timedOutCase, 'second');
    });

    test('ignores empty case markers', () {
      final watchdog = BenchmarkWorkerCaseWatchdog(
        timeout: const Duration(seconds: 1),
        markerPrefix: 'BENCH:',
        onTimeout: fail,
      );
      addTearDown(watchdog.dispose);

      watchdog.observeLine('BENCH:case:');
      expect(watchdog.currentCase, isNull);
      expect(watchdog.timedOutCase, isNull);
    });
  });
}
