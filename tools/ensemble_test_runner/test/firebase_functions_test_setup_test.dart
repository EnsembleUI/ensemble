import 'package:ensemble_test_runner/mocks/firebase_test_setup.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'firebase core mock preserves projectId from initializeApp',
    (tester) async {
      EnsembleTestHarness.ensureTestPlugins();

      await tester.runAsync(() async {
        const appName = 'firebaseFunctionsTest';
        await Firebase.initializeApp(
          name: appName,
          options: const FirebaseOptions(
            apiKey: 'test-api-key',
            appId: 'test-app-id',
            messagingSenderId: 'test-sender',
            projectId: 'test-project-id',
          ),
        );

        expect(firebaseProjectIdsByApp[appName], 'test-project-id');
        expect(Firebase.app(appName).options.projectId, 'test-project-id');
      });
    },
  );
}
