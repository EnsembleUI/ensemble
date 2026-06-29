import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dedupes consecutive screen names', () {
    final recorder = NavigationFlowRecorder();

    recorder.recordScreenChange(
      VisibleScreen(screenName: 'Hello Home', visibleSince: DateTime.now()),
    );
    recorder.recordScreenChange(
      VisibleScreen(screenName: 'Goodbye', visibleSince: DateTime.now()),
    );
    recorder.recordScreenChange(
      VisibleScreen(screenName: 'Hello Home', visibleSince: DateTime.now()),
    );
    recorder.recordScreenChange(
      VisibleScreen(screenName: 'Hello Home', visibleSince: DateTime.now()),
    );

    expect(
      recorder.flow,
      ['Hello Home', 'Goodbye', 'Hello Home'],
    );
  });
}
