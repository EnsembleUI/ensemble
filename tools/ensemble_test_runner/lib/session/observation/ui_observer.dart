import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';

/// Collects a serializable [UiObservation] of the live UI.
abstract interface class UiObserver {
  Future<UiObservation> observe([
    ObservationOptions options = const ObservationOptions(),
  ]);
}
