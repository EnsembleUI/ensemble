import 'package:ensemble_test_runner/src/core/attempt_artifact_subscriber.dart';
import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ignores non-terminal attempt events', () {
    var publications = 0;
    final subscriber = AttemptArtifactSubscriber(
      publish: () => publications++,
    );

    expect(
      subscriber.call(const ExecutionEvent(
        sequence: 1,
        kind: ExecutionEventKind.stepFinished,
      )),
      isNull,
    );
    expect(publications, 0);
  });

  test('publishes exactly once for repeated terminal events', () async {
    var publications = 0;
    final subscriber = AttemptArtifactSubscriber(
      publish: () async {
        publications++;
        await Future<void>.delayed(Duration.zero);
      },
    );
    const event = ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.attemptFinished,
    );

    await subscriber.call(event);
    await subscriber.call(event);

    expect(publications, 1);
  });
}
