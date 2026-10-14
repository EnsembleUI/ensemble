import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../tool/benchmarks/history.dart';
import '../../tool/benchmarks/results.dart';

Map<String, dynamic> run(String id,
        {String branch = 'main',
        String sdk = 'sdk',
        String stamp = '2026-01-01T00:00:00Z'}) =>
    {
      'schemaVersion': 1,
      'runId': id,
      'timestamp': stamp,
      'branch': branch,
      'environment': {'sdk': sdk},
      'catalogueHash': 'catalogue',
      'preset': 'quick',
      'mode': 'widget',
      'workers': 1,
      'cases': [
        {
          'id': 'case',
          'status': 'measured',
          'fixtureVersion': 1,
          'dimensions': {'nodes': 10},
          'operations': [],
          'timePerOperationUs': {'median': 10}
        }
      ],
    };
void main() {
  test('compact summaries retain operation dimension variants', () {
    final samples = [
      for (final policy in ['immediate', 'untilStable'])
        {
          'valid': true,
          'iterations': 1,
          'elapsedUs': 10,
          'spans': [
            {
              'spanId': 0,
              'parentId': null,
              'processId': 'process',
              'service': 'observer',
              'operation': 'observe',
              'elapsedUs': 10,
              'exclusiveUs': 10,
              'outcome': 'success',
              'counters': {'elements': 2},
              'dimensions': {'synchronizationPolicy': policy}
            }
          ]
        }
    ];
    final raw = summarizeCase({'samples': samples});
    final compact = summarizeCase({
      'samples': [
        for (final sample in samples)
          {
            ...sample,
            'summary': summarizeCase({
              'samples': [sample]
            })
          }..remove('spans')
      ]
    });
    expect((compact['operations'] as List).single['dimensions'],
        (raw['operations'] as List).single['dimensions']);
    expect((compact['operations'] as List).single['dimensions'], [
      {'synchronizationPolicy': 'immediate'},
      {'synchronizationPolicy': 'untilStable'}
    ]);
  });
  late Directory root;
  late BenchmarkHistory history;
  setUp(() {
    root = Directory.systemTemp.createTempSync('benchmark_history_');
    history = BenchmarkHistory(root);
  });
  tearDown(() async {
    await history.close();
    root.deleteSync(recursive: true);
  });
  test('records, reopens and deduplicates imports without overwriting',
      () async {
    expect(await history.record(run('first')), isTrue);
    expect(await history.record(run('first')..['branch'] = 'changed'), isFalse);
    await history.close();
    expect((await history.runs()).single['branch'], 'main');
  });
  test('baseline requires compatible environment and branch', () async {
    await history.record(run('first'));
    await history
        .record(run('other', branch: 'feature', stamp: '2026-02-01T00:00:00Z'));
    expect((await history.baseline(run('new')))!['runId'], 'first');
    expect(await history.baseline(run('new', sdk: 'other')), isNull);
    expect(() => history.baseline(run('new', sdk: 'other'), id: 'first'),
        throwsArgumentError);
    expect(
        () => history.baseline(run('new'), id: 'missing'), throwsArgumentError);
  });
  test('rejects unknown schemas and malformed imports', () async {
    expect(() => history.record(run('bad')..['schemaVersion'] = 999),
        throwsFormatException);
    expect(() => history.record(run('../bad')), throwsFormatException);
    expect(await history.runs(), isEmpty);
  });
  test('retention removes details and preserves compact history and exports',
      () async {
    await history.record(run('old'));
    final dir = Directory('${root.path}/runs/old')..createSync(recursive: true);
    writeJson(File('${dir.path}/manifest.json'),
        {'timestamp': '2026-01-01T00:00:00Z'});
    File('${dir.path}/spans.jsonl.gz').writeAsStringSync('detail');
    File('${dir.path}/export.json').writeAsStringSync('summary');
    history.pruneDetails(now: DateTime.utc(2026, 3));
    expect(File('${dir.path}/spans.jsonl.gz').existsSync(), isFalse);
    expect(File('${dir.path}/export.json').existsSync(), isTrue);
    expect((await history.runs()).length, 1);
  });
  test('summary normalizes batches and excludes invalid samples', () {
    final result = summarizeCase({
      'id': 'case',
      'status': 'measured',
      'samples': [
        {
          'index': 0,
          'valid': true,
          'iterations': 2,
          'elapsedUs': 100,
          'spans': [
            {
              'service': 'observer',
              'operation': 'walk',
              'elapsedUs': 80,
              'exclusiveUs': 50,
              'outcome': 'ok',
              'counters': {'nodes': 20}
            }
          ]
        },
        {
          'index': 1,
          'valid': false,
          'iterations': 1,
          'elapsedUs': 10000,
          'spans': [],
          'error': 'wrong output'
        },
      ]
    });
    expect((result['timePerOperationUs'] as Map)['median'], 50);
    final op = (result['operations'] as List).single as Map;
    expect(op['exclusiveUsPerIteration'], 25);
    expect(op['countersPerIteration'], {'nodes': 10});
    expect((result['invalidSamples'] as List).length, 1);
  });
  test('protocol and selection differences prevent baseline comparison',
      () async {
    final initial = run('initial')
      ..['protocol'] = {'warmups': 3, 'samples': 10}
      ..['selection'] = {
        'services': ['observer']
      };
    await history.record(initial);
    expect(
        await history.baseline({
          ...initial,
          'runId': 'new',
          'protocol': {'warmups': 0, 'samples': 1}
        }),
        isNull);
    expect(
        await history.baseline({
          ...initial,
          'runId': 'new',
          'selection': {
            'services': ['screenshot']
          }
        }),
        isNull);
    expect(
        compatibilityKey({
          ...initial,
          'environment': {'b': 2, 'a': 1}
        }),
        compatibilityKey({
          ...initial,
          'environment': {'a': 1, 'b': 2}
        }));
  });
  test('self contained imports restore compact samples exactly once', () async {
    final exported = run('imported')
      ..['samples'] = [
        {
          'caseId': 'case',
          'index': 0,
          'iterations': 2,
          'elapsedUs': 20,
          'valid': true
        }
      ];
    expect(await history.record(exported), isTrue);
    expect(await history.record(exported), isFalse);
    final samples = await (await history.database).query('samples');
    expect(samples.length, 1);
    expect((await history.runs()).single.containsKey('samples'), isFalse);
  });
  test('nested summaries exclude same service ancestors from inclusive totals',
      () {
    final result = summarizeCase({
      'id': 'case',
      'status': 'measured',
      'samples': [
        {
          'index': 0,
          'valid': true,
          'iterations': 1,
          'elapsedUs': 100,
          'spans': [
            {
              'spanId': 0,
              'parentId': null,
              'service': 'screenshot',
              'operation': 'all',
              'elapsedUs': 100,
              'exclusiveUs': 20,
              'outcome': 'ok',
              'counters': {}
            },
            {
              'spanId': 1,
              'parentId': 0,
              'service': 'screenshot',
              'operation': 'encode',
              'elapsedUs': 80,
              'exclusiveUs': 80,
              'outcome': 'ok',
              'counters': {'bytes': 16}
            },
          ]
        }
      ]
    });
    final service = (result['services'] as List).single;
    expect(service['inclusiveUsPerIteration'], 100);
    expect(service['exclusiveUsPerIteration'], 100);
    expect((result['nestedOperations'] as List).last['path'],
        'screenshot.all > screenshot.encode');
  });
  test('overlapping worker span IDs retain their own nested contexts', () {
    final result = summarizeCase({
      'samples': [
        {
          'index': 0,
          'valid': true,
          'iterations': 1,
          'elapsedUs': 10,
          'spans': [
            for (final process in ['a', 'b']) ...[
              {
                'processId': process,
                'spanId': 0,
                'parentId': null,
                'service': process,
                'operation': 'root',
                'elapsedUs': 10,
                'exclusiveUs': 5,
                'outcome': 'ok',
                'counters': {}
              },
              {
                'processId': process,
                'spanId': 1,
                'parentId': 0,
                'service': process,
                'operation': 'leaf',
                'elapsedUs': 5,
                'exclusiveUs': 5,
                'outcome': 'ok',
                'counters': {}
              },
            ]
          ]
        }
      ]
    });
    expect((result['nestedOperations'] as List).map((n) => n['path']).toSet(),
        {'a.root', 'a.root > a.leaf', 'b.root', 'b.root > b.leaf'});
  });
  test(
      'streamed sample summaries preserve weighted totals and exact percentiles',
      () {
    final samples = [
      for (var sample = 0; sample < 2; sample++)
        {
          'index': sample,
          'valid': true,
          'iterations': sample + 1,
          'elapsedUs': 10 * (sample + 1),
          'spans': [
            for (var i = 0; i < sample + 1; i++)
              {
                'processId': 'p',
                'spanId': i,
                'parentId': null,
                'service': 'service',
                'operation': 'work',
                'elapsedUs': 10 + i,
                'exclusiveUs': 10 + i,
                'outcome': 'ok',
                'counters': {'items': 2}
              },
          ]
        }
    ];
    final ordinary = summarizeCase({'samples': samples});
    final streamed = summarizeCase({
      'samples': [
        for (final sample in samples)
          {
            ...sample,
            'summary': summarizeCase({
              'samples': [sample]
            })
          }..remove('spans')
      ]
    });
    expect(streamed['operations'], ordinary['operations']);
    expect(streamed['services'], ordinary['services']);
    expect(streamed['nestedOperations'], ordinary['nestedOperations']);
    expect(streamed['timePerOperationUs'], ordinary['timePerOperationUs']);
  });
}
