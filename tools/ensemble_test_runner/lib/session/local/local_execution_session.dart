import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'dart:ui' as ui;

import 'package:ensemble/ensemble.dart';
import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/actions/action_result.dart';
import 'package:ensemble_test_runner/session/actions/artifact_request.dart';
import 'package:ensemble_test_runner/session/operation_result.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/flutter_ui_observer.dart';
import 'package:ensemble_test_runner/session/local/flutter_target_resolver.dart';
import 'package:ensemble_test_runner/session/local/leaf_command_queue.dart';
import 'package:ensemble_test_runner/session/local/local_action_executor.dart';
import 'package:ensemble_test_runner/session/local/local_session_policy.dart';
import 'package:ensemble_test_runner/session/local/local_session_wait_operations.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/session/test_execution_session.dart';
import 'package:ensemble_test_runner/src/core/operation.dart'
    show OperationKind, TestOperation;
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart'
    show operationRegistry;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Local [TestExecutionSession] over [WidgetTester].
///
/// - [attach]: suite-owned; [close] clears session-local resources only.
/// - [standalone]: factory-owned bootstrap context; [close] also resets
///   overlay/runtime state created for that session.
///
/// [harness] is optional — pure Flutter / host suites attach with
/// [ApplicationTestServices] only. Ensemble lifecycle steps still require a
/// harness when invoked.
///
/// Leaf UI work delegates to a shared [TestStepExecutor] (same instance the
/// test runner uses for privileged/lifecycle steps and screenshot hooks).
class LocalTestExecutionSession implements TestExecutionSession {
  LocalTestExecutionSession._({
    required this.sessionId,
    required this.tester,
    required this.context,
    required SessionPermissions permissions,
    required this.assertions,
    required this.executor,
    required this.ownsBootstrap,
    this.harness,
    this.services = const ApplicationTestServices(),
  })  : policy = LocalSessionPolicy(
          services: services,
          harness: harness,
          permissions: permissions,
        ),
        registry = ObservationRegistry(),
        queue = LeafCommandQueue(),
        _artifactStore = <String, Uint8List>{} {
    observer = FlutterUiObserver(
      tester: tester,
      assertions: assertions,
      registry: registry,
      nextObservationId: _nextObservationId,
      currentRevision: () => _revision,
      lastFingerprint: () => _lastFingerprint,
      markRevision: (revision, fingerprint) {
        _revision = revision;
        _lastFingerprint = fingerprint;
      },
      navigation: services.navigation,
    );
    resolver = FlutterTargetResolver(
      tester: tester,
      assertions: assertions,
      registry: registry,
      liveFingerprint: observer.liveFingerprintFor,
      currentRevision: () => _revision,
    );
    actionExecutor =
        LocalActionExecutor(executor: executor, resolver: resolver);
    executor.resolveTargetFinder = (
      target, {
      bool requireInteractive = true,
      bool allowEmpty = false,
      bool allowOffscreen = false,
    }) =>
        resolver.resolveFinder(
          target,
          requireInteractive: requireInteractive,
          allowEmpty: allowEmpty,
          allowOffscreen: allowOffscreen,
        );
  }

  /// Attach to a launched application (suite mode).
  ///
  /// Creates the assertion and step-execution services when callers do not
  /// supply them. Host suites omit [harness] and supply [services] from the
  /// launch handle.
  factory LocalTestExecutionSession.attach({
    required WidgetTester tester,
    required EnsembleTestContext context,
    EnsembleTestHarness? harness,
    ApplicationTestServices services = const ApplicationTestServices(),
    String? sessionId,
    SessionPermissions? permissions,
    EnsembleConfig? config,
    TestExecutionConfig? executionConfig,
    AssertionEngine? assertions,
    TestStepExecutor? executor,
  }) {
    final sharedAssertions = assertions ??
        AssertionEngine(
          tester: tester,
          context: context,
          services: services,
        );
    final sharedExecutor = executor ??
        TestStepExecutor(
          tester: tester,
          context: context,
          assertions: sharedAssertions,
          harness: harness,
          services: services,
          config: config,
          executionConfig: executionConfig,
        );
    return LocalTestExecutionSession._(
      sessionId: sessionId ?? 'suite_${DateTime.now().microsecondsSinceEpoch}',
      tester: tester,
      harness: harness,
      context: context,
      services: services,
      permissions: permissions ?? SessionPermissions.testController,
      assertions: sharedAssertions,
      executor: sharedExecutor,
      ownsBootstrap: false,
    );
  }

  /// Factory-owned session (standalone create). [close] resets bootstrap state.
  factory LocalTestExecutionSession.standalone({
    required WidgetTester tester,
    required EnsembleTestHarness harness,
    required EnsembleTestContext context,
    required AssertionEngine assertions,
    required TestStepExecutor executor,
    ApplicationTestServices services = const ApplicationTestServices(),
    String? sessionId,
    SessionPermissions? permissions,
  }) {
    return LocalTestExecutionSession._(
      sessionId:
          sessionId ?? 'standalone_${DateTime.now().microsecondsSinceEpoch}',
      tester: tester,
      harness: harness,
      context: context,
      services: services,
      permissions: permissions ?? SessionPermissions.restrictedUi,
      assertions: assertions,
      executor: executor,
      ownsBootstrap: true,
    );
  }

  @override
  final String sessionId;

  final WidgetTester tester;
  final EnsembleTestHarness? harness;
  final EnsembleTestContext context;
  final ApplicationTestServices services;

  /// True when created via [standalone] — owns overlay/runtime cleanup.
  final bool ownsBootstrap;

  final AssertionEngine assertions;
  final TestStepExecutor executor;
  final ObservationRegistry registry;
  final LeafCommandQueue queue;
  final LocalSessionPolicy policy;

  /// Permissions remain exposed at the session boundary for operation
  /// handlers; the policy owns the underlying authorization rules.
  SessionPermissions get permissions => policy.permissions;

  final Map<String, Uint8List> _artifactStore;
  late final FlutterTargetResolver resolver;
  late final LocalActionExecutor actionExecutor;
  late final LocalSessionWaitOperations waitOperations =
      LocalSessionWaitOperations(
    tester: tester,
    context: context,
    executor: executor,
    policy: policy,
    resolver: resolver,
    queue: queue,
    ensureOpen: _ensureOpen,
    nextOperationId: (prefix) => '${prefix}_${_actionSeq++}',
    mapExecutorFailure: mapExecutorFailure,
  );
  late final FlutterUiObserver observer;

  int _revision = 0;
  int _observationSeq = 0;
  int _actionSeq = 0;
  String? _lastFingerprint;
  bool _closed = false;

  /// Capabilities derived from available application services + UI registry.
  SessionCapabilities get capabilities => policy.capabilities;

  /// Local adapter capabilities derived from the step registry.
  static SessionCapabilities get localCapabilities => SessionCapabilities.local;

  String _nextObservationId() => 'obs_${_observationSeq++}';

  /// PNG bytes for a previously captured [TestArtifact.artifactId], if retained.
  Uint8List? artifactBytes(String artifactId) => _artifactStore[artifactId];

  void _ensureOpen() {
    if (_closed) {
      throw const TestExecutionError(
        code: TestExecutionErrorCode.executionUnavailable,
        message: 'Session is closed.',
      );
    }
  }

  @override
  Future<SessionCapabilities> getCapabilities() async {
    _ensureOpen();
    return capabilities;
  }

  @override
  Future<UiObservation> observe({
    ObservationOptions options = const ObservationOptions(),
  }) {
    return RunnerBenchmark.future('session', 'observe', () {
      _ensureOpen();
      // Mid-wait / mid-act screenshot callbacks already hold [queue]. Nesting
      // another [queue.run] deadlocks the worker. Observe is a read-only snapshot.
      if (queue.isBusy) {
        return observer.observe(options);
      }
      return queue.run(() => observer.observe(options));
    });
  }

  @override
  Future<ActionResult> act(TestOperation operation) => _act(operation);

  Future<ActionResult> _act(TestOperation operation) {
    return RunnerBenchmark.future('session', 'act', () {
      _ensureOpen();
      final descriptor = operationRegistry.requireDescriptor(
        operation,
        expectedKind: OperationKind.interaction,
      );
      return queue.run(() async {
        resolver.invalidateResolvedFinders();
        final actionId = 'action_${_actionSeq++}';
        final before = _revision;
        final sw = Stopwatch()..start();
        try {
          policy.ensureActionNamePermitted(descriptor.name);
          await actionExecutor.execute(operation);
          await observer.syncRevisionAfterMutation();
          return ActionResult(
            actionId: actionId,
            status: ActionStatus.succeeded,
            beforeRevision: before,
            afterRevision: _revision,
            duration: sw.elapsed,
          );
        } on TestExecutionError catch (error) {
          await observer.syncRevisionAfterMutation();
          return ActionResult(
            actionId: actionId,
            status: ActionStatus.failed,
            beforeRevision: before,
            afterRevision: _revision,
            duration: sw.elapsed,
            error: error,
          );
        } on EnsembleTestFailure catch (error) {
          await observer.syncRevisionAfterMutation();
          final mapped = mapExecutorFailure(error);
          return ActionResult(
            actionId: actionId,
            status: mapped.code == TestExecutionErrorCode.actionTimeout
                ? ActionStatus.timedOut
                : ActionStatus.failed,
            beforeRevision: before,
            afterRevision: _revision,
            duration: sw.elapsed,
            error: mapped,
          );
        }
      });
    });
  }

  /// Maps executor [EnsembleTestFailure] into structured session errors,
  /// preserving the full diagnostic message.
  ///
  /// Tap/wait-for-id timeouts mean the widget never became available, so they
  /// classify as [TestExecutionErrorCode.elementNotFound] (or
  /// [TestExecutionErrorCode.elementNotInteractable] when it existed but was
  /// not hit-testable). Generic "timed out" is reserved for wait steps such as
  /// waitForApi / waitForNavigation.
  @visibleForTesting
  static TestExecutionError mapExecutorFailure(EnsembleTestFailure error) {
    final message = error.message;
    final lower = message.toLowerCase();
    final TestExecutionErrorCode code;
    if (lower.contains('not hit-testable') ||
        lower.contains('not interactable') ||
        lower.contains('to become hit-testable')) {
      code = TestExecutionErrorCode.elementNotInteractable;
    } else if (lower.contains('not found') ||
        lower.contains('could not find') ||
        lower.contains('is detached') ||
        lower.contains('not in the tree') ||
        lower.contains('waiting for id')) {
      code = TestExecutionErrorCode.elementNotFound;
    } else if (lower.contains('exactly one') ||
        lower.contains('ambiguous') ||
        lower.contains('multiple')) {
      code = TestExecutionErrorCode.ambiguousTarget;
    } else if (lower.contains('timed out')) {
      code = TestExecutionErrorCode.actionTimeout;
    } else {
      code = TestExecutionErrorCode.internalError;
    }
    return TestExecutionError(
      code: code,
      message: message,
      details: const {'source': 'TestStepExecutor'},
    );
  }

  @override
  Future<WaitResult> waitFor(TestOperation operation, {Duration? timeout}) =>
      waitOperations.waitFor(operation, timeout: timeout);

  @override
  Future<AssertionResult> assertCondition(TestOperation operation) {
    return RunnerBenchmark.future('session', 'assertCondition', () {
      _ensureOpen();
      final descriptor = operationRegistry.requireDescriptor(
        operation,
        expectedKind: OperationKind.assertion,
      );
      final domain = _assertionDomain(operation.name);
      return queue.run(() async {
        resolver.invalidateResolvedFinders();
        final assertionId = 'assert_${_actionSeq++}';
        try {
          _ensureAssertionDomainPermitted(domain);
          final handled = await executor.executeRegisteredAssertion(
            operation,
            descriptor: descriptor,
          );
          if (!handled) {
            throw EnsembleTestFailure(
              'Unknown test step: ${operation.name}. See STEP_VOCABULARY.md '
              'for supported steps.',
            );
          }
          await executor.emitOperationEvidenceBoundary(operation);
          return AssertionResult(
            assertionId: assertionId,
            status: AssertionStatus.passed,
          );
        } on TestExecutionError catch (error) {
          return AssertionResult(
            assertionId: assertionId,
            status: AssertionStatus.error,
            error: error,
          );
        } on EnsembleTestFailure catch (error) {
          final mapped = LocalTestExecutionSession.mapExecutorFailure(error);
          return AssertionResult(
            assertionId: assertionId,
            status: AssertionStatus.failed,
            message: mapped.message,
            error: mapped,
          );
        }
      });
    });
  }

  void _ensureAssertionDomainPermitted(String domain) {
    if (!policy.permissions.assertionDomains.contains(domain) ||
        !policy.capabilities.assertionDomains.contains(domain)) {
      throw TestExecutionError(
        code: TestExecutionErrorCode.permissionDenied,
        message: 'Not permitted to assert domain "$domain".',
        details: {'domain': domain},
      );
    }
  }

  String _assertionDomain(String name) {
    if (name.startsWith('expectApi')) return 'api';
    if (name.contains('Storage')) return 'storage';
    if (name.contains('Script') || name.contains('Console')) return 'script';
    if (name.contains('Screen') ||
        name.contains('Navigate') ||
        name.contains('Visited') ||
        name.contains('Back')) {
      return 'navigation';
    }
    if (name.contains('Error') ||
        name.contains('Overflow') ||
        name.contains('Accessible') ||
        name.contains('Semantics')) {
      return 'quality';
    }
    return 'ui';
  }

  @override
  Future<TestArtifact> captureArtifact(ArtifactRequest request) {
    return RunnerBenchmark.future('session', 'captureArtifact', () {
      _ensureOpen();
      return queue.run(() async {
        resolver.invalidateResolvedFinders();
        if (!policy.permissions.captureArtifacts || !capabilities.screenshots) {
          throw const TestExecutionError(
            code: TestExecutionErrorCode.permissionDenied,
            message: 'Not permitted to capture artifacts.',
          );
        }
        if (request.kind != 'screenshot') {
          throw TestExecutionError(
            code: TestExecutionErrorCode.unsupportedAction,
            message: 'Unsupported artifact kind "${request.kind}".',
          );
        }
        final image = ExtendedStepHandlers.captureScreenshotImage(tester);
        try {
          final byteData = await tester.runAsync(
            () => image.toByteData(format: ui.ImageByteFormat.png),
          );
          if (byteData == null) {
            throw const TestExecutionError(
              code: TestExecutionErrorCode.internalError,
              message: 'Failed to encode screenshot as PNG.',
            );
          }
          final bytes = byteData.buffer.asUint8List();
          final id = 'art_${sessionId}_${_actionSeq++}';
          _artifactStore[id] = bytes;
          return TestArtifact(
            artifactId: id,
            kind: 'screenshot',
            path: 'memory:$id',
            mimeType: 'image/png',
            byteLength: bytes.length,
          );
        } finally {
          image.dispose();
        }
      });
    });
  }

  @override
  Future<void> close() async {
    return await RunnerBenchmark.async('session', 'close', () async {
      if (_closed) return;
      _closed = true;
      queue.close();
      registry.clear();
      _artifactStore.clear();
      if (ownsBootstrap) {
        try {
          await context.navigationFlow.stopListening(clearHistory: true);
        } finally {
          context.apiOverlay.resetCalls();
          context.runtime.clear();
        }
      }
      // Suite-attached: do not dispose harness/tester.
    });
  }
}
