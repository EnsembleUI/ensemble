import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/cli/ensemble_test_cli_output.dart';
import 'package:ensemble_test_runner/runner/diagnostic_redaction.dart';
import 'package:path/path.dart' as p;

/// Owns the optional application console artifact produced by a child run.
///
/// Keeping capture here leaves process lifecycle code focused on streams and
/// exit status while making filtering and the size limit explicit.
final class CliAppConsoleLog {
  static const maxBytes = 5 * 1024 * 1024;

  static final _bytesByPath = <String, int>{};
  static final _disabledPaths = <String>{};

  static String relativePath({int? workerIndex}) {
    final name = workerIndex == null
        ? 'app_console.log'
        : 'app_console_${workerIndex + 1}.log';
    return p.join('build', 'ensemble_test_runner', 'logs', name);
  }

  static String filePath(String appDirectory, {int? workerIndex}) {
    return p.join(appDirectory, relativePath(workerIndex: workerIndex));
  }

  static File? open(String? path) {
    if (path == null) return null;
    final file = File(path);
    try {
      file.parent.createSync(recursive: true);
      final header = 'createdAt: ${DateTime.now().toIso8601String()}\n';
      file.writeAsStringSync(header);
      _bytesByPath[file.path] = utf8.encode(header).length;
      _disabledPaths.remove(file.path);
      return file;
    } on FileSystemException {
      return null;
    }
  }

  static void append(File? file, String stream, String line) {
    if (file == null || !_isApplicationLine(line)) return;
    final path = file.path;
    if (_disabledPaths.contains(path)) return;

    final entry = '[$stream] ${redactDiagnosticText(line)}\n';
    final bytes = utf8.encode(entry).length;
    final currentBytes = _bytesByPath[path] ?? file.lengthSync();
    if (currentBytes + bytes > maxBytes) {
      _appendFinal(
        file,
        '[runner] app console log truncated at '
        '${(maxBytes / (1024 * 1024)).toStringAsFixed(0)} MB\n',
      );
      _disabledPaths.add(path);
      return;
    }

    try {
      file.writeAsStringSync(entry, mode: FileMode.append);
      _bytesByPath[path] = currentBytes + bytes;
    } on FileSystemException {
      _disabledPaths.add(path);
    }
  }

  static bool _isApplicationLine(String line) {
    return !line.startsWith(jsonReportPrefix) &&
        !line.startsWith(junitReportPrefix);
  }

  static void _appendFinal(File file, String line) {
    try {
      file.writeAsStringSync(line, mode: FileMode.append);
      _bytesByPath[file.path] =
          (_bytesByPath[file.path] ?? 0) + utf8.encode(line).length;
    } on FileSystemException {
      // Diagnostics must not make the test process fail.
    }
  }
}
