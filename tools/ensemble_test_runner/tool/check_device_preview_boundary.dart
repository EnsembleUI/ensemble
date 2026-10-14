import 'dart:io';

/// Enforces the optional device-preview integration boundary.
///
/// The preview package is intentionally imported by one adapter only. This
/// keeps the execution and reporting layers independent from its API and
/// gives a future replacement one small integration point.
void main() {
  final lib = Directory('lib');
  final violations = <String>[];
  for (final file in lib.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart') ||
        file.path.endsWith('device_preview_adapter.dart')) {
      continue;
    }
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      if (lines[index].contains(
          "package:ensemble_device_preview/ensemble_device_preview.dart")) {
        violations.add('${file.path}:${index + 1}');
      }
    }
  }
  if (violations.isNotEmpty) {
    stderr.writeln('Device-preview import boundary violated:');
    for (final violation in violations) {
      stderr.writeln('  $violation');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('Device-preview import boundary OK.');
}
