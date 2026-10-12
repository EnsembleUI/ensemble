import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/wait_operation_handler.dart';
import 'package:ensemble_test_runner/session/action_operation_handler.dart';
import 'package:ensemble_test_runner/session/assertion_operation_handler.dart';
import 'package:ensemble_test_runner/session/lifecycle_operation_handler.dart';
import 'package:ensemble_test_runner/session/http_request_operation_handler.dart';
import 'package:ensemble_test_runner/session/environment_operation_handler.dart';
import 'package:ensemble_test_runner/session/storage_operation_handler.dart';
import 'package:ensemble_test_runner/session/mock_operation_handler.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/runtime.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'runtime_operation_handlers.dart';

/// Flutter implementation of the runtime contract for registered operations.
final class FlutterTestRuntime
    implements TestRuntime, EvidenceBoundaryEventSource {
  FlutterTestRuntime(this.session)
      : capabilities = RuntimeCapabilities(operationRegistry.handlerKeys),
        _waitHandler = WaitOperationHandler(session),
        _actionHandler = ActionOperationHandler(session),
        _assertionHandler = AssertionOperationHandler(session),
        _environmentHandler = EnvironmentOperationHandler(session),
        _storageHandler = StorageOperationHandler(session) {
    final lifecycleHandler = LifecycleOperationHandler(session);
    const httpRequestHandler = HttpRequestOperationHandler();
    _handlers = RuntimeOperationHandlers(
      registry: operationRegistry,
      kindHandlers: {
        OperationKind.interaction: _actionHandler.execute,
        OperationKind.wait: _waitHandler.execute,
        OperationKind.assertion: _assertionHandler.execute,
        OperationKind.lifecycle: lifecycleHandler.execute,
      },
      handlerOverrides: {
        'http.request.direct': httpRequestHandler.execute,
        'environment.set': _environmentHandler.set,
        'environment.resetApiCalls': (operation) =>
            _environmentHandler.resetApiCalls(),
        'environment.setPermission': _environmentHandler.setPermission,
        'environment.setLocale': _environmentHandler.setLocale,
        'environment.setDevice': _environmentHandler.setDevice,
        'environment.setTheme': _environmentHandler.setTheme,
        'storage.set': _storageHandler.set,
        'storage.remove': _storageHandler.remove,
        'storage.clear': (operation) => _storageHandler.clear(),
        'api.mocks': _mockHandler.apply,
      },
    );
  }

  final LocalTestExecutionSession session;
  final WaitOperationHandler _waitHandler;
  final ActionOperationHandler _actionHandler;
  final AssertionOperationHandler _assertionHandler;
  final EnvironmentOperationHandler _environmentHandler;
  final StorageOperationHandler _storageHandler;
  late final MockOperationHandler _mockHandler = MockOperationHandler(session);
  late final RuntimeOperationHandlers _handlers;
  @override
  final RuntimeCapabilities capabilities;

  int _revision = 0;
  bool _closed = false;
  RuntimeView? _cachedObservation;
  @override
  void bindEvidenceBoundaryEmitter(EvidenceBoundaryEmitter? emitter) {
    session.executor.onEvidenceBoundary = emitter == null
        ? null
        : (step) => emitter(
              session.context.runtime.currentStepIndex,
              step.type,
            );
    session.executor.onOperationEvidenceBoundary = emitter == null
        ? null
        : (_, detail) => emitter(
              session.context.runtime.currentStepIndex,
              detail,
            );
    session.executor.onNamedOperationEvidenceBoundary = emitter == null
        ? null
        : (name) => emitter(
              session.context.runtime.currentStepIndex,
              name,
            );
  }

  @override
  Future<RuntimeView> observe(ObservationRequest request) async {
    _checkOpen();
    final cached = _cachedObservation;
    if (cached != null &&
        cached.revision == _revision &&
        // This runtime currently exposes one detail shape, so require an exact
        // level match instead of claiming a richer view can satisfy a poorer one.
        cached.level == request.level &&
        sameInput(cached.target, request.target)) {
      return cached;
    }

    var visible = false;
    try {
      final finder = session.executor.finderForTargetArgs(
        Map<String, dynamic>.from(request.target),
        requireInteractive: false,
      );
      visible =
          finder.evaluate().any(session.assertions.isElementVisuallyActionable);
    } on TestExecutionError catch (error) {
      if (error.code != TestExecutionErrorCode.elementNotFound) rethrow;
      // A missing conditional target takes the hidden edge. Other resolution
      // failures must fail the attempt instead of silently skipping a branch.
    }
    final view = RuntimeView(
      revision: _revision,
      level: request.level,
      target: request.target,
      targetVisible: visible,
    );
    _cachedObservation = view;
    return view;
  }

  @override
  Future<OperationResult> execute(TestOperation operation) async {
    _checkOpen();
    // An attempted operation can partially mutate UI state before failing.
    _revision++;
    _cachedObservation = null;
    try {
      if (RunnerBenchmark.collector == null) {
        await _handlers.execute(operation);
      } else {
        await RunnerBenchmark.async(
          'execution',
          'operationRuntime',
          () => _handlers.execute(operation),
        );
      }
      return const OperationResult.success();
    } on EnsembleTestFailure catch (error, stackTrace) {
      return OperationResult.failure(
        error.toString(),
        cause: error,
        stackTrace: stackTrace,
      );
    } on TestExecutionError catch (error, stackTrace) {
      return OperationResult.failure(
        error.toString(),
        errorCode: error.code.name,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _cachedObservation = null;
    await session.close();
  }

  void _checkOpen() {
    if (_closed) throw StateError('Flutter runtime is closed.');
  }
}
