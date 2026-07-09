import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dedupes consecutive screen names', () async {
    final recorder = NavigationFlowRecorder();

    recorder.recordScreenChange(
      VisibleScreen(screenName: 'Hello Home', visibleSince: DateTime.now()),
    );
    await recorder.flushPending();
    recorder.recordScreenChange(
      VisibleScreen(screenName: 'Goodbye', visibleSince: DateTime.now()),
    );
    await recorder.flushPending();
    recorder.recordScreenChange(
      VisibleScreen(screenName: 'Hello Home', visibleSince: DateTime.now()),
    );
    await recorder.flushPending();
    recorder.recordScreenChange(
      VisibleScreen(screenName: 'Hello Home', visibleSince: DateTime.now()),
    );
    await recorder.flushPending();

    expect(
      recorder.flow,
      ['Hello Home', 'Goodbye', 'Hello Home'],
    );
  });

  test('coalesces transient route removal screen changes', () async {
    final recorder = NavigationFlowRecorder();

    recorder.recordScreenChange(
      VisibleScreen(screenName: 'InitApp', visibleSince: DateTime.now()),
    );
    await recorder.flushPending();

    recorder.recordScreenChange(
      VisibleScreen(screenName: 'Login', visibleSince: DateTime.now()),
    );
    recorder.recordScreenChange(
      VisibleScreen(screenName: 'AutoSignIn', visibleSince: DateTime.now()),
    );
    await recorder.flushPending();

    expect(recorder.flow, ['InitApp', 'AutoSignIn']);
  });
}
