// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:path/path.dart' as p;

/// Coordinates ownership of the shared suite artifact directory.
///
/// Worker processes intentionally share the directory after the top-level
/// invocation has acquired this lock.
final class CliRunArtifactLock {
  CliRunArtifactLock(String appDir)
      : _file = File(
          p.join(appDir, 'build', 'ensemble_test_runner', '.run.lock'),
        );

  final File _file;
  bool _acquired = false;

  bool acquire() {
    try {
      return _create();
    } on PathExistsException {
      if (!_removeStaleLock()) return false;
      try {
        return _create();
      } on FileSystemException {
        return false;
      }
    } on FileSystemException {
      return false;
    }
  }

  bool _create() {
    _file.parent.createSync(recursive: true);
    _file.createSync(exclusive: true);
    _file.writeAsStringSync(
      'pid=$pid\nstartedAt=${DateTime.now().toUtc().toIso8601String()}\n',
      flush: true,
    );
    _acquired = true;
    return true;
  }

  bool _removeStaleLock() {
    try {
      final contents = _file.readAsStringSync();
      final match =
          RegExp(r'^pid=(\d+)$', multiLine: true).firstMatch(contents);
      final ownerPid = int.tryParse(match?.group(1) ?? '');
      if (ownerPid == null) {
        final age = DateTime.now().difference(_file.statSync().modified);
        if (age < const Duration(seconds: 30)) return false;
      } else if (_isProcessAlive(ownerPid)) {
        return false;
      }
      _file.deleteSync();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  bool _isProcessAlive(int processId) {
    final result = Process.runSync('kill', ['-0', '$processId']);
    return result.exitCode == 0;
  }

  void release() {
    if (!_acquired) return;
    try {
      _file.deleteSync();
    } on FileSystemException {
      // Cleanup must not hide the test result.
    }
    _acquired = false;
  }
}
