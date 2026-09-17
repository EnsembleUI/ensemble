import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/actions/action_result.dart';
import 'package:ensemble_test_runner/session/actions/artifact_request.dart';
import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/assertions/test_assertion.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/flutter_ui_observer.dart';
import 'package:ensemble_test_runner/session/local/leaf_command_queue.dart';
import 'package:ensemble_test_runner/session/local/local_action_executor.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/session/test_execution_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Local [TestExecutionSession] over [WidgetTester] + [EnsembleTestHarness].
///
/// - [attach]: suite-owned harness; [close] clears session-local resources only.
/// - [standalone]: factory-owned bootstrap context; [close] also resets
///   overlay/runtime state created for that session.
///
/// Leaf UI work delegates to a shared [TestStepExecutor] (same instance the
/// YAML runner uses for privileged/lifecycle steps and screenshot hooks).
class LocalTestExecutionSession implements TestExecutionSession {
  LocalTestExecutionSession._({
    required this.sessionId,
    required this.tester,
    required this.harness,
    required this.context,
    required this.permissions,
    required this.assertions,
    required this.executor,
    required this.ownsBootstrap,
  })  : registry = ObservationRegistry(),
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
    );
    resolver = FlutterTargetResolver(
      tester: tester,
      assertions: assertions,
      registry: registry,
      liveFingerprint: observer.liveFingerprintFor,
    );
    actionExecutor = LocalActionExecutor(
      executor: executor,
      resolver: resolver,
    );
  }

  /// Attach to a runner-owned harness (suite mode).
  ///
  /// Prefer passing the suite's [executor] and [assertions] so YAML leaf
  /// steps, privileged steps, and screenshot hooks share one execution path.
  factory LocalTestExecutionSession.attach({
    required WidgetTester tester,
    required EnsembleTestHarness harness,
    required EnsembleTestContext context,
    String? sessionId,
    SessionPermissions? permissions,
    TestExecutionConfig? executionConfig,
    AssertionEngine? assertions,
    TestStepExecutor? executor,
  }) {
    final sharedAssertions =
        assertions ?? AssertionEngine(tester: tester, context: context);
    final sharedExecutor = executor ??
        TestStepExecutor(
          tester: tester,
          context: context,
          assertions: sharedAssertions,
          harness: harness,
          executionConfig: executionConfig,
        );
    return LocalTestExecutionSession._(
      sessionId: sessionId ??
          'suite_${DateTime.now().microsecondsSinceEpoch}',
      tester: tester,
      harness: harness,
      context: context,
      permissions: permissions ?? SessionPermissions.yamlController,
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
    String? sessionId,
    SessionPermissions? permissions,
  }) {
    return LocalTestExecutionSession._(
      sessionId: sessionId ??
          'standalone_${DateTime.now().microsecondsSinceEpoch}',
      tester: tester,
      harness: harness,
      context: context,
      permissions: permissions ?? SessionPermissions.restrictedUi,
      assertions: assertions,
      executor: executor,
      ownsBootstrap: true,
    );
  }

  @override
  final String sessionId;

  final WidgetTester tester;
  final EnsembleTestHarness harness;
  final EnsembleTestContext context;
  final SessionPermissions permissions;

  /// True when created via [standalone] — owns overlay/runtime cleanup.
  final bool ownsBootstrap;

  final AssertionEngine assertions;
  final TestStepExecutor executor;
  final ObservationRegistry registry;
  final LeafCommandQueue queue;
  final Map<String, Uint8List> _artifactStore;
  late final FlutterTargetResolver resolver;
  late final LocalActionExecutor actionExecutor;
  late final FlutterUiObserver observer;

  int _revision = 0;
  int _observationSeq = 0;
  int _actionSeq = 0;
  String? _lastFingerprint;
  bool _closed = false;

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

  void _ensureActionPermitted(TestAction action) {
    if (!permissions.actions.contains(action.type) ||
        !localCapabilities.actions.contains(action.type)) {
      throw TestExecutionError(
        code: TestExecutionErrorCode.permissionDenied,
        message: 'Not permitted to run "${action.type}".',
        details: {'action': action.type},
      );
    }
  }

  void _ensureAssertPermitted(TestAssertion assertion) {
    if (!permissions.assertionDomains.contains(assertion.domain) ||
        !localCapabilities.assertionDomains.contains(assertion.domain)) {
      throw TestExecutionError(
        code: TestExecutionErrorCode.permissionDenied,
        message: 'Not permitted to assert domain "${assertion.domain}".',
        details: {'domain': assertion.domain},
      );
    }
  }

  void _ensureWaitPermitted(WaitCondition condition) {
    if (!permissions.waits.contains(condition.waitKind) ||
        !localCapabilities.waits.contains(condition.waitKind)) {
      throw TestExecutionError(
        code: TestExecutionErrorCode.permissionDenied,
        message: 'Not permitted to wait for "${condition.waitKind}".',
        details: {'wait': condition.waitKind},
      );
    }
  }

  @override
  Future<SessionCapabilities> getCapabilities() async {
    _ensureOpen();
    return localCapabilities;
  }

  @override
  Future<UiObservation> observe({
    ObservationOptions options = const ObservationOptions(),
  }) {
    _ensureOpen();
    return queue.run(() => observer.observe(options));
  }

  @override
  Future<ActionResult> act(
    TestAction action, {
    String? expectedObservationId,
  }) {
    _ensureOpen();
    return queue.run(() async {
      final actionId = 'action_${_actionSeq++}';
      final before = _revision;
      final sw = Stopwatch()..start();
      try {
        _ensureActionPermitted(action);
        if (expectedObservationId != null) {
          final target = action.primaryTarget;
          if (target != null && target.usesSnapshotElement) {
            if (target.observationId != expectedObservationId) {
              throw TestExecutionError(
                code: TestExecutionErrorCode.staleObservation,
                message:
                    'expectedObservationId "$expectedObservationId" does not '
                    'match target observationId "${target.observationId}".',
              );
            }
          }
        }
        await actionExecutor.execute(action);
        return ActionResult(
          actionId: actionId,
          status: ActionStatus.succeeded,
          beforeRevision: before,
          afterRevision: _revision,
          duration: sw.elapsed,
        );
      } on TestExecutionError catch (error) {
        return ActionResult(
          actionId: actionId,
          status: ActionStatus.failed,
          beforeRevision: before,
          afterRevision: _revision,
          duration: sw.elapsed,
          error: error,
        );
      } on EnsembleTestFailure catch (error) {
        final mapped = _mapExecutorFailure(error);
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
  }

  /// Maps executor [EnsembleTestFailure] into structured session errors,
  /// preserving the full diagnostic message.
  static TestExecutionError _mapExecutorFailure(EnsembleTestFailure error) {
    final message = error.message;
    final lower = message.toLowerCase();
    final code = lower.contains('timed out')
        ? TestExecutionErrorCode.actionTimeout
        : (lower.contains('not found') ||
                lower.contains('could not find') ||
                lower.contains('is detached') ||
                lower.contains('not in the tree'))
            ? TestExecutionErrorCode.elementNotFound
            : (lower.contains('not hit-testable') ||
                    lower.contains('not interactable'))
                ? TestExecutionErrorCode.elementNotInteractable
                : (lower.contains('exactly one') ||
                        lower.contains('ambiguous') ||
                        lower.contains('multiple'))
                    ? TestExecutionErrorCode.ambiguousTarget
                    : TestExecutionErrorCode.internalError;
    return TestExecutionError(
      code: code,
      message: message,
      details: const {'source': 'TestStepExecutor'},
    );
  }

  @override
  Future<WaitResult> waitFor(
    WaitCondition condition, {
    Duration? timeout,
  }) {
    _ensureOpen();
    return queue.run(() async {
      final waitId = 'wait_${_actionSeq++}';
      final sw = Stopwatch()..start();
      try {
        _ensureWaitPermitted(condition);
        final timeoutMs = timeout?.inMilliseconds ??
            executor.config.defaultWaitTimeout.inMilliseconds;
        switch (condition) {
          case PumpWait(:final duration):
            await executor.execute(
              TestStep(
                type: duration == Duration.zero ? 'pump' : 'wait',
                args: {'durationMs': duration.inMilliseconds},
              ),
            );
          case SettleWait(:final timeout):
            await executor.execute(
              TestStep(
                type: 'settle',
                args: {
                  if (timeout != null) 'timeoutMs': timeout.inMilliseconds,
                },
              ),
            );
          case ElementWait(:final testId, :final gone):
            await executor.execute(
              TestStep(
                type: gone ? 'waitForGone' : 'waitFor',
                args: {'id': testId, 'timeoutMs': timeoutMs},
              ),
            );
          case TextWait(:final text, :final anyOf):
            await executor.execute(
              TestStep(
                type: 'waitForText',
                args: {
                  if (text != null) 'text': text,
                  if (anyOf != null) 'anyOf': anyOf,
                  'timeoutMs': timeoutMs,
                },
              ),
            );
          case ScreenWait(:final screen):
            await executor.execute(
              TestStep(
                type: 'waitForNavigation',
                args: {'screen': screen, 'timeoutMs': timeoutMs},
              ),
            );
          case ApiWait(:final name, :final args):
            await executor.execute(
              TestStep(
                type: 'waitForApi',
                args: {
                  if (name != null) 'name': name,
                  ...args,
                  'timeoutMs': timeoutMs,
                },
              ),
            );
          case GenericWait(:final name, :final args):
            await executor.execute(
              TestStep(
                type: name,
                args: {
                  ...args,
                  if (!args.containsKey('timeoutMs')) 'timeoutMs': timeoutMs,
                },
              ),
            );
        }
        return WaitResult(
          waitId: waitId,
          status: WaitStatus.satisfied,
          duration: sw.elapsed,
        );
      } on TestExecutionError catch (error) {
        return WaitResult(
          waitId: waitId,
          status: WaitStatus.failed,
          duration: sw.elapsed,
          error: error,
        );
      } on EnsembleTestFailure catch (error) {
        final mapped = _mapExecutorFailure(error);
        return WaitResult(
          waitId: waitId,
          status: mapped.code == TestExecutionErrorCode.actionTimeout
              ? WaitStatus.timedOut
              : WaitStatus.failed,
          duration: sw.elapsed,
          error: mapped,
        );
      }
    });
  }

  @override
  Future<AssertionResult> assertCondition(TestAssertion assertion) {
    _ensureOpen();
    return queue.run(() async {
      final assertionId = 'assert_${_actionSeq++}';
      try {
        _ensureAssertPermitted(assertion);
        switch (assertion) {
          case ElementVisibleAssertion(:final testId, :final visible):
            await executor.execute(
              TestStep(
                type: visible ? 'expectVisible' : 'expectNotVisible',
                args: {'id': testId},
              ),
            );
          case ElementExistsAssertion(:final testId, :final exists):
            await executor.execute(
              TestStep(
                type: exists ? 'expectExists' : 'expectNotExists',
                args: {'id': testId},
              ),
            );
          case ElementTextAssertion(:final testId, :final text, :final contains):
            await executor.execute(
              TestStep(
                type: contains ? 'expectTextContains' : 'expectText',
                args: {'id': testId, 'text': text},
              ),
            );
          case ElementEnabledAssertion(:final testId, :final enabled):
            await executor.execute(
              TestStep(
                type: enabled ? 'expectEnabled' : 'expectDisabled',
                args: {'id': testId},
              ),
            );
          case ScreenAssertion(:final screen):
            await executor.execute(
              TestStep(type: 'expectScreen', args: {'screen': screen}),
            );
          case GenericAssertion(:final name, :final args):
            await executor.execute(TestStep(type: name, args: args));
        }
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
        final mapped = _mapExecutorFailure(error);
        return AssertionResult(
          assertionId: assertionId,
          status: AssertionStatus.failed,
          message: mapped.message,
          error: mapped,
        );
      }
    });
  }

  @override
  Future<TestArtifact> captureArtifact(ArtifactRequest request) {
    _ensureOpen();
    return queue.run(() async {
      if (!permissions.captureArtifacts || !localCapabilities.screenshots) {
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
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    queue.close();
    registry.clear();
    _artifactStore.clear();
    if (ownsBootstrap) {
      context.apiOverlay.resetCalls();
      context.runtime.clear();
    }
    // Suite-attached: do not dispose harness/tester.
  }
}
