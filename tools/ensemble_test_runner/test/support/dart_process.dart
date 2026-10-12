import 'dart:io';

import 'package:ensemble_test_runner/cli/flutter_command_resolver.dart';
import 'package:path/path.dart' as p;

Future<ProcessResult> runDartScript(
  String script, {
  List<String> arguments = const [],
}) {
  final packageRoot = Directory.current.path;
  final flutter = resolveFlutterExecutable(packageRoot);
  final dart =
      flutter == 'flutter' ? 'dart' : p.join(p.dirname(flutter), 'dart');
  final packageConfig =
      p.join(packageRoot, '.dart_tool', 'package_config.json');

  return Process.run(
    dart,
    ['--packages=$packageConfig', script, ...arguments],
    workingDirectory: packageRoot,
  );
}
