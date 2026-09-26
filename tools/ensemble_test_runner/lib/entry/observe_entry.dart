/// Standalone `--inspect-ui` body shared with [runEnsembleYamlTests].
library;

import 'dart:io';

import 'package:ensemble_test_runner/discovery/ensemble_test_discovery.dart';
import 'package:ensemble_test_runner/mocks/firebase_test_setup.dart';
import 'package:ensemble_test_runner/mocks/wifi_test_setup.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/local/standalone_test_session_factory.dart';
import 'package:ensemble_test_runner/session/observation/observe_formatter.dart';
import 'package:ensemble_test_runner/session/observation/observe_screenshot.dart';
import 'package:ensemble_test_runner/session/observation/suggested_locator.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/test_session_factory.dart';
import 'package:flutter_test/flutter_test.dart';

const _observeScreen = String.fromEnvironment('ensembleTestObserveScreen');
const _observeFormatRaw =
    String.fromEnvironment('ensembleTestObserveFormat', defaultValue: 'text');

/// Host `--inspect-ui` uses this dart-define (no YAML suite).
bool get isApplicationObserveOnly =>
    const bool.fromEnvironment('ensembleTestObserveOnly');

/// Standalone `--inspect-ui` via `test/ensemble_tests.dart` + observe dart-defines.
bool get isStandaloneInspectUiRequested =>
    isApplicationObserveOnly && _observeScreen.trim().isNotEmpty;

/// Format requested by the CLI for observe-only runs.
ObserveFormat applicationObserveFormat() =>
    ObserveFormat.parse(_observeFormatRaw);

/// Runs inspect-ui inside an existing Flutter test binding / [testWidgets].
///
/// Called from [registerEnsembleYamlTests] so standalone apps keep using
/// `test/ensemble_tests.dart` (same bootstrap as the YAML suite).
Future<void> executeStandaloneInspectUi({
  required WidgetTester tester,
  required ExecutionMode mode,
  Future<void> Function()? bootstrap,
  Map<String, Function>? externalMethods,
  String? screen,
  ObserveFormat? format,
}) async {
  final resolvedScreen = (screen ?? _observeScreen).trim();
  if (resolvedScreen.isEmpty) {
    throw StateError(
      'ensemble test --inspect-ui requires --screen=<name> for standalone apps.',
    );
  }
  final resolvedFormat = format ?? ObserveFormat.parse(_observeFormatRaw);

  if (bootstrap == null) {
    fail(
      'Ensemble inspect-ui requires module bootstrap. '
      'In test/ensemble_tests.dart call runEnsembleYamlTests with '
      'bootstrap: () => EnsembleModules().init().',
    );
  }
  await tester.runAsync(() async {
    await bootstrap();
    if (mode == ExecutionMode.widget) {
      ensureWifiTestDoublesForTest();
      ensureLiveAuthActionsForTest();
    }
    await Future<void>.delayed(Duration.zero);
  });

  final target = await EnsembleTestDiscovery.loadAppTarget();
  final harness = EnsembleTestHarness(
    appPath: target.appPath,
    appHome: target.appHome,
    i18nPath: target.i18nPath,
    externalMethods: externalMethods,
    executionMode: mode,
  );
  final factory = StandaloneTestSessionFactory(
    tester: tester,
    harness: harness,
  );

  final suiteConfig =
      await loadInspectUiSuiteConfig(testsAssetPrefix: target.testsAssetPrefix);
  final devices = resolveInspectUiDevices(
    suiteConfig.devices,
    forScreenshots: inspectUiScreenshotEnabled,
  );
  final secureContent = suiteConfig.screenshots.secureContent;
  final usedNames = <String>{};
  final screenshotPaths = <String>[];
  UiObservation? observation;

  for (final device in devices) {
    if (mode == ExecutionMode.widget) {
      await applyInspectUiScreenshotViewport(tester, device);
    }

    final session = await factory.create(
      TestSessionConfiguration(
        sessionId: 'observe_${device.id}',
        startScreen: resolvedScreen,
        permissions: SessionPermissions.restrictedUi,
        deviceTarget: device,
      ),
    );
    try {
      observation = await session.observe(options: inspectUiObservationOptions);
      if (session is LocalTestExecutionSession) {
        observation = enrichSuggestedLocators(
          observation: observation,
          resolver: session.resolver,
          registry: session.registry,
        );
      }
      if (inspectUiScreenshotEnabled && mode == ExecutionMode.widget) {
        final dir = inspectUiScreenshotDirFromEnvironment();
        if (dir != null) {
          var basename = inspectUiScreenshotBasename(
            screen: resolvedScreen,
            theme: device.theme,
            locale: device.locale,
          );
          if (!usedNames.add(basename)) {
            basename = inspectUiScreenshotBasename(
              screen: resolvedScreen,
              theme: device.theme,
              locale: device.locale,
              deviceId: device.id,
              includeDeviceId: true,
            );
            usedNames.add(basename);
          }
          final path = await writeInspectUiScreenshotForDevice(
            tester: tester,
            observation: observation,
            device: device,
            outputPath: '$dir${Platform.pathSeparator}$basename.png',
            secureContent: secureContent,
          );
          if (path != null) screenshotPaths.add(path);
        }
      }
    } finally {
      await session.close();
    }
  }

  if (observation == null) {
    fail('ensemble test --inspect-ui produced no observation.');
  }
  const ObserveFormatter().emit(
    observation,
    format: resolvedFormat,
    screenshotPaths: screenshotPaths,
  );
}
