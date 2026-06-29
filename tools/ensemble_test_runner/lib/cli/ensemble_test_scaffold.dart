import 'dart:io';

import 'package:ensemble_test_runner/inspect/ensemble_app_inspector.dart';
import 'package:path/path.dart' as p;

const _schemaUrl =
    'https://cdn.ensembleui.com/schemas/ensemble_tests_schema.json';

class EnsembleTestScaffoldResult {
  final String path;
  final bool created;

  const EnsembleTestScaffoldResult({required this.path, required this.created});
}

class EnsembleTestScaffold {
  final String appDir;

  EnsembleTestScaffold(this.appDir);

  EnsembleTestScaffoldResult create(List<String> arguments) {
    final id = _optionValue(arguments, '--scaffold-test') ?? 'new_test';
    final normalizedId = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final inspection = EnsembleAppInspector(appDir).inspect();
    final screen = _optionValue(arguments, '--screen') ?? inspection.appHome;
    final feature = _optionValue(arguments, '--feature');
    final tags = arguments
        .where((arg) => arg.startsWith('--tag='))
        .map((arg) => arg.substring('--tag='.length))
        .where((tag) => tag.isNotEmpty)
        .toList();

    final testsDir = Directory(p.join(appDir, inspection.appPath, 'tests'));
    testsDir.createSync(recursive: true);
    Directory(p.join(testsDir.path, 'fixtures')).createSync(recursive: true);

    final file = File(p.join(testsDir.path, '$normalizedId.test.yaml'));
    if (file.existsSync()) {
      return EnsembleTestScaffoldResult(path: file.path, created: false);
    }

    final buffer = StringBuffer()
      ..writeln('# yaml-language-server: \$schema=$_schemaUrl')
      ..writeln('id: $normalizedId');
    if (feature != null && feature.isNotEmpty)
      buffer.writeln('feature: $feature');
    if (tags.isNotEmpty) buffer.writeln('tags: [${tags.join(', ')}]');
    buffer
      ..writeln('description: Describe the user behavior this test covers')
      ..writeln('startScreen: $screen')
      ..writeln('steps:')
      ..writeln('  - expectVisible:')
      ..writeln('      id: TODO_widget_test_id');

    file.writeAsStringSync(buffer.toString());
    return EnsembleTestScaffoldResult(path: file.path, created: true);
  }
}

String? _optionValue(List<String> arguments, String name) {
  for (final arg in arguments) {
    if (arg == name) return '';
    if (arg.startsWith('$name=')) return arg.substring(name.length + 1);
  }
  return null;
}
