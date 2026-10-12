import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';

/// Capability and permission policy for a local execution session.
///
/// Keeping this policy separate makes the session responsible for execution
/// while this object owns the rules that decide which operations are exposed.
class LocalSessionPolicy {
  LocalSessionPolicy({
    required this.services,
    required this.harness,
    required this.permissions,
  }) : capabilities = _capabilities(services, harness);

  final ApplicationTestServices services;
  final EnsembleTestHarness? harness;
  final SessionPermissions permissions;
  final SessionCapabilities capabilities;

  static SessionCapabilities _capabilities(
    ApplicationTestServices services,
    EnsembleTestHarness? harness,
  ) {
    final hasNavigation = services.navigation != null || harness != null;
    final hasApi = services.api != null || harness != null;
    final hasStorage = services.storage != null || harness != null;
    return SessionCapabilities(
      actions: SessionCapabilities.local.actions,
      assertionDomains: {
        'ui',
        'quality',
        'script',
        if (hasNavigation) 'navigation',
        if (hasApi) 'api',
        if (hasStorage) 'storage',
      },
      waits: SessionCapabilities.local.waits,
      semanticTree: true,
      runtimeMetadata: services.metadata != null || harness != null,
      navigationState: hasNavigation,
      screenshots: true,
      coordinateActions: false,
      apiAssertions: hasApi,
      storageAssertions: hasStorage,
      secureFieldRedaction: true,
      observationRevisions: true,
      snapshotElementTargets: true,
    );
  }

  void ensureActionNamePermitted(String name) {
    if (!permissions.actions.contains(name) ||
        !capabilities.actions.contains(name)) {
      throw TestExecutionError(
        code: TestExecutionErrorCode.permissionDenied,
        message: 'Not permitted to run "$name".',
        details: {'action': name},
      );
    }
  }

  void ensureWaitKindPermitted(String waitKind) {
    if (!permissions.waits.contains(waitKind) ||
        !capabilities.waits.contains(waitKind)) {
      throw TestExecutionError(
        code: TestExecutionErrorCode.permissionDenied,
        message: 'Not permitted to wait for "$waitKind".',
        details: {'wait': waitKind},
      );
    }
  }

  void ensurePrivilegedOperationPermitted(String name) {
    if (permissions.privilegedOperations) return;
    throw TestExecutionError(
      code: TestExecutionErrorCode.permissionDenied,
      message: 'Not permitted to run "$name".',
      details: {'operation': name},
    );
  }

  void ensureLifecycleOperationPermitted(String name) {
    if (permissions.lifecycleOperations) return;
    throw TestExecutionError(
      code: TestExecutionErrorCode.permissionDenied,
      message: 'Not permitted to run "$name".',
      details: {'operation': name},
    );
  }
}
