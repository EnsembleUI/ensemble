import 'dart:ui' as ui;
import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/diagnostic_ui_snapshot.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/step_report_capture.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('collection preserves frozen screenshot and diagnostic pairing',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('Fixture', key: ValueKey('target')))));
    final context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(id: 'fixture', steps: []));
    final assertions = AssertionEngine(tester: tester, context: context);
    Future<List<Object>> capture() async {
      ui.Image? image;
      DiagnosticUiSnapshot? observation;
      final scheduled = tester.binding.hasScheduledFrame;
      try {
        await captureStepReportArtifacts(captureScreenshot: () async {
          image = ExtendedStepHandlers.captureScreenshotImage(tester);
          observation = captureDiagnosticUiSnapshot(
              tester: tester, assertions: assertions);
          return true;
        });
        expect(tester.binding.hasScheduledFrame, scheduled);
        final bytes = await tester
            .runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
        return [
          bytes!.buffer.asUint8List(),
          observation!.observation.elements.map((e) => e.toJson()).toList()
        ];
      } finally {
        image?.dispose();
      }
    }

    final ordinary = await capture();
    expect(RunnerBenchmark.collector, isNull);
    final collector =
        BenchmarkCollector(caseId: 'fixture', sample: 0, processId: 'test');
    final measured = await RunnerBenchmark.collect(collector, capture);
    expect(measured, ordinary);
    expect(collector.spans.any((s) => s.service == 'screenshot'), isTrue);
    expect(collector.spans.any((s) => s.service == 'observer'), isTrue);
    expect(
        collector.toJson().where((s) => s['outcome'] == 'incomplete'), isEmpty);
    expect(RunnerBenchmark.collector, isNull);
  });
}
