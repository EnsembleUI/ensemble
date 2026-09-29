import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'benchmarks/history.dart';
import 'benchmarks/report.dart';
import 'benchmarks/results.dart';
import 'benchmarks/operation_cases.dart';

const _prefix = 'ENSEMBLE_BENCHMARK_V1:';

Future<void> main(List<String> arguments) async {
  try {
    await run(arguments);
  } catch (error, stack) {
    stderr.writeln('Benchmark failed: $error');
    if (arguments.contains('--verbose')) stderr.writeln(stack);
    exitCode = 1;
  }
}

Future<void> run(List<String> arguments) async {
  final flags = <String>{}, values = <String, String>{};
  for (final argument in arguments) {
    if (!argument.startsWith('--'))
      throw ArgumentError('Expected --option: $argument');
    final equal = argument.indexOf('=');
    if (equal < 0) {
      flags.add(argument.substring(2));
    } else {
      values[argument.substring(2, equal)] = argument.substring(equal + 1);
    }
  }
  const acceptedFlags = {
    'help',
    'history',
    'list',
    'check-coverage',
    'verbose',
    'prune-details'
  };
  const acceptedValues = {
    'preset',
    'service',
    'mode',
    'device',
    'compare',
    'root',
    'import',
    'samples',
    'warmup',
    'min-sample-ms',
    'case',
    'flutter',
    'retention-days',
    'isolation'
  };
  final unknown = {
    ...flags.difference(acceptedFlags),
    ...values.keys.toSet().difference(acceptedValues)
  };
  if (unknown.isNotEmpty) throw ArgumentError('Unknown options: $unknown');
  if (flags.contains('help')) {
    stdout.writeln(
        '''Standalone runner benchmark (run from tools/ensemble_test_runner)
--preset=quick|full          Default quick; full isolates each case in a process
--service=screenshot,observer --case=<case-id>
--mode=widget|integration    Integration requires --device=<id>
--samples=N --warmup=N --min-sample-ms=N
--compare=<run-id>           Pin a compatible baseline
--history --import=<export.json> --prune-details --retention-days=30
--list --check-coverage --root=<directory> --flutter=<executable> --verbose''');
    return;
  }
  final package = File.fromUri(Platform.script).parent.parent;
  final requestedRoot = Directory(p
      .absolute(values['root'] ?? p.join(package.path, '.ensemble_benchmarks')))
    ..createSync(recursive: true);
  final root = Directory(requestedRoot.resolveSymbolicLinksSync());
  final history = BenchmarkHistory(root);
  try {
    if (values.containsKey('import')) {
      final imported = jsonDecode(File(values['import']!).readAsStringSync())
          as Map<String, dynamic>;
      final inserted = await history.record(imported);
      stdout.writeln(inserted
          ? 'Imported ${imported['runId']}'
          : 'Already stored ${imported['runId']}');
      writeBenchmarkReport(
          File(p.join(root.path, 'index.html')), await history.runs());
      return;
    }
    if (flags.contains('prune-details')) {
      history.pruneDetails(
          days: _integer(values, 'retention-days', 30, min: 1));
      stdout.writeln('Pruned expired detail files; compact history retained.');
      return;
    }
    if (flags.contains('history')) {
      final runs = await history.runs();
      writeBenchmarkReport(File(p.join(root.path, 'index.html')), runs);
      if (runs.isEmpty) {
        stdout.writeln(
            'No benchmark runs are stored yet. Run --preset=quick to create the first one.');
      }
      for (final r in runs)
        stdout.writeln(
            '${r['runId']} ${r['timestamp']} ${r['branch']} ${r['commit']} ${r['mode']}');
      stdout.writeln('Report: ${p.join(root.path, 'index.html')}');
      return;
    }
    checkInstrumentedOperations(package);
    final preset = values['preset'] ?? 'quick',
        mode = values['mode'] ?? 'widget';
    if (values['isolation'] != null &&
        !['shared', 'case'].contains(values['isolation']))
      throw ArgumentError('Invalid isolation');
    if (!['quick', 'full'].contains(preset) ||
        !['widget', 'integration'].contains(mode))
      throw ArgumentError('Invalid preset or mode');
    if (mode == 'integration' && (values['device'] ?? '').isEmpty)
      throw ArgumentError('Integration requires --device=<id>');
    final flutter = values['flutter'] ?? defaultFlutterExecutable();
    final resolved = await Process.run(flutter, ['pub', 'get', '--offline'],
        workingDirectory: package.path);
    if (resolved.exitCode != 0)
      throw StateError(
          'Resolve dependencies for the selected Flutter SDK with melos bootstrap first: ${resolved.stderr}');
    final version = await Process.run(flutter, ['--version', '--machine']);
    if (version.exitCode != 0)
      throw StateError('Flutter unavailable: ${version.stderr}');
    final sdk = jsonDecode(version.stdout.toString()) as Map<String, dynamic>;
    Map<String, dynamic>? deviceIdentity;
    if (mode == 'integration') {
      final devices = await Process.run(flutter, ['devices', '--machine']);
      if (devices.exitCode != 0)
        throw StateError(
            'Cannot read benchmark device identity: ${devices.stderr}');
      final matches = (jsonDecode(devices.stdout.toString()) as List)
          .where((device) => device['id'] == values['device'])
          .toList();
      if (matches.length != 1)
        throw ArgumentError(
            'Benchmark device is not connected: ${values['device']}');
      final device = matches.single as Map;
      deviceIdentity = {
        for (final key in ['id', 'name', 'targetPlatform', 'sdk', 'emulator'])
          key: device[key]
      };
    }
    final fixtureHash = _fixtureHash(package);
    final implementationHash = _implementationHash(package);
    final runId = '${DateTime.now().toUtc().microsecondsSinceEpoch}_$pid';
    final runRoot = Directory(p.join(root.path, 'runs', runId))
      ..createSync(recursive: true);
    final options = <String, Object?>{
      'preset': preset,
      'mode': mode,
      'services': (values['service'] ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
      'case': values['case'],
      'warmups': _integer(values, 'warmup', preset == 'quick' ? 3 : 5, min: 0),
      'samples':
          _integer(values, 'samples', preset == 'quick' ? 10 : 30, min: 1),
      'minimumSampleMs': _integer(values, 'min-sample-ms', 200, min: 0),
      'fixtureRoot': p.join(runRoot.path, 'fixtures'),
      'workerOutput': p.join(runRoot.path, 'catalogue.json.gz'),
      'catalogueOnly': true
    };
    String? host;
    if (mode == 'integration')
      host = await _prepareHost(package, runRoot, flutter, values['device']!);
    final catalogue = await _worker(package, runRoot, flutter, options,
        host: host,
        device: values['device'],
        verbose: flags.contains('verbose'));
    final selected =
        (catalogue['selected'] as List).cast<Map<String, dynamic>>();
    final knownServices =
        (catalogue['catalogue'] as List).map((c) => c['service']).toSet();
    final unknownServices =
        (options['services'] as List).toSet().difference(knownServices);
    if (unknownServices.isNotEmpty)
      throw ArgumentError('Unknown benchmark services: $unknownServices');
    final emptyServices = (options['services'] as List)
        .where((service) => !selected.any((c) =>
            c['service'] == service ||
            (c['operations'] as List)
                .any((op) => op.toString().startsWith('$service.'))))
        .toList();
    if (emptyServices.isNotEmpty)
      throw ArgumentError(
          'No $preset cases match services $emptyServices; use --preset=full');
    if (options['case'] != null &&
        !selected.any((c) => c['id'] == options['case']))
      throw ArgumentError('Unknown benchmark case ${options['case']}');
    if (selected.isEmpty)
      throw ArgumentError('No benchmark cases match the selection');
    if (flags.contains('list') || flags.contains('check-coverage')) {
      for (final c in catalogue['catalogue'] as List)
        stdout.writeln(
            '${c['id']} [${c['service']}]${c['skipReason'] == null ? '' : ' — ${c['skipReason']}'}');
      stdout.writeln('Catalogue checked; ${selected.length} cases selected.');
      return;
    }
    options['catalogueOnly'] = false;
    final suiteWatch = Stopwatch()..start();
    final caseResults = <Map<String, dynamic>>[],
        workerResults = <Map<String, dynamic>>[];
    final isolateCases = values['isolation'] != 'shared' &&
        (preset == 'full' || selected.any((c) => c['cold'] == true));
    if (isolateCases) {
      for (final c in selected) {
        stdout.writeln('Benchmark ${c['id']}');
        final rounds = c['cold'] == true ? (options['samples'] as int) : 1;
        final combined = <Map<String, dynamic>>[];
        for (var round = 0; round < rounds; round++) {
          final result = await _worker(
              package,
              runRoot,
              flutter,
              {
                ...options,
                'case': c['id'],
                'isolatedCase': true,
                'includeControls': false,
                'services': <String>[],
                if (c['cold'] == true) 'samples': 1,
                'sampleOffset': round,
                'fixtureRoot': p.join(
                    runRoot.path, 'fixtures', c['id'] as String, '$round'),
                'workerOutput': p.join(
                    runRoot.path, 'worker-output', '${c['id']}.$round.json.gz')
              },
              host: host,
              device: values['device'],
              verbose: flags.contains('verbose'));
          combined.addAll((result['cases'] as List).map((row) => {
                ...Map<String, dynamic>.from(row as Map),
                'processId': result['processId']
              }));
          workerResults.add({...result}..remove('cases'));
        }
        final first = combined.first;
        caseResults.add({
          ...first,
          if (c['cold'] == true)
            'resources': {
              'scope': 'fresh-process-per-sample',
              'processes': [
                for (final row in combined)
                  {'processId': row['processId'], ...row['resources'] as Map}
              ]
            },
          'samples': [for (final r in combined) ...r['samples'] as List],
          'status': combined.any((r) => r['status'] == 'invalid')
              ? 'invalid'
              : first['status'],
        });
      }
    } else {
      final result = await _worker(
          package,
          runRoot,
          flutter,
          {
            ...options,
            'workerOutput':
                p.join(runRoot.path, 'worker-output', 'quick.json.gz')
          },
          host: host,
          device: values['device'],
          verbose: flags.contains('verbose'));
      caseResults
          .addAll((result['cases'] as List).cast<Map<String, dynamic>>());
      workerResults.add({...result}..remove('cases'));
    }
    final summaries = [for (final c in caseResults) summarizeCase(c)];
    final selectedIds = selected.map((c) => c['id']).toSet();
    final skippedIds = summaries
        .where((c) => c['status'] == 'skipped')
        .map((c) => c['id'])
        .toSet();
    final expectedOperations = operationCases.entries
        .where((entry) => selectedIds.contains(entry.value))
        .map((entry) => entry.key)
        .toSet();
    final observedOperations = summaries
        .expand((c) =>
            (c['operations'] as List? ?? []).map((op) => op['key'] as String))
        .toSet();
    final skippedOperations = operationCases.entries
        .where((entry) => skippedIds.contains(entry.value))
        .map((entry) => entry.key)
        .toSet();
    final missingOperations = expectedOperations
        .difference(observedOperations)
        .difference(skippedOperations)
        .toList()
      ..sort();
    final metadata = <String, dynamic>{
      'schemaVersion': benchmarkSchemaVersion,
      'runId': runId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'commit': _git(package, ['rev-parse', 'HEAD']),
      'branch': Platform.environment['GITHUB_HEAD_REF']?.isNotEmpty == true
          ? Platform.environment['GITHUB_HEAD_REF']
          : Platform.environment['GITHUB_REF_TYPE'] == 'branch'
              ? Platform.environment['GITHUB_REF_NAME']
              : _git(package, ['rev-parse', '--abbrev-ref', 'HEAD']),
      'dirty': _git(package, ['status', '--porcelain']).isNotEmpty,
      'implementationHash': implementationHash,
      'sourceChangedDuringRun': fixtureHash != _fixtureHash(package) ||
          implementationHash != _implementationHash(package),
      'preset': preset,
      'mode': mode,
      'workers': 1,
      'selection': {'services': options['services'], 'case': options['case']},
      'suiteWallMs': suiteWatch.elapsedMilliseconds,
      'longestWorkerWallMs': workerResults
          .map((w) => (w['processWallMs'] as num?) ?? 0)
          .fold<num>(0, (a, b) => a > b ? a : b),
      'protocol': {
        'warmups': options['warmups'],
        'samples': options['samples'],
        'minimumSampleMs': options['minimumSampleMs'],
        'isolation': isolateCases ? 'case' : 'shared'
      },
      'catalogueHash': sha256
          .convert(utf8.encode(jsonEncode(catalogue['catalogue'])))
          .toString(),
      'environment': {
        'flutterRevision': sdk['frameworkRevision'],
        'engineRevision': sdk['engineRevision'],
        'flutterVersion': sdk['frameworkVersion'],
        'dartVersion': sdk['dartSdkVersion'],
        'os': Platform.operatingSystem,
        'osVersion': Platform.environment['ENSEMBLE_BENCHMARK_OS_VERSION'] ??
            Platform.operatingSystemVersion,
        'host': Platform.environment['ENSEMBLE_BENCHMARK_HOST'] ??
            Platform.localHostname,
        'processors': Platform.numberOfProcessors,
        'device': values['device'],
        'deviceIdentity': deviceIdentity,
        'display': catalogue['bindingEnvironment'],
        'buildMode': 'debug',
        'binding': mode == 'widget' ? 'live-only-pumps' : 'integration',
        'lockHash': _hashFile(File(p.join(package.path, 'pubspec.lock'))),
        'fixtureSourceHash': fixtureHash,
        'codec': _codecMetadata(package)
      },
      'workerResults': workerResults,
      'cases': summaries,
      'collectionOverhead': {
        for (final c in summaries
            .where((c) => c['id'].toString().startsWith('control.')))
          c['id'] as String: c['timePerOperationUs']
      },
      'coverage': {
        'catalogueCases': (catalogue['catalogue'] as List).length,
        'selected': selected.length,
        'measured': summaries.where((c) => c['status'] == 'measured').length,
        'skipped': summaries.where((c) => c['status'] == 'skipped').length,
        'invalid': summaries.where((c) => c['status'] == 'invalid').length,
        'missing': missingOperations.length,
        'operations': {
          'declared': operationCases.length,
          'selected': expectedOperations.length,
          'measured':
              expectedOperations.intersection(observedOperations).length,
          'skipped': skippedOperations.length,
          'missing': missingOperations
        }
      }
    };
    if (metadata['sourceChangedDuringRun'] == true)
      throw StateError(
          'Runner or fixture sources changed during the benchmark; raw worker output is retained, rerun with a stable checkout');
    final baseline = await history.baseline(metadata, id: values['compare']);
    metadata['baselineRunId'] = baseline?['runId'];
    metadata['comparison'] =
        baseline == null ? <Object>[] : compareCases(metadata, baseline);
    writeJson(
        File(p.join(runRoot.path, 'manifest.json')),
        {...metadata}
          ..remove('cases')
          ..remove('comparison'));
    writeJson(File(p.join(runRoot.path, 'summary.json')), metadata);

    final allSamples = <Map<String, dynamic>>[];
    final traceFile = File(p.join(runRoot.path, 'spans.jsonl.gz')).openWrite();
    final trace = gzip.encoder.startChunkedConversion(traceFile);
    for (final c in caseResults)
      for (final raw in c['samples'] as List? ?? []) {
        final s = Map<String, dynamic>.from(raw as Map);
        final spans = s['spans'] as List? ??
            jsonDecode(utf8.decode(gzip.decode(
                File(s['spansPath'] as String).readAsBytesSync()))) as List;
        allSamples.add({...s}
          ..remove('spans')
          ..remove('spansPath')
          ..remove('summary'));
        for (final span in spans)
          trace.add(utf8.encode('${jsonEncode(span)}\n'));
        await traceFile.flush();
      }
    trace.close();
    await traceFile.close();
    writeJson(File(p.join(runRoot.path, 'export.json')), {
      ...metadata,
      'samples': [
        for (final s in allSamples) {...s}..remove('spans')
      ]
    });
    await history.record(metadata, samples: allSamples);
    writeBenchmarkReport(
        File(p.join(root.path, 'index.html')), await history.runs());
    history.pruneDetails();
    stdout.writeln('Run $runId: ${metadata['coverage']}');
    stdout.writeln('Baseline: ${baseline?['runId'] ?? 'no baseline'}');
    stdout.writeln('Report: ${p.join(root.path, 'index.html')}');
    stdout.writeln('Export: ${p.join(runRoot.path, 'export.json')}');
    if (summaries.any((c) => c['status'] == 'invalid')) exitCode = 1;
    if (missingOperations.isNotEmpty) {
      stderr
          .writeln('Expected operations were not measured: $missingOperations');
      exitCode = 1;
    }
  } finally {
    await history.close();
  }
}

Future<Map<String, dynamic>> _worker(Directory package, Directory runRoot,
    String flutter, Map<String, Object?> options,
    {String? host, String? device, bool verbose = false}) async {
  final output = File(options['workerOutput'] as String);
  output.parent.createSync(recursive: true);
  final arguments = [
    'test',
    if (host == null)
      p.join(package.path, 'tool', 'benchmarks', 'widget_entry.dart')
    else
      'integration_test/benchmark_test.dart',
    '--no-pub',
    '--reporter=expanded',
    if (host != null) ...['-d', device!],
    '--dart-define=ensembleBenchmarkOptions=${jsonEncode(options)}',
    '--dart-define=ensembleTestArtifactRoot=${options['fixtureRoot']}',
    '--dart-define=ensembleTestArtifactDisplayRoot=${options['fixtureRoot']}',
    '--dart-define=ensembleTestExecutionMode=${options['mode']}',
    '--dart-define=ensembleBenchmarkDart=${Platform.resolvedExecutable}',
    '--dart-define=ensembleBenchmarkFlutter=$flutter',
    '--dart-define=ensembleBenchmarkPackageRoot=${package.path}'
  ];
  final clock = Stopwatch()..start();
  int? readyMs;
  final process = await Process.start(flutter, arguments,
      workingDirectory: host ?? package.path);
  final lines = <String>[];
  Future<void> listen(Stream<List<int>> stream) async {
    await for (final line
        in stream.transform(utf8.decoder).transform(const LineSplitter())) {
      lines.add(line);
      if (line.contains('${_prefix}ready'))
        readyMs ??= clock.elapsedMilliseconds;
      if (verbose || line.contains('${_prefix}case:')) stdout.writeln(line);
    }
  }

  await Future.wait([listen(process.stdout), listen(process.stderr)]);
  final code = await process.exitCode;
  File(p.join(runRoot.path, 'worker.log'))
      .writeAsStringSync(lines.join('\n') + '\n', mode: FileMode.append);
  if (code != 0)
    throw StateError(
        'Benchmark worker exited $code. See ${p.join(runRoot.path, 'worker.log')}:\n${lines.skip((lines.length - 15).clamp(0, lines.length)).join('\n')}');
  if (host != null) {
    final chunks = <int>[];
    String? expected;
    int? size;
    bool complete = false;
    for (final line in lines) {
      final index = line.indexOf(_prefix);
      if (index < 0) continue;
      final raw = line.substring(index + _prefix.length);
      if (!raw.startsWith('{')) continue;
      final item =
          jsonDecode(raw.substring(0, raw.lastIndexOf('}') + 1)) as Map;
      switch (item['event']) {
        case 'start':
          chunks.clear();
          expected = item['sha256'] as String;
          size = item['size'] as int;
        case 'chunk':
          if (item['offset'] != chunks.length)
            throw StateError('Missing benchmark transport chunk');
          chunks.addAll(base64Decode(item['data'] as String));
        case 'end':
          complete = item['sha256'] == expected;
      }
    }
    if (!complete ||
        size != chunks.length ||
        sha256.convert(chunks).toString() != expected)
      throw StateError('Incomplete benchmark device results');
    output.writeAsBytesSync(chunks);
  }
  if (!output.existsSync()) throw StateError('Worker produced no results');
  final result = jsonDecode(utf8.decode(gzip.decode(output.readAsBytesSync())))
      as Map<String, dynamic>;
  result['processWallMs'] = clock.elapsedMilliseconds;
  result['bootstrapToReadyMs'] = readyMs;
  return result;
}

Future<String> _prepareHost(
    Directory package, Directory runRoot, String flutter, String device) async {
  final host = p.join(runRoot.path, 'fixtures', 'host');
  final devices = await Process.run(flutter, ['devices', '--machine']);
  final list = jsonDecode(devices.stdout.toString()) as List;
  final selected = list.where((d) => d['id'] == device).toList();
  if (selected.isEmpty)
    throw ArgumentError('Unknown integration device $device');
  final platform =
      selected.single['targetPlatform'].toString().split('-').first;
  final target = platform == 'darwin' ? 'macos' : platform;
  if (!['android', 'ios', 'macos', 'windows', 'linux'].contains(target))
    throw ArgumentError('Unsupported integration platform $platform');
  final created = await Process.run(flutter, [
    'create',
    '--project-name=ensemble_benchmark_host',
    '--org=com.ensembleui',
    '--platforms=$target',
    host
  ]);
  if (created.exitCode != 0)
    throw StateError('Cannot create benchmark host: ${created.stderr}');
  if (target == 'ios') {
    final podfile = File(p.join(host, 'ios', 'Podfile'));
    if (podfile.existsSync()) {
      final content = podfile.readAsStringSync();
      final pattern = RegExp(r"^\s*#?\s*platform :ios,.*$", multiLine: true);
      podfile.writeAsStringSync(pattern.hasMatch(content)
          ? content.replaceAll(pattern, "platform :ios, '15.0'")
          : "platform :ios, '15.0'\n$content");
    }
    final project =
        File(p.join(host, 'ios', 'Runner.xcodeproj', 'project.pbxproj'));
    if (project.existsSync())
      project.writeAsStringSync(project.readAsStringSync().replaceAll(
          RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = [^;]+;'),
          'IPHONEOS_DEPLOYMENT_TARGET = 15.0;'));
  }
  File(p.join(host, 'pubspec.yaml'))
      .writeAsStringSync('''name: ensemble_benchmark_host
environment:
  sdk: ">=3.5.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  ensemble_test_runner:
    path: ${jsonEncode(package.path)}
''');
  final config = jsonDecode(
      File(p.join(package.path, '.dart_tool', 'package_config.json'))
          .readAsStringSync()) as Map;
  final overrides = StringBuffer('dependency_overrides:\n');
  final repo = package.parent.parent.path;
  for (final dep in config['packages'] as List) {
    final uri = File(p.join(package.path, '.dart_tool', 'package_config.json'))
        .uri
        .resolve(dep['rootUri'] as String);
    if (uri.scheme == 'file' &&
        p.isWithin(repo, uri.toFilePath()) &&
        dep['name'] != 'ensemble_test_runner')
      overrides.writeln(
          '  ${dep['name']}:\n    path: ${jsonEncode(uri.toFilePath())}');
  }
  File(p.join(host, 'pubspec_overrides.yaml'))
      .writeAsStringSync(overrides.toString());
  Directory(p.join(host, 'integration_test')).createSync();
  File(p.join(host, 'integration_test', 'benchmark_test.dart')).writeAsStringSync(
      "import 'package:integration_test/integration_test.dart';\nimport '${File(p.join(package.path, 'tool', 'benchmarks', 'worker.dart')).uri}' as worker;\nvoid main(){IntegrationTestWidgetsFlutterBinding.ensureInitialized();worker.benchmarkWorkerMain();}\n");
  final get =
      await Process.run(flutter, ['pub', 'get'], workingDirectory: host);
  if (get.exitCode != 0)
    throw StateError('Benchmark host dependencies failed: ${get.stderr}');
  return host;
}

int _integer(Map<String, String> values, String name, int fallback,
    {required int min}) {
  final result = values[name] == null ? fallback : int.tryParse(values[name]!);
  if (result == null || result < min)
    throw ArgumentError('--$name must be an integer >= $min');
  return result;
}

String _git(Directory dir, List<String> arguments) {
  final r = Process.runSync('git', arguments, workingDirectory: dir.path);
  return r.exitCode == 0 ? r.stdout.toString().trim() : 'unknown';
}

String? _hashFile(File file) => file.existsSync()
    ? sha256.convert(file.readAsBytesSync()).toString()
    : null;
Map<String, Object?> _codecMetadata(Directory package) {
  final config =
      File(p.join(package.path, '.dart_tool', 'package_config.json'));
  if (!config.existsSync()) return {'webp': 'unavailable'};
  final data = jsonDecode(config.readAsStringSync()) as Map;
  for (final entry in data['packages'] as List)
    if (entry['name'] == 'webp') {
      final root = config.uri.resolve(entry['rootUri'] as String).toFilePath();
      return {
        'webpPackageHash': _hashFile(File(p.join(root, 'pubspec.yaml'))),
        'webpEncoders': [
          for (final dir in [
            'mac-arm64',
            'mac-x86-64',
            'linux-aarch64',
            'linux-x86-64',
            'windows-x64'
          ])
            if (File(p.join(
                    root, dir, dir == 'windows-x64' ? 'cwebp.exe' : 'cwebp'))
                .existsSync())
              dir
        ]
      };
    }
  return {'webp': 'unavailable'};
}

String defaultFlutterExecutable() {
  final candidate = File(p.normalize(p.join(
      p.dirname(Platform.resolvedExecutable),
      '..',
      '..',
      '..',
      '..',
      'bin',
      Platform.isWindows ? 'flutter.bat' : 'flutter')));
  return candidate.existsSync() ? candidate.path : 'flutter';
}

String _fixtureHash(Directory package) {
  final base = Directory(p.join(package.path, 'tool', 'benchmarks'));
  final files = base
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.yaml') || f.path.endsWith('.dart'))
      .toList()
    ..add(File(p.join(package.path, 'tool', 'benchmark_runner.dart')))
    ..sort((a, b) => a.path.compareTo(b.path));
  return sha256
      .convert(utf8.encode(files
          .map((f) => '${p.relative(f.path, from: base.path)}:${_hashFile(f)}')
          .join('\n')))
      .toString();
}

String _implementationHash(Directory package) {
  final base = Directory(p.join(package.path, 'lib'));
  final files = base
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return sha256
      .convert(utf8.encode(files
          .map((f) => '${p.relative(f.path, from: base.path)}:${_hashFile(f)}')
          .join('\n')))
      .toString();
}
