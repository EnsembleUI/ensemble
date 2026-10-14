import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/operation_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('operation dispatch identities reject blank or padded names', () {
    for (final name in ['', '   ', ' tap']) {
      expect(
        () => OperationDescriptor(
          name: name,
          kind: OperationKind.interaction,
          argumentSchema: const {},
        ),
        throwsArgumentError,
        reason: 'name: "$name"',
      );
    }
  });

  test('aliases and handler keys reject blank or padded identities', () {
    for (final alias in ['', '   ', ' tap']) {
      expect(
        () => OperationDescriptor(
          name: 'tap',
          kind: OperationKind.interaction,
          argumentSchema: const {},
          aliases: [alias],
        ),
        throwsArgumentError,
        reason: 'alias: "$alias"',
      );
    }

    for (final handlerKey in ['', '   ', ' interaction.tap']) {
      expect(
        () => OperationDescriptor(
          name: 'tap',
          kind: OperationKind.interaction,
          argumentSchema: const {},
          handlerKey: handlerKey,
        ),
        throwsArgumentError,
        reason: 'handler key: "$handlerKey"',
      );
    }
  });

  test('control names reject blank and padded dispatch identities', () {
    for (final name in ['', '   ', ' group']) {
      expect(
        () => OperationRegistry(
          const [],
          controls: [ControlDescriptor(name: name, kind: ControlKind.group)],
        ),
        throwsArgumentError,
        reason: 'control: "$name"',
      );
    }
  });

  test('wait capability names reject blank and padded metadata', () {
    for (final kind in ['', '   ', ' text']) {
      expect(
        () => OperationDescriptor(
          name: 'waitFor',
          kind: OperationKind.wait,
          argumentSchema: const {},
          supportedWaitKinds: [kind],
        ),
        throwsArgumentError,
        reason: 'wait kind: "$kind"',
      );
    }
  });

  test('primary wait metadata is validated against operation kind and set', () {
    for (final kind in ['', '   ', ' text']) {
      expect(
        () => OperationDescriptor(
          name: 'waitFor',
          kind: OperationKind.wait,
          argumentSchema: const {},
          waitKind: kind,
          supportedWaitKinds: const ['navigation'],
        ),
        throwsArgumentError,
        reason: 'primary wait kind: "$kind"',
      );
    }

    expect(
      () => OperationDescriptor(
        name: 'tap',
        kind: OperationKind.interaction,
        argumentSchema: const {},
        waitKind: 'settle',
      ),
      throwsArgumentError,
      reason: 'non-wait operation declares a wait kind',
    );

    expect(
      () => OperationDescriptor(
        name: 'waitFor',
        kind: OperationKind.wait,
        argumentSchema: const {},
        waitKind: 'navigation',
        supportedWaitKinds: const ['settle'],
      ),
      throwsArgumentError,
      reason: 'supported kinds omit the primary wait kind',
    );
  });

  test('wait target state is constrained to valid wait metadata', () {
    for (final state in ['present', 'absent']) {
      final descriptor = OperationDescriptor(
        name: 'waitForTarget',
        kind: OperationKind.wait,
        argumentSchema: const {},
        waitKind: 'uiElement',
        waitTargetState: state,
      );
      expect(descriptor.waitTargetState, state);
    }

    for (final state in ['', 'visible', ' absent ']) {
      expect(
        () => OperationDescriptor(
          name: 'waitForTarget',
          kind: OperationKind.wait,
          argumentSchema: const {},
          waitKind: 'uiElement',
          waitTargetState: state,
        ),
        throwsArgumentError,
        reason: 'invalid target state "$state"',
      );
    }

    expect(
      () => OperationDescriptor(
        name: 'tap',
        kind: OperationKind.interaction,
        argumentSchema: const {},
        waitTargetState: 'absent',
      ),
      throwsArgumentError,
      reason: 'non-wait operations cannot declare a target state',
    );
  });
}
