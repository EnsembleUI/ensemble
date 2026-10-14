import 'dart:async';

/// Internal instrumentation, active only inside the standalone benchmark tool.
/// No clocks, records or output are created by ordinary runner invocations.
abstract final class RunnerBenchmark {
  static final Object _collectorKey = Object();
  static final Object _parentKey = Object();

  static BenchmarkCollector? get collector =>
      Zone.current[_collectorKey] as BenchmarkCollector?;

  static T collect<T>(BenchmarkCollector collector, T Function() body) =>
      runZoned(body, zoneValues: {_collectorKey: collector, _parentKey: null});

  static T sync<T>(String service, String operation, T Function() body) {
    final active = collector;
    if (active == null) return body();
    final span = active.begin(
        service, operation, Zone.current[_parentKey] as BenchmarkSpan?);
    try {
      return runZoned(body, zoneValues: {_parentKey: span});
    } catch (_) {
      span.outcome = 'error';
      rethrow;
    } finally {
      active.end(span);
    }
  }

  /// Tracks methods which return a Future without an async declaration.
  /// The inactive path returns the original Future and preserves sync throws.
  static Future<T> future<T>(
      String service, String operation, Future<T> Function() body) {
    final active = collector;
    if (active == null) return body();
    final span = active.begin(
        service, operation, Zone.current[_parentKey] as BenchmarkSpan?);
    try {
      final result = runZoned(body, zoneValues: {_parentKey: span});
      return result.then((value) {
        active.end(span);
        return value;
      }, onError: (Object error, StackTrace stack) {
        span.outcome = 'error';
        active.end(span);
        Error.throwWithStackTrace(error, stack);
      });
    } catch (_) {
      span.outcome = 'error';
      active.end(span);
      rethrow;
    }
  }

  static Future<T> async<T>(
      String service, String operation, Future<T> Function() body) async {
    final active = collector;
    if (active == null) return body();
    final span = active.begin(
        service, operation, Zone.current[_parentKey] as BenchmarkSpan?);
    try {
      return await runZoned(body, zoneValues: {_parentKey: span});
    } catch (_) {
      span.outcome = 'error';
      rethrow;
    } finally {
      active.end(span);
    }
  }

  static BenchmarkPending? pending(String service, String operation) {
    final active = collector;
    if (active == null) return null;
    return BenchmarkPending(
        active,
        active.begin(
            service, operation, Zone.current[_parentKey] as BenchmarkSpan?));
  }

  static void count(String name, num value) {
    final span = Zone.current[_parentKey] as BenchmarkSpan?;
    if (span != null)
      span.counters.update(name, (n) => n + value, ifAbsent: () => value);
  }

  static void dimension(String name, Object value) {
    final span = Zone.current[_parentKey] as BenchmarkSpan?;
    if (span != null) span.dimensions[name] = value;
  }
}

class BenchmarkCollector {
  BenchmarkCollector(
      {required this.caseId,
      required this.sample,
      required this.processId,
      this.worker = 0,
      this.dimensions = const {},
      this.executables = const {},
      this.disabledExecutables = const {}})
      : clock = Stopwatch()..start();

  final String caseId;
  final int sample;
  final String processId;
  final int worker;
  final Map<String, Object?> dimensions;
  final Map<String, String> executables;
  final Set<String> disabledExecutables;
  final Stopwatch clock;
  final List<BenchmarkSpan> spans = [];

  BenchmarkSpan begin(String service, String operation, BenchmarkSpan? parent) {
    final span = BenchmarkSpan(
        id: spans.length,
        parentId: parent?.id,
        service: service,
        operation: operation,
        startUs: clock.elapsedMicroseconds);
    spans.add(span);
    return span;
  }

  void end(BenchmarkSpan span) {
    span.endUs = clock.elapsedMicroseconds;
  }

  List<Map<String, Object?>> toJson() {
    final children = <int, List<BenchmarkSpan>>{};
    for (final span in spans) {
      final parent = span.parentId;
      if (parent != null) children.putIfAbsent(parent, () => []).add(span);
    }
    return [
      for (final span in spans)
        {
          'caseId': caseId,
          'sample': sample,
          'processId': processId,
          'worker': worker,
          ...span.toJson(),
          'dimensions': {...dimensions, ...span.dimensions},
          'exclusiveUs': span.elapsedUs -
              coveredMicroseconds(
                  children[span.id] ?? [], span.startUs, span.endUs),
        }
    ];
  }
}

class BenchmarkSpan {
  BenchmarkSpan(
      {required this.id,
      required this.parentId,
      required this.service,
      required this.operation,
      required this.startUs});
  final int id;
  final int? parentId;
  final String service;
  final String operation;
  final int startUs;
  int? endUs;
  String outcome = 'ok';
  final Map<String, num> counters = {};
  final Map<String, Object> dimensions = {};
  int get elapsedUs => (endUs ?? startUs) - startUs;
  Map<String, Object?> toJson() => {
        'spanId': id,
        'parentId': parentId,
        'service': service,
        'operation': operation,
        'startUs': startUs,
        'elapsedUs': elapsedUs,
        'outcome': endUs == null ? 'incomplete' : outcome,
        'counters': counters,
        'dimensions': dimensions,
      };
}

/// Length of the union of child intervals, clipped to the parent's lifetime.
int coveredMicroseconds(List<BenchmarkSpan> spans, int start, int? end) {
  if (end == null) return 0;
  final intervals = spans
      .where((s) => s.endUs != null)
      .map((s) => (s.startUs.clamp(start, end), s.endUs!.clamp(start, end)))
      .toList()
    ..sort((a, b) => a.$1.compareTo(b.$1));
  var total = 0, left = start, right = start;
  for (final interval in intervals) {
    if (interval.$1 > right) {
      total += right - left;
      left = interval.$1;
    }
    if (interval.$2 > right) right = interval.$2;
  }
  return total + right - left;
}

class BenchmarkPending {
  BenchmarkPending(this.collector, this.span);
  final BenchmarkCollector collector;
  final BenchmarkSpan span;
  void finish() {
    if (span.endUs == null) collector.end(span);
  }
}
