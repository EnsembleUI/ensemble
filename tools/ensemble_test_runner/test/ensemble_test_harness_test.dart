import 'dart:io';

import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/encrypted_storage_manager.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/test_harness_host_runtime.dart';
import 'package:ensemble_test_runner/runner/test_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('removes only stale runner-owned storage directories', () async {
    final root = Directory.systemTemp.createTempSync('ensemble_storage_sweep_');
    addTearDown(() => root.deleteSync(recursive: true));
    final stale = Directory('${root.path}/ensemble_test_runner_storage_stale')
      ..createSync();
    File('${stale.path}/data').writeAsStringSync('stale');
    final staleArtifacts = Directory('${root.path}/ensemble_artifacts_123_old')
      ..createSync();
    File('${staleArtifacts.path}/partial.bin').writeAsBytesSync([1, 2, 3]);
    final unrelated = Directory('${root.path}/other_storage')..createSync();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final recent = Directory('${root.path}/ensemble_test_runner_storage_recent')
      ..createSync();
    final recentArtifacts = Directory('${root.path}/ensemble_artifacts_456_new')
      ..createSync();

    TestHarnessHostRuntime.pruneStaleTestStorageDirectories(
      temporaryRoot: root,
      staleAfter: const Duration(seconds: 1),
    );

    expect(stale.existsSync(), isFalse);
    expect(staleArtifacts.existsSync(), isFalse);
    expect(recent.existsSync(), isTrue);
    expect(recentArtifacts.existsSync(), isTrue);
    expect(unrelated.existsSync(), isTrue);
  });

  testWidgets('cleans temporary app storage after its owner is disposed',
      (tester) async {
    EnsembleTestHarness.ensureTestPlugins();
    await const MethodChannel('plugins.flutter.io/path_provider')
        .invokeMethod<String>('getTemporaryDirectory');
    expect(EnsembleTestHarness.testStoragePathCreatedForTest, isTrue);

    EnsembleTestHarness.disposeTestStorage();

    expect(EnsembleTestHarness.testStoragePathCreatedForTest, isFalse);
  });

  testWidgets('host plugin setup does not capture an attempt recorder',
      (tester) async {
    final attemptFlow = NavigationFlowRecorder()..seed(['Attempt']);
    ScreenTracker().clearAll();

    EnsembleTestHarness.ensureTestPlugins();
    ScreenTracker().trackScreen(screenName: 'PreSuite');
    await tester.pump();

    expect(attemptFlow.flow, ['Attempt']);
    ScreenTracker().clearAll();
  });

  test('app font bootstrap aliases package icon font families', () {
    final aliases = EnsembleTestHarness.fontFamilyAliasesForTest(
      'packages/font_awesome_flutter/FontAwesomeSolid',
    );

    expect(
      aliases,
      containsAll([
        'packages/font_awesome_flutter/FontAwesomeSolid',
        'FontAwesomeSolid',
        'fontawesomesolid',
      ]),
    );
  });

  test('app font bootstrap can try decoded asset keys', () {
    final candidates = EnsembleTestHarness.fontAssetCandidatesForTest(
      'packages/font_awesome_flutter/lib/fonts/Font%20Awesome%207%20Free-Solid-900.otf',
    );

    expect(
      candidates,
      contains(
        'packages/font_awesome_flutter/lib/fonts/Font Awesome 7 Free-Solid-900.otf',
      ),
    );
  });

  test('package info bootstrap reads app metadata from app files', () {
    final dir = Directory.systemTemp.createTempSync('ensemble_package_info_');
    try {
      File('${dir.path}/pubspec.yaml').writeAsStringSync('''
name: sample_app
version: 0.6.0+60
''');
      Directory('${dir.path}/ensemble').createSync();
      File('${dir.path}/ensemble/ensemble.properties').writeAsStringSync('''
appId=com.example.sampleapp.dev
appName=Sample App Dev
''');

      expect(
        EnsembleTestHarness.packageInfoForTest(dir.path),
        {
          'appName': 'Sample App Dev',
          'packageName': 'com.example.sampleapp.dev',
          'version': '0.6.0',
          'buildNumber': '60',
        },
      );
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('package info bootstrap falls back without app metadata files', () {
    final dir = Directory.systemTemp.createTempSync('ensemble_package_info_');
    try {
      expect(
        EnsembleTestHarness.packageInfoForTest(dir.path),
        {
          'appName': 'EnsembleTest',
          'packageName': 'com.ensemble.test',
          'version': '1.0.0',
          'buildNumber': '1',
        },
      );
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('device info mock matches the host platform shape', () {
    final map = EnsembleTestHarness.deviceInfoMockForTest();
    if (Platform.isIOS) {
      expect(map['name'], isA<String>());
      expect(map['systemName'], isA<String>());
      expect(map['systemVersion'], isA<String>());
      expect(map['utsname'], isA<Map>());
      expect(map['computerName'], isNull);
    } else if (Platform.isAndroid) {
      expect(map['name'], isA<String>());
      expect(map['model'], isA<String>());
      expect(map['version'], isA<Map>());
      expect(map['computerName'], isNull);
    } else {
      expect(map['computerName'], isA<String>());
      expect(map['hostName'], isA<String>());
      expect(map['osRelease'], isA<String>());
    }
  });

  testWidgets('app font bootstrap is safe when font manifest is unavailable',
      (tester) async {
    EnsembleTestHarness.ensureTestPlugins();

    await EnsembleTestHarness.ensureAppFontsLoaded();
  });

  testWidgets('SDK Roboto is registered when the app does not ship it',
      (tester) async {
    EnsembleTestHarness.ensureTestPlugins();
    await tester.runAsync(EnsembleTestHarness.ensureAppFontsLoaded);

    final painter = TextPainter(
      text: const TextSpan(
        text: 'Sign in',
        style: TextStyle(fontSize: 20, fontFamily: 'Roboto'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Ahem renders every glyph as a 1em square, so "Sign in" would be 140px.
    expect(painter.width, lessThan(120));
    expect(painter.width, greaterThan(40));

    final inter = TextPainter(
      text: const TextSpan(
        text: 'Sign in',
        style: TextStyle(fontSize: 20, fontFamily: 'Inter_regular'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(inter.width, lessThan(120));
    expect(inter.width, greaterThan(40));
  });

  testWidgets('initial keychain state is written to secure storage',
      (tester) async {
    EnsembleTestHarness.ensureTestPlugins();

    await applyTestStorageBootstrap(
      const EnsembleTestSetup(
        initialKeychain: {
          'sessionPsi': 'test-psi',
          'authPayload': {'token': 'abc'},
        },
      ),
    );

    expect(await StorageManager().readSecurely('sessionPsi'), 'test-psi');
    expect(
      await StorageManager().readSecurely('authPayload'),
      {'token': 'abc'},
    );
  });

  testWidgets('initial secureStorage state is encrypted into public storage',
      (tester) async {
    EnsembleTestHarness.ensureTestPlugins();
    installTestEncryptionKey();

    await tester.runAsync(
      () => applyTestStorageBootstrap(
        const EnsembleTestSetup(
          initialSecureStorage: {
            'dnsBackup': {'hasBackup': true},
          },
        ),
      ),
    );

    expect(StorageManager().read('enc_dnsBackup'), isA<String>());
    expect(
      EncryptedStorageManager.getSecureStorage('dnsBackup'),
      {'hasBackup': true},
    );
  });
}
