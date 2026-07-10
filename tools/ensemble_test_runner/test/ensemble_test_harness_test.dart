import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app font bootstrap is safe when font manifest is unavailable',
      (tester) async {
    EnsembleTestHarness.ensureTestPlugins();

    await EnsembleTestHarness.ensureAppFontsLoaded();
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
}
