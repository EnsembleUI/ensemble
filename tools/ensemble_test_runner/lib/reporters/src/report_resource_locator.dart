import 'dart:convert';
import 'dart:io';

/// Finds report resources relative to the package root recorded in each config.
///
/// A stale or unreadable active config must not prevent a valid fallback
/// config from resolving the package in a workspace, path, or Git cache.
Uri findReportResourceRoot(Iterable<File> packageConfigs) {
  for (final config in packageConfigs) {
    try {
      if (!config.existsSync()) continue;
      final decoded = jsonDecode(config.readAsStringSync());
      if (decoded is! Map || decoded['packages'] is! List) continue;
      for (final entry in decoded['packages'] as List) {
        if (entry is! Map || entry['name'] != 'ensemble_test_runner') {
          continue;
        }
        final rootUri = entry['rootUri'];
        if (rootUri is! String) continue;
        var root = config.uri.resolve(rootUri);
        // Package resources are read from the local package installation.
        // Ignore malformed or remote roots so one stale config cannot block
        // a later valid workspace/path/Git config.
        if (!root.isScheme('file')) continue;
        if (!root.path.endsWith('/')) {
          root = root.replace(path: '${root.path}/');
        }
        final resources = root.resolve('resources/report/');
        if (File.fromUri(resources.resolve('report.css')).existsSync() &&
            File.fromUri(resources.resolve('report.js')).existsSync()) {
          return resources;
        }
      }
    } on FormatException {
      // Package config JSON can be stale while tooling is updating it.
      continue;
    } on FileSystemException {
      // Keep searching other package-config locations.
      continue;
    }
  }
  throw StateError(
    'Cannot locate ensemble_test_runner report resources. '
    'Run with a package config that includes this package and its resources.',
  );
}
