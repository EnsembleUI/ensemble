import 'dart:async';

import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/runner/test_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test journey begins after pending launch routes are recorded',
      () async {
    final recorder = NavigationFlowRecorder(
      screenChanges: () => const Stream.empty(),
    )..seed(['old-test-route']);
    final observedLaunchRoutes = <String>[];
    recorder.onScreenAdded = observedLaunchRoutes.add;
    recorder.recordScreenChange(
      VisibleScreen(
        screenName: 'LaunchRoute',
        screenId: 'launch',
        visibleSince: DateTime(2026),
      ),
    );

    await recorder.beginTestAfterPending(() {
      expect(observedLaunchRoutes, ['LaunchRoute']);
      return 'CurrentRoute';
    });

    expect(recorder.flow, ['CurrentRoute']);
    expect(observedLaunchRoutes, ['LaunchRoute']);
  });

  test('records rapid consecutive screen changes without dropping any',
      () async {
    final flow = NavigationFlowRecorder();
    flow.beginTest('AutoSignIn');

    flow.recordScreenChange(
      VisibleScreen(
        screenName: 'AutoSignIn_Device',
        visibleSince: DateTime.now(),
      ),
    );
    flow.recordScreenChange(
      VisibleScreen(screenName: 'Home', visibleSince: DateTime.now()),
    );
    await flow.flushPending();

    expect(flow.flow, ['AutoSignIn', 'AutoSignIn_Device', 'Home']);
  });

  test('onScreenAdded fires for each newly recorded screen', () async {
    final seen = <String>[];
    final flow = NavigationFlowRecorder();
    flow.beginTest(null);
    flow.onScreenAdded = (name) async {
      seen.add(name);
    };

    flow.recordScreenChange(
      VisibleScreen(
        screenName: 'AutoSignIn_Device',
        visibleSince: DateTime.now(),
      ),
    );
    flow.recordScreenChange(
      VisibleScreen(screenName: 'Home', visibleSince: DateTime.now()),
    );
    await flow.flushPending();

    expect(flow.flow, ['AutoSignIn_Device', 'Home']);
    expect(seen, ['AutoSignIn_Device', 'Home']);
  });

  test('recorder instances isolate flow, callbacks, and listener disposal',
      () async {
    final firstChanges = StreamController<VisibleScreen?>.broadcast(sync: true);
    final secondChanges =
        StreamController<VisibleScreen?>.broadcast(sync: true);
    final first =
        NavigationFlowRecorder(screenChanges: () => firstChanges.stream);
    final second =
        NavigationFlowRecorder(screenChanges: () => secondChanges.stream);
    final firstCallbacks = <String>[];
    final secondCallbacks = <String>[];
    first
      ..beginTest('First')
      ..onScreenAdded = firstCallbacks.add;
    second
      ..beginTest('Second')
      ..onScreenAdded = secondCallbacks.add;
    await Future.wait([
      first.startListeningWhenReady(),
      second.startListeningWhenReady(),
    ]);

    firstChanges.add(VisibleScreen(
      screenName: 'FirstNext',
      visibleSince: DateTime.now(),
    ));
    secondChanges.add(VisibleScreen(
      screenName: 'SecondNext',
      visibleSince: DateTime.now(),
    ));
    await Future.wait([first.flushPending(), second.flushPending()]);

    expect(first.flow, ['First', 'FirstNext']);
    expect(second.flow, ['Second', 'SecondNext']);
    expect(firstCallbacks, ['FirstNext']);
    expect(secondCallbacks, ['SecondNext']);

    await first.dispose();
    firstChanges.add(VisibleScreen(
      screenName: 'IgnoredAfterDispose',
      visibleSince: DateTime.now(),
    ));
    secondChanges.add(VisibleScreen(
      screenName: 'SecondStillActive',
      visibleSince: DateTime.now(),
    ));
    await second.flushPending();

    expect(first.flow, isEmpty);
    expect(firstCallbacks, ['FirstNext']);
    expect(second.flow, ['Second', 'SecondNext', 'SecondStillActive']);
    expect(secondCallbacks, ['SecondNext', 'SecondStillActive']);

    await second.dispose();
    await firstChanges.close();
    await secondChanges.close();
  });

  test('starting an active recorder twice keeps one stream subscription',
      () async {
    var streamRequests = 0;
    final changes = StreamController<VisibleScreen?>.broadcast(sync: true);
    final recorder = NavigationFlowRecorder(screenChanges: () {
      streamRequests++;
      return changes.stream;
    });
    await recorder.startListeningWhenReady();
    await recorder.startListeningWhenReady();

    expect(streamRequests, 1);
    expect(changes.hasListener, isTrue);

    changes.add(VisibleScreen(
      screenName: 'Home',
      visibleSince: DateTime.now(),
    ));
    await recorder.flushPending();
    expect(recorder.flow, ['Home']);

    await recorder.stopListening();
    await recorder.startListeningWhenReady();
    expect(streamRequests, 2);
    await recorder.dispose();
    await changes.close();
  });

  test('attempt startup waits for prior listener cancellation', () async {
    final cancellationCleanup = Completer<void>();
    var listenerStarts = 0;
    final controller = StreamController<VisibleScreen?>.broadcast(sync: true);
    final changes = _DelayedCancelStream(
      controller.stream,
      cancellationCleanup.future,
      onListen: () => listenerStarts++,
    );
    final recorder = NavigationFlowRecorder(screenChanges: () => changes);
    await recorder.startListeningWhenReady();

    await recorder.stopListening();
    var started = false;
    final start = recorder.startListeningWhenReady().then((_) {
      started = true;
    });

    expect(started, isFalse);
    expect(listenerStarts, 1);
    cancellationCleanup.complete();
    await start;
    expect(listenerStarts, 2);

    controller.add(VisibleScreen(
      screenName: 'NextAttemptHome',
      visibleSince: DateTime.now(),
    ));
    await recorder.flushPending();
    expect(recorder.flow, ['NextAttemptHome']);

    await recorder.dispose();
    await controller.close();
  });

  test('callback failure does not discard later pending screen events',
      () async {
    final controller = StreamController<VisibleScreen?>.broadcast(sync: true);
    final recorder = NavigationFlowRecorder(
      screenChanges: () => controller.stream,
    );
    final callbacks = <String>[];
    recorder.onScreenAdded = (name) {
      callbacks.add(name);
      if (name == 'First') {
        controller.add(
          VisibleScreen(screenName: 'Third', visibleSince: DateTime.now()),
        );
        throw StateError('evidence callback failed');
      }
    };
    await recorder.startListeningWhenReady();
    controller.add(
      VisibleScreen(screenName: 'First', visibleSince: DateTime.now()),
    );
    controller.add(
      VisibleScreen(screenName: 'Second', visibleSince: DateTime.now()),
    );

    await expectLater(
      recorder.flushPending(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'evidence callback failed',
        ),
      ),
    );

    expect(callbacks, ['First', 'Second', 'Third']);
    expect(recorder.flow, ['First', 'Second', 'Third']);
    await recorder.dispose();
    await controller.close();
  });

  test('disposal clears local state when stream cancellation fails', () async {
    final controller = StreamController<VisibleScreen?>.broadcast(sync: true);
    var cancellationCalls = 0;
    final recorder = NavigationFlowRecorder(
      screenChanges: () => _FailingCancelStream(
        controller.stream,
        onCancel: () => cancellationCalls++,
      ),
    )..beginTest('Home');
    recorder.onScreenAdded = (_) {};
    await recorder.startListeningWhenReady();

    await expectLater(recorder.dispose(), throwsStateError);
    await recorder.dispose();

    expect(recorder.isListening, isFalse);
    expect(recorder.onScreenAdded, isNull);
    expect(recorder.flow, isEmpty);
    expect(cancellationCalls, 1);
    await controller.close();
  });

  test('failed disposal stays local to its recorder', () async {
    final failingController =
        StreamController<VisibleScreen?>.broadcast(sync: true);
    final activeController =
        StreamController<VisibleScreen?>.broadcast(sync: true);
    var cancellationCalls = 0;
    final failing = NavigationFlowRecorder(
      screenChanges: () => _FailingCancelStream(
        failingController.stream,
        onCancel: () => cancellationCalls++,
      ),
    )..beginTest('Failing');
    final active = NavigationFlowRecorder(
      screenChanges: () => activeController.stream,
    )..beginTest('Active');
    await Future.wait([
      failing.startListeningWhenReady(),
      active.startListeningWhenReady(),
    ]);

    await expectLater(failing.dispose(), throwsStateError);
    await failing.dispose();
    failingController.add(
      VisibleScreen(screenName: 'Ignored', visibleSince: DateTime.now()),
    );
    activeController.add(
      VisibleScreen(screenName: 'Still active', visibleSince: DateTime.now()),
    );
    await active.flushPending();

    expect(cancellationCalls, 1);
    expect(failing.isListening, isFalse);
    expect(failing.flow, isEmpty);
    expect(active.isListening, isTrue);
    expect(active.flow, ['Active', 'Still active']);

    await active.dispose();
    await failingController.close();
    await activeController.close();
  });
}

class _DelayedCancelStream extends Stream<VisibleScreen?> {
  _DelayedCancelStream(
    this.delegate,
    this.cancelCompletion, {
    required this.onListen,
  });

  final Stream<VisibleScreen?> delegate;
  final Future<void> cancelCompletion;
  final void Function() onListen;

  @override
  StreamSubscription<VisibleScreen?> listen(
    void Function(VisibleScreen?)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    onListen();
    final subscription = delegate.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    return _DelayedCancelSubscription(subscription, cancelCompletion);
  }
}

class _DelayedCancelSubscription<T> implements StreamSubscription<T> {
  _DelayedCancelSubscription(this.delegate, this.cancelCompletion);

  final StreamSubscription<T> delegate;
  final Future<void> cancelCompletion;

  @override
  Future<void> cancel() async {
    await delegate.cancel();
    await cancelCompletion;
  }

  @override
  void onData(void Function(T)? handleData) => delegate.onData(handleData);

  @override
  void onError(Function? handleError) => delegate.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => delegate.onDone(handleDone);

  @override
  void pause([Future<void>? resumeSignal]) => delegate.pause(resumeSignal);

  @override
  void resume() => delegate.resume();

  @override
  bool get isPaused => delegate.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) => delegate.asFuture(futureValue);
}

class _FailingCancelStream extends Stream<VisibleScreen?> {
  _FailingCancelStream(this.delegate, {required this.onCancel});

  final Stream<VisibleScreen?> delegate;
  final void Function() onCancel;

  @override
  StreamSubscription<VisibleScreen?> listen(
    void Function(VisibleScreen?)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _FailingCancelSubscription(
      delegate.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      ),
      onCancel: onCancel,
    );
  }
}

class _FailingCancelSubscription<T> implements StreamSubscription<T> {
  _FailingCancelSubscription(this.delegate, {required this.onCancel});

  final StreamSubscription<T> delegate;
  final void Function() onCancel;

  @override
  Future<void> cancel() async {
    onCancel();
    await delegate.cancel();
    throw StateError('stream cleanup failed');
  }

  @override
  void onData(void Function(T)? handleData) => delegate.onData(handleData);

  @override
  void onError(Function? handleError) => delegate.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => delegate.onDone(handleDone);

  @override
  void pause([Future<void>? resumeSignal]) => delegate.pause(resumeSignal);

  @override
  void resume() => delegate.resume();

  @override
  bool get isPaused => delegate.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) => delegate.asFuture(futureValue);
}
