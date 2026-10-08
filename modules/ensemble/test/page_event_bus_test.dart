import 'dart:async';

import 'package:ensemble/framework/page_event_bus.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter_test/flutter_test.dart';

class _ModelEvent {
  _ModelEvent(this.modelId, this.value);

  final String modelId;
  final Object? value;
}

class _ParentEvent {}

class _ChildEvent extends _ParentEvent {}

class _MutableModelEvent {
  _MutableModelEvent(this.modelId);

  String modelId;
}

class _MutablePropertyEvent {
  _MutablePropertyEvent(this.property);

  final String modelId = 'same-model';
  String property;
}

PageEventBus _newBus() => PageEventBus(
      modelIdOf: (event) => event is _ModelEvent ? event.modelId : null,
    );

void main() {
  test('EventBus public streams preserve registration order across indexes',
      () async {
    final bus = _newBus();
    final order = <String>[];
    bus
        .onIndexed<_ModelEvent>('a', (event) => true)
        .listen((_) => order.add('A'));
    bus.on<_ModelEvent>().listen((_) => order.add('direct-on'));
    bus.streamController.stream.listen((_) => order.add('direct-controller'));
    bus
        .onIndexed<_ModelEvent>('a', (event) => true)
        .listen((_) => order.add('B'));

    bus.fire(_ModelEvent('a', 1));
    expect(order, isEmpty, reason: 'the page EventBus remains asynchronous');
    await Future<void>.delayed(Duration.zero);

    expect(order, ['A', 'direct-on', 'direct-controller', 'B']);
    await bus.streamController.close();
  });

  test('indexed bindings skip unrelated model listeners', () async {
    final bus = _newBus();
    final seen = <String>[];
    var unrelatedPredicateChecks = 0;
    bus.onIndexed<_ModelEvent>('a', (_) => true).listen((_) => seen.add('a'));
    bus.onIndexed<_ModelEvent>('b', (_) {
      unrelatedPredicateChecks++;
      return true;
    }).listen((_) => seen.add('b'));
    bus.fire(_ModelEvent('a', 1));
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['a']);
    expect(unrelatedPredicateChecks, 0,
        reason: 'unrelated model bindings must not run their event filter');
    await bus.streamController.close();
  });

  test('registration after fire cannot see an event already in flight',
      () async {
    final bus = _newBus();
    final initial = <int>[];
    final late = <int>[];
    bus
        .onIndexed<_ModelEvent>('a', (_) => true)
        .listen((event) => initial.add(event.value as int));
    bus.fire(_ModelEvent('a', 1));
    bus
        .onIndexed<_ModelEvent>('a', (_) => true)
        .listen((event) => late.add(event.value as int));
    await Future<void>.delayed(Duration.zero);
    expect(initial, [1]);
    expect(late, isEmpty);
    await bus.streamController.close();
  });

  test('bindings and direct listeners retain ordinary EventBus order',
      () async {
    final bus = _newBus();
    final order = <String>[];
    bus.onIndexed<_ModelEvent>('a', (_) => true).listen((_) => order.add('A'));
    bus.on<_ModelEvent>().listen((_) => order.add('direct'));
    bus.onIndexed<_ModelEvent>('a', (_) => true).listen((_) => order.add('B'));
    bus.fire(_ModelEvent('a', 1));
    await Future<void>.delayed(Duration.zero);
    expect(order, ['A', 'direct', 'B']);
    await bus.streamController.close();
  });

  test('routing observes model ID mutation before and during delivery',
      () async {
    Future<List<String>> run(EventBus bus, {required bool indexed}) async {
      final seen = <String>[];
      void bind(String model, String label) {
        if (indexed) {
          (bus as PageEventBus)
              .onIndexed<_MutableModelEvent>(
                  model, (event) => event.modelId == model)
              .listen((_) => seen.add(label));
        } else {
          bus.on<_MutableModelEvent>().listen((event) {
            if (event.modelId == model) seen.add(label);
          });
        }
      }

      bind('a', 'A');
      bus.on<_MutableModelEvent>().listen((event) {
        event.modelId = 'b';
        seen.add('direct');
      });
      bind('b', 'B');

      bus.fire(_MutableModelEvent('a'));
      await Future<void>.delayed(Duration.zero);
      seen.clear();
      final changedBeforeDelivery = _MutableModelEvent('a');
      bus.fire(changedBeforeDelivery);
      changedBeforeDelivery.modelId = 'b';
      await Future<void>.delayed(Duration.zero);
      return seen;
    }

    final reference = EventBus();
    final referenceSeen = await run(reference, indexed: false);
    reference.destroy();
    final bus = PageEventBus(
      modelIdOf: (event) => event is _MutableModelEvent ? event.modelId : null,
    );
    final indexedSeen = await run(bus, indexed: true);
    expect(indexedSeen, referenceSeen);
    expect(indexedSeen, ['direct', 'B']);
    await bus.streamController.close();
  });

  test('later indexed callbacks filter after preceding direct mutation',
      () async {
    Future<List<String>> run(EventBus bus, {required bool indexed}) async {
      final seen = <String>[];
      void bind(String property, String label) {
        if (indexed) {
          (bus as PageEventBus)
              .onIndexed<_MutablePropertyEvent>(
                  'same-model', (event) => event.property == property)
              .listen((_) => seen.add(label));
        } else {
          bus.on<_MutablePropertyEvent>().listen((event) {
            if (event.modelId == 'same-model' && event.property == property) {
              seen.add(label);
            }
          });
        }
      }

      bind('not-current', 'before');
      bus.on<_MutablePropertyEvent>().listen((event) {
        event.property = 'changed';
        seen.add('direct');
      });
      bind('changed', 'after');
      bus.fire(_MutablePropertyEvent('initial'));
      await Future<void>.delayed(Duration.zero);
      return seen;
    }

    final reference = EventBus();
    final expected = await run(reference, indexed: false);
    reference.destroy();
    final bus = PageEventBus(
      modelIdOf: (event) =>
          event is _MutablePropertyEvent ? event.modelId : null,
    );
    final actual = await run(bus, indexed: true);
    expect(actual, expected);
    expect(actual, ['direct', 'after']);
    await bus.streamController.close();
  });

  test('cancel after fire suppresses a pending slot; new slot starts fresh',
      () async {
    final bus = _newBus();
    final seen = <Object?>[];
    final subscription = bus
        .onIndexed<_ModelEvent>('a', (_) => true)
        .listen((event) => seen.add(event.value));
    bus.fire(_ModelEvent('a', 'old'));
    await subscription.cancel();
    bus
        .onIndexed<_ModelEvent>('a', (_) => true)
        .listen((event) => seen.add(event.value));
    bus.fire(_ModelEvent('a', 'new'));
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['new']);
    await bus.streamController.close();
  });

  test('cancelling a later slot from an earlier callback prevents delivery',
      () async {
    Future<List<String>> run(EventBus bus) async {
      final seen = <String>[];
      late StreamSubscription<_ModelEvent> later;
      bus.on<_ModelEvent>().listen((_) {
        seen.add('first');
        later.cancel();
      });
      later = bus.on<_ModelEvent>().listen((_) => seen.add('later'));
      bus.on<_ModelEvent>().listen((_) => seen.add('last'));
      bus.fire(_ModelEvent('a', 1));
      await Future<void>.delayed(Duration.zero);
      return seen;
    }

    final reference = EventBus();
    final referenceSeen = await run(reference);
    reference.destroy();
    final bus = _newBus();
    final seen = await run(bus);
    expect(seen, referenceSeen);
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['first', 'last']);
    await bus.streamController.close();
  });

  test('controller listener lifecycle callbacks follow first/last listener',
      () async {
    final bus = _newBus();
    final callbacks = <String>[];
    bus.streamController.onListen = () => callbacks.add('listen');
    bus.streamController.onCancel = () => callbacks.add('cancel');
    final first = bus.on<dynamic>().listen((_) {});
    final second = bus.streamController.stream.listen((_) {});
    expect(bus.streamController.hasListener, isTrue);
    expect(callbacks, ['listen']);
    await first.cancel();
    expect(callbacks, ['listen']);
    await second.cancel();
    expect(callbacks, ['listen', 'cancel']);
    expect(bus.streamController.hasListener, isFalse);
    await bus.streamController.close();
  });

  test('broadcast controller rejects pause and resume callbacks', () {
    final bus = _newBus();
    expect(() => bus.streamController.onPause = () {}, throwsUnsupportedError);
    expect(() => bus.streamController.onResume = () {}, throwsUnsupportedError);
    bus.destroy();
  });

  test('controller close callback ordering matches EventBus', () async {
    Future<List<String>> run(EventBus bus) async {
      final callbacks = <String>[];
      bus.streamController.onCancel = () => callbacks.add('cancel');
      bus.on<dynamic>().listen((_) {}, onDone: () => callbacks.add('done'));
      await bus.streamController.close();
      await Future<void>.delayed(Duration.zero);
      return callbacks;
    }

    final reference = EventBus();
    final expected = await run(reference);
    final actual = await run(_newBus());
    expect(actual, expected);
    expect(actual, ['cancel', 'done']);
  });

  test('pause/resume queues events independently per subscription', () async {
    final bus = _newBus();
    final paused = <int>[];
    final active = <int>[];
    final pausedSubscription = bus
        .onIndexed<_ModelEvent>('a', (_) => true)
        .listen((event) => paused.add(event.value as int));
    bus
        .onIndexed<_ModelEvent>('a', (_) => true)
        .listen((event) => active.add(event.value as int));
    pausedSubscription.pause();
    bus.fire(_ModelEvent('a', 1));
    bus.fire(_ModelEvent('a', 2));
    await Future<void>.delayed(Duration.zero);
    expect(paused, isEmpty);
    expect(active, [1, 2]);
    pausedSubscription.resume();
    await Future<void>.delayed(Duration.zero);
    expect(paused, [1, 2]);
    await bus.streamController.close();
  });

  test('reentrant fire retains asynchronous ordered delivery', () async {
    final bus = _newBus();
    final seen = <String>[];
    bus.on<_ModelEvent>().listen((event) {
      seen.add('A${event.value}');
      if (event.value == 1) bus.fire(_ModelEvent('a', 2));
    });
    bus.on<_ModelEvent>().listen((event) => seen.add('B${event.value}'));
    bus.fire(_ModelEvent('a', 1));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['A1', 'B1', 'A2', 'B2']);
    await bus.streamController.close();
  });

  test('typed listeners preserve EventBus subtype filtering', () async {
    final bus = _newBus();
    final seen = <String>[];
    bus.on<_ParentEvent>().listen((_) => seen.add('parent'));
    bus.on<_ChildEvent>().listen((_) => seen.add('child'));
    bus.on<dynamic>().listen((_) => seen.add('dynamic'));
    bus.fire(_ChildEvent());
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['parent', 'child', 'dynamic']);
    await bus.streamController.close();
  });

  test('addError is delivered to indexed and direct subscribers', () async {
    final bus = _newBus();
    final errors = <Object>[];
    bus
        .onIndexed<_ModelEvent>('a', (_) => true)
        .listen((_) {}, onError: errors.add);
    bus.on<_ModelEvent>().listen((_) {}, onError: errors.add);
    bus.streamController.addError(StateError('bus error'));
    await Future<void>.delayed(Duration.zero);
    expect(errors, hasLength(2));
    expect(errors.every((error) => error is StateError), isTrue);
    await bus.streamController.close();
  });

  test('a listener exception stays in its Zone and does not block later slots',
      () async {
    Future<(List<int>, List<Object>)> run(EventBus bus) async {
      final seen = <int>[];
      final errors = <Object>[];
      runZonedGuarded(() {
        bus.on<_ModelEvent>().listen((_) => throw StateError('listener'));
        bus.on<_ModelEvent>().listen((event) => seen.add(event.value as int));
        bus.fire(_ModelEvent('a', 1));
      }, (error, _) => errors.add(error));
      await Future<void>.delayed(Duration.zero);
      return (seen, errors);
    }

    final reference = EventBus();
    final expected = await run(reference);
    reference.destroy();
    final bus = _newBus();
    final actual = await run(bus);
    expect(actual.$1, expected.$1);
    expect(actual.$2.map((error) => error.runtimeType),
        expected.$2.map((error) => error.runtimeType));
    expect(actual.$1, [1]);
    expect(actual.$2.single, isA<StateError>());
    await bus.streamController.close();
  });

  test('addStream forwards events and restores controller state', () async {
    final bus = _newBus();
    final seen = <int>[];
    bus.on<_ModelEvent>().listen((event) => seen.add(event.value as int));
    await bus.streamController.addStream(
      Stream<_ModelEvent>.fromIterable([
        _ModelEvent('a', 1),
        _ModelEvent('b', 2),
      ]),
    );
    await Future<void>.delayed(Duration.zero);
    expect(seen, [1, 2]);
    await bus.streamController.close();
  });

  test('addStream cancelOnError forwards error and releases add lock',
      () async {
    final bus = _newBus();
    final errors = <Object>[];
    bus.on<_ModelEvent>().listen((_) {}, onError: errors.add);
    final source = StreamController<_ModelEvent>();
    final adding =
        bus.streamController.addStream(source.stream, cancelOnError: true);
    source.addError(StateError('source error'));
    await adding;
    bus.fire(_ModelEvent('a', 'after stream'));
    await Future<void>.delayed(Duration.zero);
    expect(errors, hasLength(1));
    await source.close();
    await bus.streamController.close();
  });

  test('destroy closes stream and reports isClosed', () async {
    final bus = _newBus();
    var done = false;
    bus.on<dynamic>().listen((_) {}, onDone: () => done = true);
    bus.destroy();
    expect(bus.streamController.isClosed, isTrue);
    await bus.streamController.done;
    expect(done, isTrue);
  });

  test('close waits for a paused subscriber to resume and receive done',
      () async {
    final bus = _newBus();
    final seen = <int>[];
    var done = false;
    final subscription =
        bus.on<int>().listen(seen.add, onDone: () => done = true);
    subscription.pause();
    bus.fire(1);
    bus.destroy();
    await Future<void>.delayed(Duration.zero);
    expect(seen, isEmpty);
    expect(done, isFalse);
    subscription.resume();
    await bus.streamController.done;
    expect(seen, [1]);
    expect(done, isTrue);
  });

  test('regular EventBus remains unchanged for app-wide events', () async {
    final bus = EventBus();
    final seen = <Object>[];
    bus.on<String>().listen(seen.add);
    bus.fire('global');
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['global']);
    bus.destroy();
  });

  test('registering a listener after destroy is inert and receives done',
      () async {
    final bus = _newBus();
    var onListenCalls = 0;
    bus.streamController.onListen = () => onListenCalls++;
    bus.on<_ModelEvent>().listen((_) {});
    expect(bus.streamController.hasListener, isTrue);

    bus.destroy();
    await bus.streamController.done;
    expect(bus.streamController.isClosed, isTrue);
    expect(bus.streamController.hasListener, isFalse);

    final seen = <Object?>[];
    var indexedDone = false;
    bus.onIndexed<_ModelEvent>('a', (_) => true).listen(
          (event) => seen.add(event.value),
          onDone: () => indexedDone = true,
        );
    var directDone = false;
    bus.on<_ModelEvent>().listen((_) {}, onDone: () => directDone = true);
    await Future<void>.delayed(Duration.zero);

    expect(seen, isEmpty,
        reason: 'a listener registered after destroy must not receive events');
    expect(indexedDone, isTrue);
    expect(directDone, isTrue);
    expect(onListenCalls, 1,
        reason: 'late registrations must not be treated as first listeners');
  });

  test('firing after destroy throws and destroy/close are idempotent',
      () async {
    final bus = _newBus();
    bus.on<_ModelEvent>().listen((_) {});
    bus.destroy();
    bus.destroy();
    expect(() => bus.fire(_ModelEvent('a', 1)), throwsStateError);
    expect(() => bus.streamController.add(_ModelEvent('a', 1)),
        throwsStateError);
    await bus.streamController.done;
    expect(bus.streamController.isClosed, isTrue);
  });

  test('many indexed listeners sharing one model id all receive the event',
      () async {
    final bus = _newBus();
    const count = 1000;
    final received = List<int>.filled(count, 0);
    var unrelatedPredicateChecks = 0;
    for (var i = 0; i < count; i++) {
      bus
          .onIndexed<_ModelEvent>(
              'target', (event) => event.modelId == 'target')
          .listen((event) => received[i] = (event.value as int) + 1);
      // A second listener tree for a different model must never run its filter.
      bus.onIndexed<_ModelEvent>('other', (event) {
        unrelatedPredicateChecks++;
        return true;
      }).listen((_) {});
    }
    bus.fire(_ModelEvent('target', 7));
    await Future<void>.delayed(Duration.zero);
    expect(received.every((value) => value == 8), isTrue,
        reason: 'every binding on the shared model must fire exactly once');
    expect(unrelatedPredicateChecks, 0,
        reason: 'bindings on other models must not evaluate their predicate');
    await bus.streamController.close();
  });

  test('reentrant fired events from indexed listeners stay ordered', () async {
    final bus = _newBus();
    final seen = <String>[];
    bus.onIndexed<_ModelEvent>('a', (_) => true).listen((event) {
      seen.add('A${event.value}');
      if (event.value == 1) {
        bus.fire(_ModelEvent('a', 2));
      }
    });
    bus
        .onIndexed<_ModelEvent>('a', (_) => true)
        .listen((event) => seen.add('B${event.value}'));
    bus.fire(_ModelEvent('a', 1));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['A1', 'B1', 'A2', 'B2']);
    await bus.streamController.close();
  });

  test('rapid create/destroy cycles leave no retained slots', () async {
    for (var i = 0; i < 200; i++) {
      final bus = _newBus();
      for (var j = 0; j < 5; j++) {
        bus.onIndexed<_ModelEvent>('a', (_) => true).listen((_) {});
      }
      bus.on<_ModelEvent>().listen((_) {});
      expect(bus.streamController.hasListener, isTrue);
      bus.destroy();
      await bus.streamController.done;
      expect(bus.streamController.hasListener, isFalse);
      expect(bus.streamController.isClosed, isTrue);
    }
  });
}
