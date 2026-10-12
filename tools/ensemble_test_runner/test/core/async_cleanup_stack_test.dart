import 'dart:async';

import 'package:ensemble_test_runner/src/core/async_cleanup_stack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runs every callback in reverse order after a cleanup failure',
      () async {
    final cleanup = AsyncCleanupStack();
    final events = <String>[];
    cleanup.add(() => events.add('first'));
    cleanup.add(() {
      events.add('second');
      throw StateError('second failed');
    });
    cleanup.add(() => events.add('third'));

    await expectLater(cleanup.close(), throwsStateError);
    expect(events, ['third', 'second', 'first']);
    expect(cleanup.failures, hasLength(1));
    expect(cleanup.failures.single.error, isA<StateError>());
  });

  test('retains every callback failure while throwing the first one', () async {
    final cleanup = AsyncCleanupStack();
    cleanup.add(() => throw StateError('first registered'));
    cleanup.add(() => throw FormatException('second registered'));

    await expectLater(cleanup.close(), throwsFormatException);

    expect(
      cleanup.failures.map((failure) => failure.error.toString()),
      ['FormatException: second registered', 'Bad state: first registered'],
    );
  });

  test('is idempotent after cleanup completed', () async {
    final cleanup = AsyncCleanupStack();
    var calls = 0;
    cleanup.add(() => calls++);

    await cleanup.close();
    await cleanup.close();

    expect(calls, 1);
  });

  test('overlapping close calls await one in-flight cleanup', () async {
    final cleanup = AsyncCleanupStack();
    final release = Completer<void>();
    var calls = 0;
    cleanup.add(() async {
      calls++;
      await release.future;
    });

    final first = cleanup.close();
    final second = cleanup.close();

    expect(identical(first, second), isTrue);
    expect(calls, 1);
    var firstCompleted = false;
    first.whenComplete(() => firstCompleted = true);
    await Future<void>.delayed(Duration.zero);
    expect(firstCompleted, isFalse);

    release.complete();
    await Future.wait([first, second]);
    expect(firstCompleted, isTrue);
    expect(calls, 1);
  });

  test('run cleans up once when the body succeeds', () async {
    final cleanup = AsyncCleanupStack();
    var calls = 0;
    cleanup.add(() => calls++);

    final value = await cleanup.run(() async => 42);

    expect(value, 42);
    expect(calls, 1);
    await cleanup.close();
    expect(calls, 1);
  });

  test('run keeps body failure primary when cleanup also fails', () async {
    final cleanup = AsyncCleanupStack();
    cleanup.add(() => throw StateError('cleanup failed'));

    await expectLater(
      cleanup.run<void>(() async => throw StateError('body failed')),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        'body failed',
      )),
    );
  });

  test('run closes exactly once when the body is cancelled', () async {
    final cleanup = AsyncCleanupStack();
    var calls = 0;
    cleanup.add(() => calls++);

    await expectLater(
      cleanup.run<void>(() async => throw StateError('cancelled')),
      throwsStateError,
    );
    await cleanup.close();

    expect(calls, 1);
  });
}
