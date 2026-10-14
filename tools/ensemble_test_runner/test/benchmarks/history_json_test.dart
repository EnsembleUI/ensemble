import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/benchmarks/history_json.dart';

Map<String, dynamic> _run(String id,
    {String branch = 'main', String sdk = 'sdk'}) {
  return {
    'schemaVersion': 1,
    'runId': id,
    'timestamp': '2026-01-01T00:00:00Z',
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
        'dimensions': {'nodes': 1},
        'operations': [],
      }
    ],
  };
}

void main() {
  late Directory root;
  late BenchmarkHistory history;

  setUp(() {
    root = Directory.systemTemp.createTempSync('benchmark_history_json_');
    history = BenchmarkHistory(root);
  });

  tearDown(() async {
    await history.close();
    root.deleteSync(recursive: true);
  });

  test('persists compact runs without a database file', () async {
    expect(await history.record(_run('first')), isTrue);
    expect(await history.record(_run('first')), isFalse);
    await history.close();

    final reopened = BenchmarkHistory(root);
    expect((await reopened.runs()).single['runId'], 'first');
    expect(File('${root.path}/history.json').existsSync(), isTrue);
    expect(File('${root.path}/history.sqlite').existsSync(), isFalse);
    final document = jsonDecode(
      File('${root.path}/history.json').readAsStringSync(),
    ) as Map;
    expect(document['version'], 1);
    await reopened.close();
  });

  test('selects only compatible branch baselines', () async {
    await history.record(_run('first'));
    await history.record(_run('other', branch: 'feature'));
    expect((await history.baseline(_run('new')))!['runId'], 'first');
    expect(await history.baseline(_run('new', sdk: 'other')), isNull);
    expect(
      () => history.baseline(_run('new', sdk: 'other'), id: 'first'),
      throwsArgumentError,
    );
  });

  test('detail retention keeps the newest run details and compact summaries',
      () async {
    final stamps = [
      for (var index = 0; index < 4; index++)
        DateTime.utc(2026, 3, 4 - index).toIso8601String(),
    ];
    for (var index = 0; index < stamps.length; index++) {
      final id = 'retained-$index';
      final summary = _run(id)..['timestamp'] = stamps[index];
      await history.record(summary);
      final directory = Directory('${root.path}/runs/$id')
        ..createSync(recursive: true);
      File('${directory.path}/manifest.json')
          .writeAsStringSync(jsonEncode({'timestamp': stamps[index]}));
      File('${directory.path}/spans.jsonl.gz').writeAsStringSync('details');
      Directory('${directory.path}/fixtures').createSync();
      Directory('${directory.path}/worker-output').createSync();
    }

    final pruned = history.pruneDetails(
      now: DateTime.utc(2026, 3, 5),
      days: 30,
      keepMostRecentRuns: 2,
    );

    expect(pruned, 2);
    for (var index = 0; index < stamps.length; index++) {
      final directory = Directory('${root.path}/runs/retained-$index');
      expect(
        File('${directory.path}/spans.jsonl.gz').existsSync(),
        index < 2,
      );
    }
    expect((await history.runs()).length, stamps.length);
  });

  test('retention removes only stale incomplete benchmark directories', () {
    final stale = Directory('${root.path}/runs/123_1')
      ..createSync(recursive: true);
    final staleLog = File('${stale.path}/worker.log')
      ..writeAsStringSync('interrupted run');
    staleLog.setLastModifiedSync(DateTime.utc(2026, 2, 1));
    final recent = Directory('${root.path}/runs/456_2')
      ..createSync(recursive: true);
    final recentLog = File('${recent.path}/worker.log')
      ..writeAsStringSync('recent run');
    recentLog.setLastModifiedSync(DateTime.utc(2026, 3, 4));

    history.pruneDetails(
      now: DateTime.utc(2026, 3, 5),
      incompleteRetentionDays: 7,
    );

    expect(stale.existsSync(), isFalse);
    expect(recent.existsSync(), isTrue);
  });
}
