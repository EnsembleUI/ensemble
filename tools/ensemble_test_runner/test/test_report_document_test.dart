import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/test_report_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compressed report payload round-trips without a sidecar file', () {
    final document = TestReportDocument.buildComplete(
      EnsembleTestRunResult(results: [
        EnsembleSingleTestResult.passed(testId: 'case', durationMs: 12),
      ]),
      artifactRoot: '/tmp/report-root',
      displayRoot: 'build/ensemble_test_runner',
    );

    final restored = TestReportDocument.decodeCompressed(
      TestReportDocument.encodeCompressed(document),
    );

    expect(restored['state'], document['state']);
    expect(restored['summary'], document['summary']);
    expect((restored['tests'] as List).single['id'], 'case');
  });

  test('rejects a compressed payload that is not a JSON object', () {
    final bytes = TestReportDocument.encodeCompressed({'state': 'complete'});
    expect(
      () => TestReportDocument.decodeCompressed(bytes.sublist(0, 0)),
      throwsFormatException,
    );
  });
}
