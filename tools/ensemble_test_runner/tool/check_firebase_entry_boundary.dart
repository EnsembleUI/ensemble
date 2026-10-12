import 'dart:io';

import 'package:path/path.dart' as p;

const _packagePrefix = 'package:ensemble_test_runner/';
final _importPattern =
    RegExp("(?:import|export|part)\\\\s+['\\\"]([^'\\\"]+)['\\\"]");

void main() {
  final packageRoot = Directory.current.absolute;
  const entryPoints = [
    'lib/entry/ensemble_integration_test_entry.dart',
    'lib/entry/application_test_entry.dart',
  ];
  final violations = <String>[];

  for (final entry in entryPoints) {
    for (final path in _reachableRunnerLibraries(packageRoot, entry)) {
      if (p.split(path).any(
            (segment) => segment.toLowerCase().contains('firebase'),
          )) {
        violations
            .add('$entry reaches ${p.relative(path, from: packageRoot.path)}');
      }
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('Firebase import boundary violated:');
    for (final violation in violations) {
      stderr.writeln('  $violation');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('Firebase import boundary OK for no-Firebase entry points.');
}

Set<String> _reachableRunnerLibraries(Directory root, String entry) {
  final pending = <String>[p.join(root.path, entry)];
  final visited = <String>{};

  while (pending.isNotEmpty) {
    final filePath = p.normalize(pending.removeLast());
    if (!visited.add(filePath)) continue;
    final file = File(filePath);
    if (!file.existsSync()) continue;

    for (final match in _importPattern.allMatches(file.readAsStringSync())) {
      final uri = match.group(1)!;
      String? resolved;
      if (uri.startsWith(_packagePrefix)) {
        resolved =
            p.join(root.path, 'lib', uri.substring(_packagePrefix.length));
      } else if (!uri.startsWith('package:') && !uri.startsWith('dart:')) {
        resolved = p.normalize(p.join(p.dirname(filePath), uri));
      }
      if (resolved != null && resolved.startsWith(p.join(root.path, 'lib'))) {
        pending.add(resolved);
      }
    }
  }
  return visited;
}
