import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const benchmarkSchemaVersion = 1;
const benchmarkFixtureVersion = 1;

Map<String, Object?> statistics(List<num> values) {
  if (values.isEmpty) return {'count': 0, 'median': null, 'p95': null};
  final sorted = values.map((v) => v.toDouble()).toList()..sort();
  final mean = sorted.reduce((a, b) => a + b) / sorted.length;
  final variance = sorted.fold<double>(0, (n, v) => n + math.pow(v - mean, 2)) /
      sorted.length;
  final mid = sorted.length ~/ 2;
  return {
    'count': sorted.length,
    'median':
        sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2,
    'p95': sorted[(sorted.length * .95).ceil() - 1],
    'min': sorted.first,
    'max': sorted.last,
    'mean': mean,
    'stddev': math.sqrt(variance),
    'coefficientOfVariation': mean == 0 ? 0 : math.sqrt(variance) / mean
  };
}

Map<String, Object?> summarizeCase(Map<String, dynamic> result) {
  final samples =
      (result['samples'] as List? ?? []).cast<Map<String, dynamic>>();
  final valid = samples.where((s) => s['valid'] == true).toList();
  if (samples.isNotEmpty && samples.every((s) => s['summary'] is Map))
    return summarizePrecomputed(result, samples, valid);
  final operations = <String, List<Map<String, dynamic>>>{};
  for (final sample in valid) {
    for (final raw in sample['spans'] as List) {
      final span = Map<String, dynamic>.from(raw as Map);
      operations
          .putIfAbsent('${span['service']}.${span['operation']}', () => [])
          .add(span);
    }
  }
  final serviceSpans = <String, List<Map<String, dynamic>>>{};
  final paths = <String, List<Map<String, dynamic>>>{};
  for (final sample in valid) {
    final spans = (sample['spans'] as List)
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
    final byId = {
      for (final span in spans)
        if (span['spanId'] != null)
          '${span['processId']}:${span['spanId']}': span
    };
    for (final span in spans) {
      final lineage = <Map<String, dynamic>>[];
      var parent = byId['${span['processId']}:${span['parentId']}'];
      while (parent != null) {
        lineage.insert(0, parent);
        parent = byId['${parent['processId']}:${parent['parentId']}'];
      }
      final copy = {
        ...span,
        'serviceRoot': !lineage.any((a) => a['service'] == span['service'])
      };
      serviceSpans.putIfAbsent(span['service'] as String, () => []).add(copy);
      final path = [...lineage, span]
          .map((a) => '${a['service']}.${a['operation']}')
          .join(' > ');
      paths.putIfAbsent(path, () => []).add(span);
    }
  }
  final batches = valid.fold<int>(0, (n, s) => n + (s['iterations'] as int));
  return {...result}
    ..remove('samples')
    ..addAll({
      'fixturePreparationUs': statistics([
        for (final sample in valid)
          if (sample['fixturePreparationUs'] is num)
            (sample['fixturePreparationUs'] as num) /
                (sample['iterations'] as int)
      ]),
      'fixtureCleanupUs': statistics([
        for (final sample in valid)
          if (sample['fixtureCleanupUs'] is num)
            (sample['fixtureCleanupUs'] as num) / (sample['iterations'] as int)
      ]),
      'verificationUs': statistics([
        for (final sample in valid)
          if (sample['verificationUs'] is num)
            (sample['verificationUs'] as num) / (sample['iterations'] as int)
      ]),
      'sampleCount': samples.length,
      'validSampleCount': valid.length,
      'timePerOperationUs': statistics([
        for (final s in valid)
          (s['elapsedUs'] as num) / (s['iterations'] as int)
      ]),
      'services': [
        for (final e in serviceSpans.entries)
          {
            'service': e.key,
            'exclusiveUsPerIteration':
                e.value.fold<num>(0, (n, s) => n + (s['exclusiveUs'] as num)) /
                    (batches == 0 ? 1 : batches),
            'inclusiveUsPerIteration': e.value
                    .where((s) => s['serviceRoot'] == true)
                    .fold<num>(0, (n, s) => n + (s['elapsedUs'] as num)) /
                (batches == 0 ? 1 : batches),
            'invocationsPerIteration':
                e.value.length / (batches == 0 ? 1 : batches),
            'perCallUs':
                statistics([for (final s in e.value) s['elapsedUs'] as num]),
            'durationHistogramUs':
                histogram([for (final s in e.value) s['elapsedUs'] as num]),
          }
      ],
      'nestedOperations': [
        for (final e in paths.entries)
          {
            'path': e.key,
            'callsPerIteration': e.value.length / (batches == 0 ? 1 : batches),
            'perCallUs':
                statistics([for (final s in e.value) s['elapsedUs'] as num]),
            'durationHistogramUs':
                histogram([for (final s in e.value) s['elapsedUs'] as num]),
            'exclusiveUsPerIteration':
                e.value.fold<num>(0, (n, s) => n + (s['exclusiveUs'] as num)) /
                    (batches == 0 ? 1 : batches),
          }
      ],
      'externalProcessResources': [
        for (final sample in valid)
          ...sample['externalProcessResources'] as List? ?? []
      ],
      'resourceObservations': [
        for (final sample in valid)
          if (sample['resourceObservations'] != null)
            sample['resourceObservations']
      ],
      'workers': [
        for (final sample in valid) ...[
          for (final span in sample['spans'] as List)
            if (span['operation'] == 'runFlutterTestProcess')
              {
                'sample': sample['index'],
                'processId': span['dimensions']['childProcessId'],
                'durationUs': span['elapsedUs'],
                'bootstrapToReadyUs': span['dimensions']['bootstrapToReadyUs'],
              }
        ]
      ],
      'operations': [
        for (final entry in operations.entries)
          {
            'key': entry.key,
            'service': entry.value.first['service'],
            'operation': entry.value.first['operation'],
            'invocations': entry.value.length,
            'invocationsPerIteration':
                batches == 0 ? null : entry.value.length / batches,
            'inclusiveUs':
                entry.value.fold<num>(0, (n, s) => n + (s['elapsedUs'] as num)),
            'exclusiveUs': entry.value
                .fold<num>(0, (n, s) => n + (s['exclusiveUs'] as num)),
            'exclusiveUsPerIteration': batches == 0
                ? null
                : entry.value
                        .fold<num>(0, (n, s) => n + (s['exclusiveUs'] as num)) /
                    batches,
            'perCallUs': statistics(
                [for (final s in entry.value) s['elapsedUs'] as num]),
            'durationHistogramUs':
                histogram([for (final s in entry.value) s['elapsedUs'] as num]),
            'countersPerIteration': _counters(entry.value, batches),
            'dimensions': uniqueDimensions(
                entry.value.map((span) => span['dimensions'] ?? const {})),
            'outcomes': {
              for (final outcome
                  in entry.value.map((s) => s['outcome']).toSet())
                outcome.toString():
                    entry.value.where((s) => s['outcome'] == outcome).length
            },
          }
      ],
      'invalidSamples': [
        for (final s in samples.where((s) => s['valid'] != true))
          {'sample': s['index'], 'error': s['error']}
      ],
    });
}

Map<String, num> _counters(List<Map<String, dynamic>> spans, int batches) {
  final sums = <String, num>{};
  for (final span in spans) {
    (span['counters'] as Map).forEach((key, value) {
      sums.update(key as String, (n) => n + (value as num),
          ifAbsent: () => value as num);
    });
  }
  return {
    for (final e in sums.entries) e.key: e.value / (batches == 0 ? 1 : batches)
  };
}

List<Object?> uniqueDimensions(Iterable<Object?> values) => {
      for (final value in values) jsonEncode(canonicalJson(value)): value
    }.values.toList();

Object? canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: canonicalJson(value[key])};
  }
  if (value is List) return value.map(canonicalJson).toList();
  return value;
}

String compatibilityKey(Map<String, dynamic> run) {
  final environment =
      Map<String, dynamic>.from(run['environment'] as Map? ?? const {});
  // This hash fingerprints benchmark source for provenance and detecting a
  // source change during a run. It also includes report/history code, so it
  // must not prevent comparison when only the HTML renderer changes. Per-case
  // fixtureVersion and dimensions are checked by compareCases instead.
  environment.remove('fixtureSourceHash');
  return jsonEncode(canonicalJson({
    'schemaVersion': run['schemaVersion'],
    'environment': environment,
    'catalogueHash': run['catalogueHash'],
    'preset': run['preset'],
    'mode': run['mode'],
    'workers': run['workers'],
    'protocol': run['protocol'],
    'selection': run['selection'],
  }));
}

List<Map<String, Object?>> compareCases(
    Map<String, dynamic> run, Map<String, dynamic> baseline) {
  final prior = {
    for (final c in baseline['cases'] as List) (c as Map)['id']: c
  };
  return [
    for (final c in run['cases'] as List)
      if (c['status'] == 'measured' &&
          prior[c['id']]?['status'] == 'measured' &&
          c['fixtureVersion'] == prior[c['id']]!['fixtureVersion'] &&
          jsonEncode(c['dimensions']) ==
              jsonEncode(prior[c['id']]!['dimensions']))
        _difference(Map<String, dynamic>.from(c),
            Map<String, dynamic>.from(prior[c['id']]!))
  ];
}

Map<String, Object?> _difference(
    Map<String, dynamic> current, Map<String, dynamic> prior) {
  final now = current['timePerOperationUs']['median'] as num?;
  final before = prior['timePerOperationUs']['median'] as num?;
  final oldOps = {for (final op in prior['operations'] as List) op['key']: op};
  return {
    'caseId': current['id'],
    'baselineMedianUs': before,
    'medianUs': now,
    'deltaUs': now == null || before == null ? null : now - before,
    'deltaPercent': now == null || before == null || before == 0
        ? null
        : (now - before) / before * 100,
    'operations': [
      for (final op in current['operations'] as List)
        {
          'key': op['key'],
          'exclusiveUsPerIteration': op['exclusiveUsPerIteration'],
          'baselineExclusiveUsPerIteration': oldOps[op['key']]
              ?['exclusiveUsPerIteration'],
          'invocationsPerIteration': op['invocationsPerIteration'],
          'baselineInvocationsPerIteration': oldOps[op['key']]
              ?['invocationsPerIteration'],
          'countersPerIteration': op['countersPerIteration'],
          'baselineCountersPerIteration': oldOps[op['key']]
              ?['countersPerIteration'],
          'dimensions': op['dimensions'],
          'baselineDimensions': oldOps[op['key']]?['dimensions'],
        }
    ]
  };
}

void writeJson(File file, Object value) {
  file.parent.createSync(recursive: true);
  final temporary = File('${file.path}.tmp');
  temporary
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(value));
  temporary.renameSync(file.path);
}

Map<String, int> histogram(Iterable<num> values) {
  final result = <String, int>{};
  for (final value in values)
    result.update(value.toString(), (n) => n + 1, ifAbsent: () => 1);
  return result;
}

Map<String, Object?> histogramStatistics(Map<String, int> histogram) {
  final entries = histogram.entries
      .map((e) => (num.parse(e.key).toDouble(), e.value))
      .toList()
    ..sort((a, b) => a.$1.compareTo(b.$1));
  final count = entries.fold<int>(0, (n, e) => n + e.$2);
  if (count == 0) return statistics([]);
  double at(int index) {
    var seen = 0;
    for (final e in entries) {
      seen += e.$2;
      if (seen > index) return e.$1;
    }
    return entries.last.$1;
  }

  final mean = entries.fold<double>(0, (n, e) => n + e.$1 * e.$2) / count;
  final variance =
      entries.fold<double>(0, (n, e) => n + math.pow(e.$1 - mean, 2) * e.$2) /
          count;
  return {
    'count': count,
    'median': count.isOdd
        ? at(count ~/ 2)
        : (at(count ~/ 2 - 1) + at(count ~/ 2)) / 2,
    'p95': at((count * .95).ceil() - 1),
    'min': entries.first.$1,
    'max': entries.last.$1,
    'mean': mean,
    'stddev': math.sqrt(variance),
    'coefficientOfVariation': mean == 0 ? 0 : math.sqrt(variance) / mean
  };
}

Map<String, Object?> summarizePrecomputed(Map<String, dynamic> result,
    List<Map<String, dynamic>> samples, List<Map<String, dynamic>> valid) {
  final batches = valid.fold<int>(0, (n, s) => n + (s['iterations'] as int));
  List<Map<String, Object?>> merge(String section, String key) {
    final groups = <String, List<(Map<String, dynamic>, int)>>{};
    for (final sample in valid)
      for (final raw in sample['summary'][section] as List? ?? []) {
        final row = Map<String, dynamic>.from(raw as Map);
        groups
            .putIfAbsent(row[key] as String, () => [])
            .add((row, sample['iterations'] as int));
      }
    return [
      for (final entry in groups.entries)
        (() {
          final first = entry.value.first.$1;
          final hist = <String, int>{};
          for (final row in entry.value)
            (row.$1['durationHistogramUs'] as Map? ?? {}).forEach((k, v) =>
                hist.update(k as String, (n) => n + (v as int),
                    ifAbsent: () => v as int));
          num sum(String field, {bool weighted = false}) =>
              entry.value.fold<num>(
                  0,
                  (n, row) =>
                      n +
                      ((row.$1[field] as num?) ?? 0) * (weighted ? row.$2 : 1));
          num normalized(String field) =>
              sum(field, weighted: true) / (batches == 0 ? 1 : batches);
          final merged = <String, Object?>{
            ...first,
            'durationHistogramUs': hist,
            'perCallUs': histogramStatistics(hist),
            'exclusiveUsPerIteration': normalized('exclusiveUsPerIteration')
          };
          if (section == 'operations') {
            merged['dimensions'] = uniqueDimensions(entry.value
                .expand((row) => row.$1['dimensions'] as List? ?? []));
            final counters = <String, num>{}, outcomes = <String, int>{};
            for (final row in entry.value) {
              (row.$1['countersPerIteration'] as Map).forEach((k, v) =>
                  counters.update(k as String, (n) => n + (v as num) * row.$2,
                      ifAbsent: () => (v as num) * row.$2));
              (row.$1['outcomes'] as Map).forEach((k, v) => outcomes.update(
                  k as String, (n) => n + (v as int),
                  ifAbsent: () => v as int));
            }
            merged.addAll({
              'invocations': sum('invocations'),
              'invocationsPerIteration': normalized('invocationsPerIteration'),
              'inclusiveUs': sum('inclusiveUs'),
              'exclusiveUs': sum('exclusiveUs'),
              'countersPerIteration': {
                for (final e in counters.entries)
                  e.key: e.value / (batches == 0 ? 1 : batches)
              },
              'outcomes': outcomes
            });
          } else if (section == 'services') {
            merged.addAll({
              'inclusiveUsPerIteration': normalized('inclusiveUsPerIteration'),
              'invocationsPerIteration': normalized('invocationsPerIteration')
            });
          } else {
            merged['callsPerIteration'] = normalized('callsPerIteration');
          }
          return merged;
        })()
    ];
  }

  return {...result}
    ..remove('samples')
    ..addAll({
      'fixturePreparationUs': statistics([
        for (final sample in valid)
          if (sample['fixturePreparationUs'] is num)
            (sample['fixturePreparationUs'] as num) /
                (sample['iterations'] as int)
      ]),
      'fixtureCleanupUs': statistics([
        for (final sample in valid)
          if (sample['fixtureCleanupUs'] is num)
            (sample['fixtureCleanupUs'] as num) / (sample['iterations'] as int)
      ]),
      'verificationUs': statistics([
        for (final sample in valid)
          if (sample['verificationUs'] is num)
            (sample['verificationUs'] as num) / (sample['iterations'] as int)
      ]),
      'sampleCount': samples.length,
      'validSampleCount': valid.length,
      'timePerOperationUs': statistics([
        for (final s in valid)
          (s['elapsedUs'] as num) / (s['iterations'] as int)
      ]),
      'operations': merge('operations', 'key'),
      'services': merge('services', 'service'),
      'nestedOperations': merge('nestedOperations', 'path'),
      'workers': [
        for (final s in valid) ...s['summary']['workers'] as List? ?? []
      ],
      'externalProcessResources': [
        for (final s in valid) ...s['externalProcessResources'] as List? ?? []
      ],
      'resourceObservations': [
        for (final s in valid)
          if (s['resourceObservations'] != null) s['resourceObservations']
      ],
      'invalidSamples': [
        for (final s in samples.where((s) => s['valid'] != true))
          {'sample': s['index'], 'error': s['error']}
      ],
    });
}
