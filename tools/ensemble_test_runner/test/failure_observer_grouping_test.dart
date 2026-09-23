import 'package:ensemble_test_runner/reporters/step_log_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groupLogsByStep attaches observer frames to the failed step', () {
    final steps = groupLogsByStep(
      stepsOutline: const [
        'tap(login)',
        'waitForNavigation(Home)',
      ],
      stepDurationsMs: const [100, 200],
      stepStartTimes: const [
        '2026-01-01T00:00:00.000Z',
        '2026-01-01T00:00:01.000Z',
      ],
      apiEvents: const [],
      rawConsoleLines: const [],
      screenshotFrames: [
        {
          'stepIndex': 1,
          'label': '2. waitForNavigation(Home)',
          'file': 'normal.webp',
          'href': 'screenshots/normal.webp',
        },
        {
          'stepIndex': 1,
          'role': 'observer',
          'label': 'Home',
          'file': 'observer.webp',
          'href': 'screenshots/observer.webp',
          'screen': 'Home',
          'elements': [
            {'index': 1, 'type': 'button', 'title': 'Continue', 'id': 'go'},
          ],
        },
      ],
    );

    expect(steps, hasLength(2));
    expect(steps[0]['observer'], isNull);
    final shots = steps[1]['screenshots'] as List;
    expect(shots, hasLength(2));
    expect(shots.map((s) => s['file']), containsAll(['normal.webp', 'observer.webp']));
    final observer = steps[1]['observer'] as Map;
    expect(observer['screen'], 'Home');
    expect(observer.containsKey('screenshot'), isFalse);
    expect(observer['elements'], hasLength(1));
    expect(observer['elements'].single['id'], 'go');
  });
}
