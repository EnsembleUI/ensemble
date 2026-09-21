import 'dart:io';

import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/encrypted_storage_manager.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
name: inhome
version: 0.6.0+60
''');
      Directory('${dir.path}/ensemble').createSync();
      File('${dir.path}/ensemble/ensemble.properties').writeAsStringSync('''
appId=com.kpn.inhome.dev
appName=KPN InHome Dev
''');

      expect(
        EnsembleTestHarness.packageInfoForTest(dir.path),
        {
          'appName': 'KPN InHome Dev',
          'packageName': 'com.kpn.inhome.dev',
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

    await applyYamlTestStorageBootstrap(
      const EnsembleTestSetup(
        initialKeychain: {
          'kpnPsi': 'test-psi',
          'authPayload': {'token': 'abc'},
        },
      ),
    );

    expect(await StorageManager().readSecurely('kpnPsi'), 'test-psi');
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
      () => applyYamlTestStorageBootstrap(
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
