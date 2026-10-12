import 'dart:ui' show Locale, Size;

import 'package:ensemble_test_runner/application/application_test_types.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/actions/test_theme.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/src/core/operation_input.dart';
import 'package:flutter_test/flutter_test.dart';

/// Applies storage mutations through the active application capability or the
/// standalone test context.
abstract final class TestStorageOperations {
  static Future<void> write({
    required ApplicationTestServices services,
    required EnsembleTestContext context,
    required bool hasHarness,
    required OperationInput operation,
  }) async {
    final key = _requiredStorageKey(operation, 'setStorage');
    final storage = services.storage;
    if (storage != null) {
      await storage.write(key, operation.arguments['value']);
      return;
    }
    _requireHarness(hasHarness);
    context.setStorage(key, operation.arguments['value']);
  }

  static Future<void> remove({
    required ApplicationTestServices services,
    required EnsembleTestContext context,
    required bool hasHarness,
    required OperationInput operation,
  }) async {
    final key = _requiredStorageKey(operation, 'removeStorage');
    final storage = services.storage;
    if (storage != null) {
      await storage.remove(key);
      return;
    }
    _requireHarness(hasHarness);
    context.removeStorage(key);
  }

  static Future<void> clear({
    required ApplicationTestServices services,
    required EnsembleTestContext context,
    required bool hasHarness,
  }) async {
    final storage = services.storage;
    if (storage != null) {
      await storage.clear();
      return;
    }
    _requireHarness(hasHarness);
    await context.clearStorage();
  }

  static void _requireHarness(bool hasHarness) {
    if (!hasHarness) throw const UnsupportedApplicationCapability('storage');
  }

  static String _requiredStorageKey(OperationInput operation, String name) {
    final key = operation.arguments['key']?.toString();
    if (key == null || key.isEmpty) {
      throw EnsembleTestFailure('$name requires "key"');
    }
    return key;
  }
}

/// Clears recorded API calls through the configured service or test overlay.
///
/// Both execution adapters use the same capability precedence so logging and
/// API observation remain untouched by this operation.
void resetTestApiCalls({
  required ApplicationTestServices services,
  required EnsembleTestContext context,
  required bool hasHarness,
}) {
  final api = services.api;
  if (api is ApiMockingTestService) {
    api.resetCalls();
    return;
  }
  if (api != null) {
    throw const UnsupportedApplicationCapability('apiMocking');
  }
  if (!hasHarness) {
    throw const UnsupportedApplicationCapability('api');
  }
  context.apiOverlay.resetCalls();
}

/// Applies a validated environment override through the shared test context.
///
/// Session-backed and executor operation paths retain their own authorization
/// checks, then delegate mutation and argument validation here.
void applyTestEnvironmentOverride({
  required EnsembleTestContext context,
  required OperationInput input,
}) {
  final key = input.arguments['key']?.toString();
  if (key == null || key.isEmpty) {
    throw EnsembleTestFailure('setEnv requires "key"');
  }
  context.setEnv(key, input.arguments['value']);
}

/// Applies a permission override with identical validation on each runtime path.
void applyTestPermission({
  required EnsembleTestContext context,
  required OperationInput input,
}) {
  final name = input.arguments['name']?.toString();
  if (name == null || name.isEmpty) {
    throw EnsembleTestFailure('setPermission requires "name"');
  }
  context.runtime.permissions[name] =
      input.arguments['value']?.toString() ?? 'granted';
}

/// Applies a locale consistently from either authored or compiled input.
void applyTestLocale(EnsembleTestContext context, OperationInput input) {
  final locale = input.arguments['locale']?.toString() ?? 'en';
  final parts = locale.replaceAll('-', '_').split('_');
  context.setEnv('APP_LOCALE', locale);
  context.runtime.locale = Locale(
    parts.first,
    parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
  );
}

/// Applies the shared environment and runtime theme state.
///
/// Adapters provide their own frame-pump callback so this mutation preserves
/// their existing widget lifecycle boundary.
Future<void> applyTestTheme({
  required EnsembleTestContext context,
  required String? theme,
  required Future<void> Function() pump,
}) async {
  if (theme == null || theme.trim().isEmpty) return;
  context.setEnv('APP_THEME', theme);
  final applied = applyEnsembleTestTheme(theme);
  context.runtime.themeMode = applied ?? theme;
  if (applied != null) await pump();
}

/// Applies a requested virtual device size for widget execution.
///
/// Standalone and session-backed operation adapters share this mutation while
/// retaining their own permission and settling boundaries.
Future<void> applyTestDeviceSize({
  required WidgetTester tester,
  required EnsembleTestContext context,
  required EnsembleTestHarness? harness,
  required OperationInput input,
  required Future<void> Function() settle,
}) async {
  final activeHarness = harness;
  if (activeHarness == null) {
    throw const UnsupportedApplicationCapability('ensembleHarness');
  }
  if (activeHarness.runtimeAdapter.usesPhysicalDisplay) {
    throw EnsembleTestFailure(
      'setDevice cannot override the simulator/emulator display in '
      'integration mode.',
    );
  }

  final width = (input.arguments['width'] as num?)?.toDouble() ?? 390;
  final height = (input.arguments['height'] as num?)?.toDouble() ?? 844;
  final size = Size(width, height);
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  context.runtime.deviceSize = size;
  await settle();
}
