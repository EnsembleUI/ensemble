import 'dart:async';

import 'package:ensemble_test_runner/runner/event_driven_settler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settles after two quiet turns', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('ready')));

    await EventDrivenSettler(tester: tester).settle(
      timeout: const Duration(milliseconds: 200),
    );

    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('returns after the initial pump when the tree is already idle',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('idle')));
    var pumps = 0;

    await EventDrivenSettler(
      tester: tester,
      onPump: () => pumps++,
    ).settle(timeout: const Duration(milliseconds: 200));

    expect(pumps, 1);
  });

  testWidgets('flushes a post-frame state update before reporting action idle',
      (tester) async {
    var ready = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!ready) {
              setState(() => ready = true);
            }
          });
          return MaterialApp(home: Text(ready ? 'ready' : 'pending'));
        },
      ),
    );

    await EventDrivenSettler(tester: tester).settle(
      timeout: const Duration(milliseconds: 200),
    );

    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('bounds external work that never completes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('busy')));

    Object? failure;
    try {
      await EventDrivenSettler(
        tester: tester,
        hasExternalWork: () => true,
      ).settle(timeout: const Duration(milliseconds: 20));
    } on Object catch (error) {
      failure = error;
    }
    expect(failure, isA<FlutterError>());
  });

  testWidgets('counts external polling against the settle deadline',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('busy')));
    const timeout = Duration(milliseconds: 30);
    final start = tester.binding.clock.now();

    Object? failure;
    try {
      await EventDrivenSettler(
        tester: tester,
        hasExternalWork: () => true,
        externalWorkPollTimeout: const Duration(milliseconds: 100),
        activeFrameDuration: const Duration(milliseconds: 100),
        graceFrameDuration: const Duration(milliseconds: 16),
      ).settle(timeout: timeout);
    } on Object catch (error) {
      failure = error;
    }

    expect(failure, isA<FlutterError>());
    final elapsed = tester.binding.clock.now().difference(start);
    expect(elapsed, greaterThanOrEqualTo(timeout));
    expect(elapsed, lessThan(const Duration(milliseconds: 50)));
  });

  testWidgets('bounds an external completion signal that never completes',
      (tester) async {
    final never = Completer<void>();
    await tester.pumpWidget(const MaterialApp(home: Text('blocked')));

    Object? failure;
    try {
      await EventDrivenSettler(
        tester: tester,
        hasExternalWork: () => true,
        waitForExternalWork: () => never.future,
        externalWorkPollTimeout: const Duration(milliseconds: 10),
      ).settle(timeout: const Duration(milliseconds: 30));
    } on Object catch (error) {
      failure = error;
    }

    expect(failure, isA<FlutterError>());
  });

  testWidgets('external polling time counts against condition timeout',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('blocked')));
    const timeout = Duration(milliseconds: 250);
    final start = tester.binding.clock.now();

    Object? failure;
    try {
      await EventDrivenSettler(
        tester: tester,
        hasExternalWork: () => true,
        externalWorkPollTimeout: const Duration(milliseconds: 100),
        activeFrameDuration: const Duration(milliseconds: 100),
        graceFrameDuration: const Duration(milliseconds: 16),
      ).waitFor(condition: () => false, timeout: timeout);
    } on Object catch (error) {
      failure = error;
    }

    expect(failure, isA<FlutterError>());
    final elapsed = tester.binding.clock.now().difference(start);
    expect(elapsed, greaterThanOrEqualTo(timeout));
    expect(elapsed, lessThan(const Duration(milliseconds: 300)));
  });

  testWidgets('uses the external completion signal before active polling',
      (tester) async {
    var pending = true;
    var waits = 0;
    await tester.pumpWidget(const MaterialApp(home: Text('external')));

    await EventDrivenSettler(
      tester: tester,
      hasExternalWork: () => pending,
      waitForExternalWork: () {
        waits++;
        pending = false;
        return Future<void>.value();
      },
      activeFrameDuration: const Duration(milliseconds: 100),
    ).settle(timeout: const Duration(milliseconds: 200));

    expect(waits, 1);
    expect(pending, isFalse);
  });

  testWidgets('accepts a condition observed on the final external-work pump',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('boundary')));
    const timeout = Duration(milliseconds: 32);
    final start = tester.binding.clock.now();
    var pending = true;
    var ready = false;

    Object? failure;
    try {
      await EventDrivenSettler(
        tester: tester,
        hasExternalWork: () => pending,
        waitForExternalWork: () => Completer<void>().future,
        externalWorkPollTimeout: Duration.zero,
        graceFrameDuration: const Duration(milliseconds: 16),
        activeFrameDuration: timeout,
        onPump: () {
          if (tester.binding.clock.now().difference(start) >= timeout) {
            ready = true;
          }
        },
      ).waitFor(condition: () => ready, timeout: timeout);
    } on Object catch (error) {
      failure = error;
    }

    expect(failure, isNull);
    expect(ready, isTrue);
    expect(tester.binding.clock.now().difference(start), timeout);
  });

  testWidgets('accepts a condition observed on the final grace pump',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('grace-boundary')));
    const timeout = Duration(milliseconds: 16);
    final start = tester.binding.clock.now();
    var ready = false;

    Object? failure;
    try {
      await EventDrivenSettler(
        tester: tester,
        hasExternalWork: () => true,
        graceFrameDuration: timeout,
        onPump: () {
          if (tester.binding.clock.now().difference(start) >= timeout) {
            ready = true;
          }
        },
      ).waitFor(condition: () => ready, timeout: timeout);
    } on Object catch (error) {
      failure = error;
    }

    expect(failure, isNull);
    expect(ready, isTrue);
    expect(tester.binding.clock.now().difference(start), timeout);
  });

  testWidgets('waits for a condition without fixed-duration polling',
      (tester) async {
    var ready = false;
    await tester.pumpWidget(const MaterialApp(home: Text('waiting')));
    unawaited(Future<void>.delayed(const Duration(milliseconds: 10), () {
      ready = true;
    }));

    await EventDrivenSettler(tester: tester).waitFor(
      condition: () => ready,
      timeout: const Duration(milliseconds: 200),
    );

    expect(ready, isTrue);
  });

  testWidgets('does not pump when a condition is already true', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('ready')));
    var pumps = 0;

    await EventDrivenSettler(
      tester: tester,
      onPump: () => pumps++,
    ).waitFor(
      condition: () => true,
      timeout: const Duration(milliseconds: 200),
    );

    expect(pumps, 0);
  });
}
