#!/usr/bin/env dart

/// Generates LICENSES.md — an inventory of every resolved third-party package
/// and its license, plus first-party packages in this repo.
///
/// Data comes from `dart pub deps --json` in each Melos package under
/// `modules/`, `packages/`, and `tools/` (example apps are skipped). That
/// inspects the resolved graph after `melos bootstrap`, including transitives,
/// not just the pubspec manifests.
///
/// A package is `production` when it is reachable from any package's
/// `dependencies` (not `dev_dependencies`). Optional Ensemble modules are
/// included whether or not starter has them uncommented.
///
/// Usage: dart scripts/generate-license-report.dart [--out LICENSES.md]
/// Prerequisite: melos bootstrap
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const defaultOut = 'LICENSES.md';

/// Licenses that need a human decision rather than a glance: copyleft or
/// source-disclosure obligations, non-OSS terms, and anything unidentified.
/// Permissive licenses (MIT/ISC/BSD/Apache-2.0/0BSD/Unlicense/CC0) are not listed.
const needsReviewLicenses = {
  'Unknown',
  'SEE LICENSE IN README.md',
  'LGPL-3.0-or-later',
  'LGPL-3.0-only',
  'LGPL-2.1-or-later',
  'LGPL-2.1-only',
  'LGPL-2.1',
  'LGPL-3.0',
  'GPL-2.0',
  'GPL-2.0-only',
  'GPL-2.0-or-later',
  'GPL-3.0',
  'GPL-3.0-only',
  'GPL-3.0-or-later',
  'AGPL-3.0',
  'AGPL-3.0-only',
  'AGPL-3.0-or-later',
  'MPL-2.0',
  'CDDL-1.0',
  'EPL-2.0',
  'CC-BY-4.0',
  'CC-BY-SA-4.0',
  'Proprietary',
};

/// Licenses established by reading the license file shipped inside a package
/// whose detection would otherwise be `Unknown`. Only for packages where the
/// text is unambiguous. Anything uncertain stays `Unknown`.
const licenseCorrections = <String, LicenseCorrection>{
  // Filled after the first generation if a file is unambiguous but undetected.
};

/// Packages that have been reviewed and accepted. They are listed in their own
/// section rather than dropped, so the decision stays auditable.
///
/// Recording an acceptance here does NOT change the recorded license — the
/// report always states what the package actually declares.
const reviewed = <String, String>{
  // Filled after a human pass on the "Needing review" section.
};

/// Context for packages that remain `Unknown`, or proprietary terms that are
/// not an SPDX identifier.
const unknownNotes = <String, String>{
  'moengage_flutter':
      'Proprietary. LICENSE restricts use to MoEngage customers; redistribution of source or binaries is disallowed without prior written permission. The other `moengage_*` packages ship the same terms.',
};

class LicenseCorrection {
  const LicenseCorrection({required this.license, required this.source});
  final String license;
  final String source;
}

class LocalPackage {
  LocalPackage({required this.name, required this.dir, required this.version});
  final String name;
  final String dir;
  final String version;
}

class Row {
  Row({
    required this.name,
    required this.version,
    required this.license,
    required this.declared,
    required this.corrected,
    required this.reviewedNote,
    required this.scope,
    required this.homepage,
    required this.source,
  });

  final String name;
  final String version;
  final String license;
  final String declared;
  final bool corrected;
  final String? reviewedNote;
  final String scope; // production | dev | first-party | sdk
  final String homepage;
  final String source;

  String get key => '$name@$version';
}

void main(List<String> args) {
  final outIndex = args.indexOf('--out');
  final out = outIndex != -1 && outIndex + 1 < args.length
      ? args[outIndex + 1]
      : defaultOut;

  final repoRoot = Directory.current;
  final locals = discoverLocalPackages(repoRoot);
  if (locals.isEmpty) {
    stderr.writeln('No packages found under modules/, packages/, or tools/.');
    exit(1);
  }

  final missingConfig = locals
      .where(
          (p) => !File('${p.dir}/.dart_tool/package_config.json').existsSync())
      .toList();
  if (missingConfig.isNotEmpty) {
    stderr.writeln(
      'Missing .dart_tool/package_config.json. Run `melos bootstrap` first.\n'
      'First missing: ${missingConfig.first.dir}',
    );
    exit(1);
  }

  final localNames = {for (final p in locals) p.name};
  final locations = <String, String>{}; // name@version -> package root on disk
  final rowsByKey = <String, Row>{};

  for (final local in locals) {
    final graph = readPubDeps(local.dir);
    final config = readPackageConfig(local.dir);
    for (final e in config.entries) {
      locations.putIfAbsent('${e.key.name}@${e.key.version}', () => e.value);
      locations.putIfAbsent(e.key.name, () => e.value);
    }

    final prodReachable = productionReachable(graph);
    for (final pkg in graph) {
      if (pkg.name.isEmpty) continue;
      final version = pkg.source == 'sdk' ? 'SDK' : pkg.version;
      final key = '${pkg.name}@$version';
      final existing = rowsByKey[key];

      final isFirstParty =
          localNames.contains(pkg.name) || pkg.source == 'path';
      final isSdk = pkg.source == 'sdk';
      String scope;
      if (isFirstParty) {
        scope = 'first-party';
      } else if (isSdk) {
        scope = 'sdk';
      } else if (prodReachable.contains(pkg.name)) {
        scope = 'production';
      } else {
        scope = 'dev';
      }

      if (existing != null) {
        rowsByKey[key] = _preferScope(existing, scope);
        continue;
      }

      rowsByKey[key] = Row(
        name: pkg.name,
        version: version,
        license: '', // filled below
        declared: '',
        corrected: false,
        reviewedNote: reviewed[pkg.name],
        scope: scope,
        homepage: '',
        source: pkg.source,
      );
    }
  }

  // Guarantee every local package appears, even if dart pub deps omitted it.
  for (final local in locals) {
    final key = '${local.name}@${local.version}';
    rowsByKey.putIfAbsent(
      key,
      () => Row(
        name: local.name,
        version: local.version,
        license: '',
        declared: '',
        corrected: false,
        reviewedNote: reviewed[local.name],
        scope: 'first-party',
        homepage: '',
        source: 'path',
      ),
    );
    locations.putIfAbsent(key, () => local.dir);
    locations.putIfAbsent(local.name, () => local.dir);
  }

  final rows = rowsByKey.values.toList();
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    final loc = locations[r.key] ?? locations[r.name];
    String declared;
    String homepage = '';
    if (r.scope == 'sdk') {
      declared = 'BSD-3-Clause';
    } else if (loc == null) {
      declared = 'Unknown';
    } else {
      homepage = readHomepage(loc);
      declared = detectLicenseInPackage(loc) ?? 'Unknown';
    }
    final correction = licenseCorrections[r.name];
    rows[i] = Row(
      name: r.name,
      version: r.version,
      license: correction?.license ?? declared,
      declared: declared,
      corrected: correction != null,
      reviewedNote: r.reviewedNote,
      scope: r.scope,
      homepage: homepage,
      source: r.source,
    );
  }

  rows.sort((a, b) {
    final n = a.name.compareTo(b.name);
    return n != 0 ? n : a.version.compareTo(b.version);
  });

  writeReport(File(out), rows, locals.length);
  stderr.writeln(
    'Wrote $out: ${rows.length} packages, '
    '${rows.where((r) => needsReview(r.license) && r.reviewedNote == null && r.scope != 'first-party' && r.scope != 'sdk').length} needing review.',
  );
}

Row _preferScope(Row existing, String incoming) {
  const rank = {'first-party': 3, 'sdk': 2, 'production': 1, 'dev': 0};
  final keep = (rank[existing.scope] ?? 0) >= (rank[incoming] ?? 0);
  return keep
      ? existing
      : Row(
          name: existing.name,
          version: existing.version,
          license: existing.license,
          declared: existing.declared,
          corrected: existing.corrected,
          reviewedNote: existing.reviewedNote,
          scope: incoming,
          homepage: existing.homepage,
          source: existing.source,
        );
}

/// Melos packages under modules/, packages/, tools/ — not example apps.
List<LocalPackage> discoverLocalPackages(Directory repoRoot) {
  final out = <LocalPackage>[];
  for (final top in ['modules', 'packages', 'tools']) {
    final dir = Directory('${repoRoot.path}/$top');
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File ||
          !entity.path.endsWith('${Platform.pathSeparator}pubspec.yaml')) {
        continue;
      }
      final rel = entity.path.substring(repoRoot.path.length + 1);
      final parts = rel.split(Platform.pathSeparator);
      if (parts.contains('example') ||
          parts.contains('build') ||
          parts.contains('.dart_tool')) {
        continue;
      }
      final text = File(entity.path).readAsStringSync();
      final name = _yamlScalar(text, 'name');
      final version = _yamlScalar(text, 'version') ?? '0.0.0';
      if (name == null) continue;
      out.add(LocalPackage(
        name: name,
        dir: File(entity.path).parent.path,
        version: version,
      ));
    }
  }
  out.sort((a, b) => a.dir.compareTo(b.dir));
  return out;
}

String? _yamlScalar(String text, String key) {
  final re = RegExp('^$key:\\s*(.*)\\s*\$', multiLine: true);
  final m = re.firstMatch(text);
  if (m == null) return null;
  var v = m.group(1)!.trim();
  if ((v.startsWith('"') && v.endsWith('"')) ||
      (v.startsWith("'") && v.endsWith("'"))) {
    v = v.substring(1, v.length - 1);
  }
  // Ignore YAML comments after the value.
  final comment = v.indexOf(' #');
  if (comment != -1) v = v.substring(0, comment).trim();
  return v.isEmpty ? null : v;
}

class DepPkg {
  DepPkg({
    required this.name,
    required this.version,
    required this.kind,
    required this.source,
    required this.dependencies,
    required this.directDependencies,
  });

  final String name;
  final String version;
  final String kind;
  final String source;
  final List<String> dependencies;
  final List<String> directDependencies;
}

List<DepPkg> readPubDeps(String packageDir) {
  final result = Process.runSync(
    'dart',
    ['pub', 'deps', '--json', '-C', packageDir],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    stderr.writeln('dart pub deps failed in $packageDir:\n${result.stderr}');
    exit(1);
  }
  final stdout = result.stdout as String;
  final start = stdout.indexOf('{');
  if (start == -1) {
    stderr.writeln('No JSON from dart pub deps in $packageDir');
    exit(1);
  }
  final json = jsonDecode(stdout.substring(start)) as Map<String, dynamic>;
  final packages =
      (json['packages'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  return [
    for (final p in packages)
      DepPkg(
        name: p['name'] as String? ?? '',
        version: p['version'] as String? ?? '',
        kind: p['kind'] as String? ?? '',
        source: p['source'] as String? ?? '',
        dependencies: ((p['dependencies'] as List<dynamic>?) ?? [])
            .map((e) => e.toString())
            .toList(),
        directDependencies: ((p['directDependencies'] as List<dynamic>?) ?? [])
            .map((e) => e.toString())
            .toList(),
      ),
  ];
}

Set<String> productionReachable(List<DepPkg> graph) {
  final byName = {for (final p in graph) p.name: p};
  final root = graph.cast<DepPkg?>().firstWhere(
        (p) => p?.kind == 'root',
        orElse: () => null,
      );
  if (root == null) return {};
  final start = root.directDependencies.isNotEmpty
      ? root.directDependencies
      : root.dependencies;
  final seen = <String>{};
  final queue = [...start];
  while (queue.isNotEmpty) {
    final name = queue.removeLast();
    if (!seen.add(name)) continue;
    final pkg = byName[name];
    if (pkg == null) continue;
    queue.addAll(pkg.dependencies);
  }
  return seen;
}

class _NameVer {
  _NameVer(this.name, this.version);
  final String name;
  final String version;
  @override
  bool operator ==(Object other) =>
      other is _NameVer && other.name == name && other.version == version;
  @override
  int get hashCode => Object.hash(name, version);
}

/// name / name@version -> package root directory
Map<_NameVer, String> readPackageConfig(String packageDir) {
  final file = File('$packageDir/.dart_tool/package_config.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final base = file.uri;
  final out = <_NameVer, String>{};
  for (final p
      in (json['packages'] as List<dynamic>).cast<Map<String, dynamic>>()) {
    final name = p['name'] as String;
    final rootUri = p['rootUri'] as String;
    final resolved = base.resolve(rootUri);
    var path = resolved.toFilePath();
    if (path.endsWith(Platform.pathSeparator)) {
      path = path.substring(0, path.length - 1);
    }
    final version = versionFromPath(name, path) ?? '';
    out[_NameVer(name, version)] = path;
  }
  return out;
}

String? versionFromPath(String name, String path) {
  final base = path.split(Platform.pathSeparator).last;
  final prefix = '$name-';
  if (base.startsWith(prefix)) return base.substring(prefix.length);
  return null;
}

String readHomepage(String packageRoot) {
  final pubspec = File('$packageRoot/pubspec.yaml');
  if (!pubspec.existsSync()) return '';
  final text = pubspec.readAsStringSync();
  return _yamlScalar(text, 'homepage') ?? _yamlScalar(text, 'repository') ?? '';
}

const _licenseFilenames = [
  'LICENSE',
  'LICENSE.md',
  'LICENSE.txt',
  'LICENSE-MIT',
  'LICENSE-APACHE',
  'COPYING',
  'COPYING.md',
  'UNLICENSE',
  'LICENCE',
  'licence',
  'license',
];

String? detectLicenseInPackage(String packageRoot) {
  final dir = Directory(packageRoot);
  if (!dir.existsSync()) return null;
  File? found;
  for (final name in _licenseFilenames) {
    final f = File('$packageRoot/$name');
    if (f.existsSync()) {
      found = f;
      break;
    }
  }
  if (found == null) {
    // Case-insensitive fallback for unusual names like LICENSE-other.md —
    // only when the name is clearly a license file, not a licenses/ directory
    // of bundled font texts.
    try {
      found = dir.listSync().whereType<File>().cast<File?>().firstWhere(
        (f) {
          final n = f!.uri.pathSegments.last.toLowerCase();
          return n == 'license' ||
              n.startsWith('license.') ||
              n == 'copying' ||
              n == 'unlicense';
        },
        orElse: () => null,
      );
    } on FileSystemException {
      found = null;
    }
  }
  if (found == null) return null;
  final text = found.readAsStringSync();
  return detectLicenseText(text);
}

/// Identify an SPDX-ish name from license text. Only the head of the file is
/// considered so a concatenated Flutter/engine LICENSE does not pick up
/// third-party copyleft bundled later in the same file.
String? detectLicenseText(String raw) {
  var text = raw;
  final lines = text.split('\n');
  if (lines.take(8).every((l) => l.isEmpty || l.startsWith('//'))) {
    text = lines.map((l) => l.replaceFirst(RegExp(r'^//\s?'), '')).join('\n');
  }
  final head = text.substring(0, math.min(text.length, 8000));
  // Collapse wrapping so phrases split across lines still match.
  final lower = head.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  bool has(String s) => lower.contains(s.toLowerCase());

  if (has('sil open font license')) return 'OFL-1.1';
  if (has('mozilla public license version 2')) return 'MPL-2.0';
  if (has('use of source code or binaries contained within moengage sdk')) {
    return 'Proprietary';
  }
  if (has('gnu affero general public license')) {
    return has('version 3') ? 'AGPL-3.0' : 'AGPL-3.0';
  }
  if (has('gnu lesser general public license') ||
      has('gnu library general public license')) {
    if (has('version 2.1')) return 'LGPL-2.1-or-later';
    if (has('version 3')) return 'LGPL-3.0-or-later';
    return 'LGPL-3.0-or-later';
  }
  if (has('gnu general public license')) {
    if (has('version 2')) return 'GPL-2.0';
    return 'GPL-3.0';
  }
  if (has('apache license') && (has('version 2.0') || has('apache-2.0'))) {
    return 'Apache-2.0';
  }
  if (has('bsd 3-clause') ||
      has('new bsd license') ||
      has('3-clause bsd') ||
      has('modified bsd')) {
    return 'BSD-3-Clause';
  }
  if (has('bsd 2-clause') ||
      has('simplified bsd') ||
      has('2-clause bsd') ||
      has('freebsd license')) {
    return 'BSD-2-Clause';
  }
  if (has('the mit license') ||
      RegExp(r'\bmit license\b', caseSensitive: false).hasMatch(head)) {
    return 'MIT';
  }
  if (has('permission is hereby granted, free of charge')) return 'MIT';
  if (has('isc license') ||
      (has('permission to use, copy, modify, and/or distribute this software') &&
          has('provided that the above copyright'))) {
    return 'ISC';
  }
  if (has('this is free and unencumbered software released into the public domain') ||
      has('unlicense')) {
    return 'Unlicense';
  }
  if (has('creativecommons.org/publicdomain/zero') || has('cc0 1.0')) {
    return 'CC0-1.0';
  }
  if (has("this software is provided 'as-is', without any express or implied warranty") &&
      has('origin of this software')) {
    return 'Zlib';
  }
  if (has('eclipse public license') && has('2.0')) return 'EPL-2.0';
  if (has('redistribution and use in source and binary forms')) {
    if (has('neither the name')) return 'BSD-3-Clause';
    return 'BSD-2-Clause';
  }
  if (has('opensource.org/licenses/bsd-3-clause')) return 'BSD-3-Clause';
  return null;
}

String noteFor(String name) {
  if (unknownNotes.containsKey(name)) return unknownNotes[name]!;
  if (name.startsWith('moengage_')) {
    return unknownNotes['moengage_flutter'] ?? 'Not yet investigated.';
  }
  return 'Not yet investigated.';
}

Map<String, List<String>> _groupNotes(List<String> names) {
  final grouped = <String, List<String>>{};
  for (final name in names) {
    grouped.putIfAbsent(noteFor(name), () => []).add(name);
  }
  return grouped;
}

bool needsReview(String license) {
  if (needsReviewLicenses.contains(license)) return true;
  final options = license
      .split(RegExp(r'\s+OR\s+', caseSensitive: false))
      .map((s) => s.replaceAll(RegExp(r'[()]'), '').trim())
      .toList();
  if (options.length > 1) {
    return options.every(needsReviewLicenses.contains);
  }
  final conjuncts = license
      .split(RegExp(r'\s+AND\s+', caseSensitive: false))
      .map((s) => s.replaceAll(RegExp(r'[()]'), '').trim())
      .toList();
  if (conjuncts.length > 1) {
    return conjuncts.any(needsReviewLicenses.contains);
  }
  return false;
}

String md(String s) => s.replaceAll('|', '\\|');

String link(Row r) =>
    r.homepage.isNotEmpty ? '[${md(r.name)}](${r.homepage})' : md(r.name);

void writeReport(File out, List<Row> rows, int localCount) {
  final byLicense = <String, List<Row>>{};
  for (final r in rows) {
    byLicense.putIfAbsent(r.license, () => []).add(r);
  }
  final licenseSummary = [
    for (final e in byLicense.entries)
      (
        license: e.key,
        total: e.value.length,
        production: e.value.where((r) => r.scope == 'production').length,
        review: needsReview(e.key),
      ),
  ]..sort((a, b) {
      final t = b.total.compareTo(a.total);
      return t != 0 ? t : a.license.compareTo(b.license);
    });

  final flagged = rows
      .where((r) =>
          needsReview(r.license) &&
          r.reviewedNote == null &&
          r.scope != 'first-party' &&
          r.scope != 'sdk')
      .toList();
  final accepted = rows.where((r) => r.reviewedNote != null).toList();
  final firstParty = rows.where((r) => r.scope == 'first-party').toList();
  final productionCount = rows.where((r) => r.scope == 'production').length;

  final lines = <String>[];
  lines.addAll([
    '# Third-Party Licenses',
    '',
    'Generated by `dart scripts/generate-license-report.dart` from `dart pub deps --json` in',
    'each package under `modules/`, `packages/`, and `tools/` (example apps skipped). That',
    'inspects the packages actually resolved after `melos bootstrap` — so this reflects the',
    'dependency graph, including transitives, not just the manifests. Optional Ensemble',
    'modules are included whether or not they are enabled in starter.',
    '',
    'Re-run it after any dependency change; do not edit by hand.',
    '',
    '- **Packages:** ${rows.length} ($productionCount reachable from production dependencies, ${firstParty.length} first-party, $localCount local packages scanned)',
    '- **Distinct licenses:** ${byLicense.length}',
    '- **Needing review:** ${flagged.length}',
    '- **Reviewed and accepted:** ${accepted.length}',
    '',
    '`Scope` is `production` when the package is reachable from a `dependencies` edge of any',
    'scanned package, `dev` when it only arrives through `dev_dependencies`, `first-party`',
    'when it is published from this repo, and `sdk` when it comes from the Flutter/Dart SDK.',
    '',
    '## Summary by license',
    '',
    '| License | Packages | Production | Review |',
    '| --- | --- | --- | --- |',
  ]);
  for (final s in licenseSummary) {
    lines.add(
      '| ${md(s.license)} | ${s.total} | ${s.production} | ${s.review ? 'yes' : ''} |',
    );
  }
  lines.add('');

  lines.add('## Needing review');
  lines.add('');
  if (flagged.isEmpty) {
    lines.add(
      'None outstanding — every non-permissive third-party entry has been reviewed and accepted below.',
    );
  } else {
    lines.add(
      'Copyleft, source-disclosure, non-OSS, or unidentified terms. A dual license is listed only',
    );
    lines.add(
      'when every option would need review, since otherwise the permissive option applies.',
    );
    lines.add('');
    lines.add('| Package | Version | License | Scope | Homepage |');
    lines.add('| --- | --- | --- | --- | --- |');
    for (final r in flagged) {
      lines.add(
        '| ${md(r.name)} | ${md(r.version)} | ${md(r.license)} | ${r.scope} | ${r.homepage.isEmpty ? '—' : r.homepage} |',
      );
    }
  }
  lines.add('');

  if (accepted.isNotEmpty) {
    lines.addAll([
      '## Reviewed and accepted',
      '',
      'Non-permissive or unidentified terms that have been looked at and signed off, so they no',
      'longer appear above. The license column is what the package itself declares — an acceptance',
      'records a decision, it does not restate the license.',
      '',
      '| Package | Version | License | Scope | Decision |',
      '| --- | --- | --- | --- | --- |',
    ]);
    for (final r in accepted) {
      lines.add(
        '| ${md(r.name)} | ${md(r.version)} | ${md(r.license)} | ${r.scope} | ${md(r.reviewedNote!)} |',
      );
    }
    lines.add('');
  }

  final correctedNames = [
    ...{for (final r in rows.where((r) => r.corrected)) r.name},
  ]..sort();
  if (correctedNames.isNotEmpty) {
    lines.addAll([
      '## License corrections',
      '',
      'These packages could not be identified from a standard SPDX title, so detection would',
      'have reported `Unknown`. The license below was read from the license file inside the',
      'package and is used in place of `Unknown` throughout this report.',
      '',
      '| Package | Recorded as | Basis |',
      '| --- | --- | --- |',
    ]);
    for (final name in correctedNames) {
      final c = licenseCorrections[name]!;
      lines.add('| ${md(name)} | ${md(c.license)} | ${md(c.source)} |');
    }
    lines.add('');
  }

  final unknowns = [
    ...{
      for (final r in rows.where((r) =>
          (r.license == 'Unknown' || r.license == 'Proprietary') &&
          r.scope != 'first-party' &&
          r.scope != 'sdk'))
        r.name
    },
  ]..sort();
  if (unknowns.isNotEmpty) {
    lines.addAll([
      '## Notes on unidentified or proprietary licenses',
      '',
      '`Unknown` means no license file was found, or the text did not match a known SPDX',
      'identifier. `Proprietary` means the file is not an OSS license.',
      '',
    ]);
    for (final entry in _groupNotes(unknowns).entries) {
      final names = entry.value;
      final label = names.length == 1
          ? '**${md(names.single)}**'
          : '**${names.length} packages** (${names.map((n) => '`$n`').join(', ')})';
      lines.add('- $label — ${entry.key}');
    }
    lines.add('');
  }

  lines.addAll([
    '## First-party packages',
    '',
    'Published from this repository. Not a third-party obligation; listed so the inventory is complete.',
    '',
    '| Package | Version | License |',
    '| --- | --- | --- |',
  ]);
  for (final r in firstParty) {
    lines.add('| ${md(r.name)} | ${md(r.version)} | ${md(r.license)} |');
  }
  lines.add('');

  lines.addAll([
    '## All packages',
    '',
    '| Package | Version | License | Scope |',
    '| --- | --- | --- | --- |',
  ]);
  for (final r in rows) {
    lines.add(
        '| ${link(r)} | ${md(r.version)} | ${md(r.license)} | ${r.scope} |');
  }
  lines.add('');

  out.writeAsStringSync(lines.join('\n'));
}
