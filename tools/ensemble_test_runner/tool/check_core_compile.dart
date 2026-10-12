import 'dart:io';

/// Compiles every pure-Dart core library with the Dart SDK.
///
/// This complements [check_core_imports.dart]: the import checker enforces the
/// dependency direction, while this command proves that the complete core
/// surface can be compiled without invoking Flutter. Run it from the package
/// root:
///
///     dart run tool/check_core_compile.dart
///
/// The temporary executable is always removed, including after a compiler
/// failure. A non-zero compiler exit code is returned unchanged.
Future<void> main() async {
  final root = Directory.current.absolute;
  final probe = File(_join(root.path, 'tool', 'core_compile_probe.dart'));
  if (!probe.existsSync()) {
    stderr.writeln('Core compile probe not found: ${probe.path}');
    exitCode = 2;
    return;
  }
  final expectedImports = _coreImports(root);
  final probeText = probe.readAsStringSync();
  final missingImports = expectedImports
      .where((uri) => !probeText.contains("'$uri';"))
      .toList(growable: false);
  if (missingImports.isNotEmpty) {
    stderr.writeln('Core compile probe is missing core libraries:');
    for (final uri in missingImports) {
      stderr.writeln('  $uri');
    }
    exitCode = 1;
    return;
  }

  final temp = await Directory.systemTemp.createTemp('ensemble-core-compile-');
  final output = File(_join(temp.path, 'core_probe'));
  try {
    final result = await Process.run(
      Platform.resolvedExecutable,
      <String>['compile', 'exe', probe.path, '-o', output.path],
      workingDirectory: root.path,
    );
    if (result.stdout.toString().trim().isNotEmpty) {
      stdout.write(result.stdout);
    }
    if (result.exitCode != 0) {
      if (result.stderr.toString().trim().isNotEmpty) {
        stderr.write(result.stderr);
      }
      exitCode = result.exitCode;
      return;
    }
    if (!output.existsSync() || output.lengthSync() == 0) {
      stderr.writeln('Dart compiler produced no core probe executable.');
      exitCode = 1;
      return;
    }
    stdout.writeln(
      'Core standalone compile OK '
      '(${output.lengthSync()} bytes, Dart ${Platform.version.split(' ').first}).',
    );
  } finally {
    await temp.delete(recursive: true);
  }
}

List<String> _coreImports(Directory root) {
  final core = Directory(_joinParts(root.path, 'lib', 'src', 'core'));
  final files = core
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.path.substring(root.path.length + 1))
      .map((path) => path.replaceAll(Platform.pathSeparator, '/'))
      .map((path) => 'package:ensemble_test_runner/${path.substring(4)}')
      .toList()
    ..sort();
  return files;
}

String _join(String first, String second, [String? third]) {
  final separator = Platform.pathSeparator;
  final parts = <String>[first, second, if (third != null) third];
  return parts.join(separator);
}

String _joinParts(String first, String second, String third, String fourth) =>
    <String>[first, second, third, fourth].join(Platform.pathSeparator);
