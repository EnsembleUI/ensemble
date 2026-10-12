library;

import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/entry/host_test_artifacts.dart';
import 'package:ensemble_test_runner/reporters/test_reporter.dart'
    show outlineSteps;
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/screenshot_target_support.dart';
import 'package:ensemble_test_runner/runner/screenshot_lottie_ready.dart';
import 'package:ensemble_test_runner/runner/step_report_capture.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ensemble_test_runner/src/runtime/test_execution_binding.dart';

/// Selects the test binding required by the resolved execution mode.
void ensureApplicationTestBinding(ExecutionMode mode) {
  ensureExecutionBinding(mode);
}

/// Services started inside the test process.
///
/// When [ensembleTestHostOwnsServices] is true (CLI integration backend), the
/// development machine already started fixtures and the device must not spawn
/// them again.
List<TestServiceConfig> hostProcessServiceConfigs(
  List<TestServiceConfig> configured, {
  bool hostOwnsServices = const bool.fromEnvironment(
    'ensembleTestHostOwnsServices',
  ),
}) =>
    hostOwnsServices ? const [] : configured;

EnsembleTestReportDetails hostReport(
  EnsembleTestCase test,
  ApplicationTestServices? services, {
  List<int> stepDurationsMs = const [],
  List<String> stepStartTimes = const [],
}) {
  final navigation = services?.navigation;
  final history = navigation?.routeHistory ?? const <String>[];
  return EnsembleTestReportDetails(
    startScreen: history.isEmpty ? null : history.first,
    endScreen: navigation?.currentRoute,
    navigationKnown: navigation != null,
    session: test.session,
    screensVisited: history,
    stepsOutline: outlineSteps(test.steps),
    stepDurationsMs: stepDurationsMs,
    stepStartTimes: stepStartTimes,
  );
}

Map<String, bool> capabilityStatus(ApplicationTestServices? services) => {
      'navigation': services?.navigation != null,
      'api': services?.api != null,
      'storage': services?.storage != null,
      'metadata': services?.metadata != null,
    };

TestFailureKind failureKind(
  Object? error, {
  TestApplicationHandle? handle,
}) {
  if (error is UnsupportedApplicationCapability) {
    return TestFailureKind.unsupportedCapability;
  }
  if (error is ApplicationTestCrash) return TestFailureKind.crash;
  if (handle == null) return TestFailureKind.bootstrap;
  if (error is TestExecutionError) {
    switch (error.code) {
      case TestExecutionErrorCode.elementNotFound:
        return TestFailureKind.elementNotFound;
      case TestExecutionErrorCode.ambiguousTarget:
        return TestFailureKind.ambiguousTarget;
      case TestExecutionErrorCode.unsupportedAction:
      case TestExecutionErrorCode.executionUnavailable:
        return TestFailureKind.unsupportedCapability;
      default:
        return TestFailureKind.assertion;
    }
  }
  return TestFailureKind.assertion;
}

/// True when suite config.yaml declares API mocks (files or inline).
bool suiteDeclaresApiMocks(EnsembleTestConfig config) =>
    config.inlineMocks.isNotEmpty || config.mockFiles.isNotEmpty;

/// True when the test or suite declares storage fixtures.
bool hostDeclaresStorageFixtures(EnsembleTestContext context) {
  bool hasStorageKeys(Map<String, dynamic> state) =>
      state.containsKey('storage') ||
      state.containsKey('secureStorage') ||
      state.containsKey('keychain');
  return hasStorageKeys(context.testCase.initialState) ||
      hasStorageKeys(context.config.initialState) ||
      context.setup.initialPublicStorage != null ||
      context.setup.initialSecureStorage != null ||
      context.setup.initialKeychain != null;
}

/// Effective API mocks after suite + test composition (planner-merged).
Map<String, MockAPIResponse> effectiveHostApiMocks(
  EnsembleTestContext context,
) =>
    Map<String, MockAPIResponse>.from(context.testCase.mocks.apis);

/// Whether Ensemble's HTTP provider currently carries the test API overlay.
bool ensembleApiOverlayAttached(EnsembleTestContext context) {
  final providers = Ensemble().getConfig()?.apiProviders;
  final http = providers?['http'];
  return identical(http, context.apiOverlay) || http is TestApiProviderOverlay;
}

Future<bool> captureHostStepReportArtifactsSafely({
  required WidgetTester tester,
  required EnsembleTestContext context,
  required LocalTestExecutionSession session,
  required TestStep step,
  required int stepIndex,
  required List<TestFailureDetails> secondaryFailures,
  Future<bool> Function()? prepareCapture,
  bool atCurrentFrame = false,
  ObservationDetailLevel observationDetail = ObservationDetailLevel.standard,
}) async {
  // Keep the host path aligned with TestVisualArtifacts: excluded evidence
  // exits before benchmark instrumentation or any capture setup.
  if (!context.config.screenshots.shouldCaptureStep(step.type)) return false;

  // StepEvidenceSubscriber owns de-duplication across pre-action and
  // completed-step boundaries. Keep this function focused on capturing and
  // publishing one host frame; inspecting report state here creates a second,
  // independent capture guard.
  return await RunnerBenchmark.async(
      'workflow', 'captureHostStepReportArtifactsSafely', () async {
    try {
      // Some evidence boundaries (currently navigation matches) need to
      // confirm that their target survives a paint opportunity before this
      // shared capture owner freezes the frame. A false result leaves the
      // step-finished fallback eligible to capture the rendered destination.
      if (prepareCapture != null && !await prepareCapture()) return false;
      if (atCurrentFrame && step.type == 'waitForText') {
        // Match the standalone adapter: freeze the text only after its
        // highlight has reached a visible paint opacity. Text can satisfy the
        // predicate while an AnimatedOpacity transition is still underway.
        await ScreenshotTargetSupport(
          drainFlutterExceptions: _drainHostFlutterExceptions,
        ).waitForHighlightTargetToPaint(session.executor, step);
      }
      var captured = false;
      await captureStepReportArtifacts(
        // Eligibility was checked before benchmark instrumentation above.
        // Repeating the same configuration lookup in the shared report
        // wrapper does not add safety here and runs for every captured step.
        enabled: true,
        captureScreenshot: () async {
          // Capture is awaited inline and appends at most one frame. Comparing
          // list lengths is constant time; filtering all prior frames before
          // and after each screenshot made long suites pay a growing scan cost.
          final before = context.runtime.screenshotSheetFrames.length;
          await captureHostStepScreenshotSafely(
            tester: tester,
            context: context,
            assertions: session.assertions,
            navigation: session.services.navigation,
            step: step,
            stepIndex: stepIndex,
            observationDetail: observationDetail,
            secondaryFailures: secondaryFailures,
            atCurrentFrame: atCurrentFrame,
          );
          final after = context.runtime.screenshotSheetFrames.length;
          captured = after > before;
          return captured;
        },
      );
      return captured;
    } catch (_) {
      // Report capture must never replace the real test failure.
      return false;
    }
  });
}

/// Waits until a hosted navigation match has survived a paint opportunity.
/// Route notifications can precede the destination's first rendered frame;
/// returning false leaves the normal step-finished capture eligible.
Future<bool> prepareHostNavigationMatchCapture({
  required WidgetTester tester,
  required String? screen,
}) async {
  if (screen == null || screen.isEmpty) return false;
  final tracker = ScreenTracker();
  bool targetIsVisible() =>
      tracker.isScreenVisible(screenName: screen) ||
      tracker.isScreenVisible(screenId: screen);

  if (!targetIsVisible()) return false;
  await pumpScreenshotStabilityFrames(tester);
  if (!targetIsVisible()) return false;
  if (areVisibleLottiesReady(tester)) {
    seekVisibleLottiesForScreenshot(tester);
    await tester.pump();
  }
  return targetIsVisible();
}

void _drainHostFlutterExceptions(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

/// Keeps host screenshot failures secondary to the test outcome while
/// suppressing known render/capture diagnostics.
void recordHostScreenshotCaptureFailure({
  required Object error,
  required List<TestFailureDetails> secondaryFailures,
}) {
  if (isHostScreenshotDiagnostic(error) ||
      isHostScreenshotCaptureFailure(error)) {
    return;
  }
  secondaryFailures.add(
    TestFailureDetails(
      kind: TestFailureKind.assertion,
      message: 'Screenshot failed: $error',
      phase: 'screenshot',
    ),
  );
}

Future<void> captureHostStepScreenshotSafely({
  required WidgetTester tester,
  required EnsembleTestContext context,
  required AssertionEngine assertions,
  required NavigationTestService? navigation,
  required TestStep step,
  required int stepIndex,
  required List<TestFailureDetails> secondaryFailures,
  bool atCurrentFrame = false,
  ObservationDetailLevel observationDetail = ObservationDetailLevel.standard,
}) async {
  return await RunnerBenchmark.async(
      'workflow', 'captureHostStepScreenshotSafely', () async {
    try {
      await captureHostStepScreenshot(
        tester: tester,
        context: context,
        assertions: assertions,
        navigation: navigation,
        step: step,
        stepIndex: stepIndex,
        atCurrentFrame: atCurrentFrame,
        observationDetail: observationDetail,
      );
    } catch (error) {
      recordHostScreenshotCaptureFailure(
        error: error,
        secondaryFailures: secondaryFailures,
      );
    }
  });
}

/// Rejects YAML mocks/fixtures that cannot attach to the application under test.
///
/// Effective fixtures come from suite `config.yaml` and the individual test
/// (already merged into [EnsembleTestContext.testCase] by the planner). A host
/// must either expose [ApiMockingTestService] / [StorageTestService] or have the
/// Ensemble API overlay installed on the real HTTP provider — otherwise we fail
/// closed before steps run.
///
/// When [requireResolved] is false (pre-launch), Ensemble overlay attachment is
/// checked immediately; pure-Flutter hosts may defer until launch returns
/// services. When [requireResolved] is true (post-launch), unresolved fixtures
/// always throw.
void ensureHostFixturesSupported(
  EnsembleTestContext context, {
  ApplicationTestServices? services,
  bool requireResolved = false,
}) {
  final apiMocks = effectiveHostApiMocks(context);
  final suiteDeclaresMocks = suiteDeclaresApiMocks(context.config);
  final needsApiMocking = apiMocks.isNotEmpty || suiteDeclaresMocks;
  final needsStorage = hostDeclaresStorageFixtures(context);

  if (suiteDeclaresMocks && apiMocks.isEmpty) {
    throw EnsembleTestFailure(
      'Suite config declares API mocks but none were resolved onto the test. '
      'Check suite mocks / profiles composition.',
    );
  }

  if (needsApiMocking) {
    final api = services?.api;
    if (api is ApiMockingTestService) {
      api.applyMocks(TestMocks(apis: apiMocks));
    } else if (api != null) {
      throw const UnsupportedApplicationCapability('apiMocking');
    } else if (ensembleApiOverlayAttached(context)) {
      // Ensemble HTTP provider owns the overlay installed by applyInPlaceSetup.
      for (final entry in apiMocks.entries) {
        context.apiOverlay.setMock(entry.key, entry.value);
      }
    } else if (requireResolved || Ensemble().getConfig() != null) {
      // Ensemble was initialized but the overlay never attached, or we are
      // past launch with no host ApiMockingTestService.
      throw const UnsupportedApplicationCapability('apiMocking');
    }
    // else: pure Flutter pre-launch — wait for services after launch.
  }

  if (needsStorage) {
    if (services?.storage != null) {
      // Host-owned storage fixtures are applied by the driver's storage service
      // during prepare/launch; presence of the capability is enough here.
      return;
    }
    if (Ensemble().getConfig() != null) {
      // applyInPlaceSetup already ran applyTestBootstrap when config exists.
      return;
    }
    if (requireResolved) {
      throw const UnsupportedApplicationCapability('storage');
    }
  }
}

void validateHostPlan(
  EnsembleTestExecutionPlan plan,
  ApplicationTestDriver driver,
) {
  for (final definition in plan.ordered) {
    final test = definition.testCase;
    if (test.hasStartScreen && driver is! ScreenLaunchApplicationTestDriver) {
      throw EnsembleTestFailure(
        'Host test "${test.id}" must not define startScreen; launch state is '
        'owned by ApplicationTestDriver.',
      );
    }
    if (test.session != null && driver is! ApplicationCheckpointDriver) {
      throw EnsembleTestFailure(
        'Host test "${test.id}" uses session but its driver does not implement '
        'ApplicationCheckpointDriver.',
      );
    }
  }
}
