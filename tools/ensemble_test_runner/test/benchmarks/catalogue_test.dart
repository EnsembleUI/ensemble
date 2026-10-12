import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../tool/benchmarks/cases.dart';
import '../../tool/benchmarks/coverage.dart';
import '../../tool/benchmarks/operation_cases.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';

void main() {
  test('every instrumented production operation maps to a case', () {
    checkInstrumentedOperations(Directory.current);
  });
  test('every registered step has an intentional coverage declaration', () {
    checkCoverage();
    expect(coveredSteps, TestStepRegistry.entries.keys.toSet());
  });
  testWidgets('catalogue IDs are unique and each step has an execution case',
      (tester) async {
    final cases = buildCases(BenchmarkFixtures(tester, Directory.systemTemp));
    expect(
      cases
          .singleWhere((c) => c.id == 'observer.runtime.conditional.cached.100')
          .batchable,
      isFalse,
      reason:
          'The cached-read workload already repeats 100 observations; batching it repeats expensive Flutter fixture setup.',
    );
    expect(
      cases.singleWhere((c) => c.id == 'execution.control-flow').batchable,
      isFalse,
      reason:
          'Each control-flow invocation closes its runtime session; setup runs once per sample.',
    );
    expect(capabilityCases.keys.toSet(), coveredCapabilities);
    checkCatalogue(cases);
    final integration = buildCases(
        BenchmarkFixtures(tester, Directory.systemTemp),
        mode: 'integration');
    for (final id in [
      'screenshot.frame.ios.fallback',
      'screenshot.frame.android.fallback'
    ]) {
      expect(integration.singleWhere((c) => c.id == id).skipReason, isNotNull);
    }
    expect(
        () => checkCatalogue(
            cases.where((c) => c.id != 'screenshot.aggregate').toList()),
        throwsStateError);
    expect(cases.map((c) => c.id).toSet().length, cases.length);
    for (final step in coveredSteps) {
      expect(cases.where((c) => c.id == 'step.$step').length, 1);
    }
    expect(
        cases.where((c) => c.quick).map((c) => c.service).toSet(),
        containsAll([
          'screenshot',
          'observer',
          'planner',
          'report',
          'workflow',
          'control'
        ]));
  });
  testWidgets('kernel subscriber benchmark pair completes equivalent plans',
      (tester) async {
    final cases = buildCases(BenchmarkFixtures(tester, Directory.systemTemp));
    final disabled = cases.singleWhere((c) => c.id == 'kernel.no_subscribers');
    final enabled =
        cases.singleWhere((c) => c.id == 'kernel.subscribers.enabled');

    expect(disabled.dimensions['operations'], enabled.dimensions['operations']);
    expect(disabled.dimensions['eventSubscribers'], 0);
    expect(enabled.dimensions['eventSubscribers'], 1);
    final disabledResult = await disabled.body();
    final enabledResult = await enabled.body();
    disabled.verify!(disabledResult);
    enabled.verify!(enabledResult);
  });
  testWidgets('evidence workflow benchmark cases use a matched workload',
      (tester) async {
    final cases = buildCases(BenchmarkFixtures(tester, Directory.systemTemp));
    final disabled = cases.singleWhere(
      (benchmark) => benchmark.id == 'workflow.evidence.disabled',
    );
    final enabled = cases.singleWhere(
      (benchmark) => benchmark.id == 'workflow.evidence.enabled',
    );

    expect(disabled.quick, isTrue);
    expect(enabled.quick, isTrue);
    expect(disabled.dimensions['steps'], 4);
    expect(enabled.dimensions['steps'], disabled.dimensions['steps']);
    expect(disabled.dimensions['evidenceSubscribers'], 0);
    expect(enabled.dimensions['evidenceSubscribers'], 1);
    expect(disabled.dimensions['screenshotsEnabled'], isFalse);
    expect(enabled.dimensions['screenshotsEnabled'], isTrue);
    expect(disabled.dimensions.keys, enabled.dimensions.keys);
  });
  testWidgets('tapFinder operation benchmark runs the finder route',
      (tester) async {
    final benchmark = buildCases(
      BenchmarkFixtures(tester, Directory.systemTemp),
    ).singleWhere(
      (item) => item.id == 'workflow.capture.finderTap',
    );
    expect(
      benchmark.toJson()['operations'],
      contains('execution.tapFinder'),
    );
    final collector = BenchmarkCollector(
      caseId: benchmark.id,
      sample: 0,
      processId: 'catalogue-test',
    );
    try {
      final result = await RunnerBenchmark.collect(collector, benchmark.body);
      benchmark.verify!(result);
      expect(
        collector.spans.any(
          (span) =>
              span.service == 'execution' && span.operation == 'tapFinder',
        ),
        isTrue,
      );
    } finally {
      await benchmark.cleanup?.call();
    }
  });
  testWidgets('navigation drain workload reaches its instrumented operation',
      (tester) async {
    final fixtures = BenchmarkFixtures(tester, Directory.systemTemp);
    final benchmark = buildCases(fixtures).singleWhere(
      (c) => c.id == 'execution.navigation-live-call-drain',
    );
    final collector = BenchmarkCollector(
      caseId: benchmark.id,
      sample: 0,
      processId: 'catalogue-test',
    );
    try {
      await benchmark.prepare?.call();
      final result = await RunnerBenchmark.collect(collector, benchmark.body);
      benchmark.verify?.call(result);
      expect(
        collector.spans.any(
          (span) =>
              span.service == 'execution' &&
              span.operation == 'navigationLiveCallDrain',
        ),
        isTrue,
      );
    } finally {
      await benchmark.cleanup?.call();
    }
  });
  testWidgets(
      'rich report workloads preserve every step and artifact reference',
      (tester) async {
    final root =
        Directory.systemTemp.createTempSync('benchmark_report_contract_');
    try {
      final cases = buildCases(BenchmarkFixtures(tester, root));
      for (final count in [10, 1000]) {
        final benchmark =
            cases.singleWhere((c) => c.id == 'report.rich.$count');
        final output = await tester.runAsync(benchmark.body) as Map;
        benchmark.verify!(output);
        final report = (output['tests'] as List).single['report'] as Map;
        expect((report['stepsOutline'] as List).length, count);
        expect((report['stepDurationsMs'] as List).length, count);
        expect((report['screens'] as Map).length, count);
      }
    } finally {
      root.deleteSync(recursive: true);
    }
  });
}
