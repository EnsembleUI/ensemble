import 'dart:async';

import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:ensemble_test_runner/src/core/compiler.dart';
import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/execution_kernel_runner.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/operation_registry.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';
import 'package:ensemble_test_runner/src/core/plan_wire_transport.dart';
import 'package:ensemble_test_runner/src/core/policy.dart';
import 'package:ensemble_test_runner/src/core/runtime.dart';
import 'package:ensemble_test_runner/src/core/step_timing_subscriber.dart';
import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registry rejects duplicate canonical names and aliases', () {
    final tap = OperationDescriptor(
      name: 'tap',
      kind: OperationKind.interaction,
      argumentSchema: const {'type': 'object'},
      aliases: ['press'],
    );
    expect(
      () => OperationRegistry([
        tap,
        OperationDescriptor(
          name: 'press',
          kind: OperationKind.interaction,
          argumentSchema: const {'type': 'object'},
        ),
      ]),
      throwsArgumentError,
    );
    final registry = OperationRegistry([tap]);
    expect(registry.lookup('press'), same(tap));
    expect(registry.canonicalNames, {'tap'});
    expect(identical(registry.canonicalNames, registry.canonicalNames), isTrue);
  });

  test('registry rejects empty handler keys', () {
    expect(
      () => OperationDescriptor(
        name: 'tap',
        kind: OperationKind.interaction,
        handlerKey: '   ',
        argumentSchema: const {},
      ),
      throwsArgumentError,
    );
  });

  test('descriptor timeout permission requires an integer schema property', () {
    expect(
      () => OperationDescriptor(
        name: 'expectText',
        kind: OperationKind.assertion,
        argumentSchema: const {'type': 'object', 'properties': {}},
        acceptsTimeout: true,
      ),
      throwsArgumentError,
    );
    expect(
      () => OperationDescriptor(
        name: 'expectText',
        kind: OperationKind.assertion,
        argumentSchema: const {
          'type': 'object',
          'properties': {
            'timeoutMs': {'type': 'string'}
          },
        },
        acceptsTimeout: true,
      ),
      throwsArgumentError,
    );
  });

  test('registry rejects handler keys shared across operation kinds', () {
    expect(
      () => OperationRegistry([
        OperationDescriptor(
          name: 'tap',
          kind: OperationKind.interaction,
          handlerKey: 'shared',
          argumentSchema: const {},
        ),
        OperationDescriptor(
          name: 'waitFor',
          kind: OperationKind.wait,
          handlerKey: 'shared',
          argumentSchema: const {},
        ),
      ]),
      throwsArgumentError,
    );
  });

  test('registry permits one handler key for operations of one kind', () {
    final registry = OperationRegistry([
      OperationDescriptor(
        name: 'tap',
        kind: OperationKind.interaction,
        handlerKey: 'shared',
        argumentSchema: const {},
      ),
      OperationDescriptor(
        name: 'press',
        kind: OperationKind.interaction,
        handlerKey: 'shared',
        argumentSchema: const {},
      ),
    ]);

    expect(registry.lookup('tap')!.handlerKey, 'shared');
    expect(registry.lookup('press')!.handlerKey, 'shared');
  });

  test('operation argument schemas are immutable at every level', () {
    final descriptor = OperationDescriptor(
      name: 'tap',
      kind: OperationKind.interaction,
      argumentSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string'},
        },
        'required': ['id'],
      },
    );

    expect(
      () => descriptor.argumentSchema['type'] = 'array',
      throwsUnsupportedError,
    );
    final properties = descriptor.argumentSchema['properties'] as Map;
    expect(() => properties['id'] = {}, throwsUnsupportedError);
    final required = descriptor.argumentSchema['required'] as List;
    expect(() => required.add('target'), throwsUnsupportedError);
  });

  test('every generated leaf step resolves through the core registry', () {
    for (final entry in TestStepRegistry.entries.entries) {
      if (entry.value.category == TestStepCategory.control) continue;
      final descriptor = operationRegistry.lookup(entry.key);
      expect(descriptor, isNotNull, reason: entry.key);
      expect(descriptor!.name, TestStepVocabulary.resolveStepType(entry.key));
      expect(descriptor.kind.name, entry.value.executionKind.name);
      if (entry.key == descriptor.name) {
        expect(descriptor.argumentSchema, entry.value.argumentSchema,
            reason: entry.key);
      } else {
        expect(descriptor.argumentSchema,
            TestStepVocabulary.argJsonSchemaFor(descriptor.name),
            reason: '${entry.key} should expose its canonical schema');
        expect(
          operationRegistry.lookup(entry.key),
          same(operationRegistry.lookup(descriptor.name)),
        );
      }
    }
  });

  test('specialized handler keys come from step metadata', () {
    for (final entry in TestStepRegistry.entries.entries) {
      final handlerKey = entry.value.handlerKey;
      if (handlerKey == null) continue;
      expect(
        operationRegistry.lookup(entry.key)!.handlerKey,
        handlerKey,
        reason: entry.key,
      );
    }
  });

  test('registry assigns stable handler keys to specialized operations', () {
    expect(
      operationRegistry.lookup('httpRequest')!.handlerKey,
      'http.request.direct',
    );
    expect(
      operationRegistry.lookup('setEnv')!.handlerKey,
      'environment.set',
    );
    expect(
      operationRegistry.lookup('resetApiCalls')!.handlerKey,
      'environment.resetApiCalls',
    );
    expect(
      operationRegistry.lookup('setStorage')!.handlerKey,
      'storage.set',
    );
    expect(
      operationRegistry.lookup('clearStorage')!.handlerKey,
      'storage.clear',
    );
    expect(
      operationRegistry.lookup('goBack')!.handlerKey,
      'lifecycle.goBack',
    );
    expect(
      operationRegistry.lookup('restartApp')!.handlerKey,
      'lifecycle.restartApp',
    );
    expect(
      operationRegistry.lookup('resetAppState')!.handlerKey,
      'lifecycle.resetAppState',
    );
    expect(
      operationRegistry.lookup('trigger')!.handlerKey,
      'lifecycle.trigger',
    );
    // Alias resolution retains the canonical descriptor and handler identity.
    expect(
      operationRegistry.lookup('launchApp')!.handlerKey,
      'lifecycle.restartApp',
    );
    expect(
      operationRegistry.lookup('expectApiCalled')!.handlerKey,
      'assertion.apiCalled',
    );
    expect(
      operationRegistry.lookup('expectApiNotCalled')!.handlerKey,
      'assertion.apiNotCalled',
    );
    expect(
      operationRegistry.lookup('expectStorage')!.handlerKey,
      'assertion.storageEquals',
    );
    expect(
      operationRegistry.lookup('setPermission')!.handlerKey,
      'environment.setPermission',
    );
    expect(
      operationRegistry.lookup('setLocale')!.handlerKey,
      'environment.setLocale',
    );
    expect(
      operationRegistry.lookup('setDevice')!.handlerKey,
      'environment.setDevice',
    );
    expect(
      operationRegistry.lookup('setTheme')!.handlerKey,
      'environment.setTheme',
    );
  });

  test('registry owns control classification and canonical action names', () {
    const controls = {
      'group': ControlKind.group,
      'repeat': ControlKind.repeat,
      'optional': ControlKind.optional,
      'ifVisible': ControlKind.ifVisible,
    };
    for (final entry in controls.entries) {
      final control = entry.key;
      expect(operationRegistry.isControl(control), isTrue);
      expect(operationRegistry.controlKind(control), entry.value);
      expect(operationRegistry.lookup(control), isNull);
    }
    expect(operationRegistry.namesForKind(OperationKind.interaction),
        contains('tap'));
    expect(operationRegistry.namesForKind(OperationKind.wait),
        contains('waitFor'));
    expect(operationRegistry.namesForKind(OperationKind.wait),
        isNot(contains('waitForText')));
    expect(operationRegistry.isControl('tap'), isFalse);
  });

  test('compiler rejects empty control blocks before execution', () {
    final compiler = PlanCompiler(operationRegistry);
    for (final name in ['group', 'repeat', 'optional', 'ifVisible']) {
      expect(
        () => compiler.compile('empty_$name', [
          PlanStep(
            name: name,
            input: name == 'repeat' ? const {'times': 1} : const {},
            source: SourceLocation('contract.yaml', 'steps[0]'),
          ),
        ]),
        throwsFormatException,
        reason: name,
      );
    }
  });

  test('optional recovery tracks only loops compiled in its body', () {
    final compiler = PlanCompiler(operationRegistry);
    PlanStep step(String name,
            {Map<String, Object?> input = const {},
            List<PlanStep> children = const []}) =>
        PlanStep(
          name: name,
          input: input,
          children: children,
          source: SourceLocation('scoped_loop_resets.yaml', name),
        );
    PlanStep repeat(int times, String id) => step(
          'repeat',
          input: {'times': times},
          children: [
            step('tap', input: {'id': id})
          ],
        );
    final plan = compiler.compile('scoped_loop_resets', [
      step('optional', children: [
        step('repeat', input: const {
          'times': 2
        }, children: [
          step('optional', children: [repeat(3, 'nested')]),
        ]),
        repeat(4, 'sibling'),
      ]),
      repeat(5, 'outside'),
    ]);
    final loopIds =
        plan.nodes.values.whereType<LoopNode>().map((e) => e.id).toSet();
    final recoveries = plan.nodes.values.whereType<RecoveryNode>().toList();

    expect(loopIds, hasLength(4));
    expect(recoveries, hasLength(2));
    final nestedRecovery = recoveries.singleWhere(
      (recovery) => recovery.resetLoops.length == 1,
    );
    final enclosingRecovery = recoveries.singleWhere(
      (recovery) => recovery.resetLoops.length == 3,
    );
    expect(
      nestedRecovery.resetLoops,
      everyElement(isIn(enclosingRecovery.resetLoops)),
    );
    expect(enclosingRecovery.resetLoops.difference(loopIds), isEmpty);
    expect(loopIds.difference(enclosingRecovery.resetLoops), hasLength(1));

    final reusedCompilerPlan = compiler.compile(
      'reused_compiler',
      [
        PlanStep(
          name: 'optional',
          children: [
            PlanStep(
              name: 'tap',
              input: const {'id': 'single'},
              source: const SourceLocation('reuse.yaml', 'steps[0].steps[0]'),
            ),
          ],
          source: const SourceLocation('reuse.yaml', 'steps[0]'),
        ),
      ],
    );
    expect(
      reusedCompilerPlan.nodes.values
          .whereType<RecoveryNode>()
          .single
          .resetLoops,
      isEmpty,
    );
  });

  test('compiler and kernel preserve every repeat-count boundary', () async {
    final compiler = PlanCompiler(
      operationRegistry,
      maxRepeatIterations: 2,
    );
    PlanStep repeat(Object? times) => PlanStep(
          name: 'repeat',
          input: {'times': times},
          source: const SourceLocation('contract.yaml', 'steps[0]'),
          children: [
            PlanStep(
              name: 'tap',
              input: const {'id': 'item'},
              source: const SourceLocation(
                'contract.yaml',
                'steps[0].steps[0]',
              ),
            ),
          ],
        );

    for (final value in [3, -1, 2.5, double.infinity, double.nan]) {
      expect(
        () => compiler.compile('invalid_$value', [repeat(value)]),
        throwsFormatException,
        reason: 'repeat count $value must be rejected',
      );
    }

    for (final testCase in [
      (value: 0, expectedRuns: 0),
      (value: 1, expectedRuns: 1),
      (value: 2, expectedRuns: 2),
      (value: null, expectedRuns: 1),
    ]) {
      final plan = compiler.compile(
        'repeat_${testCase.value}',
        [repeat(testCase.value)],
      );
      expect(
        plan.nodes.values.whereType<LoopNode>().single.times,
        testCase.expectedRuns,
      );
      final runtime = _FakeRuntime(supported: {'tap'});
      final result = await ExecutionKernel(
        plan: plan,
        policy: CompiledExecutionPolicy(plan),
        runtime: runtime,
      ).run();
      expect(result.outcome, AttemptOutcome.passed);
      expect(runtime.executed, hasLength(testCase.expectedRuns));
    }

    expect(
      () => PlanCompiler(operationRegistry, maxRepeatIterations: 0),
      throwsArgumentError,
    );
  });

  test('compiled YAML follows nested control flow and optional recovery',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: flow
startScreen: Home
steps:
  - group:
      steps:
        - repeat:
            times: 2
            steps:
              - tap: {id: first}
        - ifVisible:
            id: banner
            steps:
              - optional:
                  step:
                    tap: {id: dismiss}
        - expectVisible: {id: ready}
''');
    final plan = CompiledPlanCompiler().compile(testCase);
    final runtime = _FakeRuntime(
      supported: {'tap', 'expectVisible'},
      visible: true,
      failName: 'tap',
      failInputId: 'dismiss',
    );
    final events = <ExecutionEvent>[];
    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: runtime,
      eventSubscribers: [events.add],
    ).run();

    expect(result.outcome, AttemptOutcome.passed);
    expect(runtime.executed,
        ['tap:first', 'tap:first', 'tap:dismiss', 'expectVisible:ready']);
    expect(runtime.observeCalls, 1);
    expect(runtime.observationLevels, [ObservationLevel.minimal]);
    expect(runtime.closeCalls, 1);
    expect(events.map((event) => event.sequence),
        orderedEquals(List.generate(events.length, (index) => index + 1)));
    expect(events.first.kind, ExecutionEventKind.attemptStarted);
    expect(events.last.kind, ExecutionEventKind.attemptFinished);
    expect(
      events
          .where((event) =>
              event.kind == ExecutionEventKind.stepStarted ||
              event.kind == ExecutionEventKind.stepFinished)
          .map((event) => '${event.kind.name}:${event.stepIndex}'),
      ['stepStarted:0', 'stepFinished:0'],
    );
  });

  test('event subscriptions dispatch only registered event kinds', () async {
    final testCase = EnsembleTestParser.parseString('''
id: filtered_events
startScreen: Home
steps:
  - tap: {id: first}
''');
    final plan = CompiledPlanCompiler().compile(testCase);
    final runtime = _FakeRuntime(supported: {'tap'});
    final allEvents = <ExecutionEvent>[];
    final selectedEvents = <ExecutionEventKind>[];

    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: runtime,
      eventSubscribers: [allEvents.add],
      eventSubscriptions: [
        EventSubscription(
          kinds: {ExecutionEventKind.stepFinished},
          handle: (event) => selectedEvents.add(event.kind),
        ),
      ],
    ).run();

    expect(result.outcome, AttemptOutcome.passed);
    expect(
      selectedEvents,
      [ExecutionEventKind.stepFinished],
    );
    expect(allEvents.length, result.events);
    expect(allEvents.last.kind, ExecutionEventKind.attemptFinished);
  });

  test('compiled visibility branches select exactly one arm', () async {
    final testCase = EnsembleTestParser.parseString('''
id: visibility_branch
startScreen: Home
steps:
  - ifVisible:
      id: banner
      steps:
        - tap: {id: dismiss}
  - tap: {id: continue}
''');
    final plan = CompiledPlanCompiler().compile(testCase);

    for (final scenario in [
      (visible: true, expected: ['tap:dismiss', 'tap:continue']),
      (visible: false, expected: ['tap:continue']),
    ]) {
      final runtime = _FakeRuntime(
        supported: {'tap'},
        visible: scenario.visible,
      );
      final result = await ExecutionKernel(
        plan: plan,
        policy: CompiledExecutionPolicy(plan),
        runtime: runtime,
      ).run();

      expect(result.outcome, AttemptOutcome.passed);
      expect(runtime.executed, scenario.expected);
      expect(runtime.observeCalls, 1);
      expect(runtime.observationLevels, [ObservationLevel.minimal]);
      expect(runtime.closeCalls, 1);
    }
  });

  test('structured visibility branch preserves its target and child order',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: structured_visibility_branch
startScreen: Home
steps:
  - ifVisible:
      target: {text: Banner, within: {testId: banner_region}}
      steps:
        - tap: {id: dismiss}
        - group:
            steps:
              - tap: {id: confirm}
  - tap: {id: continue}
''');
    final plan = CompiledPlanCompiler().compile(testCase);
    const target = {
      'target': {
        'text': 'Banner',
        'within': {'testId': 'banner_region'},
      },
    };

    for (final scenario in [
      (visible: true, expected: ['tap:dismiss', 'tap:confirm', 'tap:continue']),
      (visible: false, expected: ['tap:continue']),
    ]) {
      final runtime = _FakeRuntime(
        supported: {'tap'},
        visible: scenario.visible,
      );
      final result = await ExecutionKernel(
        plan: plan,
        policy: CompiledExecutionPolicy(plan),
        runtime: runtime,
      ).run();

      expect(result.outcome, AttemptOutcome.passed);
      expect(runtime.executed, scenario.expected);
      expect(runtime.observedTargets, [target]);
      expect(runtime.observationLevels, [ObservationLevel.minimal]);
      expect(runtime.closeCalls, 1);
    }
  });

  test('shared kernel runner supplies the compiled policy by default',
      () async {
    final runtime = _FakeRuntime(supported: {'tap'});
    final events = <ExecutionEvent>[];
    final result = await ExecutionKernelRunner(
      plan: _singleOperationPlan(),
      runtime: runtime,
      eventSubscribers: [events.add],
    ).run();

    expect(result.outcome, AttemptOutcome.passed);
    expect(runtime.executed, ['tap:button']);
    expect(runtime.closeCalls, 1);
    expect(events.map((event) => event.kind),
        contains(ExecutionEventKind.attemptFinished));
  });

  test('aliases are canonical before a runtime sees operations', () async {
    final testCase = EnsembleTestParser.parseString('''
id: aliases
startScreen: Home
steps:
  - launchApp: {}
''');
    final plan = CompiledPlanCompiler().compile(testCase);
    final runtime = _FakeRuntime(supported: {'restartApp'});
    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: runtime,
    ).run();
    expect(result.outcome, AttemptOutcome.passed,
        reason: result.primaryFailure);
    expect(runtime.executed, ['restartApp:null']);
  });

  test('every generated alias compiles to its canonical operation', () {
    final compiler = PlanCompiler(operationRegistry);
    final aliases = TestStepRegistry.entries.entries
        .where((entry) =>
            entry.value.category != TestStepCategory.control &&
            TestStepVocabulary.resolveStepType(entry.key) != entry.key)
        .toList(growable: false);

    expect(aliases, isNotEmpty);
    for (final entry in aliases) {
      final canonical = TestStepVocabulary.resolveStepType(entry.key);
      final plan = compiler.compile('alias_${entry.key}', [
        PlanStep(
          name: entry.key,
          input: const {'id': 'kept'},
          source: SourceLocation('contracts.test.yaml', entry.key),
        ),
      ]);
      final operation =
          plan.nodes.values.whereType<OperationNode>().single.operation;

      expect(operation.name, canonical, reason: entry.key);
      expect(operation.input, const {'id': 'kept'}, reason: entry.key);
      expect(operation.source.path, 'contracts.test.yaml', reason: entry.key);
      expect(operation.source.stepPath, entry.key, reason: entry.key);
    }
  });

  test('alias execution emits a stable canonical operation trace', () async {
    final testCase = EnsembleTestParser.parseString('''
id: alias_trace
startScreen: Home
steps:
  - launchApp: {}
''');
    final plan = CompiledPlanCompiler().compile(testCase);

    Future<List<String>> collectCanonicalTrace() async {
      final events = <ExecutionEvent>[];
      final result = await ExecutionKernel(
        plan: plan,
        policy: CompiledExecutionPolicy(plan),
        runtime: _FakeRuntime(supported: {'restartApp'}),
        eventSubscribers: [events.add],
      ).run();
      expect(result.outcome, AttemptOutcome.passed);
      return events
          .where((event) =>
              event.kind == ExecutionEventKind.operationStarted ||
              event.kind == ExecutionEventKind.operationFinished)
          .map((event) => '${event.kind.name}:${event.operation}')
          .toList(growable: false);
    }

    final first = await collectCanonicalTrace();
    expect(
        first, ['operationStarted:restartApp', 'operationFinished:restartApp']);
    expect(await collectCanonicalTrace(), first);
  });

  test('the same plan and observations produce the same directive sequence',
      () async {
    final plan = _singleOperationPlan();
    Future<List<String>> collect() async {
      final directives = <String>[];
      final runtime = _FakeRuntime(supported: {'tap'});
      final result = await ExecutionKernel(
        plan: plan,
        policy: CompiledExecutionPolicy(plan),
        runtime: runtime,
        eventSubscribers: [
          (event) {
            if (event.kind == ExecutionEventKind.directiveSelected) {
              directives.add('${event.nodeId}:${event.detail}');
            }
          }
        ],
      ).run();
      expect(result.outcome, AttemptOutcome.passed);
      return directives;
    }

    expect(await collect(), await collect());
  });

  test('the same plan and runtime event sequence produce stable results',
      () async {
    final plan = _singleOperationPlan();
    Future<
        ({
          AttemptOutcome outcome,
          String? failure,
          String? failureCode,
          List<
              (
                int,
                ExecutionEventKind,
                String?,
                String?,
                String?,
                String?,
                int?
              )> events,
          List<String> operations,
          int closeCalls,
        })> collect() async {
      final runtime = _FakeRuntime(supported: {'tap'});
      final events = <ExecutionEvent>[];
      final result = await ExecutionKernel(
        plan: plan,
        policy: CompiledExecutionPolicy(plan),
        runtime: runtime,
        eventSubscribers: [events.add],
      ).run();
      return (
        outcome: result.outcome,
        failure: result.primaryFailure,
        failureCode: result.failureCode,
        events: events
            .map((event) => (
                  event.sequence,
                  event.kind,
                  event.nodeId,
                  event.detail,
                  event.operation,
                  event.source?.path,
                  event.stepIndex,
                ))
            .toList(growable: false),
        operations: runtime.executed,
        closeCalls: runtime.closeCalls,
      );
    }

    final first = await collect();
    final second = await collect();

    expect(first.outcome, AttemptOutcome.passed);
    expect(second.outcome, first.outcome);
    expect(second.failure, first.failure);
    expect(second.failureCode, first.failureCode);
    expect(second.events, orderedEquals(first.events));
    expect(second.operations, orderedEquals(first.operations));
    expect(second.closeCalls, first.closeCalls);
    expect(
      first.events.map((event) => event.$1),
      orderedEquals(List.generate(first.events.length, (index) => index + 1)),
    );
    expect(first.closeCalls, 1);
  });

  test('nested loops reset their counters for each outer iteration', () async {
    final plan = PlanCompiler(OperationRegistry([
      OperationDescriptor(
        name: 'tap',
        kind: OperationKind.interaction,
        argumentSchema: const {'type': 'object'},
      ),
    ], controls: const [
      ControlDescriptor(name: 'repeat', kind: ControlKind.repeat),
    ])).compile('nested', [
      PlanStep(
        name: 'repeat',
        input: const {'times': 2},
        source: const SourceLocation('nested.yaml', 'steps[0]'),
        children: [
          PlanStep(
            name: 'repeat',
            input: const {'times': 2},
            source: const SourceLocation('nested.yaml', 'steps[0].steps[0]'),
            children: [
              PlanStep(
                name: 'tap',
                input: const {'id': 'item'},
                source: const SourceLocation(
                    'nested.yaml', 'steps[0].steps[0].steps[0]'),
              ),
            ],
          ),
        ],
      ),
    ]);
    final runtime = _FakeRuntime(supported: {'tap'});
    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: runtime,
    ).run();
    expect(result.outcome, AttemptOutcome.passed);
    expect(runtime.executed, hasLength(4));
  });

  test('optional failure clears loop state before the next outer iteration',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: optional_loop
startScreen: Home
steps:
  - repeat:
      times: 2
      steps:
        - optional:
            steps:
              - repeat:
                  times: 1
                  steps:
                    - tap: {id: missing}
        - tap: {id: after}
''');
    final plan = CompiledPlanCompiler().compile(testCase);
    final runtime = _FakeRuntime(
      supported: {'tap'},
      failName: 'tap',
      failInputId: 'missing',
    );
    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: runtime,
    ).run();
    expect(result.outcome, AttemptOutcome.passed);
    expect(runtime.executed,
        ['tap:missing', 'tap:after', 'tap:missing', 'tap:after']);
  });

  test('optional recovery does not swallow unexpected thrown failures',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: optional_throw
startScreen: Home
steps:
  - optional:
      step:
        tap: {id: missing}
  - tap: {id: after}
''');
    final plan = CompiledPlanCompiler().compile(testCase);
    final runtime = _FakeRuntime(
      supported: {'tap'},
      failInputId: 'missing',
      throwOnFailure: true,
    );
    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: runtime,
    ).run();
    expect(result.outcome, AttemptOutcome.failed);
    expect(result.cause, isA<StateError>());
    expect(runtime.executed, ['tap:missing']);
    expect(runtime.closeCalls, 1);
  });

  test('optional block does not recover a failed conditional observation',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: optional_observation
startScreen: Home
steps:
  - optional:
      step:
        ifVisible:
          target: {text: Banner}
          step:
            tap: {id: dismiss}
  - tap: {id: after}
''');
    final plan = CompiledPlanCompiler().compile(testCase);
    expect(plan.nodes.values.whereType<BranchNode>().single.target, {
      'target': {'text': 'Banner'}
    });
    final plans = [plan, ExecutionPlan.fromWire(plan.toWire())];
    final results = <AttemptResult>[];
    final traces = <List<String>>[];
    final observationFailureSources = <SourceLocation?>[];
    final runtimes = <_FakeRuntime>[];
    for (final executionPlan in plans) {
      final runtime = _FakeRuntime(
        supported: {'tap'},
        observeError: StateError('observation unavailable'),
      );
      final events = <ExecutionEvent>[];
      final result = await ExecutionKernel(
        plan: executionPlan,
        policy: CompiledExecutionPolicy(executionPlan),
        runtime: runtime,
        eventSubscribers: [events.add],
      ).run();
      results.add(result);
      traces.add(events
          .map((event) =>
              '${event.kind.name}:${event.nodeId}:${event.operation}:${event.detail}:${event.source}')
          .toList());
      observationFailureSources.add(events
          .singleWhere(
              (event) => event.kind == ExecutionEventKind.observationFailed)
          .source);
      runtimes.add(runtime);
    }

    for (final result in results) {
      expect(result.outcome, AttemptOutcome.failed);
      expect(result.failureCode, 'internalError');
      expect(result.cause, isA<StateError>());
      expect(result.failureSource?.path, '<memory>');
      expect(result.failureSource?.stepPath, 'steps[0].steps[0]');
    }
    expect(observationFailureSources, hasLength(2));
    for (final source in observationFailureSources) {
      expect(source?.path, '<memory>');
      expect(source?.stepPath, 'steps[0].steps[0]');
    }
    expect(results[1].failureOperation, results[0].failureOperation);
    expect(traces[1], traces[0]);
    for (final runtime in runtimes) {
      expect(runtime.executed, isEmpty);
      expect(runtime.observationLevels, [ObservationLevel.minimal]);
      expect(runtime.closeCalls, 1);
    }
  });

  test('nested bounded loops round-trip and preserve execution order',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: nested_bounded_loop_wire
startScreen: Home
steps:
  - repeat:
      times: 2
      steps:
        - tap: {id: outer_start}
        - repeat:
            times: 3
            steps:
              - tap: {id: inner}
        - tap: {id: outer_end}
  - tap: {id: after}
''');
    final compiled = CompiledPlanCompiler().compile(testCase);
    final plan = ExecutionPlan.fromWire(compiled.toWire());
    final runtime = _FakeRuntime(supported: {'tap'});

    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: runtime,
    ).run();

    expect(result.outcome, AttemptOutcome.passed);
    expect(runtime.executed, [
      'tap:outer_start',
      'tap:inner',
      'tap:inner',
      'tap:inner',
      'tap:outer_end',
      'tap:outer_start',
      'tap:inner',
      'tap:inner',
      'tap:inner',
      'tap:outer_end',
      'tap:after',
    ]);
    expect(runtime.closeCalls, 1);
  });

  test(
      'nested group branch recovery stays local across repeated iterations '
      'after wire decoding', () async {
    final testCase = EnsembleTestParser.parseString('''
id: nested_branch_recovery_matrix
startScreen: Home
steps:
  - repeat:
      times: 2
      steps:
        - optional:
            steps:
              - ifVisible:
                  id: banner
                  steps:
                    - group:
                        steps:
                          - tap: {id: dismiss}
                          - tap: {id: confirm}
              - tap: {id: optional_tail}
        - tap: {id: iteration_tail}
  - tap: {id: after_repeat}
''');
    final compiledPlan = CompiledPlanCompiler().compile(testCase);
    final plans = {
      'compiled': compiledPlan,
      'wire-decoded': ExecutionPlan.fromWire(compiledPlan.toWire()),
    };

    for (final scenario in [
      (
        visible: true,
        failInputId: 'dismiss',
        expected: [
          'tap:dismiss',
          'tap:iteration_tail',
          'tap:dismiss',
          'tap:iteration_tail',
          'tap:after_repeat',
        ],
      ),
      (
        visible: true,
        failInputId: 'confirm',
        expected: [
          'tap:dismiss',
          'tap:confirm',
          'tap:iteration_tail',
          'tap:dismiss',
          'tap:confirm',
          'tap:iteration_tail',
          'tap:after_repeat',
        ],
      ),
      (
        visible: true,
        failInputId: null,
        expected: [
          'tap:dismiss',
          'tap:confirm',
          'tap:optional_tail',
          'tap:iteration_tail',
          'tap:dismiss',
          'tap:confirm',
          'tap:optional_tail',
          'tap:iteration_tail',
          'tap:after_repeat',
        ],
      ),
      (
        visible: false,
        failInputId: 'dismiss',
        expected: [
          'tap:optional_tail',
          'tap:iteration_tail',
          'tap:optional_tail',
          'tap:iteration_tail',
          'tap:after_repeat',
        ],
      ),
      (
        visible: false,
        failInputId: 'confirm',
        expected: [
          'tap:optional_tail',
          'tap:iteration_tail',
          'tap:optional_tail',
          'tap:iteration_tail',
          'tap:after_repeat',
        ],
      ),
      (
        visible: false,
        failInputId: null,
        expected: [
          'tap:optional_tail',
          'tap:iteration_tail',
          'tap:optional_tail',
          'tap:iteration_tail',
          'tap:after_repeat',
        ],
      ),
    ]) {
      for (final entry in plans.entries) {
        final runtime = _FakeRuntime(
          supported: {'tap'},
          visible: scenario.visible,
          failInputId: scenario.failInputId,
        );
        final result = await ExecutionKernel(
          plan: entry.value,
          policy: CompiledExecutionPolicy(entry.value),
          runtime: runtime,
        ).run();

        final reason = '${entry.key}: visible=${scenario.visible}, '
            'failInputId=${scenario.failInputId}';
        expect(result.outcome, AttemptOutcome.passed, reason: reason);
        expect(runtime.executed, scenario.expected, reason: reason);
        expect(runtime.observeCalls, 2, reason: reason);
        expect(
            runtime.observedTargets,
            [
              const {'id': 'banner'},
              const {'id': 'banner'},
            ],
            reason: reason);
        expect(
            runtime.observationLevels,
            [
              ObservationLevel.minimal,
              ObservationLevel.minimal,
            ],
            reason: reason);
        expect(runtime.closeCalls, 1, reason: reason);
      }
    }
  });

  test('nested control-flow outcomes match between compiled and wire plans',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: control_flow_wire_matrix
startScreen: Home
steps:
  - repeat:
      times: 2
      steps:
        - optional:
            steps:
              - ifVisible:
                  id: banner
                  steps:
                    - group:
                        steps:
                          - tap: {id: first}
                          - tap: {id: second}
              - tap: {id: optional_tail}
        - tap: {id: iteration_tail}
  - tap: {id: after_repeat}
''');
    final compiled = CompiledPlanCompiler().compile(testCase);
    final plans = [
      compiled,
      ExecutionPlan.fromWire(compiled.toWire()),
    ];

    for (final visible in [false, true]) {
      for (final failureId in [null, 'first', 'second']) {
        for (final operationLimit in [1, 2, 10]) {
          for (final cancelAtOperationStart in [null, 1, 3]) {
            final results = <({
              AttemptResult result,
              List<String> operations,
              List<(ExecutionEventKind, String?, String?, String?)> events,
              int observations,
              int closeCalls,
            })>[];

            for (final plan in plans) {
              final cancellation = ExecutionCancellation();
              final runtime = _FakeRuntime(
                supported: {'tap'},
                visible: visible,
                failInputId: failureId,
              );
              final events = <ExecutionEvent>[];
              final result = await ExecutionKernel(
                plan: plan,
                policy: CompiledExecutionPolicy(plan),
                runtime: runtime,
                cancellation: cancellation,
                limits: ExecutionLimits(maxOperations: operationLimit),
                eventSubscribers: [
                  (event) {
                    events.add(event);
                    if (event.kind == ExecutionEventKind.operationStarted &&
                        cancelAtOperationStart != null &&
                        events
                                .where((event) =>
                                    event.kind ==
                                    ExecutionEventKind.operationStarted)
                                .length ==
                            cancelAtOperationStart) {
                      cancellation.cancel();
                    }
                  }
                ],
              ).run();
              results.add((
                result: result,
                operations: runtime.executed,
                events: events
                    .map((event) => (
                          event.kind,
                          event.nodeId,
                          event.operation,
                          event.detail,
                        ))
                    .toList(),
                observations: runtime.observeCalls,
                closeCalls: runtime.closeCalls,
              ));
            }

            final caseDescription = 'visible=$visible, failureId=$failureId, '
                'operationLimit=$operationLimit, '
                'cancelAtOperationStart=$cancelAtOperationStart';
            expect(results[1].result.outcome, results[0].result.outcome,
                reason: caseDescription);
            expect(results[1].result.primaryFailure,
                results[0].result.primaryFailure,
                reason: caseDescription);
            expect(results[1].result.failureCode, results[0].result.failureCode,
                reason: caseDescription);
            expect(results[1].result.failureOperation,
                results[0].result.failureOperation,
                reason: caseDescription);
            expect(results[1].result.operations, results[0].result.operations,
                reason: caseDescription);
            expect(results[1].operations, results[0].operations,
                reason: caseDescription);
            expect(results[1].events, results[0].events,
                reason: caseDescription);
            expect(results[1].observations, results[0].observations,
                reason: caseDescription);
            expect(results.map((entry) => entry.closeCalls), [1, 1],
                reason: caseDescription);
          }
        }
      }
    }
  });

  test('unhandled conditional observation failure stops plan traversal',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: unhandled_observation_failure
startScreen: Home
steps:
  - ifVisible:
      id: banner
      step:
        tap: {id: dismiss}
  - tap: {id: after_branch}
''');
    final plan = CompiledPlanCompiler().compile(testCase);
    final plans = [plan, ExecutionPlan.fromWire(plan.toWire())];
    final results = <AttemptResult>[];
    final traces = <List<String>>[];
    final runtimes = <_FakeRuntime>[];
    for (final executionPlan in plans) {
      final runtime = _FakeRuntime(
        supported: {'tap'},
        observeError: StateError('observation unavailable'),
      );
      final events = <ExecutionEvent>[];
      final result = await ExecutionKernel(
        plan: executionPlan,
        policy: CompiledExecutionPolicy(executionPlan),
        runtime: runtime,
        eventSubscribers: [events.add],
      ).run();
      results.add(result);
      traces.add(events
          .map((event) =>
              '${event.kind.name}:${event.nodeId}:${event.operation}:${event.detail}')
          .toList());
      runtimes.add(runtime);
    }

    for (final result in results) {
      expect(result.outcome, AttemptOutcome.failed);
      expect(result.cause, isA<StateError>());
    }
    expect(results[1].failureCode, results[0].failureCode);
    expect(results[1].failureOperation, results[0].failureOperation);
    expect(traces[1], traces[0]);
    for (final runtime in runtimes) {
      expect(runtime.executed, isEmpty);
      expect(runtime.closeCalls, 1);
      expect(runtime.observationLevels, [ObservationLevel.minimal]);
      expect(runtime.observedTargets, [
        const {'id': 'banner'}
      ]);
    }
    expect(
      traces.first.where((event) => event.startsWith('observationFailed:')),
      hasLength(1),
    );
    expect(traces.first.last, startsWith('attemptFinished:'));
  });

  test('operation and close failures stay identical after wire decoding',
      () async {
    final plan = _singleOperationPlan();
    final plans = [plan, ExecutionPlan.fromWire(plan.toWire())];
    final results = <AttemptResult>[];
    final runtimes = <_FakeRuntime>[];
    final eventTraces = <List<String>>[];

    for (final executionPlan in plans) {
      final runtime = _FakeRuntime(
        supported: {'tap'},
        failName: 'tap',
        closeError: StateError('close failed'),
      );
      final events = <ExecutionEvent>[];
      final result = await ExecutionKernel(
        plan: executionPlan,
        policy: CompiledExecutionPolicy(executionPlan),
        runtime: runtime,
        eventSubscribers: [events.add],
      ).run();
      results.add(result);
      runtimes.add(runtime);
      eventTraces.add(events
          .map((event) =>
              '${event.kind.name}:${event.nodeId}:${event.operation}:${event.detail}')
          .toList());
    }

    for (final result in results) {
      expect(result.outcome, AttemptOutcome.failed);
      expect(result.primaryFailure, 'tap failed');
      expect(result.secondaryFailures.single, contains('close failed'));
    }
    expect(results[1].failureCode, results[0].failureCode);
    expect(results[1].failureOperation, results[0].failureOperation);
    expect(results[1].operations, results[0].operations);
    expect(results[1].secondaryFailures, results[0].secondaryFailures);
    expect(runtimes.map((runtime) => runtime.executed), [
      ['tap:button'],
      ['tap:button'],
    ]);
    expect(eventTraces[1], eventTraces[0]);
    expect(runtimes.map((runtime) => runtime.closeCalls), [1, 1]);
  });

  test('optional recovery and close failure match after wire decoding',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: optional_recovery_close_failure
startScreen: Home
steps:
  - optional:
      step:
        tap: {id: recoverable}
  - tap: {id: after}
''');
    final compiled = CompiledPlanCompiler().compile(testCase);
    final plans = [compiled, ExecutionPlan.fromWire(compiled.toWire())];
    final results = <AttemptResult>[];
    final runtimes = <_FakeRuntime>[];
    final eventTraces = <List<String>>[];

    for (final plan in plans) {
      final runtime = _FakeRuntime(
        supported: {'tap'},
        failInputId: 'recoverable',
        closeError: StateError('close failed'),
      );
      final events = <ExecutionEvent>[];
      final result = await ExecutionKernel(
        plan: plan,
        policy: CompiledExecutionPolicy(plan),
        runtime: runtime,
        eventSubscribers: [events.add],
      ).run();
      results.add(result);
      runtimes.add(runtime);
      eventTraces.add(events
          .map((event) =>
              '${event.kind.name}:${event.nodeId}:${event.operation}:${event.detail}')
          .toList());
    }

    for (final result in results) {
      expect(result.outcome, AttemptOutcome.failed);
      expect(result.failureCode, 'closeFailed');
      expect(result.primaryFailure, contains('close failed'));
      expect(result.secondaryFailures, isEmpty);
    }
    expect(results[1].operations, results[0].operations);
    expect(results[1].secondaryFailures, results[0].secondaryFailures);
    expect(eventTraces[1], eventTraces[0]);
    expect(runtimes.map((runtime) => runtime.executed), [
      ['tap:recoverable', 'tap:after'],
      ['tap:recoverable', 'tap:after'],
    ]);
    expect(runtimes.map((runtime) => runtime.closeCalls), [1, 1]);
  });

  test('runtime closes when evidence-boundary binding fails', () async {
    final plan = _singleOperationPlan();
    final runtime = _BoundaryFailureRuntime(failOnAttach: true);

    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: runtime,
    ).run();

    expect(result.outcome, AttemptOutcome.failed);
    expect(result.primaryFailure, contains('Evidence boundary attach failed'));
    expect(runtime.closeCalls, 1);
  });

  test('runtime closes and reports a failed evidence-boundary detach',
      () async {
    final plan = _singleOperationPlan();
    final runtime = _BoundaryFailureRuntime(failOnDetach: true);

    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: runtime,
    ).run();

    expect(result.outcome, AttemptOutcome.failed);
    expect(result.failureCode, 'cleanupFailed');
    expect(result.primaryFailure, contains('Evidence boundary detach failed'));
    expect(runtime.executed, ['tap:button']);
    expect(runtime.closeCalls, 1);
  });

  test('operation events and failures expose the canonical operation name',
      () async {
    final plan = _singleOperationPlan();
    final events = <ExecutionEvent>[];
    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: _FakeRuntime(supported: {'tap'}, failName: 'tap'),
      eventSubscribers: [events.add],
    ).run();

    expect(result.outcome, AttemptOutcome.failed);
    expect(result.failureOperation, 'tap');
    expect(
      result.failureSource,
      const SourceLocation('test.yaml', 'steps[0]'),
    );
    expect(
      events
          .where((event) =>
              event.kind == ExecutionEventKind.operationStarted ||
              event.kind == ExecutionEventKind.operationFinished)
          .map((event) => event.source),
      [
        const SourceLocation('test.yaml', 'steps[0]'),
        const SourceLocation('test.yaml', 'steps[0]'),
      ],
    );
    expect(
      events
          .where((event) =>
              event.kind == ExecutionEventKind.operationStarted ||
              event.kind == ExecutionEventKind.operationFinished)
          .map((event) => event.operation),
      ['tap', 'tap'],
    );
  });

  test('invalid policy edge fails before execution and closes runtime',
      () async {
    final plan = _singleOperationPlan();
    final runtime = _FakeRuntime(supported: {'tap'});
    final result = await ExecutionKernel(
      plan: plan,
      policy: const _WrongPolicy(),
      runtime: runtime,
    ).run();
    expect(result.outcome, AttemptOutcome.failed);
    expect(result.primaryFailure, contains('invalid operation'));
    expect(runtime.executed, isEmpty);
    expect(runtime.closeCalls, 1);
  });

  test('operation limit and cancellation close runtime', () async {
    final plan = _singleOperationPlan();
    final limited = _FakeRuntime(supported: {'tap'});
    final limitedResult = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: limited,
      limits: const ExecutionLimits(maxOperations: 1),
    ).run();
    expect(limitedResult.outcome, AttemptOutcome.passed);

    final cancellation = ExecutionCancellation()..cancel();
    final cancelled = _FakeRuntime(supported: {'tap'});
    final cancelledResult = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: cancelled,
      cancellation: cancellation,
    ).run();
    expect(cancelledResult.outcome, AttemptOutcome.cancelled);
    expect(cancelled.executed, isEmpty);
    expect(cancelled.closeCalls, 1);
  });

  test('cancellation from operation-start subscriber prevents side effects',
      () async {
    final plan = _singleOperationPlan();
    final cancellation = ExecutionCancellation();
    final runtime = _FakeRuntime(supported: {'tap'});
    final events = <ExecutionEventKind>[];

    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: runtime,
      cancellation: cancellation,
      eventSubscribers: [
        (event) {
          events.add(event.kind);
          if (event.kind == ExecutionEventKind.operationStarted) {
            cancellation.cancel();
          }
        }
      ],
    ).run();

    expect(result.outcome, AttemptOutcome.cancelled);
    expect(result.failureCode, 'cancelled');
    expect(runtime.executed, isEmpty);
    expect(runtime.closeCalls, 1);
    expect(
      events.where((kind) =>
          kind == ExecutionEventKind.operationStarted ||
          kind == ExecutionEventKind.operationFinished),
      [
        ExecutionEventKind.operationStarted,
        ExecutionEventKind.operationFinished,
      ],
    );
  });

  test('cancellation from directive subscriber prevents dispatch', () async {
    final plan = _singleOperationPlan();
    final cancellation = ExecutionCancellation();
    final runtime = _FakeRuntime(supported: {'tap'});
    final events = <ExecutionEventKind>[];

    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: runtime,
      cancellation: cancellation,
      eventSubscribers: [
        (event) {
          events.add(event.kind);
          if (event.kind == ExecutionEventKind.directiveSelected) {
            cancellation.cancel();
          }
        }
      ],
    ).run();

    expect(result.outcome, AttemptOutcome.cancelled);
    expect(runtime.executed, isEmpty);
    expect(events, isNot(contains(ExecutionEventKind.operationStarted)));
    expect(runtime.closeCalls, 1);
  });

  test('cancellation stops a bounded repeat and closes direct and wire plans',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: cancel_bounded_repeat
startScreen: Home
steps:
  - repeat:
      times: 4
      steps:
        - group:
            steps:
              - tap: {id: repeated}
  - tap: {id: after_repeat}
''');
    final compiled = CompiledPlanCompiler().compile(testCase);
    final plans = [compiled, ExecutionPlan.fromWire(compiled.toWire())];
    final outcomes = <AttemptResult>[];
    final executed = <List<String>>[];
    final eventTraces = <List<String>>[];
    final closeCalls = <int>[];

    for (final plan in plans) {
      final cancellation = ExecutionCancellation();
      final runtime = _FakeRuntime(supported: {'tap'});
      final events = <ExecutionEvent>[];
      var operationStarts = 0;
      final result = await ExecutionKernel(
        plan: plan,
        policy: CompiledExecutionPolicy(plan),
        runtime: runtime,
        cancellation: cancellation,
        eventSubscribers: [
          (event) {
            events.add(event);
            if (event.kind == ExecutionEventKind.operationStarted &&
                ++operationStarts == 2) {
              cancellation.cancel();
            }
          }
        ],
      ).run();
      outcomes.add(result);
      executed.add(runtime.executed);
      eventTraces.add(events
          .map((event) =>
              '${event.kind.name}:${event.nodeId}:${event.operation}:${event.detail}')
          .toList());
      closeCalls.add(runtime.closeCalls);
    }

    for (final result in outcomes) {
      expect(result.outcome, AttemptOutcome.cancelled);
      expect(result.failureCode, 'cancelled');
      expect(result.primaryFailure, 'Execution cancelled.');
      // The kernel counts the started, cancelled attempt, but does not dispatch
      // its runtime side effect.
      expect(result.operations, 2);
    }
    expect(executed, [
      ['tap:repeated'],
      ['tap:repeated'],
    ]);
    expect(eventTraces[1], eventTraces[0]);
    expect(closeCalls, [1, 1]);
  });

  test('loop entry limit matches for direct and wire repeat plans', () async {
    final testCase = EnsembleTestParser.parseString('''
id: repeat_loop_entry_limit
startScreen: Home
steps:
  - repeat:
      times: 3
      steps:
        - group:
            steps:
              - tap: {id: repeated}
  - tap: {id: after_repeat}
''');
    final compiled = CompiledPlanCompiler().compile(testCase);
    final plans = [compiled, ExecutionPlan.fromWire(compiled.toWire())];
    final results = <({
      AttemptResult result,
      List<String> operations,
      List<String> events,
      int closeCalls,
    })>[];

    for (final plan in plans) {
      final runtime = _FakeRuntime(supported: {'tap'});
      final events = <ExecutionEvent>[];
      final result = await ExecutionKernel(
        plan: plan,
        policy: CompiledExecutionPolicy(plan),
        runtime: runtime,
        limits: const ExecutionLimits(maxLoopEntries: 1),
        eventSubscribers: [events.add],
      ).run();
      results.add((
        result: result,
        operations: runtime.executed,
        events: events
            .map((event) =>
                '${event.kind.name}:${event.nodeId}:${event.operation}:${event.detail}')
            .toList(),
        closeCalls: runtime.closeCalls,
      ));
    }

    for (final entry in results) {
      expect(entry.result.outcome, AttemptOutcome.limitExceeded);
      expect(entry.result.failureCode, 'loopLimitExceeded');
      expect(entry.result.failureOperation, isNull);
      expect(entry.operations, ['tap:repeated']);
      expect(entry.closeCalls, 1);
    }
    expect(results[1].result.primaryFailure, results[0].result.primaryFailure);
    expect(results[1].result.operations, results[0].result.operations);
    expect(results[1].operations, results[0].operations);
    expect(results[1].events, results[0].events);
  });

  test('cancellation requested during an operation closes runtime once',
      () async {
    final cancellation = ExecutionCancellation();
    final runtime = _FakeRuntime(
      supported: {'tap'},
      executeDelay: const Duration(milliseconds: 5),
    );
    Timer(const Duration(milliseconds: 1), cancellation.cancel);

    final result = await ExecutionKernel(
      plan: _singleOperationPlan(),
      policy: CompiledExecutionPolicy(_singleOperationPlan()),
      runtime: runtime,
      cancellation: cancellation,
    ).run();

    expect(result.outcome, AttemptOutcome.cancelled);
    expect(runtime.closeCalls, 1);
  });

  test('wall-time limit wins over a late operation failure', () async {
    final runtime = _FakeRuntime(
      supported: {'tap'},
      executeDelay: const Duration(milliseconds: 40),
      failName: 'tap',
    );

    final result = await ExecutionKernel(
      plan: _singleOperationPlan(),
      policy: CompiledExecutionPolicy(_singleOperationPlan()),
      runtime: runtime,
      limits: const ExecutionLimits(
        wallTime: Duration(milliseconds: 10),
      ),
    ).run();

    expect(result.outcome, AttemptOutcome.limitExceeded);
    expect(result.failureCode, 'limitExceeded');
    expect(result.primaryFailure, 'Execution limit exceeded.');
    expect(runtime.closeCalls, 1);
  });

  test('cancellation wins over a late operation failure', () async {
    final cancellation = ExecutionCancellation();
    final runtime = _FakeRuntime(
      supported: {'tap'},
      executeDelay: const Duration(milliseconds: 40),
      failName: 'tap',
    );
    Timer(const Duration(milliseconds: 10), cancellation.cancel);

    final result = await ExecutionKernel(
      plan: _singleOperationPlan(),
      policy: CompiledExecutionPolicy(_singleOperationPlan()),
      runtime: runtime,
      cancellation: cancellation,
    ).run();

    expect(result.outcome, AttemptOutcome.cancelled);
    expect(result.failureCode, 'cancelled');
    expect(result.primaryFailure, 'Execution cancelled.');
    expect(runtime.closeCalls, 1);
  });

  test(
      'late recoverable failures retain termination identity after wire decode',
      () async {
    final directPlan = _lateFailureRecoveryPlan();
    final wirePlan = ExecutionPlanWireTransport.decode(
      ExecutionPlanWireTransport.encode(directPlan),
    );
    final plans = [directPlan, wirePlan];
    final scenarios = <({String name, bool cancel, Duration wallTime})>[
      (
        name: 'deadline',
        cancel: false,
        wallTime: const Duration(milliseconds: 15),
      ),
      (
        name: 'cancellation',
        cancel: true,
        wallTime: const Duration(seconds: 1),
      ),
    ];

    for (final scenario in scenarios) {
      final results = <AttemptResult>[];
      final executed = <List<String>>[];
      final closeCalls = <int>[];
      final eventTraces = <List<String>>[];
      for (final plan in plans) {
        final cancellation = ExecutionCancellation();
        if (scenario.cancel) {
          Timer(const Duration(milliseconds: 5), cancellation.cancel);
        }
        final runtime = _FakeRuntime(
          supported: {'tap'},
          failName: 'tap',
          executeDelay: const Duration(milliseconds: 50),
        );
        final events = <ExecutionEvent>[];
        final result = await ExecutionKernel(
          plan: plan,
          policy: CompiledExecutionPolicy(plan),
          runtime: runtime,
          cancellation: cancellation,
          limits: ExecutionLimits(wallTime: scenario.wallTime),
          eventSubscribers: [events.add],
        ).run();
        results.add(result);
        executed.add(runtime.executed);
        closeCalls.add(runtime.closeCalls);
        eventTraces.add(events
            .map(
                (event) => '${event.kind.name}:${event.nodeId}:${event.detail}')
            .toList());
      }

      final expectedOutcome = scenario.cancel
          ? AttemptOutcome.cancelled
          : AttemptOutcome.limitExceeded;
      for (final result in results) {
        expect(result.outcome, expectedOutcome, reason: scenario.name);
        expect(
            result.failureCode, scenario.cancel ? 'cancelled' : 'limitExceeded',
            reason: scenario.name);
        expect(
            result.primaryFailure,
            scenario.cancel
                ? 'Execution cancelled.'
                : 'Execution limit exceeded.',
            reason: scenario.name);
        expect(result.failureSource?.path, 'test.yaml', reason: scenario.name);
        expect(result.failureSource?.stepPath, 'steps[0]',
            reason: scenario.name);
        expect(result.failureOperation, 'tap', reason: scenario.name);
      }
      expect(
          executed,
          [
            ['tap:primary'],
            ['tap:primary'],
          ],
          reason: '${scenario.name}: recoverable failure must not resume');
      expect(closeCalls, [1, 1], reason: scenario.name);
      expect(eventTraces[1], eventTraces[0], reason: scenario.name);
    }
  });

  test('cancellation wins over a late policy failure', () async {
    final cancellation = ExecutionCancellation();
    final runtime = _FakeRuntime(supported: {'tap'});
    final result = await ExecutionKernel(
      plan: _singleOperationPlan(),
      policy: _CancellingThrowingPolicy(cancellation),
      runtime: runtime,
      cancellation: cancellation,
    ).run();

    expect(result.outcome, AttemptOutcome.cancelled);
    expect(result.failureCode, 'cancelled');
    expect(result.primaryFailure, 'Execution cancelled.');
    expect(runtime.executed, isEmpty);
    expect(runtime.closeCalls, 1);
  });

  test('limits terminate loops and wall-time exhaustion', () async {
    final loopPlan = ExecutionPlan(id: 'long_loop', start: 'loop', nodes: {
      'loop': const LoopNode('loop', times: 100, body: 'loop', next: 'end'),
      'end': const EndNode('end'),
    });
    final loopRuntime = _FakeRuntime(supported: {});
    final loopResult = await ExecutionKernel(
      plan: loopPlan,
      policy: CompiledExecutionPolicy(loopPlan),
      runtime: loopRuntime,
      limits: const ExecutionLimits(maxDirectives: 3),
    ).run();
    expect(loopResult.outcome, AttemptOutcome.limitExceeded);
    expect(loopResult.failureCode, 'limitExceeded');
    expect(loopRuntime.closeCalls, 1);

    final boundedLoopRuntime = _FakeRuntime(supported: {});
    final boundedLoopResult = await ExecutionKernel(
      plan: loopPlan,
      policy: CompiledExecutionPolicy(loopPlan),
      runtime: boundedLoopRuntime,
      limits: const ExecutionLimits(
        maxDirectives: 100,
        maxLoopEntries: 2,
      ),
    ).run();
    expect(boundedLoopResult.outcome, AttemptOutcome.limitExceeded);
    expect(boundedLoopResult.failureCode, 'loopLimitExceeded');
    expect(boundedLoopResult.primaryFailure, 'Loop limit exceeded.');
    expect(boundedLoopRuntime.closeCalls, 1);

    final wallRuntime = _FakeRuntime(supported: {'tap'});
    final plan = _singleOperationPlan();
    final wallResult = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: wallRuntime,
      limits: const ExecutionLimits(wallTime: Duration.zero),
    ).run();
    expect(wallResult.outcome, AttemptOutcome.limitExceeded);
    expect(wallRuntime.executed, isEmpty);
    expect(wallRuntime.closeCalls, 1);
  });

  test('event subscriber failures stay secondary', () async {
    final plan = _singleOperationPlan();
    final runtime = _FakeRuntime(supported: {'tap'});
    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: runtime,
      eventSubscribers: [(_) => throw StateError('observer unavailable')],
    ).run();
    expect(result.outcome, AttemptOutcome.passed);
    expect(result.secondaryFailures, hasLength(result.events));
    expect(runtime.closeCalls, 1);
  });

  test('disabled observer path counts events without allocating deliveries',
      () async {
    final plan = _singleOperationPlan();
    final runtime = _EvidenceBoundaryRuntime();
    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: runtime,
    ).run();

    expect(result.outcome, AttemptOutcome.passed);
    expect(result.events, greaterThan(0));
    expect(result.secondaryFailures, isEmpty);
    expect(runtime.mutationStarted, isTrue);
  });

  test('event subscribers run in order and failures do not silence peers',
      () async {
    final plan = _singleOperationPlan();
    final runtime = _FakeRuntime(supported: {'tap'});
    final delivery = <String>[];
    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: runtime,
      eventSubscribers: [
        (event) => delivery.add('first:${event.sequence}'),
        (event) {
          delivery.add('broken:${event.sequence}');
          throw StateError('subscriber unavailable');
        },
        (event) => delivery.add('later:${event.sequence}'),
      ],
    ).run();

    expect(result.outcome, AttemptOutcome.passed);
    expect(result.secondaryFailures, hasLength(result.events));
    expect(delivery, hasLength(result.events * 3));
    for (var sequence = 1; sequence <= result.events; sequence++) {
      final offset = (sequence - 1) * 3;
      expect(delivery.sublist(offset, offset + 3), [
        'first:$sequence',
        'broken:$sequence',
        'later:$sequence',
      ]);
    }
  });

  test('pre-mutation evidence failures stay secondary to action execution',
      () async {
    final plan = _singleOperationPlan();
    final runtime = _EvidenceBoundaryRuntime();
    final delivered = <ExecutionEventKind>[];
    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: runtime,
      eventSubscribers: [
        (event) {
          if (event.kind == ExecutionEventKind.evidenceBoundary) {
            expect(runtime.mutationStarted, isFalse);
            throw StateError('screenshot failed');
          }
        },
        (event) {
          delivered.add(event.kind);
        },
      ],
    ).run();

    expect(runtime.mutationStarted, isTrue);
    expect(result.outcome, AttemptOutcome.passed);
    expect(delivered, contains(ExecutionEventKind.evidenceBoundary));
    expect(
      result.secondaryFailures.any((failure) => failure
          .contains('Event subscriber 0 failed: Bad state: screenshot failed')),
      isTrue,
    );
  });

  test('step timing is available to following subscribers', () async {
    final testCase = EnsembleTestParser.parseString('''
id: timed
startScreen: Home
steps:
  - tap: {id: target}
''');
    final plan = CompiledPlanCompiler().compile(testCase);
    final timing = StepTimingSubscriber();
    final callbackStarts = <String?>[];
    final callbackDurations = <int?>[];
    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: _FakeRuntime(supported: {'tap'}),
      eventSubscribers: [
        timing.call,
        (event) {
          if (event.kind == ExecutionEventKind.stepStarted) {
            callbackStarts.add(timing.startTimeFor(event.stepIndex!));
          } else if (event.kind == ExecutionEventKind.stepFinished) {
            callbackDurations.add(timing.durationFor(event.stepIndex!));
          }
        }
      ],
    ).run();

    expect(result.outcome, AttemptOutcome.passed);
    expect(callbackStarts, hasLength(1));
    expect(callbackStarts.single, isNotNull);
    expect(callbackDurations, hasLength(1));
    expect(callbackDurations.single, isA<int>());
  });

  test('subscriber failures cannot replace the primary operation failure',
      () async {
    final plan = _singleOperationPlan();
    final runtime = _FakeRuntime(supported: {'tap'}, failName: 'tap');
    final delivered = <ExecutionEventKind>[];
    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: runtime,
      eventSubscribers: [
        (_) => throw StateError('subscriber failed'),
        (event) => delivered.add(event.kind),
      ],
    ).run();

    expect(result.outcome, AttemptOutcome.failed);
    expect(result.primaryFailure, 'tap failed');
    expect(result.failureCode, 'operationFailed');
    expect(result.secondaryFailures, hasLength(result.events));
    expect(delivered, hasLength(result.events));
    expect(delivered.last, ExecutionEventKind.attemptFinished);
  });

  test('compiled inputs cannot be mutated through nested values', () {
    final source = <String, Object?>{
      'target': <String, Object?>{
        'within': <String, Object?>{'id': 'form'}
      },
    };
    final operation = TestOperation(
      id: 'tap',
      name: 'tap',
      kind: OperationKind.interaction,
      handlerKey: 'interaction.tap',
      input: source,
      source: const SourceLocation('test.yaml', 'steps[0]'),
    );
    (source['target'] as Map<String, Object?>)['within'] = {'id': 'other'};
    final target = operation.input['target'] as Map<String, Object?>;
    expect((target['within'] as Map)['id'], 'form');
    expect(() => target['id'] = 'other', throwsUnsupportedError);
  });

  test('compiler and plan reject unknown operations and dangling edges', () {
    final compiler = PlanCompiler(OperationRegistry(const []));
    expect(
      () => compiler.compile('unknown', [
        PlanStep(
          name: 'notRegistered',
          source: const SourceLocation('case.yaml', 'steps[0]'),
        ),
      ]),
      throwsFormatException,
    );
    expect(
      () => ExecutionPlan(id: 'dangling', start: 'tap', nodes: {
        'tap': OperationNode(
          'tap',
          TestOperation(
            id: 'tap',
            name: 'tap',
            kind: OperationKind.interaction,
            handlerKey: 'interaction.tap',
            input: const {},
            source: const SourceLocation('case.yaml', 'steps[0]'),
          ),
          'missing',
        ),
        'end': const EndNode('end'),
      }),
      throwsFormatException,
    );
  });

  test('plan rejects nodes that cannot execute from its entry point', () {
    expect(
      () => ExecutionPlan(id: 'unreachable', start: 'start', nodes: {
        'start': const EndNode('start'),
        'orphan': const EndNode('orphan'),
      }),
      throwsFormatException,
    );
  });

  test('plan rejects operation identity drift and negative step indexes', () {
    expect(
      () => ExecutionPlan(id: 'operation-id-drift', start: 'operation', nodes: {
        'operation': OperationNode(
          'operation',
          TestOperation(
            id: 'different-operation',
            name: 'tap',
            kind: OperationKind.interaction,
            handlerKey: 'interaction.tap',
            input: const {},
            source: const SourceLocation('case.yaml', 'steps[0]'),
          ),
          'end',
        ),
        'end': const EndNode('end'),
      }),
      throwsFormatException,
    );

    expect(
      () => ExecutionPlan(id: 'negative-step-index', start: 'boundary', nodes: {
        'boundary': const StepBoundaryNode(
          'boundary',
          stepIndex: -1,
          started: true,
          next: 'end',
        ),
        'end': const EndNode('end'),
      }),
      throwsFormatException,
    );
  });
}

ExecutionPlan _singleOperationPlan() => ExecutionPlan(
      id: 'single',
      start: 'tap',
      nodes: {
        'tap': OperationNode(
          'tap',
          TestOperation(
            id: 'tap',
            name: 'tap',
            kind: OperationKind.interaction,
            handlerKey: 'interaction.tap',
            input: {'id': 'button'},
            source: const SourceLocation('test.yaml', 'steps[0]'),
          ),
          'end',
        ),
        'end': const EndNode('end'),
      },
    );

ExecutionPlan _lateFailureRecoveryPlan() => ExecutionPlan(
      id: 'late_failure_recovery',
      start: 'primary',
      nodes: {
        'primary': OperationNode(
          'primary',
          TestOperation(
            id: 'primary',
            name: 'tap',
            kind: OperationKind.interaction,
            handlerKey: 'interaction.tap',
            input: const {'id': 'primary'},
            source: const SourceLocation('test.yaml', 'steps[0]'),
          ),
          'end',
          onFailure: 'recovery',
        ),
        'recovery':
            RecoveryNode('recovery', next: 'tail', resetLoops: const []),
        'tail': OperationNode(
          'tail',
          TestOperation(
            id: 'tail',
            name: 'tap',
            kind: OperationKind.interaction,
            handlerKey: 'interaction.tap',
            input: const {'id': 'tail'},
            source: const SourceLocation('test.yaml', 'steps[1]'),
          ),
          'end',
        ),
        'end': const EndNode('end'),
      },
    );

final class _EvidenceBoundaryRuntime
    implements TestRuntime, EvidenceBoundaryEventSource {
  EvidenceBoundaryEmitter? _emitter;
  bool mutationStarted = false;

  @override
  final capabilities = RuntimeCapabilities({'interaction.tap'});

  @override
  void bindEvidenceBoundaryEmitter(EvidenceBoundaryEmitter? emitter) {
    _emitter = emitter;
  }

  @override
  Future<RuntimeView> observe(ObservationRequest request) async => RuntimeView(
        revision: 0,
        level: request.level,
        target: request.target,
        targetVisible: true,
      );

  @override
  Future<OperationResult> execute(TestOperation operation) async {
    await _emitter?.call(0, operation.name);
    mutationStarted = true;
    return const OperationResult.success();
  }

  @override
  Future<void> close() async {}
}

final class _BoundaryFailureRuntime
    implements TestRuntime, EvidenceBoundaryEventSource {
  _BoundaryFailureRuntime({
    this.failOnAttach = false,
    this.failOnDetach = false,
  });

  final bool failOnAttach;
  final bool failOnDetach;
  final _FakeRuntime delegate = _FakeRuntime(supported: {'tap'});

  int get closeCalls => delegate.closeCalls;
  List<String> get executed => delegate.executed;

  @override
  RuntimeCapabilities get capabilities => delegate.capabilities;

  @override
  void bindEvidenceBoundaryEmitter(EvidenceBoundaryEmitter? emitter) {
    if (emitter != null && failOnAttach) {
      throw StateError('Evidence boundary attach failed');
    }
    if (emitter == null && failOnDetach) {
      throw StateError('Evidence boundary detach failed');
    }
  }

  @override
  Future<RuntimeView> observe(ObservationRequest request) =>
      delegate.observe(request);

  @override
  Future<OperationResult> execute(TestOperation operation) =>
      delegate.execute(operation);

  @override
  Future<void> close() => delegate.close();
}

final class _FakeRuntime implements TestRuntime {
  _FakeRuntime({
    required Set<String> supported,
    this.visible = false,
    this.failName,
    this.failInputId,
    this.throwOnFailure = false,
    this.observeError,
    this.closeError,
    this.executeDelay = Duration.zero,
  }) : capabilities = RuntimeCapabilities({
          for (final name in supported) name,
          for (final name in supported)
            operationRegistry.lookup(name)?.handlerKey ?? name,
        });

  @override
  final RuntimeCapabilities capabilities;
  final bool visible;
  final String? failName;
  final String? failInputId;
  final bool throwOnFailure;
  final Object? observeError;
  final Object? closeError;
  final Duration executeDelay;
  final List<String> executed = [];
  int observeCalls = 0;
  final List<ObservationLevel> observationLevels = [];
  final List<Map<String, Object?>> observedTargets = [];
  int closeCalls = 0;

  @override
  Future<RuntimeView> observe(ObservationRequest request) async {
    observeCalls++;
    observationLevels.add(request.level);
    observedTargets.add(request.target);
    if (observeError != null) throw observeError!;
    return RuntimeView(
      revision: observeCalls,
      level: request.level,
      target: request.target,
      targetVisible: visible,
    );
  }

  @override
  Future<OperationResult> execute(TestOperation operation) async {
    if (executeDelay > Duration.zero) await Future<void>.delayed(executeDelay);
    final id = operation.input['id'];
    executed.add('${operation.name}:$id');
    if ((failName == null || operation.name == failName) &&
        (failName != null || failInputId != null) &&
        (failInputId == null || id == failInputId)) {
      if (throwOnFailure) throw StateError('tap threw');
      return const OperationResult.failure('tap failed');
    }
    return const OperationResult.success();
  }

  @override
  Future<void> close() async {
    closeCalls++;
    if (closeError != null) throw closeError!;
  }
}

final class _WrongPolicy implements ExecutionPolicy {
  const _WrongPolicy();

  @override
  Future<ExecutionDirective> next(RunState state, RuntimeView? view) async =>
      const ExecuteDirective('missing');
}

final class _CancellingThrowingPolicy implements ExecutionPolicy {
  const _CancellingThrowingPolicy(this.cancellation);

  final ExecutionCancellation cancellation;

  @override
  Future<ExecutionDirective> next(RunState state, RuntimeView? view) async {
    cancellation.cancel();
    throw StateError('late policy failure');
  }
}
