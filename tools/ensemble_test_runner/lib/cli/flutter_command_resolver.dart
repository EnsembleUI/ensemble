import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves the Flutter SDK that produced an application's package graph.
///
/// A globally selected `flutter` can differ from the SDK recorded in
/// `.dart_tool/package_config.json`; invoking it against that graph produces
/// an opaque invalid-SDK-hash failure. Resolution is read-only and falls back
/// to PATH when the application has no usable package graph yet.
String resolveFlutterExecutable(
  String appDirectory, {
  String fallback = 'flutter',
}) {
  final packageConfig = File(
    p.join(appDirectory, '.dart_tool', 'package_config.json'),
  );
  if (!packageConfig.existsSync()) return fallback;

  try {
    final decoded = jsonDecode(packageConfig.readAsStringSync());
    if (decoded is! Map) return fallback;
    final packages = decoded['packages'];
    if (packages is! List) return fallback;
    for (final package in packages) {
      if (package is! Map || package['name'] != 'flutter') continue;
      final rootUri = package['rootUri'];
      if (rootUri is! String) continue;
      var root = Uri.parse(rootUri);
      if (!root.isAbsolute) {
        root = Uri.file(p.join(packageConfig.parent.path, rootUri));
      }
      final packageRoot = root.toFilePath();
      final sdkRoot = Directory(packageRoot).parent.parent.path;
      final candidate = File(p.join(sdkRoot, 'bin', 'flutter'));
      if (candidate.existsSync()) return candidate.path;
    }
  } on FormatException {
    // A partially written package graph should not prevent the CLI from
    // reporting the normal dependency/bootstrap error.
  } on IOException {
    // The fallback executable gives the caller the usual process diagnostic.
  }
  return fallback;
}
