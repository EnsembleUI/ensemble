// melos's `version` command can leave a hosted dependency constraint
// mangled, e.g. `^1.2.50-beta.13 <2.0.0"`, when the original was a compound
// range (">=1.2.50 <2.0.0") rather than a bare caret -- it only replaces the
// leading token of the old text. This repairs that shape across the
// workspace. Anything starting with `^` that doesn't fit it exactly fails
// loudly rather than being guessed at.

import 'dart:io';

import 'package:pub_semver/pub_semver.dart';

// Deliberately not restricted to the known corruption's exact tail shape,
// so a variant of it can't slip past silently -- see the fail-loudly branch.
final _caretLine = RegExp(
  r'^(?<prefix>[ \t]*[\w.-]+[ \t]*:[ \t]*)'
  r'''(?<value>["']?\^[^\r\n]*)$''',
  multiLine: true,
);

// What melos's rewrite always emits: a caret immediately followed by a
// valid version (pub_semver versions always start with a digit).
final _leadingCaretToken = RegExp(r'^\^[0-9][\w.\-+]*');

void main(List<String> args) {
  final root = Directory(args.isNotEmpty ? args[0] : '.');
  if (!root.existsSync()) {
    stderr.writeln('::error::Root directory not found: ${root.path}');
    exitCode = 1;
    return;
  }

  final pubspecs = root
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) => f.path.endsWith('pubspec.yaml'))
      .where((f) => !f.path.contains('${Platform.pathSeparator}build${Platform.pathSeparator}'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  var filesFixed = 0;
  var constraintsFixed = 0;
  var hadUnrepairable = false;

  for (final file in pubspecs) {
    final original = file.readAsStringSync();
    final matches = _caretLine.allMatches(original).toList();
    if (matches.isEmpty) continue;

    var updated = original;
    var fileChanged = false;

    for (final match in matches.reversed) {
      final rawValue = match.namedGroup('value')!;
      final logicalValue = _stripMatchedQuotes(rawValue);

      if (_tryParse(logicalValue) != null) continue; // already valid

      final tokenMatch = _leadingCaretToken.firstMatch(logicalValue);
      if (tokenMatch == null || _tryParse(tokenMatch[0]!) == null) {
        stderr.writeln(
          '::error::${file.path}: found unparseable constraint '
          '"$rawValue" that does not match the known melos corruption '
          'pattern (valid "^<version>" prefix). Needs manual review.',
        );
        hadUnrepairable = true;
        continue;
      }

      final caretToken = tokenMatch[0]!;
      final replacement = '${match.namedGroup('prefix')}$caretToken';
      updated = updated.replaceRange(match.start, match.end, replacement);
      fileChanged = true;
      constraintsFixed++;
      stdout.writeln(
        '${file.path}: repaired "$rawValue" -> "$caretToken"',
      );
    }

    if (fileChanged) {
      file.writeAsStringSync(updated);
      filesFixed++;
    }
  }

  if (hadUnrepairable) {
    stderr.writeln(
      '::error::One or more constraints looked corrupted but could not be '
      'safely auto-repaired. Aborting so a human can look.',
    );
    exitCode = 1;
    return;
  }

  if (constraintsFixed == 0) {
    stdout.writeln('No corrupted dependency constraints found.');
  } else {
    stdout.writeln(
      'Repaired $constraintsFixed constraint(s) across $filesFixed file(s).',
    );
  }
}

String _stripMatchedQuotes(String value) {
  if (value.length >= 2) {
    final first = value[0];
    final last = value[value.length - 1];
    if ((first == '"' || first == "'") && last == first) {
      return value.substring(1, value.length - 1);
    }
  }
  return value;
}

VersionConstraint? _tryParse(String value) {
  try {
    return VersionConstraint.parse(value);
  } on FormatException {
    return null;
  }
}
