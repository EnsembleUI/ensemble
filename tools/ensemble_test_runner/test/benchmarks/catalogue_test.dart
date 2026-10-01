import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../tool/benchmarks/cases.dart';
import '../../tool/benchmarks/coverage.dart';
import '../../tool/benchmarks/operation_cases.dart';
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
