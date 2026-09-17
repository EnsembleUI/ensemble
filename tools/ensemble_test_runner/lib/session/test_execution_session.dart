import 'package:ensemble_test_runner/session/actions/action_result.dart';
import 'package:ensemble_test_runner/session/actions/artifact_request.dart';
import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/assertions/test_assertion.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';

/// Interface for one isolated app test execution (observe / act / wait / assert).
///
/// ## Ownership
///
/// - **Suite-attached:** [EnsembleTestRunner] owns harness bootstrap and suite
///   cleanup. [close] releases only session-local state (command queue,
///   revisions, observation registry) — never the harness, tester, mocks, or
///   suite-end storage restore.
/// - **Standalone:** Independent of YAML, still inside a Flutter test binding.
///   A factory reuses [EnsembleTestHarness] bootstrap; callers never touch
///   [WidgetTester] directly.
///
/// ## Revisions
///
/// [UiObservation.revision] advances when observable UI state changes (text,
/// enabled, visibility, bounds, values, actions, navigation). Completing an
/// action does not by itself bump the revision.
///
/// ## Leaf locking
///
/// Only leaf operations (`observe`, `act`, `waitFor`, `assertCondition`,
/// `captureArtifact`) acquire the session command lock. YAML control-flow
/// (`group` / `repeat` / `optional` / `ifVisible`) must not hold it.
///
/// ## Element identity
///
/// Snapshot [UiElement.elementId] values resolve only through the observation
/// registry and are revalidated before execution. They never fall back to
/// [testId].
///
/// ## Capabilities vs permissions
///
/// [getCapabilities] reports what the adapter can provide.
/// [SessionPermissions] (configured at creation) reports what the caller
/// may invoke. Both must allow an operation.
abstract interface class TestExecutionSession {
  String get sessionId;

  Future<SessionCapabilities> getCapabilities();

  Future<UiObservation> observe({
    ObservationOptions options = const ObservationOptions(),
  });

  Future<ActionResult> act(
    TestAction action, {
    String? expectedObservationId,
  });

  Future<WaitResult> waitFor(
    WaitCondition condition, {
    Duration? timeout,
  });

  Future<AssertionResult> assertCondition(TestAssertion assertion);

  Future<TestArtifact> captureArtifact(ArtifactRequest request);

  /// Releases session-local resources. Idempotent.
  Future<void> close();
}
