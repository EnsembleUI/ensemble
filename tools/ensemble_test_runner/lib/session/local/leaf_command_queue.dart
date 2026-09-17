import 'dart:async';
import 'dart:collection';

/// Non-reentrant async queue for **leaf** session operations only.
///
/// Control-flow (`group` / `repeat` / …) must not acquire this lock. Nested
/// YAML bodies call leaf APIs sequentially; each leaf acquires and releases.
/// Internal helpers must not call public locked entry points while holding
/// the lock (no lock-under-lock).
class LeafCommandQueue {
  Future<void> _tail = Future<void>.value();
  bool _closed = false;
  Object? _owner;

  bool get isClosed => _closed;

  /// Whether a leaf command is currently executing.
  bool get isBusy => _owner != null;

  void close() {
    _closed = true;
  }

  /// Runs [body] as a leaf command. Concurrent callers are serialized.
  Future<T> run<T>(Future<T> Function() body) {
    if (_closed) {
      return Future<T>.error(
        StateError('LeafCommandQueue is closed'),
      );
    }
    final token = Object();
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;

    return previous.catchError((_) {}).then((_) async {
      if (_closed) {
        throw StateError('LeafCommandQueue is closed');
      }
      _owner = token;
      try {
        return await body();
      } finally {
        if (identical(_owner, token)) {
          _owner = null;
        }
        if (!gate.isCompleted) {
          gate.complete();
        }
      }
    });
  }
}

/// Bounded FIFO of observation ids for LRU eviction.
class BoundedObservationIds {
  BoundedObservationIds({this.capacity = 3});

  final int capacity;
  final Queue<String> _ids = Queue<String>();

  List<String> get ids => List.unmodifiable(_ids);

  /// Returns ids that fell out of the window (to drop from the registry).
  List<String> remember(String observationId) {
    _ids.remove(observationId);
    _ids.addLast(observationId);
    final dropped = <String>[];
    while (_ids.length > capacity) {
      dropped.add(_ids.removeFirst());
    }
    return dropped;
  }

  void clear() => _ids.clear();
}
