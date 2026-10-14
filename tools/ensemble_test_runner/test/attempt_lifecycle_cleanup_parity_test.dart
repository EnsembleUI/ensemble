import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/attempt_execution_boundary.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('host and standalone select cleanup failure after success',
      (tester) async {
    final host = await _runAdapter(
      tester,
      host: true,
      bodyFails: false,
      cleanupErrors: ['driver teardown failed'],
    );
    final standalone = await _runAdapter(
      tester,
      host: false,
      bodyFails: false,
      cleanupErrors: ['driver teardown failed'],
    );

    _expectSameOutcome(host, standalone);
    expect(host.completed, isTrue);
    expect(host.bodyError, isNull);
    expect(host.primaryFailure?.error.toString(),
        'Bad state: driver teardown failed');
  });

  testWidgets('host and standalone keep body failure primary', (tester) async {
    final host = await _runAdapter(
      tester,
      host: true,
      bodyFails: true,
      cleanupErrors: ['driver teardown failed'],
    );
    final standalone = await _runAdapter(
      tester,
      host: false,
      bodyFails: true,
      cleanupErrors: ['driver teardown failed'],
    );

    _expectSameOutcome(host, standalone);
    expect(host.bodyError.toString(), 'Bad state: test body failed');
    expect(host.primaryFailure?.error, same(host.bodyError));
  });

  testWidgets('host and standalone retain every teardown error in order',
      (tester) async {
    const cleanupErrors = [
      'artifact finalization failed',
      'driver teardown failed',
      'scope resource release failed',
    ];
    final host = await _runAdapter(
      tester,
      host: true,
      bodyFails: true,
      cleanupErrors: cleanupErrors,
    );
    final standalone = await _runAdapter(
      tester,
      host: false,
      bodyFails: true,
      cleanupErrors: cleanupErrors,
    );

    _expectSameOutcome(host, standalone);
    expect(
      host.closeFailures.map((failure) => failure.error.toString()),
      cleanupErrors.map((message) => 'Bad state: $message'),
    );
    expect(host.primaryFailure?.error, same(host.bodyError));
  });
}

Future<AttemptExecutionOutcome<void>> _runAdapter(
  WidgetTester tester, {
  required bool host,
  required bool bodyFails,
  required List<String> cleanupErrors,
}) {
  final boundary = AttemptExecutionBoundary(
    context: EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'cleanup-parity', steps: []),
    ),
    tester: tester,
  );

  // Host attempt finalization reports artifact errors before its registered
  // resource teardown; standalone owns all teardown through the cleanup stack.
  final stackErrors = host && cleanupErrors.isNotEmpty
      ? cleanupErrors.skip(1).toList()
      : cleanupErrors;
  for (final message in stackErrors.reversed) {
    boundary.addCleanup(() => throw StateError(message));
  }
  return boundary.runCaptured<void>(
    body: () async {
      if (bodyFails) throw StateError('test body failed');
    },
    beforeClose: host && cleanupErrors.isNotEmpty
        ? (_, __) async => throw StateError(cleanupErrors.first)
        : null,
  );
}

void _expectSameOutcome(
  AttemptExecutionOutcome<void> host,
  AttemptExecutionOutcome<void> standalone,
) {
  expect(host.completed, standalone.completed);
  expect(host.bodyError?.toString(), standalone.bodyError?.toString());
  expect(host.primaryFailure?.error.toString(),
      standalone.primaryFailure?.error.toString());
  expect(
    host.closeFailures.map((failure) => failure.error.toString()),
    standalone.closeFailures.map((failure) => failure.error.toString()),
  );
}
