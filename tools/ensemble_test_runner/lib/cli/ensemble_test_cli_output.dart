/// CLI output filtering for [runEnsembleYamlTestsCli].
library;

const suiteReportStart = '┌─ Ensemble YAML tests';
const screenTrackerPrefix = 'SCREEN TRACKER:';
const noDeclarativeTestsPrefix = 'No declarative tests found.';
const jsonReportPrefix = 'ENSEMBLE_TEST_JSON_REPORT:';
const junitReportPrefix = 'ENSEMBLE_TEST_JUNIT_REPORT:';
const flutterExceptionStart = '══╡ EXCEPTION CAUGHT BY ';
const flutterTakeExceptionHint =
    '(The following exception is now available via WidgetTester.takeException:)';

/// Filters stdout from a running `flutter test` process for live CLI display.
///
/// The full stdout is still captured and parsed at the end. This filter only
/// decides which lines are safe to show while the process is still running.
class LiveFlutterTestOutputFilter {
  var _suppressRest = false;

  bool shouldEmit(String line) {
    if (_suppressRest) return false;
    if (line.startsWith(jsonReportPrefix) ||
        line.startsWith(junitReportPrefix) ||
        line.startsWith(flutterTakeExceptionHint)) {
      return false;
    }
    if (line.startsWith(suiteReportStart) ||
        line.startsWith(flutterExceptionStart)) {
      _suppressRest = true;
      return false;
    }
    return line.trim().isNotEmpty;
  }
}

/// Strips Flutter test framework noise; keeps navigation logs and the suite report.
String extractSuiteReport(
  String output, {
  bool includeScreenTracker = true,
}) {
  final lines = output.split('\n');
  final kept = <String>[];
  var inReport = false;

  for (final line in lines) {
    if (includeScreenTracker && line.startsWith(screenTrackerPrefix)) {
      kept.add(line);
      continue;
    }
    if (line.startsWith(suiteReportStart)) {
      inReport = true;
    }
    if (inReport) {
      kept.add(line);
      if (line.startsWith('└─')) {
        inReport = false;
      }
    }
  }

  if (kept.isEmpty) return '';
  return '${kept.join('\n')}\n';
}

/// Whether the user asked for full subprocess output (`--verbose`).
bool isVerboseCli(List<String> arguments) => arguments.contains('--verbose');

/// Extracts known actionable failures from Flutter's framework error output.
String extractKnownFailure(String output) {
  final ensembleFailure = _extractFrameworkFailureMessage(
    output,
    'The following EnsembleTestFailure was thrown running a test:',
  );
  if (ensembleFailure.isNotEmpty) {
    return ensembleFailure;
  }

  final noTests = RegExp(
    r'No declarative tests found\. Add \*\.test\.yaml files under [^\r\n]+',
  ).firstMatch(output);
  if (noTests != null) {
    return noTests.group(0)!;
  }
  return '';
}

String _extractFrameworkFailureMessage(String output, String marker) {
  final start = output.indexOf(marker);
  if (start < 0) return '';
  final messageStart = start + marker.length;
  final messageEnd =
      output.indexOf('\n\nWhen the exception was thrown', messageStart);
  if (messageEnd < 0) return '';
  return output.substring(messageStart, messageEnd).trim();
}

String extractJsonReport(String output) {
  return _extractPrefixedReport(output, jsonReportPrefix);
}

String extractJunitReport(String output) {
  return _extractPrefixedReport(output, junitReportPrefix)
      .replaceAll(r'\n', '\n');
}

String _extractPrefixedReport(String output, String prefix) {
  for (final line in output.split('\n')) {
    if (line.startsWith(prefix)) {
      return line.substring(prefix.length);
    }
  }
  return '';
}

/// Arguments forwarded to `flutter test` (CLI-only flags removed).
List<String> flutterTestArguments(List<String> arguments) {
  final forwarded = <String>[];
  for (var i = 0; i < arguments.length; i++) {
    final a = arguments[i];
    if (a == '--input') {
      i++;
      continue;
    }
    if (a.startsWith('--input=')) continue;
    if (a.startsWith('--app-dir') ||
        a.startsWith('--report') ||
        a == '--doctor' ||
        a == '--inspect-app' ||
        a == '--validate-only' ||
        a == '--scaffold-test' ||
        a.startsWith('--scaffold-test=') ||
        a.startsWith('--screen=') ||
        a.startsWith('--id=') ||
        a.startsWith('--feature=') ||
        a.startsWith('--tag=') ||
        a.startsWith('--path=') ||
        a.startsWith('--jobs=') ||
        a.startsWith('--timeout=') ||
        a == '--verbose' ||
        a == '--quiet') {
      continue;
    }
    forwarded.add(a);
  }
  return forwarded;
}

/// Flutter sometimes prints asset cleanup warnings after a successful run.
bool isBenignFlutterTestStderr(String stderr) {
  if (stderr.trim().isEmpty) return true;
  return stderr.contains('Failed to clean up asset directory') &&
      stderr.contains('flutter clean');
}
