import 'dart:convert';
import 'dart:io';

/// Measures the production source and executable budgets used by the runner
/// redesign. This intentionally has no package imports so it can run before
/// dependency resolution and cannot change the runtime dependency graph.
///
/// Run from the package root:
///
///     dart run tool/audit_size_budgets.dart
///     dart run tool/audit_size_budgets.dart --aot=build/runner
///     dart run tool/audit_size_budgets.dart --json
///     dart run tool/audit_size_budgets.dart --fail-on-budget
void main(List<String> arguments) {
  final json = arguments.contains('--json');
  final failOnBudget = arguments.contains('--fail-on-budget');
  final root = Directory.current.absolute;
  final maxFileLines = _intOption(arguments, '--max-file-lines') ?? 700;
  final baselineLines = _intOption(arguments, '--baseline-lines') ?? 44956;
  final aotPath = _stringOption(arguments, '--aot');
  final lib = Directory('${root.path}${Platform.pathSeparator}lib');
  if (!lib.existsSync()) {
    stderr.writeln('lib directory not found: ${lib.path}');
    exitCode = 2;
    return;
  }

  final files = <Map<String, Object?>>[];
  var handwrittenLines = 0;
  var generatedLines = 0;
  for (final entity in lib.listSync(recursive: true).whereType<File>()) {
    if (!entity.path.endsWith('.dart')) continue;
    final lines = entity.readAsLinesSync();
    final generated = _isGenerated(lines);
    final count = lines.length;
    final relative = _relative(root, entity);
    files.add({
      'path': relative,
      'lines': count,
      'generated': generated,
    });
    if (generated) {
      generatedLines += count;
    } else {
      handwrittenLines += count;
    }
  }
  files.sort((a, b) => (b['lines']! as int).compareTo(a['lines']! as int));
  final oversized = files
      .where((file) =>
          file['generated'] != true && (file['lines']! as int) > maxFileLines)
      .toList(growable: false);
  final reduction = baselineLines == 0
      ? 0.0
      : (baselineLines - handwrittenLines) / baselineLines * 100;
  final aotFile = aotPath == null ? null : File(aotPath);
  if (aotFile != null && !aotFile.existsSync()) {
    stderr.writeln('AOT executable not found: ${aotFile.path}');
    exitCode = 2;
    return;
  }
  final aotBytes = aotFile?.lengthSync();
  final overBudget = handwrittenLines > baselineLines || oversized.isNotEmpty;
  final result = <String, Object?>{
    'dartFiles': files.length,
    'handwrittenLines': handwrittenLines,
    'generatedLines': generatedLines,
    'baselineLines': baselineLines,
    'reductionPercent': double.parse(reduction.toStringAsFixed(2)),
    'maxFileLines': maxFileLines,
    'overBudget': overBudget,
    'oversizedHandwrittenFiles': oversized,
    if (aotPath != null) 'aot': {'path': aotPath, 'bytes': aotBytes},
  };

  if (json) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
  } else {
    stdout.writeln('Dart files: ${files.length}');
    stdout.writeln('Handwritten production lines: $handwrittenLines');
    stdout.writeln('Generated production lines: $generatedLines');
    stdout.writeln(
      'Reduction from $baselineLines-line baseline: '
      '${reduction.toStringAsFixed(2)}%',
    );
    stdout.writeln('Files over $maxFileLines lines:');
    if (oversized.isEmpty) {
      stdout.writeln('  none');
    } else {
      for (final file in oversized) {
        stdout.writeln('  ${file['lines']} ${file['path']}');
      }
    }
    if (aotPath != null) stdout.writeln('AOT bytes: $aotBytes ($aotPath)');
  }
  if (failOnBudget && overBudget) exitCode = 1;
}

bool _isGenerated(List<String> lines) => lines.take(20).any(
      (line) =>
          RegExp(r'^\s*//\s*GENERATED\b', caseSensitive: false).hasMatch(line),
    );

String _relative(Directory root, File file) => file.path.startsWith(root.path)
    ? file.path.substring(root.path.length + 1)
    : file.path;

String? _stringOption(List<String> arguments, String name) {
  final prefix = '$name=';
  for (final argument in arguments) {
    if (argument.startsWith(prefix)) return argument.substring(prefix.length);
  }
  return null;
}

int? _intOption(List<String> arguments, String name) {
  final value = _stringOption(arguments, name);
  if (value == null) return null;
  final parsed = int.tryParse(value);
  if (parsed == null) throw ArgumentError('$name must be an integer: $value');
  return parsed;
}
