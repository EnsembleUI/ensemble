import 'dart:async';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:flutter_test/flutter_test.dart';

BenchmarkCollector collector() =>
    BenchmarkCollector(caseId: 'fixture', sample: 0, processId: 'test');

void main() {
  test('common dimensions merge with operation dimensions after measurement',
      () {
    final c = BenchmarkCollector(
        caseId: 'case',
        sample: 0,
        processId: 'process',
        dimensions: const {'executionMode': 'widget', 'codec': 'default'});
    RunnerBenchmark.collect(
        c,
        () => RunnerBenchmark.sync('screenshot', 'encode', () {
              RunnerBenchmark.dimension('codec', 'png');
              RunnerBenchmark.count('bytes', 10);
            }));
    expect(c.toJson().single['dimensions'],
        {'executionMode': 'widget', 'codec': 'png'});
    expect(c.spans.single.dimensions, {'codec': 'png'});
  });
  test(
      'inactive instrumentation preserves return values and creates no collector',
      () async {
    expect(RunnerBenchmark.collector, isNull);
    expect(RunnerBenchmark.sync('test', 'return', () => 42), 42);
    expect(await RunnerBenchmark.async('test', 'return', () async => 42), 42);
    expect(
        () => RunnerBenchmark.sync(
            'test', 'error', () => throw StateError('original')),
        throwsStateError);
    expect(RunnerBenchmark.collector, isNull);
  });
  test('union clips and merges overlapping child intervals', () {
    final a = BenchmarkSpan(
        id: 1, parentId: 0, service: 's', operation: 'a', startUs: 5)
      ..endUs = 40;
    final b = BenchmarkSpan(
        id: 2, parentId: 0, service: 's', operation: 'b', startUs: 30)
      ..endUs = 80;
    final c = BenchmarkSpan(
        id: 3, parentId: 0, service: 's', operation: 'c', startUs: 90)
      ..endUs = 120;
    expect(coveredMicroseconds([b, c, a], 10, 100), 80);
    expect(coveredMicroseconds([], 10, 100), 0);
  });
  test('concurrent async children keep the correct parent; errors close spans',
      () async {
    final c = collector();
    await RunnerBenchmark.collect(
        c,
        () => RunnerBenchmark.async('root', 'all', () async {
              await Future.wait([
                for (var i = 0; i < 3; i++)
                  RunnerBenchmark.async('child', 'branch$i', () async {
                    await Future<void>.delayed(Duration(milliseconds: i + 1));
                    RunnerBenchmark.sync('leaf', 'inside',
                        () => RunnerBenchmark.count('work', 1));
                  })
              ]);
              try {
                RunnerBenchmark.sync(
                    'child', 'error', () => throw StateError('expected'));
              } on StateError {}
            }));
    final json = c.toJson();
    expect(json.where((s) => s['outcome'] == 'incomplete'), isEmpty);
    for (final leaf in json.where((s) => s['service'] == 'leaf')) {
      expect(json[leaf['parentId'] as int]['service'], 'child');
      expect(leaf['counters'], {'work': 1});
    }
    expect(
        json.singleWhere((s) => s['operation'] == 'error')['outcome'], 'error');
    expect(json.every((s) => (s['exclusiveUs'] as int) >= 0), isTrue);
    expect(RunnerBenchmark.collector, isNull);
  });
  test('incomplete child is not charged as completed work', () {
    final c = collector();
    final parent = c.begin('s', 'parent', null);
    c.begin('s', 'child', parent);
    c.end(parent);
    expect(c.toJson()[1]['outcome'], 'incomplete');
    expect(c.toJson()[0]['exclusiveUs'], c.toJson()[0]['elapsedUs']);
  });
  test('slow leaf and repeated work appear under their own operation', () {
    final c = collector();
    RunnerBenchmark.collect(
        c,
        () => RunnerBenchmark.sync('root', 'fixture', () {
              for (var i = 0; i < 4; i++)
                RunnerBenchmark.sync('observer', 'walk', () {
                  final clock = Stopwatch()..start();
                  while (clock.elapsedMicroseconds < 300) {}
                  RunnerBenchmark.count('nodes', 10);
                });
            }));
    final leaves = c.toJson().where((s) => s['operation'] == 'walk').toList();
    expect(leaves.length, 4);
    expect(leaves.every((s) => (s['exclusiveUs'] as int) >= 300), isTrue);
    expect(leaves.every((s) => (s['counters'] as Map)['nodes'] == 10), isTrue);
  });
  test('Future wrappers preserve inactive identity and synchronous failures',
      () async {
    final value = Future.value(42);
    expect(
        identical(
            RunnerBenchmark.future('service', 'operation', () => value), value),
        isTrue);
    final original = StateError('same object');
    try {
      RunnerBenchmark.future<void>(
          'service', 'operation', () => throw original);
      fail('expected error');
    } catch (error) {
      expect(identical(error, original), isTrue);
    }
    final c = collector();
    final completer = Completer<void>();
    final future = RunnerBenchmark.collect(
        c,
        () => RunnerBenchmark.future(
            'service', 'operation', () => completer.future));
    completer.completeError(original);
    try {
      await future;
      fail('expected error');
    } catch (error) {
      expect(identical(error, original), isTrue);
    }
    expect(c.toJson().single['outcome'], 'error');
  });
  test('timeout and queue delay close spans and collectors stay separate',
      () async {
    final a = collector(), b = collector();
    await Future.wait([
      for (final c in [a, b])
        RunnerBenchmark.collect(c, () async {
          final pending = RunnerBenchmark.pending('queue', 'delay');
          await Future<void>.delayed(const Duration(milliseconds: 1));
          pending?.finish();
          pending?.finish();
          try {
            await RunnerBenchmark.async(
                'wait',
                'timeout',
                () => Future<void>.delayed(const Duration(milliseconds: 5))
                    .timeout(const Duration(milliseconds: 1)));
          } on TimeoutException {}
        })
    ]);
    for (final c in [a, b]) {
      expect(c.spans.length, 2);
      expect(c.toJson().last['outcome'], 'error');
      expect(c.toJson().where((s) => s['outcome'] == 'incomplete'), isEmpty);
    }
  });
}
