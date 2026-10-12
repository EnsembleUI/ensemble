// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/navigation_waiter.dart';
import 'package:ensemble/widget/lottie/lottie.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/runner/debug_artifact_logs.dart';
import 'package:ensemble_test_runner/runner/failure_observer_capture.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:ensemble_test_runner/session/observation/suggested_locator.dart';
import 'package:ensemble_test_runner/session/actions/action_result.dart';
import 'package:ensemble_test_runner/session/actions/artifact_request.dart';
import 'package:ensemble_test_runner/session/operation_result.dart';
import 'package:ensemble_test_runner/session/operation_target.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/cli/ensemble_test_cli.dart';
import 'package:ensemble_test_runner/cli/ensemble_test_doctor.dart';
import 'package:ensemble_test_runner/cli/ensemble_test_scaffold.dart';
import 'package:ensemble_test_runner/cli/app_patcher.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/execution/artifact_transport.dart';
import 'package:ensemble_test_runner/inspect/ensemble_app_inspector.dart';
import 'package:ensemble_test_runner/mocks/mock_composition.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:ensemble_test_runner/reporters/atomic_file.dart';
import 'package:ensemble_test_runner/reporters/ensemble_test_history_store.dart';
import 'package:ensemble_test_runner/reporters/html_test_reporter.dart';
import 'package:ensemble_test_runner/reporters/report_json_optimizer.dart';
import 'package:ensemble_test_runner/reporters/screenshot_archive.dart';
import 'package:ensemble_test_runner/reporters/test_reporter.dart';
import 'package:ensemble_test_runner/reporters/test_report_document.dart';
import 'package:ensemble_test_runner/runner/app_performance_log.dart';
import 'package:ensemble_test_runner/runner/app_session_snapshot.dart';
import 'package:ensemble_test_runner/runner/diagnostic_ui_snapshot.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_runner.dart';
import 'package:ensemble_test_runner/runner/event_driven_settler.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/runner/screenshot_sheet_aggregator.dart';
import 'package:ensemble_test_runner/runner/host_screenshot_optimizer.dart';
import 'package:ensemble_test_runner/runner/screenshot_capture.dart';
import 'package:ensemble_test_runner/runner/screenshot_contact_sheet.dart';
import 'package:ensemble_test_runner/runner/screenshot_lottie_ready.dart';
import 'package:ensemble_test_runner/runner/step_report_capture.dart';
import 'package:ensemble_test_runner/runner/storage_step_diff.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:ensemble_test_runner/runner/test_visual_artifacts.dart';
import 'package:ensemble_test_runner/runner/test_service_manager.dart';
import 'package:ensemble_test_runner/schema/ensemble_test_schema_builder.dart';
import 'package:ensemble_test_runner/session/local/leaf_command_queue.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/src/core/runtime.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/execution_kernel_runner.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';
import 'package:ensemble_test_runner/src/core/policy.dart';
import 'package:ensemble_test_runner/src/runtime/step_evidence_subscriber.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart';
import 'package:ensemble_test_runner/src/runtime/flutter_test_runtime.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:ensemble_test_runner/src/worker_capacity.dart';
import 'package:ensemble_test_runner/validation/ensemble_test_validator.dart';
import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';
import 'coverage.dart';
import 'operation_cases.dart';
import 'worker_project.dart';

/// Advances benchmark fixtures until Flutter has had two quiet turns.
///
/// Benchmark setup must not use an unbounded settle helper: repeating
/// animations in a fixture would make the benchmark itself hang. The runner's
/// production observer uses the same bounded event-driven rule.
Future<void> settleBenchmarkFixture(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 5),
}) =>
    EventDrivenSettler(tester: tester).settle(timeout: timeout);

ScreenshotSheetAggregator? _noScreenshotSheets() => null;

void _drainNothing(WidgetTester tester) {}

class BenchmarkCase {
  BenchmarkCase(
    this.id,
    this.service,
    this.body, {
    this.externalMeasurements,
    this.prepare,
    this.verify,
    this.cleanup,
    this.quick = false,
    this.dimensions = const {},
    this.kind = 'component',
    this.skipReason,
    this.cold = false,
    this.batchable = true,
    this.fixtureVersion = 1,
  });
  final List<Map<String, dynamic>> Function()? externalMeasurements;
  final String id, service, kind;
  final Future<Object?> Function() body;
  final Future<void> Function()? prepare, cleanup;
  final void Function(Object?)? verify;
  final bool quick, cold, batchable;
  final int fixtureVersion;
  final String? skipReason;
  final Map<String, Object> dimensions;
  Map<String, Object?> toJson() => {
        'id': id,
        'service': service,
        'kind': kind,
        'fixtureVersion': fixtureVersion,
        'dimensions': dimensions,
        'operations': [
          for (final entry in operationCases.entries)
            if (entry.value == id) entry.key
        ],
        'requiredCapabilities': [
          for (final entry in capabilityCases.entries)
            if (entry.value.contains(id) &&
                SessionCapabilities.local.toJson()[entry.key] != false)
              entry.key
        ],
        'quick': quick,
        'cold': cold,
        'batchable': batchable,
        if (skipReason != null) 'skipReason': skipReason
      };
}

void _clearScreenshotArchiveFixture(String artifactRoot) {
  final report = Directory('$artifactRoot/report');
  final images = Directory('${report.path}/screenshots');
  if (images.existsSync()) images.deleteSync(recursive: true);
  final archive = File('${report.path}/${ScreenshotArchive.fileName}');
  if (archive.existsSync()) archive.deleteSync();
}

void checkCoverage() {
  final missing =
      TestStepRegistry.entries.keys.toSet().difference(coveredSteps);
  final stale = coveredSteps.difference(TestStepRegistry.entries.keys.toSet());
  final caps = SessionCapabilities.local.toJson().keys.toSet();
  final declaredCanonicalSteps =
      coveredSteps.map(TestStepVocabulary.resolveStepType).toSet();
  if (SessionCapabilities.local.actions
      .difference(declaredCanonicalSteps)
      .isNotEmpty) {
    throw StateError('Benchmark action capability coverage drift');
  }
  for (final flag in coveredCapabilityFlags.entries) {
    if (SessionCapabilities.local.toJson()[flag.key] != flag.value) {
      throw StateError(
          'Benchmark capability support changed: ${flag.key}; update its cases');
    }
  }
  if (SessionCapabilities.local.waits.difference(coveredWaitKinds).isNotEmpty ||
      coveredWaitKinds.difference(SessionCapabilities.local.waits).isNotEmpty ||
      SessionCapabilities.local.assertionDomains
          .difference(coveredAssertionDomains)
          .isNotEmpty ||
      coveredAssertionDomains
          .difference(SessionCapabilities.local.assertionDomains)
          .isNotEmpty)
    throw StateError('Benchmark wait/assertion capability coverage drift');
  if (missing.isNotEmpty ||
      stale.isNotEmpty ||
      caps.difference(coveredCapabilities).isNotEmpty ||
      coveredCapabilities.difference(caps).isNotEmpty) {
    throw StateError(
        'Benchmark coverage drift: steps missing=$missing stale=$stale; capabilities=$caps');
  }
}

const coveredWaitKinds = {
  'pump',
  'settle',
  'uiElement',
  'text',
  'navigation',
  'api'
};
const coveredAssertionDomains = {
  'ui',
  'navigation',
  'api',
  'storage',
  'script',
  'quality'
};

const runtimeSteps = {
  'openScreen',
  'reloadScreen',
  'restartApp',
  'launchApp',
  'trigger',
  'setDevice',
  'expectBackStack'
};

class BenchmarkFixtures {
  BenchmarkFixtures(this.tester, this.root);
  final WidgetTester tester;
  final Directory root;
  late EnsembleTestContext context;
  late LocalTestExecutionSession session;
  late TextEditingController controller;
  ui.Image? image;
  final storage = FixtureStorage();
  final navigation = FixtureNavigation();
  final api = FixtureApi();
  EnsembleTestHarness? harness;
  bool sessionReady = false;
  HttpServer? server;

  Future<void> prepareRuntime(String mode, {bool screenshots = false}) async {
    EnsembleTestHarness.ensureTestPlugins();
    harness = EnsembleTestHarness(
        appPath:
            '${mode == 'integration' ? 'packages/ensemble_test_runner/' : ''}tool/benchmarks/fixtures/ensemble/apps/demo/',
        appHome: 'Home');
    context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(
            id: 'benchmark_runtime',
            startScreen: 'Home',
            steps: [
              TestStep(
                  type: 'expectVisible',
                  args: {'id': 'target', 'timeoutMs': 5000})
            ]),
        config: EnsembleTestConfig(
            screenshots: ScreenshotConfig(enabled: screenshots)));
    await harness!.loadScreen(
        tester: tester, testCase: context.testCase, context: context);
    session = LocalTestExecutionSession.attach(
        tester: tester, context: context, harness: harness);
    sessionReady = true;
    controller = TextEditingController();
  }

  Future<void> prepare(
      {int nodes = 40,
      int depth = 1,
      String step = '',
      bool uniqueLabels = false,
      bool screenshots = false}) async {
    sessionReady = false;
    harness = null;
    if (image != null) {
      image!.dispose();
      image = null;
    }
    controller = TextEditingController(text: 'value');
    context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(id: 'benchmark', steps: []),
        config: EnsembleTestConfig(
            screenshots: ScreenshotConfig(enabled: screenshots)));
    if (step == 'expectConsoleLog')
      context.runtime.consoleLogs
          .add(context.runtime.formatConsoleLine('Screen loaded'));
    if (step == 'expectError') context.runtime.flutterErrors.add('overflow');
    context.apiOverlay.calls.addAll([
      for (final name in ['auth', 'profile', 'login'])
        APICallRecord(
            name: name,
            apiDefinition: loadYaml('{}') as YamlMap,
            timestamp: DateTime.utc(2026))
    ]);
    storage.values
      ..clear()
      ..['key'] = true;
    context.navigationFlow.seed(['Login', 'Home']);
    Widget target;
    if ([
      'enterText',
      'clearText',
      'replaceText',
      'submitText',
      'focus',
      'expectValue',
      'chooseDate',
      'chooseTime'
    ].contains(step)) {
      target = TextField(key: const ValueKey('target'), controller: controller);
    } else if (['check', 'uncheck', 'toggle', 'expectChecked', 'expectSelected']
        .contains(step)) {
      target = Checkbox(
          key: const ValueKey('target'),
          value: step != 'check',
          onChanged: (_) {});
    } else if (step == 'selectIndex') {
      target = ElevatedButton(
          key: const ValueKey('target'),
          onPressed: () => showDialog<void>(
              context: tester.element(find.byKey(const ValueKey('target'))),
              builder: (context) => SimpleDialog(children: [
                    ListTile(
                        title: const Text('A'),
                        onTap: () => Navigator.pop(context))
                  ])),
          child: const Text('Select'));
    } else if (step == 'select') {
      target = DropdownButton<String>(
          key: const ValueKey('target'),
          value: 'A',
          items: const [
            DropdownMenuItem(value: 'A', child: Text('A')),
            DropdownMenuItem(value: 'B', child: Text('B'))
          ],
          onChanged: (_) {});
    } else if (step == 'setSlider') {
      target = KeyedSubtree(
          key: const ValueKey('target'),
          child: Slider(value: .2, onChanged: (_) {}));
    } else {
      target = Semantics(
          label: 'Submit',
          child: ElevatedButton(
              key: const ValueKey('target'),
              onPressed: step == 'expectDisabled' ? null : () {},
              child: const Text('Hello')));
    }
    Widget tree =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      target,
      const SizedBox(key: ValueKey('emptyList')),
      const Text('Welcome', key: ValueKey('title')),
      const Text('password', key: ValueKey('secret')),
      for (var i = 0; i < nodes; i++)
        SizedBox(
            height: 18,
            child: Text(
                !uniqueLabels && i.isEven ? 'Repeated label' : 'Item $i',
                key: ValueKey('node_$i'))),
      const Offstage(child: Text('Hidden', key: ValueKey('hidden'))),
    ]);
    for (var i = 0; i < depth; i++) {
      tree = Padding(padding: const EdgeInsets.all(1), child: tree);
    }
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                key: const ValueKey('list'), child: tree))));
    await settleBenchmarkFixture(tester);
    context.navigationFlow.seed(['Login', 'Home']);
    session = LocalTestExecutionSession.attach(
        tester: tester,
        context: context,
        services: ApplicationTestServices(
            storage: storage, navigation: navigation, api: api));
    sessionReady = true;
  }

  Future<void> cleanup() async {
    image?.dispose();
    image = null;
    if (server != null) {
      await tester.runAsync(() => server!.close(force: true));
      server = null;
    }
    if (sessionReady) await session.close();
    sessionReady = false;
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    context.runtime.clear();
  }

  ui.Image capture() => ExtendedStepHandlers.captureScreenshotImage(tester);
}

class FixtureNavigation implements NavigationTestService {
  @override
  String get currentRoute => 'Home';
  @override
  List<String> get routeHistory => ['Login', 'Home'];
}

class FixtureApi implements ApiMockingTestService {
  @override
  int callCount(String name) => name == 'absent' ? 0 : 1;
  @override
  void applyMocks(TestMocks mocks) {}
  @override
  void resetCalls() {}
}

class FixtureStorage implements StorageTestService {
  final values = <String, Object?>{};
  @override
  Future<void> apply(Map<String, dynamic> state) async {
    values.addAll(state);
  }

  @override
  Future<void> restore() async {
    values.clear();
  }

  @override
  Object? read(String key) => values[key];
  @override
  Future<void> write(String key, Object? value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> clear() async {
    values.clear();
  }
}

void require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

TestOperation _sessionOperation(String name, Map<String, Object?> input) {
  final descriptor = operationRegistry.lookup(name);
  if (descriptor == null) throw StateError('No operation descriptor for $name');
  return TestOperation(
    id: 'benchmark-session-$name',
    name: descriptor.name,
    kind: descriptor.kind,
    handlerKey: descriptor.handlerKey,
    input: input,
    source: SourceLocation('benchmark', 'session.$name'),
  );
}

Future<OperationResult> _executeRuntimeStep(
  BenchmarkFixtures fixture,
  TestStep step,
) =>
    FlutterTestRuntime(fixture.session).execute(_operationForStep(step));

TestOperation _operationForStep(TestStep step) {
  final name = TestStepVocabulary.resolveStepType(step.type);
  final descriptor = operationRegistry.lookup(name);
  if (descriptor == null) {
    throw StateError('No operation descriptor for ${step.type}');
  }
  return TestOperation(
    id: 'benchmark-step',
    name: name,
    kind: descriptor.kind,
    handlerKey: descriptor.handlerKey,
    input: Map<String, Object?>.from(step.args),
    source: const SourceLocation('benchmark.yaml', 'steps[0]'),
  );
}

List<BenchmarkCase> buildCases(BenchmarkFixtures f, {String mode = 'widget'}) {
  checkCoverage();
  final cases = <BenchmarkCase>[];
  BenchmarkCase uiCase(
          String id, String service, Future<Object?> Function() body,
          {int nodes = 40,
          int depth = 1,
          bool uniqueLabels = false,
          bool quick = false,
          Map<String, Object> dimensions = const {},
          void Function(Object?)? verify,
          String? skipReason,
          String kind = 'component'}) =>
      BenchmarkCase(id, service, body,
          prepare: () => f.prepare(
                nodes: nodes,
                depth: depth,
                uniqueLabels: uniqueLabels,
              ),
          cleanup: f.cleanup,
          quick: quick,
          dimensions: {
            'nodes': nodes,
            'depth': depth,
            if (uniqueLabels) 'uniqueLabels': true,
            ...dimensions,
          },
          verify: verify,
          skipReason: skipReason,
          kind: kind);

  cases.add(BenchmarkCase('control.noop', 'control', () async => 1,
      quick: true, verify: (r) => require(r == 1, 'noop')));
  cases.add(BenchmarkCase('control.instrumented', 'control',
      () async => RunnerBenchmark.sync('control', 'noop', () => 1),
      quick: true, verify: (r) => require(r == 1, 'instrumented noop')));
  cases.add(BenchmarkCase('kernel.subscriber.dispatch', 'kernel', () async {
    var captures = 0;
    final subscriber = StepEvidenceSubscriber(capture: (_) {
      captures++;
      return true;
    });
    for (var i = 0; i < 100000; i++) {
      subscriber.call(const ExecutionEvent(
        sequence: 0,
        kind: ExecutionEventKind.operationFinished,
      ));
    }
    for (var i = 0; i < 1000; i++) {
      subscriber.call(ExecutionEvent(
        sequence: i,
        kind: ExecutionEventKind.stepFinished,
        stepIndex: i,
      ));
    }
    return captures;
  }, quick: true, verify: (r) => require(r == 1000, 'subscriber dispatch')));
  final subscriberPlan = _kernelDispatchBenchmarkPlan();
  cases.add(BenchmarkCase(
    'kernel.no_subscribers',
    'kernel',
    () async => (await ExecutionKernel(
      plan: subscriberPlan,
      policy: CompiledExecutionPolicy(subscriberPlan),
      runtime: _KernelBenchmarkRuntime(),
    ).run())
        .events,
    quick: true,
    dimensions: const {'operations': 100, 'eventSubscribers': 0},
    verify: (r) => require(r == 303, 'unobserved kernel event count: $r'),
  ));
  cases.add(BenchmarkCase(
    'kernel.subscribers.enabled',
    'kernel',
    () async {
      var delivered = 0;
      final result = await ExecutionKernel(
        plan: subscriberPlan,
        policy: CompiledExecutionPolicy(subscriberPlan),
        runtime: _KernelBenchmarkRuntime(),
        eventSubscriptions: [
          EventSubscription(
            kinds: const {ExecutionEventKind.operationFinished},
            handle: (_) => delivered++,
          ),
        ],
      ).run();
      return '${result.events}:$delivered';
    },
    quick: true,
    dimensions: const {'operations': 100, 'eventSubscribers': 1},
    verify: (r) => require(r == '303:100', 'observed kernel event count'),
  ));
  for (final nodes in [40, 400, 1200]) {
    for (final keyed in [false, true]) {
      cases.add(uiCase(
          'observer.session.$nodes.${keyed ? 'keyed' : 'full'}',
          'observer',
          () async => f.session.observe(
              options: ObservationOptions(
                  synchronization: ObservationSynchronization.immediate,
                  keyedOnly: keyed)),
          nodes: nodes,
          quick: nodes == 40 && !keyed,
          dimensions: {'keyedOnly': keyed},
          verify: (r) => require((r as UiObservation).elements.isNotEmpty,
              'Empty session observation')));
    }
    cases.add(uiCase(
        'observer.diagnostic.$nodes',
        'observer',
        () async => captureDiagnosticUiSnapshot(
            tester: f.tester,
            assertions: f.session.assertions,
            navigation: f.navigation),
        nodes: nodes,
        quick: nodes == 40,
        verify: (r) => require(
            (r as DiagnosticUiSnapshot).observation.elements.isNotEmpty,
            'Empty diagnostic snapshot')));
  }
  cases.add(uiCase(
    'observer.diagnostic.unique.40',
    'observer',
    () async => captureDiagnosticUiSnapshot(
      tester: f.tester,
      assertions: f.session.assertions,
      navigation: f.navigation,
    ),
    nodes: 40,
    uniqueLabels: true,
    quick: true,
    verify: (r) => require(
      (r as DiagnosticUiSnapshot).observation.elements.isNotEmpty,
      'Empty unique-label diagnostic snapshot',
    ),
  ));
  const repeatedConditionalObservations = 100;
  const conditionalTarget = {'id': 'target'};
  final conditionalRequest = ObservationRequest(target: conditionalTarget);
  FlutterTestRuntime? cachedRuntime;
  cases.add(BenchmarkCase(
    'observer.runtime.conditional.cached.100',
    'observer',
    () async {
      RuntimeView? view;
      for (var index = 0; index < repeatedConditionalObservations; index++) {
        view = await cachedRuntime!.observe(conditionalRequest);
      }
      RunnerBenchmark.count('observations', repeatedConditionalObservations);
      return view!.targetVisible;
    },
    prepare: () async {
      await f.prepare(nodes: 40);
      cachedRuntime = FlutterTestRuntime(f.session);
    },
    quick: true,
    // Rebuilding and settling a Flutter fixture per internal batch dominates
    // this cached-read workload. One sample already includes 100 observations;
    // repeated prepare/body/cleanup cycles add setup cost rather than signal.
    batchable: false,
    dimensions: const {'observations': repeatedConditionalObservations},
    verify: (result) =>
        require(result == true, 'Cached target was not visible'),
    cleanup: () async {
      final runtime = cachedRuntime;
      cachedRuntime = null;
      await runtime?.close();
      await f.cleanup();
    },
  ));
  cases.add(uiCase(
    'observer.runtime.conditional.uncached.100',
    'observer',
    () async {
      RuntimeView? view;
      for (var index = 0; index < repeatedConditionalObservations; index++) {
        final step = TestStep(
          type: 'ifVisible',
          args: Map<String, dynamic>.from(conditionalTarget),
        );
        var visible = false;
        try {
          final finder = f.session.executor.finderForTargetStep(
            step,
            requireInteractive: false,
          );
          visible = finder
              .evaluate()
              .any(f.session.assertions.isElementVisuallyActionable);
        } catch (_) {
          // Match the runtime's hidden edge for a missing conditional target.
        }
        view = RuntimeView(
          revision: 0,
          level: ObservationLevel.minimal,
          target: conditionalTarget,
          targetVisible: visible,
        );
      }
      RunnerBenchmark.count('observations', repeatedConditionalObservations);
      return view!.targetVisible;
    },
    nodes: 40,
    quick: true,
    dimensions: const {'observations': repeatedConditionalObservations},
    verify: (result) =>
        require(result == true, 'Uncached target was not visible'),
  ));
  cases.add(BenchmarkCase(
    'session.runtime-operation',
    'session',
    () async {
      final result = await _executeRuntimeStep(
        f,
        const TestStep(type: 'expectVisible', args: {'id': 'target'}),
      );
      return result.succeeded;
    },
    prepare: () => f.prepare(),
    cleanup: f.cleanup,
    quick: true,
    batchable: false,
    fixtureVersion: 2,
    verify: (result) => require(result == true, 'Runtime operation failed'),
  ));
  cases.add(BenchmarkCase(
    'execution.control-flow',
    'execution',
    () async {
      final testCase = EnsembleTestCase(
        id: 'benchmark_control_flow',
        startScreen: 'Home',
        steps: const [
          TestStep(
            type: 'ifVisible',
            args: {'id': 'target'},
            nestedSteps: [
              TestStep(type: 'expectVisible', args: {'id': 'target'}),
            ],
          ),
        ],
      );
      final result = await ExecutionKernelRunner(
        plan: CompiledPlanCompiler().compile(testCase),
        runtime: FlutterTestRuntime(f.session),
      ).run();
      return result.outcome == AttemptOutcome.passed;
    },
    prepare: () => f.prepare(step: 'ifVisible'),
    cleanup: f.cleanup,
    quick: true,
    // Each run closes its runtime session. A batch would call body again on
    // the closed session because preparation is once per sample, not per
    // batch iteration.
    batchable: false,
    verify: (result) =>
        require(result == true, 'Control-flow operation did not complete'),
  ));
  const finderLookups = 256;
  final finderTarget = ElementTarget(testId: 'target');
  for (final cached in [true, false]) {
    cases.add(BenchmarkCase(
      cached
          ? 'session.finder-cache.same-revision'
          : 'session.finder-cache.invalidated',
      'session',
      () async {
        final resolver = f.session.resolver;
        Finder? previous;
        var identityReuses = 0;
        var matches = 0;
        for (var i = 0; i < finderLookups; i++) {
          if (!cached) resolver.invalidateResolvedFinders();
          final finder = resolver.resolveFinder(
            finderTarget,
            requireInteractive: false,
          );
          if (identical(previous, finder)) identityReuses++;
          previous = finder;
          matches += finder.evaluate().length;
        }
        RunnerBenchmark.count('finderLookups', finderLookups);
        return {
          'finderLookups': finderLookups,
          'identityReuses': identityReuses,
          'matches': matches,
          'checksum': matches * 31 + identityReuses,
        };
      },
      prepare: () => f.prepareRuntime('widget'),
      cleanup: f.cleanup,
      quick: true,
      dimensions: {
        'lookups': finderLookups,
        'revision': 'fixed',
        'cacheMode': cached ? 'same-revision' : 'invalidate-each-lookup',
      },
      verify: (result) {
        final value = result as Map;
        require(value['finderLookups'] == finderLookups,
            'Finder workload was incomplete');
        require(value['matches'] == finderLookups,
            'Finder workload did not resolve the fixed target each time');
        require(value['identityReuses'] == (cached ? finderLookups - 1 : 0),
            'Finder cache identity behavior changed');
        require(
            value['checksum'] ==
                finderLookups * 31 + (cached ? finderLookups - 1 : 0),
            'Finder workload checksum changed');
      },
    ));
  }
  for (final sync in [
    ObservationSynchronization.nextFrame,
    ObservationSynchronization.untilStable
  ]) {
    cases.add(uiCase(
        'observer.sync.${sync.name}',
        'observer',
        () => f.session
            .observe(options: ObservationOptions(synchronization: sync)),
        dimensions: {'synchronization': sync.name},
        verify: (r) => require(!(r as UiObservation).completeness.partial,
            'Unexpected partial observation')));
  }
  cases.add(uiCase(
      'observer.deep.400',
      'observer',
      () => f.session.observe(
          options: const ObservationOptions(
              synchronization: ObservationSynchronization.immediate,
              includeBounds: false)),
      nodes: 400,
      depth: 20,
      verify: (r) =>
          require((r as UiObservation).elements.isNotEmpty, 'Deep observer')));
  cases.add(uiCase('observer.repeated.100', 'observer', () async {
    UiObservation? last;
    for (var i = 0; i < 100; i++) {
      last = await f.session.observe(
          options: const ObservationOptions(
              synchronization: ObservationSynchronization.immediate));
    }
    RunnerBenchmark.count('observations', 100);
    return last;
  },
      verify: (r) => require(
          (r as UiObservation).revision == 1, 'Unchanged tree revision drift'),
      dimensions: {'observations': 100}));
  for (final size in [400, 1200]) {
    cases.add(BenchmarkCase('screenshot.capture.$size', 'screenshot', () async {
      final image = f.capture();
      f.image = image;
      RunnerBenchmark.count('pixels', image.width * image.height);
      return [image.width, image.height];
    }, prepare: () async {
      f.tester.view.physicalSize = Size(size.toDouble(), size.toDouble());
      await f.tester.binding.setSurfaceSize(Size(
          size / f.tester.view.devicePixelRatio,
          size / f.tester.view.devicePixelRatio));
      await f.prepare();
    }, cleanup: () async {
      await f.cleanup();
      f.tester.view.resetPhysicalSize();
      f.tester.view.resetDevicePixelRatio();
      await f.tester.binding.setSurfaceSize(null);
    },
        quick: size == 400,
        // A capture is already a relatively expensive raster operation. The
        // duration-floor batching loop repeatedly rebuilds the widget fixture
        // and changes the test surface; on CI that can stall the worker before
        // it reaches the 200 ms measurement floor. Keep one capture per sample
        // and use the normal sample count for statistical coverage.
        batchable: false,
        dimensions: {'width': size, 'height': size},
        verify: (r) => require((r as List).first == size && r.last == size,
            'Wrong capture size: $r')));
  }
  cases.add(uiCase(
      'screenshot.contrast',
      'screenshot',
      () async => f.tester.runAsync<bool>(() =>
          screenshotImageRegionHasContrast(
              image: f.image!, region: const Rect.fromLTWH(10, 10, 80, 40))),
      verify: (r) => require(r is bool, 'Invalid contrast'),
      dimensions: {'pixels': 480000}).prepareOverride(f));
  for (final frames in [1, 8]) {
    cases.add(uiCase('screenshot.encode.$frames', 'screenshot', () async {
      final images = [
        for (var i = 0; i < frames; i++)
          ScreenshotSheetFrame(
              stepIndex: i, label: 'frame $i', image: f.capture())
      ];
      RunnerBenchmark.count('frames', frames);
      return await f.tester.runAsync<String?>(() => writeScreenshotFrames(
          testId: 'encode_$frames',
          config: const ScreenshotConfig(enabled: true),
          frames: images,
          status: TestStatus.passed));
    },
        quick: frames == 1,
        dimensions: {'frames': frames},
        verify: (r) => require(r is String, 'Missing frames manifest')));
  }
  for (final ready in [true, false]) {
    late EnsembleLottie lottie;
    cases.add(BenchmarkCase(
        'screenshot.lottie.${ready ? 'ready' : 'timeout'}', 'screenshot',
        () async {
      await waitForVisibleLottiesReady(f.tester,
          timeout: const Duration(milliseconds: 20),
          pollInterval: const Duration(milliseconds: 2));
      return areVisibleLottiesReady(f.tester);
    }, prepare: () async {
      await f.prepare();
      lottie = EnsembleLottie();
      await f.tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SizedBox(width: 200, height: 200, child: lottie))));
      lottie.controller.updateSource('asset://controlled-composition.json');
      lottie.controller.compositionReady = ready;
      lottie.controller.lottieController!.duration = const Duration(seconds: 1);
    },
        cleanup: f.cleanup,
        dimensions: {'compositionReady': ready},
        verify: (r) => require(r == ready, 'Lottie readiness mismatch')));
  }
  final hostRoot = Directory('${f.root.path}/host_optimizer');
  cases.add(BenchmarkCase(
      'screenshot.host.optimize',
      'screenshot',
      () async {
        await f.tester.runAsync(
            () => optimizeTransportedScreenshotsForHost(hostRoot.path));
        return jsonDecode(File('${hostRoot.path}/frames/fixture_frames.json')
            .readAsStringSync());
      },
      prepare: () async {
        await f.prepare();
        if (hostRoot.existsSync()) hostRoot.deleteSync(recursive: true);
        Directory('${hostRoot.path}/report/screenshots')
            .createSync(recursive: true);
        Directory('${hostRoot.path}/frames').createSync();
        f.image = f.capture();
        final bytes = await f.tester.runAsync(
            () => f.image!.toByteData(format: ui.ImageByteFormat.png));
        File('${hostRoot.path}/report/screenshots/fixture.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        File('${hostRoot.path}/frames/fixture_frames.json')
            .writeAsStringSync(jsonEncode({
          'frames': [
            {'file': 'fixture.png'}
          ]
        }));
      },
      cleanup: f.cleanup,
      skipReason: mode == 'integration'
          ? 'Host codec subprocesses require widget mode'
          : null,
      verify: (r) {
        final name = (r as Map)['frames'][0]['file'];
        require(
            File('${hostRoot.path}/report/screenshots/$name').lengthSync() > 0,
            'Host conversion lost screenshot');
      }));
  for (final policy in StepReportCapturePolicy.values) {
    final type = switch (policy) {
      StepReportCapturePolicy.beforeAction => 'tap',
      StepReportCapturePolicy.afterCondition => 'expectText',
      StepReportCapturePolicy.onFailure => 'expectVisible'
    };
    cases.add(BenchmarkCase('workflow.capture.${policy.name}', 'workflow',
        () async {
      final test = EnsembleTestCase(id: 'workflow', steps: [
        TestStep(
            type: type,
            args: switch (type) {
              'tap' => {'id': 'target'},
              'expectText' => {'text': 'Welcome'},
              _ => {'id': 'missing'}
            })
      ]);
      final driver = FixtureDriver(f);
      final result = await EnsembleTestRunner.application(driver: driver)
          .runPlan(
              EnsembleTestExecutionPlan(
                  ordered: [
                    EnsembleTestDefinition(assetPath: 'fixture', testCase: test)
                  ],
                  config: const EnsembleTestConfig(
                      screenshots: ScreenshotConfig(enabled: true))),
              f.tester);
      final item = result.resultsById['workflow']!;
      require(
          item.status ==
              (policy == StepReportCapturePolicy.onFailure
                  ? TestStatus.failed
                  : TestStatus.passed),
          item.message ?? 'Wrong workflow status');
      return item.toJson();
    },
        quick: policy != StepReportCapturePolicy.onFailure,
        kind: 'workflow',
        dimensions: {'capturePolicy': policy.name},
        verify: (r) => require(
            (r as Map)['testId'] == 'workflow', 'Workflow result missing')));
  }
  for (final enabled in [false, true]) {
    final subscriberCount = enabled ? 1 : 0;
    cases.add(BenchmarkCase(
      'workflow.evidence.${enabled ? 'enabled' : 'disabled'}',
      'workflow',
      () async {
        const steps = [
          TestStep(type: 'expectText', args: {'text': 'Welcome'}),
          TestStep(type: 'expectText', args: {'text': 'Welcome'}),
          TestStep(type: 'expectText', args: {'text': 'Welcome'}),
          TestStep(type: 'expectText', args: {'text': 'Welcome'}),
        ];
        final test = EnsembleTestCase(
          id: 'workflow-evidence-pair',
          steps: steps,
        );
        final result = await EnsembleTestRunner.application(
          driver: FixtureDriver(f),
        ).runPlan(
          EnsembleTestExecutionPlan(
            ordered: [
              EnsembleTestDefinition(assetPath: 'fixture', testCase: test),
            ],
            config: EnsembleTestConfig(
              screenshots: ScreenshotConfig(enabled: enabled),
            ),
          ),
          f.tester,
        );
        final item = result.resultsById[test.id]!;
        final hasFrames = item.logs.any(
          (line) => line.startsWith('screenshotFrames:'),
        );
        return {
          'status': item.status.name,
          'stepCount': steps.length,
          'reportedStepCount': item.report?.stepsOutline.length,
          'hasScreenshotFrames': hasFrames,
        };
      },
      quick: true,
      kind: 'workflow',
      dimensions: {
        'steps': 4,
        'evidenceSubscribers': subscriberCount,
        'screenshotsEnabled': enabled,
      },
      verify: (result) {
        final value = result as Map;
        require(value['status'] == TestStatus.passed.name,
            'Evidence workload did not pass');
        require(value['stepCount'] == 4, 'Evidence workload lost steps');
        require(value['reportedStepCount'] == 4,
            'Evidence workload report lost steps');
        require(value['hasScreenshotFrames'] == enabled,
            'Evidence workload frame publication did not match configuration');
      },
    ));
  }
  cases.add(BenchmarkCase(
    'workflow.capture.finderTap',
    'workflow',
    () async {
      final test = EnsembleTestCase(
        id: 'workflow-finder-tap',
        steps: const [
          TestStep(type: 'doubleTap', args: {'id': 'target'}),
        ],
      );
      final result = await EnsembleTestRunner.application(
        driver: FixtureDriver(f),
      ).runPlan(
        EnsembleTestExecutionPlan(
          ordered: [
            EnsembleTestDefinition(assetPath: 'fixture', testCase: test),
          ],
          config: EnsembleTestConfig(
            screenshots: ScreenshotConfig(enabled: true),
          ),
        ),
        f.tester,
      );
      final item = result.resultsById[test.id]!;
      require(item.status == TestStatus.passed,
          item.message ?? 'Finder tap workload failed');
      return {
        'testId': item.testId,
        'status': item.status.name,
        'hasScreenshotFrames': item.logs.any(
          (line) => line.startsWith('screenshotFrames:'),
        ),
      };
    },
    quick: true,
    kind: 'workflow',
    dimensions: const {
      'action': 'doubleTap',
      'targetPath': 'resolved-finder',
      'screenshotsEnabled': true,
    },
    verify: (result) {
      final value = result as Map;
      require(value['status'] == TestStatus.passed.name,
          'Finder tap workflow did not pass');
      require(value['hasScreenshotFrames'] == true,
          'Finder tap workflow did not publish evidence');
    },
  ));
  cases.add(BenchmarkCase(
    'workflow.trigger.tap',
    'workflow',
    () async {
      final test = EnsembleTestCase(
        id: 'workflow_trigger_tap',
        steps: const [
          TestStep(
            type: 'trigger',
            args: {'action': 'onTap', 'id': 'target'},
          ),
        ],
      );
      final driver = FixtureDriver(f);
      final result =
          await EnsembleTestRunner.application(driver: driver).runPlan(
        EnsembleTestExecutionPlan(
          ordered: [
            EnsembleTestDefinition(assetPath: 'fixture', testCase: test),
          ],
          config: const EnsembleTestConfig(
            screenshots: ScreenshotConfig(enabled: true),
          ),
        ),
        f.tester,
      );
      final item = result.resultsById['workflow_trigger_tap']!;
      require(
        item.status == TestStatus.passed,
        item.message ?? 'Trigger tap workflow failed',
      );
      return item.toJson();
    },
    quick: true,
    kind: 'workflow',
    dimensions: const {'action': 'trigger.onTap'},
    verify: (r) => require(
      (r as Map)['testId'] == 'workflow_trigger_tap',
      'Trigger workflow result missing',
    ),
  ));
  cases.add(BenchmarkCase(
    'workflow.performance-artifacts',
    'workflow',
    () async {
      final context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(id: 'performance_artifacts', steps: []),
        config: const EnsembleTestConfig(
          performance: PerformanceConfig(enabled: true),
        ),
      );
      final tracker = ScreenTracker();
      tracker.trackScreen(screenName: 'Home');
      const visuals = TestVisualArtifacts(
        screenshotSheets: _noScreenshotSheets,
        drainFlutterExceptions: _drainNothing,
      );
      visuals.captureScreenArtifacts(context);
      final result = context.runtime.screenArtifacts['Home'];
      tracker.clearAll();
      return result;
    },
    quick: true,
    kind: 'workflow',
    dimensions: const {'performanceArtifacts': true},
    verify: (result) =>
        require(result is Map, 'Screen performance artifact missing'),
  ));
  cases.add(BenchmarkCase('workflow.retry', 'workflow', () async {
    final driver = FixtureDriver(f, failFirstLaunch: true);
    final test = EnsembleTestCase(id: 'retry', retry: 1, steps: const [
      TestStep(type: 'expectText', args: {'text': 'Welcome'})
    ]);
    final result = await EnsembleTestRunner.application(driver: driver).runPlan(
        EnsembleTestExecutionPlan(ordered: [
          EnsembleTestDefinition(assetPath: 'fixture', testCase: test)
        ]),
        f.tester);
    return result.resultsById['retry'];
  },
      kind: 'workflow',
      verify: (r) => require(
          (r as EnsembleSingleTestResult).status == TestStatus.passed &&
              r.attempts == 2,
          'Retry failed')));
  cases.add(BenchmarkCase('workflow.standalone', 'workflow', () async {
    final harness = EnsembleTestHarness(
        appPath:
            '${mode == 'integration' ? 'packages/ensemble_test_runner/' : ''}tool/benchmarks/fixtures/ensemble/apps/demo/',
        appHome: 'Home');
    const test =
        EnsembleTestCase(id: 'standalone', startScreen: 'Home', steps: [
      TestStep(type: 'waitFor', args: {'id': 'target', 'timeoutMs': 5000}),
      TestStep(
          type: 'expectVisible', args: {'id': 'target', 'timeoutMs': 5000}),
      TestStep(type: 'expectText', args: {'text': 'Welcome'})
    ]);
    final result = await EnsembleTestRunner(harness: harness).runPlan(
        const EnsembleTestExecutionPlan(ordered: [
          EnsembleTestDefinition(assetPath: 'fixture', testCase: test)
        ]),
        f.tester);
    return result.resultsById['standalone'];
  },
      kind: 'workflow',
      verify: (r) => require(
          (r as EnsembleSingleTestResult).status == TestStatus.passed,
          r.message ?? 'Standalone failed')));
  cases.add(BenchmarkCase('workflow.standalone-storage', 'workflow', () async {
    final harness = EnsembleTestHarness(
        appPath:
            '${mode == 'integration' ? 'packages/ensemble_test_runner/' : ''}tool/benchmarks/fixtures/ensemble/apps/demo/',
        appHome: 'Home');
    const test = EnsembleTestCase(
      id: 'standalone_storage',
      startScreen: 'Home',
      steps: [
        TestStep(
          type: 'expectVisible',
          args: {'id': 'target', 'timeoutMs': 5000},
        ),
      ],
    );
    final result = await EnsembleTestRunner(harness: harness).runPlan(
        const EnsembleTestExecutionPlan(
          ordered: [
            EnsembleTestDefinition(assetPath: 'fixture', testCase: test)
          ],
          config: EnsembleTestConfig(
            logStorage: LogStorageConfig(enabled: true),
          ),
        ),
        f.tester);
    return result.resultsById['standalone_storage'];
  },
      kind: 'workflow',
      verify: (r) => require(
          (r as EnsembleSingleTestResult).status == TestStatus.passed,
          r.message ?? 'Standalone storage workflow failed')));
  cases.add(uiCase('session.snapshot-target', 'session', () async {
    final observation = await f.session.observe(
        options: const ObservationOptions(
            synchronization: ObservationSynchronization.immediate));
    final target = flattenElements(observation.elements)
        .firstWhere((e) => e.testId == 'target');
    final result = await f.session.act(_sessionOperation('tap', {
      'target': {
        'elementId': target.elementId,
        'observationId': observation.observationId,
      },
    }));
    require(result.succeeded, 'Snapshot action failed');
    return true;
  }, verify: (r) => require(r == true, 'Snapshot target')));
  cases.add(uiCase('session.capabilities', 'session',
      () async => (await f.session.getCapabilities()).toJson(),
      verify: (r) =>
          require((r as Map)['semanticTree'] == true, 'Capabilities')));
  cases.add(BenchmarkCase('session.queue.contention', 'session', () async {
    final queue = LeafCommandQueue();
    final order = <int>[];
    await Future.wait([
      for (var i = 0; i < 8; i++)
        queue.run(() async {
          order.add(i);
          return i;
        })
    ]);
    queue.close();
    return order;
  },
      verify: (r) =>
          require((r as List).join(',') == '0,1,2,3,4,5,6,7', 'Queue order')));

  for (final count in [10, 100, 1000]) {
    final assets = {
      for (var i = 0; i < count; i++)
        'tests/$i.test.yaml': jsonEncode({
          'id': 'test_$i',
          'steps': [
            {
              'pump': {'durationMs': 0}
            }
          ]
        })
    };
    cases.add(BenchmarkCase('planner.suite.$count', 'planner', () async {
      RunnerBenchmark.count('files', count);
      return EnsembleTestExecutionPlanner.buildForTest(assetContents: assets);
    },
        quick: count == 10,
        dimensions: {'files': count},
        verify: (r) => require(
            (r as EnsembleTestExecutionPlan).ordered.length == count,
            'Plan lost tests')));
    cases.add(BenchmarkCase(
        'planner.selection.$count',
        'planner',
        () async => EnsembleTestExecutionPlanner.buildForTest(
            assetContents: assets,
            selection: const EnsembleTestSelection(ids: {'test_0'})),
        dimensions: {'files': count, 'selected': 1},
        verify: (r) => require(
            (r as EnsembleTestExecutionPlan).ordered.length == 1,
            'Selection')));
  }
  final scenarios = [
    for (var i = 0; i < 100; i++)
      {
        'id': 'scenario_$i',
        'description': 'Scenario $i',
        'vars': {'expected': i},
      },
  ];
  cases.add(BenchmarkCase(
    'planner.scenarios.100',
    'planner',
    () async => EnsembleTestExecutionPlanner.buildForTest(
      assetContents: {
        'tests/scenarios.test.yaml': jsonEncode({
          'id': 'scenarios',
          'steps': [
            {
              'expectText': {'text': r'${scenario.expected}'},
            },
          ],
          'scenarios': scenarios,
        }),
      },
      selection: const EnsembleTestSelection(ids: {'scenarios[scenario_99]'}),
    ),
    quick: true,
    dimensions: const {'scenarios': 100, 'selected': 1},
    verify: (result) {
      final plan = result as EnsembleTestExecutionPlan;
      require(plan.ordered.length == 1, 'Scenario selection count');
      require(
        plan.ordered.single.testCase.steps.single.args['text'] == 99,
        'Selected scenario substitution',
      );
    },
  ));
  final compileBatch = [
    for (var index = 0; index < 100; index++)
      EnsembleTestCase(
        id: 'compiled_$index',
        steps: [
          for (var step = 0; step < 10; step++)
            const TestStep(type: 'pump', args: {'durationMs': 0}),
        ],
      ),
  ];
  cases.add(BenchmarkCase(
    'planner.compile-batch.100',
    'planner',
    () async => CompiledPlanBatch(compileBatch),
    quick: true,
    dimensions: const {'tests': 100, 'stepsPerTest': 10},
    verify: (result) {
      final batch = result as CompiledPlanBatch;
      require(
        batch.forTest('compiled_99').plan.id == 'compiled_99',
        'Compiled plan missing from prepared batch',
      );
    },
  ));
  cases.add(BenchmarkCase('planner.cycle', 'planner', () async {
    try {
      await EnsembleTestExecutionPlanner.buildForTest(assetContents: {
        'a': jsonEncode({'id': 'a', 'session': 'b', 'steps': []}),
        'b': jsonEncode({'id': 'b', 'session': 'a', 'steps': []})
      });
    } on EnsembleTestFailure {
      return 'expected-cycle';
    }
    return 'unexpected-success';
  },
      dimensions: {'outcome': 'expected-error'},
      verify: (r) => require(r == 'expected-cycle', 'Cycle accepted')));
  cases.add(BenchmarkCase('mock.composition', 'mock', () async {
    final target = <String, Map<String, dynamic>>{};
    MockComposition.mergeApiMaps(
        target,
        {
          'api': {
            'body': {'items': List.generate(100, (i) => i)}
          }
        },
        sourceLabel: 'benchmark');
    return target;
  },
      dimensions: {'items': 100},
      verify: (r) =>
          require((r as Map).containsKey('api'), 'Mock composition')));
  for (final count in [10, 1000]) {
    final reportResults = fixtureResults(count);
    final before = {
      for (var i = 0; i < count; i++) 'key$i': {'value': i}
    };
    final after = {
      ...before,
      'key0': {'value': -1}
    };
    cases.add(BenchmarkCase('lifecycle.storage-diff.$count', 'lifecycle',
        () async => diffStorage(before, after),
        dimensions: {'keys': count},
        verify: (r) => require((r as List).length == 1, 'Diff mismatch')));
    cases.add(BenchmarkCase('report.serialize.$count', 'report', () async {
      final json = TestReportDocument.buildComplete(reportResults,
          artifactRoot: f.root.path, displayRoot: f.root.path);
      final compact = ReportJsonOptimizer.optimize(json);
      return ReportJsonOptimizer.expand(compact);
    },
        quick: count == 10,
        dimensions: {'tests': count},
        verify: (r) => require(r is Map && (r['tests'] as List).length == count,
            'Report round trip lost tests')));
    cases.add(BenchmarkCase(
        'report.html.$count',
        'report',
        () async =>
            HtmlTestReporter().write(reportResults, artifactRoot: f.root.path),
        prepare: () async {
          final shell = File('${f.root.path}/report/index.html');
          if (shell.existsSync()) shell.deleteSync();
        },
        dimensions: {'tests': count},
        verify: (r) => require(
            File('${f.root.path}/report/index.html').existsSync(),
            'HTML missing')));
    cases.add(BenchmarkCase('report.console.$count', 'report',
        () async => TestReporter().formatSummary(reportResults),
        dimensions: {'tests': count},
        verify: (r) => require(
            (r as String).contains('test_0'), 'Console report missing test')));
  }
  cases.add(BenchmarkCase('history.append', 'history', () async {
    await f.tester.runAsync(() => EnsembleTestHistoryStore.recordCompletedRun(
        appDir: f.root.path,
        artifactRoot: f.root.path,
        result: fixtureResults(10)));
    return true;
  }, prepare: () async {
    final db = File('${f.root.path}/report/ensemble_test.db');
    if (db.existsSync()) db.deleteSync();
  },
      verify: (r) => require(
          File('${f.root.path}/report/ensemble_test.db').existsSync(),
          'History DB missing')));
  for (final bytes in [1024, 1024 * 1024]) {
    final payload = Uint8List.fromList(List.generate(bytes, (i) => i % 256));
    cases.add(BenchmarkCase('artifact.write.$bytes', 'artifact', () async {
      AtomicFile.writeBytesSync(File('${f.root.path}/payload.bin'), payload);
      RunnerBenchmark.count('bytes', bytes);
      return File('${f.root.path}/payload.bin').lengthSync();
    },
        dimensions: {'bytes': bytes},
        verify: (r) => require(r == bytes, 'Artifact size mismatch')));
    cases.add(BenchmarkCase('artifact.transport.$bytes', 'artifact', () async {
      final lines = <String>[];
      runZoned(() {
        final emitter = EnsembleTestArtifactEmitter.instance;
        emitter.resetForTest();
        emitter.emitArtifact('payload.bin', payload,
            mimeType: 'application/octet-stream');
        emitter.complete();
      },
          zoneSpecification:
              ZoneSpecification(print: (_, __, ___, line) => lines.add(line)));
      final result = await f.tester.runAsync(() =>
          materializeTransportedArtifacts(
              artifactRoot: '${f.root.path}/received',
              output: lines.join('\n')));
      RunnerBenchmark.count('bytes', bytes);
      RunnerBenchmark.count('records', lines.length);
      return result;
    },
        dimensions: {'bytes': bytes},
        verify: (r) => require(
            (r as ArtifactTransportResult).complete, 'Transport incomplete')));
  }
  const archiveFiles = 16;
  const archiveFileBytes = 256 * 1024;
  final archivePayload = List<int>.generate(
    archiveFileBytes,
    (index) => index & 0xff,
  );
  cases.add(BenchmarkCase(
    'artifact.archive.4m',
    'artifact',
    () async => ScreenshotArchive.create(f.root.path),
    prepare: () async {
      _clearScreenshotArchiveFixture(f.root.path);
      final images = Directory('${f.root.path}/report/screenshots')
        ..createSync(recursive: true);
      for (var index = 0; index < archiveFiles; index++) {
        File('${images.path}/frame_$index.webp')
            .writeAsBytesSync(archivePayload);
      }
    },
    cleanup: () async => _clearScreenshotArchiveFixture(f.root.path),
    quick: true,
    dimensions: {
      'files': archiveFiles,
      'bytes': archiveFiles * archiveFileBytes,
      'compression': 'stored',
    },
    verify: (result) => require(result == true, 'Screenshot archive missing'),
  ));
  cases.add(BenchmarkCase(
      'artifact.incomplete',
      'artifact',
      () async => f.tester.runAsync(() => materializeTransportedArtifacts(
          artifactRoot: '${f.root.path}/received',
          output: '${ensembleTestArtifactProtocolPrefix}{"event":"begin"}')),
      dimensions: {'outcome': 'expected-error'},
      verify: (r) => require(!(r as ArtifactTransportResult).complete,
          'Incomplete transport accepted')));
  cases.add(BenchmarkCase(
      'tools.schema', 'tools', () async => EnsembleTestSchemaBuilder.build(),
      verify: (r) =>
          require((r as Map).containsKey('properties'), 'Invalid schema')));
  cases.add(BenchmarkCase('tools.inspect', 'tools',
      () async => EnsembleAppInspector(f.root.path).inspect(),
      prepare: () => prepareProject(f.root),
      verify: (r) => require((r as EnsembleAppInspection).screens.isNotEmpty,
          'Inspection empty')));
  cases.add(BenchmarkCase('tools.validate', 'tools',
      () async => EnsembleTestValidator(f.root.path).validate(),
      prepare: () => prepareProject(f.root),
      verify: (r) => require(
          (r as EnsembleTestValidationResult).hasErrors == false,
          'Invalid fixture project')));
  cases.add(BenchmarkCase(
      'tools.scaffold',
      'tools',
      () async => EnsembleTestScaffold(f.root.path,
              testsDirRelative: 'ensemble/apps/demo/tests')
          .create(['--scaffold-test=generated']),
      prepare: () async {
        await prepareProject(f.root);
        final file =
            File('${f.root.path}/ensemble/apps/demo/tests/generated.test.yaml');
        if (file.existsSync()) file.deleteSync();
      },
      verify: (r) => require(
          (r as EnsembleTestScaffoldResult).created, 'Scaffold not created')));
  cases.add(BenchmarkCase(
      'tools.doctor',
      'tools',
      () async =>
          f.tester.runAsync(() => EnsembleTestDoctor(f.root.path).run()),
      prepare: () => prepareProject(f.root),
      skipReason: mode == 'integration'
          ? 'Doctor requires host process execution'
          : null,
      verify: (r) => require(
          (r as EnsembleTestDoctorResult).lines.isNotEmpty, 'Doctor empty')));
  cases.add(BenchmarkCase(
      'worker.capacity',
      'worker',
      () async => calculateAutomaticWorkerCount(
          testCount: 20,
          logicalProcessorCount: 10,
          totalMemoryBytes: 16 * 1024 * 1024 * 1024),
      verify: (r) => require(r == 4, 'Capacity mismatch')));
  for (final workers in [1, 2, 4]) {
    cases.add(BenchmarkCase('worker.shards.$workers', 'worker',
        () async => planShardRunIdsForTest(appDir: f.root.path, jobs: workers),
        prepare: () => prepareProject(f.root),
        dimensions: {'workers': workers},
        verify: (r) => require(
            (r as List).expand((s) => s as List).toSet().length == 8,
            'Sharding lost tests')));
  }
  cases.add(uiCase(
      'diagnostic.performance-log',
      'diagnostic',
      () async => f.tester.runAsync(() => writePerformanceLog(
          logger: f.context.logger,
          filePrefix: 'benchmark',
          name: 'synthetic',
          frames: const [])),
      verify: (r) => require(r is String, 'Performance processing')));
  cases.add(BenchmarkCase('lifecycle.restore-phases', 'lifecycle', () async {
    var count = 0;
    await AppSessionSnapshot.runRestorePhases(clear: () async {
      count++;
    }, rewrite: () async {
      count++;
    });
    return count;
  }, verify: (r) => require(r == 2, 'Restore phases')));
  cases.add(uiCase('screenshot.aggregate', 'screenshot', () async {
    final aggregator = ScreenshotSheetAggregator(
        screenshots: const ScreenshotConfig(enabled: true), devices: const []);
    final path = await f.tester.runAsync<String?>(() => aggregator.completeRun(
        testCase: f.context.testCase,
        frames: [
          ScreenshotSheetFrame(
              stepIndex: 0, label: 'aggregate', image: f.capture())
        ],
        status: TestStatus.passed,
        durationMs: 0));
    await f.tester.runAsync(aggregator.flushRemaining);
    return path;
  }, verify: (r) => require(r is String, 'Aggregator did not write frames')));
  cases.add(BenchmarkCase('cli.patch-restore', 'cli', () async {
    final before = File('${f.root.path}/pubspec.yaml').readAsStringSync();
    final patcher = TestAppPatcher(f.root.path);
    try {
      patcher.enable();
    } finally {
      patcher.restore();
    }
    return before == File('${f.root.path}/pubspec.yaml').readAsStringSync();
  },
      prepare: () => prepareProject(f.root),
      verify: (r) => require(r == true, 'Patcher did not restore project')));
  for (final reuse in [false, true]) {
    TestServiceManager? manager;
    final configFile = File('${f.root.path}/service.dart');
    cases.add(BenchmarkCase(
        'support_service.${reuse ? 'reuse' : 'startup'}',
        'support_service',
        () async {
          await f.tester.runAsync(() async {
            await manager!.startAll();
            await manager!.stopAll();
          });
          return true;
        },
        cold: !reuse,
        batchable: false,
        prepare: () async {
          await f.tester.runAsync(() async {
            final server =
                await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
            final port = server.port;
            if (reuse) {
              f.server = server;
              server.listen((request) async {
                request.response.write('ready');
                await request.response.close();
              });
            } else {
              await server.close(force: true);
            }
            configFile.writeAsStringSync(
                "import 'dart:io'; Future<void> main(List<String> args) async {final server=await HttpServer.bind(InternetAddress.loopbackIPv4,int.parse(args[0]));await for(final req in server){req.response.write('ready');await req.response.close();}}\n");
            manager = TestServiceManager([
              TestServiceConfig(
                  name: 'benchmark_service',
                  command: const String.fromEnvironment('ensembleBenchmarkDart',
                      defaultValue: 'dart'),
                  arguments: [configFile.path, port.toString()],
                  readyUrl: 'http://127.0.0.1:$port/',
                  readyTimeoutMs: 5000)
            ], artifactRoot: f.root.path);
          });
        },
        cleanup: () async {
          await f.tester.runAsync(() async {
            await manager?.stopAll();
            await f.server?.close(force: true);
            f.server = null;
          });
        },
        skipReason: mode == 'integration'
            ? 'Device platforms cannot spawn host Dart processes'
            : null,
        dimensions: {'prestarted': reuse},
        verify: (r) => require(r == true, 'Service lifecycle')));
  }
  final capacity = calculateAutomaticWorkerCount(
      testCount: 8,
      logicalProcessorCount: Platform.numberOfProcessors,
      totalMemoryBytes: detectTotalMemoryBytes());
  for (final workers in [1, 2, 4]) {
    for (final fail in [false, true]) {
      final project =
          Directory('${f.root.path}/worker_fixture_${workers}_$fail');
      cases.add(BenchmarkCase(
          'worker.pipeline.$workers.${fail ? 'failure' : 'success'}',
          'worker',
          () async {
            final result = await f.tester.runAsync(() =>
                runRunnerWorkersForBenchmark(
                    appDir: project.path,
                    workers: workers,
                    testsDir: 'tests',
                    testEntry: 'test/benchmark_test.dart'));
            return result;
          },
          batchable: false,
          externalMeasurements: () => Directory('${project.path}/child-traces')
              .listSync()
              .whereType<File>()
              .map((file) =>
                  jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)
              .toList(),
          prepare: () => prepareWorkerProject(project, fail: fail),
          dimensions: {'workers': workers, 'tests': 8, 'expectedFailure': fail},
          skipReason: mode == 'integration'
              ? 'Host worker subprocesses are benchmarked in widget mode'
              : workers > capacity
                  ? 'Host capacity permits $capacity worker(s)'
                  : null,
          verify: (r) {
            final result = r as ProcessResult;
            require(fail ? result.exitCode != 0 : result.exitCode == 0,
                'Unexpected worker exit ${result.exitCode}: ${result.stderr}');
            require(result.stdout.toString().contains('worker_test_0'),
                'Worker produced no test results');
            final report = jsonDecode(
                File('${project.path}/merged.json').readAsStringSync()) as Map;
            require(report['total'] == 8 && report['failed'] == (fail ? 1 : 0),
                'Worker lost or unexpectedly failed tests');
            require(
                Directory('${project.path}/child-traces')
                        .listSync()
                        .whereType<File>()
                        .length ==
                    workers,
                'Missing worker measurements');
          }));
    }
  }
  for (final name in coveredSteps) {
    final canonical = TestStepVocabulary.resolveStepType(name);
    cases.add(BenchmarkCase('step.$name', _serviceForStep(name), () async {
      final args = stepArgs(name);
      if (name == 'httpRequest')
        args['url'] = 'http://127.0.0.1:${f.server!.port}/';
      final parsed = EnsembleTestParser.parseString(jsonEncode({
        'id': 'step_fixture',
        'steps': [
          {name: args}
        ]
      }));
      if (name == 'expectStyle') {
        final result = await _executeRuntimeStep(f, parsed.steps.single);
        if (!result.succeeded &&
            result.error.toString().contains('Unsupported property')) {
          return true;
        }
        throw StateError(
            'expectStyle unexpectedly succeeded; update its benchmark fixture');
      }
      OperationResult result;
      if (name == 'httpRequest') {
        result = (await f.tester
            .runAsync(() => _executeRuntimeStep(f, parsed.steps.single)))!;
      } else {
        result = await _executeRuntimeStep(f, parsed.steps.single);
      }
      if (!result.succeeded) {
        throw result.cause ?? StateError(result.error ?? 'Step $name failed');
      }
      RunnerBenchmark.count('steps', 1);
      return true;
    }, prepare: () async {
      if (runtimeSteps.contains(canonical)) {
        await f.prepareRuntime(mode);
      } else {
        await f.prepare(step: canonical);
      }
      if (name == 'httpRequest')
        await f.tester.runAsync(() async {
          f.server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          f.server!.listen((request) async {
            request.response.write('{}');
            await request.response.close();
          });
        });
    },
        cleanup: f.cleanup,
        dimensions: {
          'step': name,
          'canonical': canonical,
          'path': 'compiled-runtime',
          if (name == 'expectStyle')
            'expectedOutcome': 'unsupported-property-error'
        },
        verify: (r) => require(r == true, 'Step $name did not complete'),
        skipReason: _stepPrerequisite(name, mode)));
  }
  for (final nodes in [40, 400]) {
    for (final kind in ['structured', 'missing', 'ambiguous']) {
      cases.add(uiCase(
          'locator.$kind.$nodes',
          'locator',
          () async => f.session.act(_sessionOperation('tap', {
                'target': {
                  'locator': {
                    'text': kind == 'structured'
                        ? 'Hello'
                        : kind == 'missing'
                            ? 'Absent'
                            : 'Repeated label',
                  },
                },
              })),
          nodes: nodes,
          dimensions: {
            'resolution': kind,
            'expectedOutcome': kind == 'structured' ? 'success' : 'error'
          }, verify: (r) {
        final result = r as ActionResult;
        require(
            kind == 'structured'
                ? result.succeeded
                : result.error?.code ==
                    (kind == 'missing'
                        ? TestExecutionErrorCode.elementNotFound
                        : TestExecutionErrorCode.ambiguousTarget),
            'Wrong locator outcome: ${result.toJson()}');
      }));
    }
  }
  ElementTarget? stale;
  cases.add(BenchmarkCase(
      'locator.stale',
      'locator',
      () async => f.session.act(_sessionOperation('tap', {
            'target': stale!.toJson(),
          })),
      prepare: () async {
        await f.prepare();
        final o = await f.session.observe(
            options: const ObservationOptions(
                synchronization: ObservationSynchronization.immediate));
        final e =
            flattenElements(o.elements).firstWhere((e) => e.testId == 'target');
        stale = ElementTarget(
            elementId: e.elementId, observationId: o.observationId);
        await f.tester.pumpWidget(const MaterialApp(home: Text('Replaced')));
      },
      cleanup: f.cleanup,
      dimensions: {'expectedOutcome': 'stale-error'},
      verify: (r) => require(
          (r as ActionResult).error?.code ==
              TestExecutionErrorCode.staleObservation,
          'Stale target accepted')));
  cases.add(uiCase('observer.with-screenshot', 'observer', () async {
    DiagnosticUiSnapshot? snapshot;
    final captured = await f.session.queue
        .run(() => captureStepReportArtifacts(captureScreenshot: () async {
              f.image = f.capture();
              // The production diagnostic observer runs synchronously on the frozen frame.
              snapshot = captureDiagnosticUiSnapshot(
                  tester: f.tester,
                  assertions: f.session.assertions,
                  navigation: f.navigation);
              return true;
            }));
    return captured &&
        f.image != null &&
        snapshot!.observation.elements.isNotEmpty;
  },
      kind: 'workflow',
      dimensions: {'pairing': 'same-synchronous-turn', 'queue': 'held'},
      verify: (r) => require(r == true, 'Screenshot/observer pairing failed')));
  cases.add(uiCase(
      'observer.request-screenshot',
      'observer',
      () => f.session.observe(
          options: const ObservationOptions(
              synchronization: ObservationSynchronization.immediate,
              includeScreenshot: true)),
      dimensions: {'requestedScreenshot': true, 'expectedScreenshot': false},
      verify: (r) => require(!(r as UiObservation).completeness.screenshot,
          'Session observer behavior changed; update benchmark')));
  cases.add(uiCase('observer.changed', 'observer', () async {
    final before = await f.session.observe(
        options: const ObservationOptions(
            synchronization: ObservationSynchronization.immediate));
    await f.tester.pumpWidget(
        const MaterialApp(home: Text('Changed', key: ValueKey('changed'))));
    final after = await f.session.observe(
        options: const ObservationOptions(
            synchronization: ObservationSynchronization.immediate));
    return [before.revision, after.revision];
  },
      kind: 'workflow',
      verify: (r) => require(
          (r as List)[1] > (r)[0], 'Changed tree did not update revision')));
  cases.add(uiCase('screenshot.sustained.100', 'screenshot', () async {
    final rss = <int>[];
    for (var i = 0; i < 100; i++) {
      final image = f.capture();
      image.dispose();
      if (i % 10 == 0) rss.add(ProcessInfo.currentRss);
    }
    return rss;
  },
      kind: 'workflow',
      dimensions: {'captures': 100, 'renderingIncluded': true},
      verify: (r) =>
          require((r as List).length == 10, 'Sustained captures incomplete')));
  for (final count in [10, 1000]) {
    cases.add(uiCase(
        'diagnostic.api-log.$count',
        'diagnostic',
        () => f.tester.runAsync(() => writeApiCallsLogFile(
                logger: f.context.logger,
                filePrefix: 'fixture',
                calls: [
                  for (var i = 0; i < count; i++)
                    f.context.apiOverlay.calls[i % 3]
                ])),
        dimensions: {'entries': count},
        verify: (r) => require(r is String, 'API log missing')));
    cases.add(uiCase(
        'diagnostic.performance-log.$count',
        'diagnostic',
        () => f.tester.runAsync(() => writePerformanceLog(
                logger: f.context.logger,
                filePrefix: 'fixture',
                name: 'synthetic',
                frames: [
                  for (var i = 0; i < count; i++)
                    AppFrameTimingEntry(
                        frameNumber: i,
                        buildStartMicros: i * 17000,
                        buildMs: 2,
                        rasterMs: 3,
                        vsyncOverheadMs: 1,
                        totalSpanMs: 6)
                ])),
        dimensions: {'entries': count, 'synthetic': true},
        verify: (r) => require(r is String, 'Performance log missing')));
  }
  cases.add(uiCase(
      'session.capture-artifact',
      'session',
      () =>
          f.session.captureArtifact(const ArtifactRequest(kind: 'screenshot')),
      verify: (r) =>
          require((r as TestArtifact).byteLength! > 0, 'Empty capture')));
  for (final matched in [true, false]) {
    cases.add(uiCase(
        'session.wait.${matched ? 'success' : 'timeout'}',
        'session',
        () => f.session.waitFor(
              _sessionOperation('waitFor', {
                'target': {'testId': matched ? 'target' : 'missing'},
                'timeoutMs': 20,
              }),
            ),
        dimensions: {'expectedOutcome': matched ? 'satisfied' : 'timeout'},
        verify: (r) => require(
            (r as WaitResult).status ==
                (matched ? WaitStatus.satisfied : WaitStatus.failed),
            'Wrong wait outcome: ${r.toJson()}')));
    cases.add(uiCase(
        'session.assert.${matched ? 'success' : 'missing'}',
        'session',
        () => f.session.assertCondition(_sessionOperation('expectExists', {
              'id': matched ? 'target' : 'missing',
            })),
        dimensions: {'expectedOutcome': matched ? 'success' : 'failed'},
        verify: (r) => require((r as AssertionResult).passed == matched,
            'Wrong assertion outcome')));
  }
  cases.add(BenchmarkCase(
      'session.permission-denied',
      'session',
      () => f.session.act(_sessionOperation('tap', {
            'target': const {'testId': 'target'},
          })),
      prepare: () async {
        await f.prepare();
        await f.session.close();
        f.session = LocalTestExecutionSession.attach(
            tester: f.tester,
            context: f.context,
            permissions: const SessionPermissions());
      },
      cleanup: f.cleanup,
      verify: (r) => require(
          (r as ActionResult).error?.code ==
              TestExecutionErrorCode.permissionDenied,
          'Permission unexpectedly granted')));
  for (final platform in ['ios', 'android']) {
    cases.add(uiCase(
        'screenshot.frame.$platform.fallback',
        'screenshot',
        () async => f.tester.runAsync<String?>(() => writeScreenshotFrames(
            testId: 'frame_$platform',
            config: const ScreenshotConfig(enabled: true),
            frames: [
              ScreenshotSheetFrame(
                  stepIndex: 0,
                  label: 'frame',
                  image: f.capture(),
                  platform: platform,
                  model: platform == 'ios'
                      ? 'iPhone 15 Pro'
                      : 'Samsung Galaxy S20')
            ],
            status: TestStatus.passed)),
        dimensions: {
          'codecFallback': true,
          'platform': platform,
          'resizingIncluded': true
        },
        skipReason: mode == 'integration'
            ? 'Device framing and host codec fallback run in widget mode; integration captures use physical device PNGs'
            : null,
        verify: (r) => require(r is String, 'Framed output missing')));
  }
  cases.add(BenchmarkCase('screenshot.secure.allow', 'screenshot', () async {
    f.image = ExtendedStepHandlers.captureScreenshotImage(f.tester);
    return f.image!.width;
  }, prepare: () async {
    await f.prepare();
    await f.tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TextField(controller: f.controller, obscureText: true))));
  },
      cleanup: f.cleanup,
      verify: (r) => require(r is int && r > 0, 'Secure capture missing')));
  cases.add(BenchmarkCase(
      'planner.matrix',
      'planner',
      () => EnsembleTestExecutionPlanner.buildForTest(
              assetContents: {
                'suite/tests/matrix.test.yaml': jsonEncode({
                  'id': 'matrix',
                  'profiles': ['a', 'b'],
                  'scenarios': [
                    {'id': 'x'},
                    {'id': 'y'}
                  ],
                  'steps': [
                    {
                      'pump': {'durationMs': 0}
                    }
                  ]
                })
              },
              config: const EnsembleTestConfig(profiles: {
                'a': TestProfile(),
                'b': TestProfile()
              }, devices: [
                TestDeviceTarget(
                    id: 'ios', platform: 'ios', model: 'iPhone 15 Pro'),
                TestDeviceTarget(
                    id: 'android',
                    platform: 'android',
                    model: 'Samsung Galaxy S20')
              ])),
      dimensions: {'profiles': 2, 'scenarios': 2, 'devices': 2},
      verify: (r) => require(
          (r as EnsembleTestExecutionPlan).ordered.length == 8,
          'Matrix expansion incomplete')));
  for (final count in [10, 100]) {
    cases.add(BenchmarkCase(
        'planner.dependency-chain.$count',
        'planner',
        () => EnsembleTestExecutionPlanner.buildForTest(assetContents: {
              for (var i = 0; i < count; i++)
                'suite/tests/$i.test.yaml': jsonEncode({
                  'id': 'chain_$i',
                  if (i > 0) 'session': 'chain_${i - 1}',
                  'steps': [
                    {
                      'pump': {'durationMs': 0}
                    }
                  ]
                })
            }),
        dimensions: {'files': count, 'edges': count - 1},
        verify: (r) => require(
            (r as EnsembleTestExecutionPlan).ordered.length == count,
            'Dependency ordering lost tests')));
  }
  cases.add(BenchmarkCase('parser.malformed', 'parser', () async {
    try {
      EnsembleTestParser.parseString('id: [');
    } catch (error) {
      return error;
    }
    return null;
  },
      dimensions: {'expectedOutcome': 'parse-error'},
      verify: (r) => require(r != null, 'Malformed input accepted')));
  cases.add(uiCase('assertion.legacy.visibility', 'assertion', () async {
    f.session.assertions.expectVisible('target');
    f.session.assertions.expectNotVisible('absent');
    return true;
  }, verify: (r) => require(r == true, 'Legacy visibility')));
  cases.add(uiCase('observer.suggested-locators', 'observer', () async {
    final o = await f.session.observe(
        options: const ObservationOptions(
            synchronization: ObservationSynchronization.immediate));
    return enrichSuggestedLocators(
        observation: o,
        resolver: f.session.resolver,
        registry: f.session.registry);
  },
      verify: (r) => require((r as UiObservation).elements.isNotEmpty,
          'Suggested locators missing')));
  cases.add(BenchmarkCase('observer.step-artifact', 'observer', () async {
    await captureStepObserverBestEffort(
        session: f.session, executor: f.session.executor, stepIndex: 0);
    return f.context.runtime.stepObservers.length;
  }, prepare: () async {
    await f.prepare(screenshots: true);
    f.context.runtime.addScreenshotSheetFrame(ScreenshotSheetFrame(
        stepIndex: 0, label: 'paired', image: f.capture()));
  }, cleanup: () async {
    for (final frame in f.context.runtime.screenshotSheetFrames)
      frame.image.dispose();
    await f.cleanup();
  }, verify: (r) => require(r == 1, 'Step observer missing')));
  cases.add(uiCase(
      'diagnostic.dump',
      'diagnostic',
      () => f.tester.runAsync(() => writeDumpTreeLogFile(
          logger: f.context.logger, filePrefix: 'fixture')),
      verify: (r) => require(r is String, 'Debug dump missing')));
  cases.add(BenchmarkCase(
      'parser.config',
      'parser',
      () async => EnsembleTestParser.parseConfigString(
          'screenshots:\n  enabled: true\n'),
      verify: (r) => require((r as EnsembleTestConfig).screenshots.enabled,
          'Config parse failed')));
  cases.add(BenchmarkCase('tools.config-schema', 'tools',
      () async => EnsembleTestSchemaBuilder.buildConfig(),
      verify: (r) => require(
          (r as Map).containsKey('properties'), 'Config schema missing')));
  cases.add(BenchmarkCase(
      'report.failure',
      'report',
      () async =>
          TestReporter().formatFailureSummary(EnsembleTestRunResult(results: [
            EnsembleSingleTestResult.failed(
                testId: 'fixture', durationMs: 0, message: 'Expected error')
          ])),
      verify: (r) => require(
          (r as String).contains('fixture'), 'Failure report missing')));
  cases.add(BenchmarkCase(
      'mock.extends-merge',
      'mock',
      () => MockComposition.resolveFile(
          testAssetPath: 'suite/test.test.yaml',
          mockFilePath: 'child.mock.json',
          assetLoader: (path) async => jsonEncode(path == 'base.mock.json'
              ? {
                  'api': {
                    'body': {'value': 1}
                  }
                }
              : {
                  r'$extends': 'base.mock.json',
                  'api': {
                    r'$merge': {'body.value': 2}
                  }
                }),
          resolveAssetPath: (from, relative) => relative),
      verify: (r) => require(
          (r as Map)['api']['body']['value'] == 2, 'Mock merge failed')));
  cases.add(BenchmarkCase('workflow.standalone-screenshots', 'workflow',
      () async {
    final harness = EnsembleTestHarness(
        appPath:
            '${mode == 'integration' ? 'packages/ensemble_test_runner/' : ''}tool/benchmarks/fixtures/ensemble/apps/demo/',
        appHome: 'Home');
    const test =
        EnsembleTestCase(id: 'standalone_capture', startScreen: 'Home', steps: [
      TestStep(
          type: 'expectVisible', args: {'id': 'target', 'timeoutMs': 5000}),
      TestStep(type: 'tap', args: {'id': 'target'}),
      TestStep(
          type: 'waitForText', args: {'text': 'Welcome', 'timeoutMs': 100}),
      TestStep(
          type: 'waitForNavigation', args: {'screen': 'Home', 'timeoutMs': 100})
    ]);
    final previous = LiveAsyncCallSupport.runner;
    LiveAsyncCallSupport.runner = f.tester.runAsync;
    try {
      return await EnsembleTestRunner(harness: harness).runPlan(
          const EnsembleTestExecutionPlan(
              ordered: [
                EnsembleTestDefinition(assetPath: 'fixture', testCase: test)
              ],
              config: EnsembleTestConfig(
                  screenshots: ScreenshotConfig(enabled: true))),
          f.tester);
    } finally {
      LiveAsyncCallSupport.runner = previous;
    }
  },
      kind: 'workflow',
      verify: (r) => require(
          (r as EnsembleTestPlanRunResult)
                  .resultsById['standalone_capture']!
                  .status ==
              TestStatus.passed,
          r.resultsById['standalone_capture']!.message ??
              'Standalone capture workflow failed')));
  cases.add(BenchmarkCase(
      'diagnostic.screen-performance',
      'diagnostic',
      () async => buildScreenPerformanceJson(
          screenName: 'fixture', frames: const [], markers: const []),
      dimensions: {'synthetic': true},
      verify: (r) =>
          require((r as Map)['totalFrames'] == 0, 'Synthetic summary wrong')));
  cases.add(uiCase('execution.text-contains', 'execution', () async {
    await f.session.executor.waitForTextContains(text: 'Wel', timeoutMs: 100);
    return true;
  }, verify: (r) => require(r == true, 'Text containment wait failed')));
  cases.add(BenchmarkCase('screenshot.navigation-pairing', 'screenshot',
      () async {
    var captured = false;
    const step = TestStep(
      type: 'waitForNavigation',
      args: {'screen': 'Home', 'timeoutMs': 100},
    );
    f.session.executor.onEvidenceBoundary = (step) async {
      captured = await const TestVisualArtifacts(
        screenshotSheets: _noScreenshotSheets,
        drainFlutterExceptions: _drainNothing,
      ).captureWaitForNavigationScreenshot(
        executor: f.session.executor,
        step: step,
        stepIndex: 0,
      );
    };
    await NavigationWaiter(
      tester: f.tester,
      context: f.context,
      navigation: f.session.executor.services.navigation,
      config: f.session.executor.config,
    ).waitForNavigation(
      screen: 'Home',
      timeoutMs: 100,
      onMatched: () => f.session.executor.emitEvidenceBoundary(step),
    );
    return captured;
  },
      prepare: () => f.prepareRuntime(mode, screenshots: true),
      cleanup: f.cleanup,
      kind: 'workflow',
      dimensions: {'capturePolicy': 'navigation-matched'},
      verify: (r) => require(
          r == true && f.context.runtime.screenshotSheetFrames.isNotEmpty,
          'Navigation screenshot missing')));
  cases.add(BenchmarkCase(
    'execution.navigation-live-call-drain',
    'execution',
    () async {
      final previousRunner = LiveAsyncCallSupport.runner;
      final releaseLiveCall = Completer<void>();
      LiveAsyncCallSupport.runner = f.tester.runAsync;
      try {
        final liveCall = LiveAsyncCallSupport.run<void>(
          () => releaseLiveCall.future,
        );
        var boundedDrainExpired = false;
        try {
          try {
            await NavigationWaiter(
              tester: f.tester,
              context: f.context,
              navigation: f.session.executor.services.navigation,
              config: f.session.executor.config,
            ).waitForNavigation(
              screen: 'Profile',
              timeoutMs: 20,
            );
          } on EnsembleTestFailure catch (error) {
            boundedDrainExpired =
                error.message.contains('bounded live-call drain expired');
            if (!boundedDrainExpired) rethrow;
          }
        } finally {
          if (!releaseLiveCall.isCompleted) releaseLiveCall.complete();
          await liveCall;
        }
        // Warmups deliberately run outside the measurement zone, so only
        // assert the behavior here. The catalogue contract test separately
        // verifies that the measured workload emits its drain span.
        return boundedDrainExpired;
      } finally {
        LiveAsyncCallSupport.runner = previousRunner;
      }
    },
    prepare: () => f.prepareRuntime(mode),
    cleanup: f.cleanup,
    quick: true,
    kind: 'workflow',
    dimensions: const {'pendingLiveCalls': 1, 'drain': 'bounded-expiry'},
    verify: (result) => require(
      result == true,
      'Navigation did not expire its bounded live-call drain',
    ),
  ));
  for (final diagnostic in [false, true]) {
    cases.add(BenchmarkCase(
        'observer.routes-modal.${diagnostic ? 'diagnostic' : 'session'}',
        'observer',
        () async {
          if (diagnostic)
            return captureDiagnosticUiSnapshot(
                    tester: f.tester,
                    assertions: f.session.assertions,
                    navigation: f.navigation)
                .observation;
          return f.session.observe(
              options: const ObservationOptions(
                  synchronization: ObservationSynchronization.immediate));
        },
        prepare: () async {
          await f.prepare();
          final navigator = Navigator.of(
              f.tester.element(find.byKey(const ValueKey('target'))));
          navigator.push<void>(MaterialPageRoute(
              builder: (_) => const Scaffold(
                  body: Text('Second route', key: ValueKey('second_route')))));
          await settleBenchmarkFixture(f.tester);
          unawaited(showDialog<void>(
              context:
                  f.tester.element(find.byKey(const ValueKey('second_route'))),
              builder: (_) => const AlertDialog(
                  content:
                      Text('Modal target', key: ValueKey('modal_target')))));
          await settleBenchmarkFixture(f.tester);
        },
        cleanup: f.cleanup,
        dimensions: {'routes': 2, 'modal': true, 'nodes': 40},
        verify: (r) {
          final elements =
              flattenElements((r as UiObservation).elements).toList();
          require(elements.any((e) => e.testId == 'modal_target'),
              'Modal target missing');
          require(
              !elements
                  .any((e) => e.testId == 'target' && e.state.visible == true),
              'Inactive route leaked as visible');
        }));
  }
  cases.add(uiCase(
      'screenshot.frames.changed',
      'screenshot',
      () async {
        final frames = [
          ScreenshotSheetFrame(
              stepIndex: 0, label: 'before', image: f.capture())
        ];
        await f.tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: Text('Changed frame'))));
        await f.tester.pump();
        frames.add(ScreenshotSheetFrame(
            stepIndex: 1, label: 'after', image: f.capture()));
        final path = await f.tester.runAsync<String?>(() =>
            writeScreenshotFrames(
                testId: 'changed_frames',
                config: const ScreenshotConfig(enabled: true),
                frames: frames,
                status: TestStatus.passed));
        return path;
      },
      kind: 'workflow',
      dimensions: {'frames': 2, 'identical': false},
      verify: (r) {
        require(r is String, 'Changed frame manifest missing');
        // Device artifacts are verified by their complete checksummed transport.
        if (mode == 'widget') {
          final entries = (jsonDecode(File(r as String).readAsStringSync())
              as Map)['frames'] as List;
          require(
              entries.length == 2 && entries[0]['file'] != entries[1]['file'],
              'Changed pixels were incorrectly deduplicated');
        }
      }));
  for (final count in [10, 1000]) {
    cases.add(uiCase('assertion.list-size.$count', 'assertion', () async {
      f.session.assertions.expectListCountFinder(
          find.byKey(const ValueKey('list')),
          expected: count,
          itemFinder: find.byWidgetPredicate((widget) =>
              widget is Text &&
              widget.key is ValueKey<String> &&
              (widget.key as ValueKey<String>).value.startsWith('node_')));
      f.session.assertions
          .expectListContains(listId: 'list', text: 'Item ${count - 1}');
      RunnerBenchmark.count('items', count);
      return true;
    },
        nodes: count,
        dimensions: {'items': count},
        verify: (r) => require(r == true, 'List assertion failed')));
    cases.add(BenchmarkCase(
        'planner.dependency-fanout.$count',
        'planner',
        () => EnsembleTestExecutionPlanner.buildForTest(assetContents: {
              for (var i = 0; i < count; i++)
                'suite/tests/$i.test.yaml': jsonEncode({
                  'id': 'fan_$i',
                  if (i > 0) 'session': 'fan_0',
                  'steps': [
                    {
                      'pump': {'durationMs': 0}
                    }
                  ]
                })
            }),
        dimensions: {'files': count, 'edges': count - 1, 'shape': 'fanout'},
        verify: (r) => require(
            (r as EnsembleTestExecutionPlan).ordered.first.testCase.id ==
                    'fan_0' &&
                r.ordered.length == count,
            'Fanout dependencies were not ordered')));
    final richResult = EnsembleTestRunResult(results: [
      EnsembleSingleTestResult.passed(
          testId: 'rich',
          durationMs: 1,
          report: EnsembleTestReportDetails(
              startScreen: 'Home',
              stepsOutline: [for (var i = 0; i < count; i++) '$i. tap target'],
              stepDurationsMs: List.filled(count, 1),
              screens: {
                for (var i = 0; i < count; i++)
                  'Screen$i': {
                    'debugTree': 'debug/$i.txt',
                    'screenshot': 'screenshots/$i.png'
                  }
              }))
    ]);
    cases.add(BenchmarkCase('report.rich.$count', 'report', () async {
      final compact = ReportJsonOptimizer.optimize(
          TestReportDocument.buildComplete(richResult,
              artifactRoot: f.root.path, displayRoot: f.root.path));
      final expanded = ReportJsonOptimizer.expand(compact);
      await HtmlTestReporter().write(richResult, artifactRoot: f.root.path);
      RunnerBenchmark.count('steps', count);
      RunnerBenchmark.count('artifactReferences', count * 2);
      return expanded;
    },
        dimensions: {
          'tests': 1,
          'steps': count,
          'artifactReferences': count * 2
        },
        verify: (r) => require(
            (r as Map)['tests'] is List &&
                ((r['tests'] as List).single['report']['stepsOutline']
                            as List)
                        .length ==
                    count &&
                ((r['tests'] as List).single['report']['screens'] as Map)
                        .length ==
                    count &&
                File('${f.root.path}/report/index.html').existsSync(),
            'Rich report output missing')));
  }
  for (final variant in ['duplicate', 'malformed', 'checksum']) {
    cases.add(BenchmarkCase('artifact.stream.$variant', 'artifact', () async {
      final lines = <String>[];
      runZoned(() {
        final emitter = EnsembleTestArtifactEmitter.instance;
        emitter.resetForTest();
        emitter.emitArtifact('payload.bin',
            Uint8List.fromList(List.generate(1024, (i) => i % 256)),
            mimeType: 'application/octet-stream');
        if (variant == 'duplicate')
          emitter.emitArtifact('payload.bin',
              Uint8List.fromList(List.generate(1024, (i) => i % 256)),
              mimeType: 'application/octet-stream');
        emitter.complete();
      },
          zoneSpecification:
              ZoneSpecification(print: (_, __, ___, line) => lines.add(line)));
      if (variant == 'malformed')
        lines.insert(1, '${ensembleTestArtifactProtocolPrefix}{bad json');
      if (variant == 'checksum') {
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (!line.startsWith(ensembleTestArtifactProtocolPrefix)) continue;
          final record = jsonDecode(
                  line.substring(ensembleTestArtifactProtocolPrefix.length))
              as Map<String, dynamic>;
          if (record['event'] == 'start') {
            record['sha256'] = 'wrong';
            lines[i] =
                '$ensembleTestArtifactProtocolPrefix${jsonEncode(record)}';
          }
        }
      }
      return f.tester.runAsync(() => materializeTransportedArtifacts(
          artifactRoot: '${f.root.path}/received_$variant',
          output: lines.join('\n')));
    },
        dimensions: {
          'bytes': 1024,
          'variant': variant,
          'expectedOutcome': variant == 'duplicate' ? 'success' : 'error'
        },
        verify: (r) => require(
            (r as ArtifactTransportResult).complete == (variant == 'duplicate'),
            'Unexpected $variant transport outcome: ${r.error}')));
  }
  cases.add(BenchmarkCase('history.existing', 'history', () async {
    await f.tester.runAsync(() => EnsembleTestHistoryStore.recordCompletedRun(
        appDir: f.root.path,
        artifactRoot: f.root.path,
        result: fixtureResults(1000)));
    return true;
  }, prepare: () async {
    final db = File('${f.root.path}/report/ensemble_test.db');
    if (db.existsSync()) db.deleteSync();
    await f.tester.runAsync(() async {
      for (var i = 0; i < 10; i++)
        await EnsembleTestHistoryStore.recordCompletedRun(
            appDir: f.root.path,
            artifactRoot: f.root.path,
            result: fixtureResults(10));
    });
  },
      dimensions: {'existingRuns': 10, 'newTests': 1000},
      verify: (r) => require(r == true, 'Existing history insertion failed')));

  for (final count in [10, 1000]) {
    cases.add(BenchmarkCase('assertion.api-count.$count', 'assertion',
        () async {
      f.session.assertions.expectApiCalled('auth', count);
      RunnerBenchmark.count('apiEntries', count);
      return true;
    }, prepare: () async {
      await f.prepare();
      final call = f.context.apiOverlay.calls.first;
      f.context.apiOverlay.calls
        ..clear()
        ..addAll(List.filled(count, call));
    },
        cleanup: f.cleanup,
        dimensions: {'apiEntries': count},
        verify: (r) => require(r == true, 'API count assertion failed')));
    cases.add(BenchmarkCase('diagnostic.console.$count', 'diagnostic',
        () => f.tester.runAsync(() => writeAppConsoleLog(f.context)),
        prepare: () async {
          await f.prepare();
          f.context.runtime.consoleLogs
              .addAll([for (var i = 0; i < count; i++) 'fixture entry $i']);
          f.context.runtime.flutterErrors
              .addAll(List.filled(count, 'Synthetic error'));
        },
        cleanup: f.cleanup,
        dimensions: {'consoleEntries': count, 'errorEntries': count},
        verify: (r) => require(r is String, 'Console log missing')));
    final keys = {for (var i = 0; i < count; i++) 'key$i': i};
    cases.add(uiCase(
        'diagnostic.storage.$count',
        'diagnostic',
        () => f.tester.runAsync(() => writeStorageLogFile(
            logger: f.context.logger, filePrefix: 'fixture', keys: keys)),
        dimensions: {'keys': count},
        verify: (r) => require(r is String, 'Storage log missing')));
  }
  for (final count in [10, 1000]) {
    final results = fixtureResults(count);
    cases.add(BenchmarkCase('report.raw-serialize.$count', 'report',
        () async => jsonEncode(results.toJson()),
        dimensions: {'tests': count},
        verify: (r) => require(
            (jsonDecode(r as String)['results'] as List).length == count,
            'Raw serialization lost results')));
  }
  cases.add(BenchmarkCase(
      'observer.secure-field',
      'observer',
      () => f.session.observe(
          options: const ObservationOptions(
              synchronization: ObservationSynchronization.immediate)),
      prepare: () async {
        await f.prepare();
        f.controller.text = 'fixture_private_credential';
        await f.tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: TextField(
                    key: const ValueKey('target'),
                    controller: f.controller,
                    obscureText: true))));
        await settleBenchmarkFixture(f.tester);
      },
      cleanup: f.cleanup,
      dimensions: {'secureField': true},
      verify: (r) {
        final observation = r as UiObservation;
        require(
            flattenElements(observation.elements)
                .any((e) => e.testId == 'target' && e.state.secure == true),
            'Secure input missing');
        require(
            !jsonEncode(observation.toJson())
                .contains('fixture_private_credential'),
            'Secure value leaked into observation');
      }));
  checkCatalogue(cases);
  return cases;
}

ExecutionPlan _kernelDispatchBenchmarkPlan() {
  const operations = 100;
  final nodes = <String, PlanNode>{};
  for (var index = 0; index < operations; index++) {
    final id = 'operation_$index';
    nodes[id] = OperationNode(
      id,
      TestOperation(
        id: id,
        name: 'noop',
        kind: OperationKind.interaction,
        handlerKey: 'noop',
        input: const {},
        source: const SourceLocation('benchmark', 'step'),
      ),
      index + 1 == operations ? 'end' : 'operation_${index + 1}',
    );
  }
  nodes['end'] = const EndNode('end');
  return ExecutionPlan(
      id: 'kernel_dispatch', start: 'operation_0', nodes: nodes);
}

final class _KernelBenchmarkRuntime implements TestRuntime {
  @override
  final RuntimeCapabilities capabilities = RuntimeCapabilities(const {'noop'});

  @override
  Future<RuntimeView> observe(ObservationRequest request) async => RuntimeView(
        revision: 0,
        level: request.level,
        target: request.target,
        targetVisible: true,
      );

  @override
  Future<OperationResult> execute(TestOperation operation) async =>
      const OperationResult.success();

  @override
  Future<void> close() async {}
}

// Setup for the contrast component deliberately occurs outside measured work.
extension on BenchmarkCase {
  BenchmarkCase prepareOverride(BenchmarkFixtures f) =>
      BenchmarkCase(id, service, body, prepare: () async {
        await f.prepare();
        f.image = f.capture();
      },
          cleanup: cleanup,
          quick: quick,
          dimensions: dimensions,
          verify: verify,
          kind: kind);
}

String _serviceForStep(String name) =>
    switch (TestStepRegistry.entries[name]!.category) {
      TestStepCategory.uiAssertion ||
      TestStepCategory.valueAssertion ||
      TestStepCategory.listAssertion ||
      TestStepCategory.apiAssertion ||
      TestStepCategory.quality =>
        'assertion',
      TestStepCategory.lifecycle => 'lifecycle',
      TestStepCategory.debug => 'diagnostic',
      _ => 'execution',
    };

String? _stepPrerequisite(String name, String mode) => null;

Map<String, dynamic> stepArgs(String name) {
  final args =
      Map<String, dynamic>.from(TestStepRegistry.entries[name]!.example);
  if (args.containsKey('id')) args['id'] = 'target';
  if (args.containsKey('itemId')) args['itemId'] = 'target';
  args['timeoutMs'] = 20;
  switch (name) {
    case 'wait':
    case 'pump':
      return {'durationMs': 0};
    case 'waitForGone':
    case 'expectNotVisible':
    case 'expectNotExists':
      return {'id': 'absent', 'timeoutMs': 20};
    case 'expectNoText':
      return {'text': 'absent'};
    case 'expectText':
    case 'expectTextContains':
    case 'waitForText':
      return {'text': 'Welcome'};
    case 'expectValue':
      return {'id': 'target', 'equals': 'value'};
    case 'expectCount':
      return {'id': 'target', 'equals': 1};
    case 'expectProperty':
    case 'expectStyle':
      return {'id': 'title', 'property': 'label', 'equals': 'Welcome'};
    case 'expectNotVisited':
      return {'screen': 'absent'};
    case 'expectBackStack':
      return {
        'screens': ['Home']
      };
    case 'expectApiNotCalled':
      return {'name': 'absent'};
    case 'expectStorage':
      return {'key': 'key', 'equals': true};
    case 'setStorage':
    case 'removeStorage':
      return {'key': 'key', 'value': true};
    case 'trigger':
      return {'id': 'target', 'action': 'onTap'};
    case 'openScreen':
      return {'screen': 'Other'};
    case 'setDevice':
      return {'width': 800, 'height': 600};
    case 'setTheme':
      return {'mode': 'light'};
    case 'chooseTime':
      return {'id': 'target', 'value': '12:30'};
    case 'select':
      return {'id': 'target', 'value': 'B'};
    case 'expectSemanticsLabel':
      return {'id': 'target', 'label': 'Hello'};
    case 'expectEmpty':
      return {'id': 'emptyList'};
    case 'expectNotEmpty':
      return {'id': 'list'};
    case 'expectListCount':
      return {'id': 'list', 'itemId': 'title', 'equals': 1};
    case 'expectListContains':
      return {'id': 'list', 'text': 'Welcome'};
    case 'group':
    case 'repeat':
    case 'optional':
    case 'ifVisible':
      return {
        'id': 'target',
        'times': 2,
        'name': 'fixture',
        'steps': [
          {
            'pump': {'durationMs': 0}
          }
        ]
      };
    case 'scroll':
      return {'delta': 10};
    case 'swipe':
      return {'id': 'list', 'direction': 'up'};
    case 'pullToRefresh':
      return {'id': 'list'};
    default:
      return args;
  }
}

EnsembleTestRunResult fixtureResults(int count) =>
    EnsembleTestRunResult(results: [
      for (var i = 0; i < count; i++)
        EnsembleSingleTestResult.passed(testId: 'test_$i', durationMs: i)
    ]);

Future<void> prepareProject(Directory root) async {
  File('${root.path}/pubspec.yaml').writeAsStringSync(
      'name: benchmark_fixture\nflutter:\n  assets:\n    - ensemble/\n');
  Directory('${root.path}/ensemble').createSync(recursive: true);
  File('${root.path}/ensemble/ensemble-config.yaml').writeAsStringSync(
      'definitions:\n  from: local\n  local:\n    path: ensemble/apps/demo\n    appHome: Home\n');
  final screens = Directory('${root.path}/ensemble/apps/demo/screens')
    ..createSync(recursive: true);
  File('${screens.path}/Home.yaml').writeAsStringSync(
      'View:\n  body:\n    Text:\n      id: title\n      text: Welcome\n');
  final oldTests = Directory('${root.path}/ensemble/apps/demo/tests');
  if (oldTests.existsSync()) oldTests.deleteSync(recursive: true);
  final tests = Directory('${root.path}/ensemble/apps/demo/tests')
    ..createSync(recursive: true);
  for (var i = 0; i < 8; i++)
    File('${tests.path}/$i.test.yaml').writeAsStringSync(jsonEncode({
      'id': 'test_$i',
      'startScreen': 'Home',
      'steps': [
        {
          'pump': {'durationMs': 0}
        }
      ]
    }));
}

class FixtureDriver implements ApplicationTestDriver {
  FixtureDriver(this.fixtures, {this.failFirstLaunch = false});
  final BenchmarkFixtures fixtures;
  final bool failFirstLaunch;
  int launches = 0;
  @override
  Future<void> setUpSuite(TestSuiteContext context) async {}
  @override
  Future<void> prepareTest(TestLaunchContext context) async {}
  @override
  Future<TestApplicationHandle> launch(
      WidgetTester tester, TestLaunchContext context) async {
    if (failFirstLaunch && launches++ == 0)
      throw StateError('Expected benchmark launch failure');
    await fixtures.prepare();
    return FixtureHandle(ApplicationTestServices(
        storage: fixtures.storage,
        navigation: fixtures.navigation,
        api: fixtures.api));
  }

  @override
  Future<void> tearDownTest(WidgetTester tester, TestLaunchContext context,
      TestApplicationHandle? handle) async {
    if (handle != null) await fixtures.cleanup();
  }

  @override
  Future<void> tearDownSuite() async {}
}

class FixtureHandle implements TestApplicationHandle {
  FixtureHandle(this.services);
  @override
  final ApplicationTestServices services;
}

Iterable<UiElement> flattenElements(List<UiElement> elements) sync* {
  for (final e in elements) {
    yield e;
    yield* flattenElements(e.children);
  }
}

void checkCatalogue(List<BenchmarkCase> cases) {
  final ids = cases.map((c) => c.id).toSet();
  if (ids.length != cases.length)
    throw StateError('Duplicate benchmark case IDs');
  final required = {
    for (final step in coveredSteps) 'step.$step',
    ...subsystemCases.values.expand((ids) => ids),
    ...capabilityCases.values.expand((ids) => ids),
    ...operationCases.values
  };
  final missing = required.difference(ids);
  if (missing.isNotEmpty)
    throw StateError('Missing benchmark catalogue coverage: $missing');
}
