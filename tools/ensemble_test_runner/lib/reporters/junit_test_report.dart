import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/result_projection.dart';

/// Serializes the machine-readable JUnit view of a completed suite.
///
/// Entry points and the host CLI all use this one projection so their test,
/// failure, duration, and XML-escaping rules cannot drift.
abstract final class JunitTestReport {
  static String build(EnsembleTestRunResult result) {
    final suite = SuiteResultProjection(result);
    final buffer = StringBuffer()
      ..writeln(
        '<testsuite name="ensemble_tests" tests="${suite.total}" '
        'failures="${suite.failed}" '
        'time="${(suite.totalDurationMs / 1000).toStringAsFixed(3)}">',
      );

    for (final test in suite.orderedResults) {
      final projection = TestResultProjection(test);
      buffer.writeln(
        '  <testcase name="${_xmlEscape(test.testId)}" '
        'time="${(projection.durationMs / 1000).toStringAsFixed(3)}">',
      );
      if (projection.attempts > 1 ||
          projection.retry > 0 ||
          projection.failedStepIndex != null ||
          projection.failureOperation != null ||
          projection.failureSource != null ||
          projection.failed) {
        buffer
          ..writeln('    <properties>')
          ..write(projection.attempts > 1 || projection.retry > 0
              ? '      <property name="ensemble.attempts" '
                  'value="${projection.attempts}"/>\n'
                  '      <property name="ensemble.retries" '
                  'value="${projection.retry}"/>\n'
              : '')
          ..write(projection.failedStepIndex == null
              ? ''
              : '      <property name="ensemble.failed_step_index" '
                  'value="${projection.failedStepIndex}"/>\n')
          ..write(projection.failureOperation == null
              ? ''
              : '      <property name="ensemble.failure.operation" '
                  'value="${_xmlEscape(projection.failureOperation!)}"/>\n')
          ..write(projection.failureSource == null
              ? ''
              : '      <property name="ensemble.failure.source.path" '
                  'value="${_xmlEscape(projection.failureSource!['path']!)}"/>\n'
                  '      <property name="ensemble.failure.source.step_path" '
                  'value="${_xmlEscape(projection.failureSource!['stepPath']!)}"/>\n')
          ..write(projection.failed
              ? '      <property name="ensemble.failure.kind" '
                  'value="${_xmlEscape(projection.failureKind ?? 'internal')}"/>\n'
              : '')
          ..writeln('    </properties>');
      }
      if (projection.failed) {
        final message = projection.failureMessage!;
        buffer
          ..writeln('    <failure message="${_xmlEscape(message)}">')
          ..writeln(_xmlEscape(projection.failureStackTrace ?? message))
          ..writeln('    </failure>');
      }
      buffer.writeln('  </testcase>');
    }
    buffer.writeln('</testsuite>');
    return buffer.toString();
  }

  static String _xmlEscape(String value) => _removeInvalidXml10Characters(value)
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  /// XML 1.0 forbids most C0 controls even when they are escaped as text.
  /// Keep tab/newline/carriage return, which are valid and useful in traces.
  static String _removeInvalidXml10Characters(String value) =>
      String.fromCharCodes(
        value.runes.where((codePoint) =>
            codePoint == 0x9 ||
            codePoint == 0xA ||
            codePoint == 0xD ||
            (codePoint >= 0x20 && codePoint <= 0xD7FF) ||
            (codePoint >= 0xE000 && codePoint <= 0xFFFD) ||
            (codePoint >= 0x10000 && codePoint <= 0x10FFFF)),
      );
}
