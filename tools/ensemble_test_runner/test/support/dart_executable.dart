import 'dart:io';

String findDartExecutable() {
  final expectedName = Platform.isWindows ? 'dart.exe' : 'dart';
  final resolved = File(Platform.resolvedExecutable);
  if (resolved.uri.pathSegments.last == expectedName) {
    return resolved.path;
  }

  final pathValue = Platform.environment['PATH'];
  if (pathValue != null) {
    for (final directory in pathValue.split(Platform.isWindows ? ';' : ':')) {
      final candidate =
          File('$directory${Platform.pathSeparator}$expectedName');
      if (candidate.existsSync()) return candidate.path;
    }
  }

  throw StateError('Could not locate the Dart SDK executable on PATH.');
}
