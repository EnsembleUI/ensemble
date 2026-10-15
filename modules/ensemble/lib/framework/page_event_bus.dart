import 'dart:async';

import 'package:event_bus/event_bus.dart';

/// Page-scoped EventBus with an index for Ensemble model listeners.
///
/// Direct listeners registered through either [EventBus.on] or
/// [EventBus.streamController.stream] share ordered slots with indexed
/// listeners. Events snapshot eligible slots when fired and deliver
/// asynchronously in registration order.
class PageEventBus extends EventBus {
  PageEventBus({required String? Function(Object? event) modelIdOf})
      : this._(_IndexedStreamController(modelIdOf));

  PageEventBus._(this._controller) : super.customController(_controller);

  final _IndexedStreamController _controller;

  /// Registers a model-specific listener, with [matches] applying source,
  /// property and scope checks after the index narrows candidate listeners.
  Stream<T> onIndexed<T>(String modelId, bool Function(T event) matches) =>
      _IndexedEventStream<T>(_controller, modelId, matches);
}

class _ListenerSlot {
  _ListenerSlot({
    required this.id,
    required this.output,
    this.modelId,
    this.matches,
  });

  final int id;
  final StreamController<dynamic> output;
  final String? modelId;
  final bool Function(dynamic)? matches;
  bool active = true;
}

/// Each listen call becomes one subscription at its EventBus registration
/// position. The single-subscription stream itself may still be used as a
/// normal broadcast source because every listen call receives a fresh slot.
class _IndexedEventStream<T> extends Stream<T> {
  _IndexedEventStream(this._controller, this._modelId, this._matches);

  final _IndexedStreamController _controller;
  final String? _modelId;
  final bool Function(T)? _matches;

  @override
  bool get isBroadcast => true;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _controller._listen<T>(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
        modelId: _modelId,
        matches: _matches,
      );
}

/// A StreamController-compatible ordered event hub. Each slot is backed by a
/// standard Dart subscription, which owns its pause queue and callback Zone.
class _IndexedStreamController implements StreamController<dynamic> {
  _IndexedStreamController(this._modelIdOf);

  final String? Function(Object? event) _modelIdOf;
  final Map<int, _ListenerSlot> _slots = {};
  final Map<String, List<int>> _modelSlots = {};
  final Map<String, int> _modelVersions = {};
  final List<int> _directSlots = [];
  final Completer<void> _doneCompleter = Completer<void>();
  int _nextId = 0;
  bool _closed = false;
  bool _addingStream = false;

  @override
  Stream<dynamic> get stream => _IndexedEventStream<dynamic>(this, null, null);

  @override
  StreamSink<dynamic> get sink => this;

  @override
  bool get isClosed => _closed;

  @override
  bool get hasListener => _slots.isNotEmpty;

  @override
  bool get isPaused => _slots.values.any((slot) => slot.output.isPaused);

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  void Function()? onListen;

  @override
  void Function()? get onPause => null;

  @override
  set onPause(void Function()? callback) => throw UnsupportedError(
      'Broadcast stream controllers do not support pause callbacks');

  @override
  void Function()? get onResume => null;

  @override
  set onResume(void Function()? callback) => throw UnsupportedError(
      'Broadcast stream controllers do not support resume callbacks');

  @override
  FutureOr<void> Function()? onCancel;

  StreamSubscription<T> _listen<T>(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
    String? modelId,
    bool Function(T event)? matches,
  }) {
    if (_closed) {
      final closed = StreamController<T>(sync: true)..close();
      return closed.stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
    }

    late final _ListenerSlot slot;
    final output = StreamController<T>.broadcast(
      sync: true,
      onCancel: () => _remove(slot),
    );
    slot = _ListenerSlot(
      id: _nextId++,
      output: output,
      modelId: modelId,
      matches: matches == null ? null : (event) => matches(event as T),
    );
    _slots[slot.id] = slot;
    if (modelId == null) {
      _directSlots.add(slot.id);
    } else {
      (_modelSlots[modelId] ??= <int>[]).add(slot.id);
      _modelVersions[modelId] = (_modelVersions[modelId] ?? 0) + 1;
    }
    if (_slots.length == 1) onListen?.call();

    return output.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  FutureOr<void> _remove(_ListenerSlot slot) {
    if (!slot.active) return null;
    slot.active = false;
    _slots.remove(slot.id);
    if (slot.modelId == null) {
      _directSlots.remove(slot.id);
    } else {
      final ids = _modelSlots[slot.modelId];
      ids?.remove(slot.id);
      _modelVersions[slot.modelId!] = (_modelVersions[slot.modelId] ?? 0) + 1;
      if (ids?.isEmpty ?? false) _modelSlots.remove(slot.modelId);
    }
    if (_slots.isEmpty) return onCancel?.call();
  }

  void _ensureCanAdd() {
    if (_closed) throw StateError('Cannot add event after closing');
    if (_addingStream)
      throw StateError('Cannot add event while adding a stream');
  }

  @override
  void add(dynamic event) {
    _ensureCanAdd();
    _dispatch(event);
  }

  void _dispatch(dynamic event) {
    final maxRegistrationId = _nextId - 1;
    // Direct subscribers are usually few. Snapshot them so subscriptions
    // created while this event is pending or being delivered cannot see it.
    final direct = List<int>.of(_directSlots);
    scheduleMicrotask(() => _deliver(event, direct, maxRegistrationId));
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _ensureCanAdd();
    // Errors are not model events, so all listeners (including bindings) get
    // the same error delivery they receive from a regular broadcast stream.
    final candidates = _slots.keys.toList(growable: false);
    scheduleMicrotask(() {
      for (final id in candidates) {
        final slot = _slots[id];
        if (slot != null && slot.active)
          slot.output.addError(error, stackTrace);
      }
    });
  }

  void _deliver(Object? event, List<int> direct, int maxRegistrationId) {
    var cursor = -1;
    var directIndex = 0;
    var modelId = _modelIdOf(event);
    var modelVersion = modelId == null ? 0 : (_modelVersions[modelId] ?? 0);
    var modelSlots = modelId == null
        ? const <int>[]
        : (_modelSlots[modelId] ?? const <int>[]);
    var modelIndex = _firstAfter(modelSlots, cursor);

    while (true) {
      while (directIndex < direct.length && direct[directIndex] <= cursor) {
        directIndex++;
      }
      final directId = directIndex < direct.length &&
              direct[directIndex] <= maxRegistrationId
          ? direct[directIndex]
          : null;

      int? bindingId;
      while (modelIndex < modelSlots.length) {
        final candidateId = modelSlots[modelIndex];
        if (candidateId <= cursor) {
          modelIndex++;
          continue;
        }
        // Do not inspect bindings beyond the next direct listener yet. That
        // listener may mutate the event, and those later bindings must filter
        // the mutated value when their registration turn is reached.
        if (directId != null && candidateId > directId) break;
        if (candidateId > maxRegistrationId) break;
        final candidate = _slots[candidateId];
        if (candidate != null &&
            candidate.active &&
            candidate.matches!(event)) {
          bindingId = candidateId;
          break;
        }
        modelIndex++;
      }

      if (directId == null && bindingId == null) return;
      final deliverDirect =
          directId != null && (bindingId == null || directId < bindingId);
      final id = deliverDirect ? directId : bindingId!;
      final slot = _slots[id];
      cursor = id;
      if (deliverDirect) directIndex++;
      if (slot != null && slot.active) slot.output.add(event);

      // Only recalculate the model index after a callback. This preserves the
      // old behavior if a listener mutates the event while avoiding repeated
      // model lookups for the normal, immutable-event path.
      final updatedModelId = _modelIdOf(event);
      final updatedVersion =
          updatedModelId == null ? 0 : (_modelVersions[updatedModelId] ?? 0);
      if (updatedModelId != modelId || updatedVersion != modelVersion) {
        modelId = updatedModelId;
        modelVersion = updatedVersion;
        modelSlots = modelId == null
            ? const <int>[]
            : (_modelSlots[modelId] ?? const <int>[]);
        modelIndex = _firstAfter(modelSlots, cursor);
      } else if (!deliverDirect) {
        modelIndex++;
      }
    }
  }

  int _firstAfter(List<int> ids, int value) {
    var low = 0;
    var high = ids.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (ids[mid] <= value) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  @override
  Future<void> addStream(Stream<dynamic> source, {bool? cancelOnError}) async {
    if (_addingStream) throw StateError('addStream is already in progress');
    if (_closed) throw StateError('Cannot add stream after closing');
    _addingStream = true;
    final completer = Completer<void>();
    late StreamSubscription<dynamic> subscription;
    subscription = source.listen(
      _dispatch,
      onError: (Object error, StackTrace stack) {
        _dispatchError(error, stack);
        if (cancelOnError == true && !completer.isCompleted) {
          subscription.cancel().whenComplete(completer.complete);
        }
      },
      onDone: completer.complete,
      cancelOnError: cancelOnError ?? false,
    );
    try {
      await completer.future;
    } finally {
      await subscription.cancel();
      _addingStream = false;
    }
  }

  @override
  Future close() {
    if (_closed) return done;
    if (_addingStream) {
      throw StateError('Cannot close while adding a stream');
    }
    _closed = true;
    final slots = _slots.values.toList(growable: false);
    // Closing a sync controller from its own callback throws StateError.
    // Defer closure until the current ordered delivery has unwound.
    scheduleMicrotask(() async {
      for (final slot in slots) {
        slot.active = false;
      }
      _slots.clear();
      _modelSlots.clear();
      _modelVersions.clear();
      _directSlots.clear();
      if (slots.isNotEmpty) await onCancel?.call();

      final closing = <Future<void>>[];
      for (final slot in slots) {
        closing.add(slot.output.close());
      }
      await Future.wait(closing);
      if (!_doneCompleter.isCompleted) _doneCompleter.complete();
    });
    return done;
  }

  void _dispatchError(Object error, StackTrace? stackTrace) {
    final candidates = _slots.keys.toList(growable: false);
    scheduleMicrotask(() {
      for (final id in candidates) {
        final slot = _slots[id];
        if (slot != null && slot.active)
          slot.output.addError(error, stackTrace);
      }
    });
  }
}
