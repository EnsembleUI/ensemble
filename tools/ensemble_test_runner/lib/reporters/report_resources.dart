import 'dart:io';

import 'package:ensemble_test_runner/reporters/src/report_resource_locator.dart';

/// Loads report assets from this package without adding them to Dart snapshots.
abstract final class ReportResources {
  static final Uri _root = _findRoot();
  static final String css = _read('report.css');
  static final String javascript = _read('report.js');

  static String _read(String name) {
    final asset = File.fromUri(_root.resolve(name));
    if (asset.existsSync()) return asset.readAsStringSync();
    throw StateError(
        'Cannot locate ensemble_test_runner report asset "$name".');
  }

  static Uri _findRoot() => findReportResourceRoot(_packageConfigs());

  static Iterable<File> _packageConfigs() sync* {
    final active = Platform.packageConfig;
    if (active != null && active.isNotEmpty) {
      final uri = Uri.parse(active);
      yield File.fromUri(
          uri.hasScheme ? uri : Directory.current.uri.resolveUri(uri));
    }
    yield File.fromUri(
      Directory.current.uri.resolve('.dart_tool/package_config.json'),
    );
  }
}
