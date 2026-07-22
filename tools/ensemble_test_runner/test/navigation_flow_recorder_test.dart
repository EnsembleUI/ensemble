import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    YamlTestSession.navigationFlow.clear();
    YamlTestSession.navigationFlow.onScreenAdded = null;
  });

  test('records rapid consecutive screen changes without dropping any',
      () async {
    final flow = YamlTestSession.navigationFlow;
    flow.beginTest('AutoSignIn');

    flow.recordScreenChange(
      VisibleScreen(
        screenName: 'AutoSignIn_Gateway',
        visibleSince: DateTime.now(),
      ),
    );
    flow.recordScreenChange(
      VisibleScreen(screenName: 'Home', visibleSince: DateTime.now()),
    );
    await flow.flushPending();

    expect(flow.flow, ['AutoSignIn', 'AutoSignIn_Gateway', 'Home']);
  });

  test('onScreenAdded fires for each newly recorded screen', () async {
    final seen = <String>[];
    final flow = YamlTestSession.navigationFlow;
    flow.beginTest(null);
    flow.onScreenAdded = (name) async {
      seen.add(name);
    };

    flow.recordScreenChange(
      VisibleScreen(
        screenName: 'AutoSignIn_Gateway',
        visibleSince: DateTime.now(),
      ),
    );
    flow.recordScreenChange(
      VisibleScreen(screenName: 'Home', visibleSince: DateTime.now()),
    );
    await flow.flushPending();

    expect(flow.flow, ['AutoSignIn_Gateway', 'Home']);
    expect(seen, ['AutoSignIn_Gateway', 'Home']);
  });
}
