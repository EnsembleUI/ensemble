/// Firebase-specific setup kept behind the runner's internal integration
/// boundary. Runtime and harness code depend on this narrow registration API
/// instead of importing the individual Firebase bridges.
library;

import 'package:ensemble_test_runner/mocks/firebase_test_setup.dart';
import 'package:ensemble_test_runner/src/integrations/test_integration_registration.dart';

/// Default Firebase integration for widget test execution.
const firebaseTestIntegration = TestIntegrationRegistration(
  name: 'firebase',
  install: registerFirebaseTestSupport,
  afterBootstrap: registerFirebaseTestActions,
);

/// Installs Firebase platform mocks before app bootstrap in widget tests.
void registerFirebaseTestSupport() {
  ensureFirebaseCoreMocksForTest();
}

/// Installs Firebase auth actions after app bootstrap in widget tests.
void registerFirebaseTestActions() {
  ensureLiveAuthActionsForTest();
}
