/// CLI output filtering for [runEnsembleYamlTestsCli].
library;

const suiteReportStart = '┌─ Ensemble YAML tests';
const screenTrackerPrefix = 'SCREEN TRACKER:';
const noDeclarativeTestsPrefix = 'No declarative tests found.';

/// Strips Flutter test framework noise; keeps navigation logs and the suite report.
String extractSuiteReport(String output) {
  final lines = output.split('\n');
  final kept = <String>[];
  var inReport = false;

  for (final line in lines) {
    if (line.startsWith(screenTrackerPrefix)) {
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
  final noTests = RegExp(
    r'No declarative tests found\. Add \*\.test\.yaml files under [^\r\n]+',
  ).firstMatch(output);
  if (noTests != null) {
    return noTests.group(0)!;
  }
  return '';
}

/// Arguments forwarded to `flutter test` (CLI-only flags removed).
List<String> flutterTestArguments(List<String> arguments) {
  return arguments
      .where(
        (a) => !a.startsWith('--app-dir') && a != '--verbose' && a != '--quiet',
      )
      .toList();
}

/// Flutter sometimes prints asset cleanup warnings after a successful run.
bool isBenignFlutterTestStderr(String stderr) {
  if (stderr.trim().isEmpty) return true;
  return stderr.contains('Failed to clean up asset directory') &&
      stderr.contains('flutter clean');
}
