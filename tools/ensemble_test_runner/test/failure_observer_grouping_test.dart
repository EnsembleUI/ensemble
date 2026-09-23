import 'package:ensemble_test_runner/reporters/step_log_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groupLogsByStep attaches observer metadata without a second screenshot',
      () {
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
          'screen': 'Home',
          'elements': [
            {'index': 1, 'type': 'button', 'title': 'Continue', 'id': 'go'},
          ],
          'overlays': [
            {
              'left': 10.0,
              'top': 20.0,
              'width': 15.0,
              'height': 5.0,
              'id': 'go',
              'type': 'button',
            },
          ],
        },
      ],
    );

    expect(steps, hasLength(2));
    expect(steps[0]['observer'], isNull);
    final shots = steps[1]['screenshots'] as List;
    expect(shots, hasLength(1));
    expect(shots.single['file'], 'normal.webp');
    final observer = steps[1]['observer'] as Map;
    expect(observer['screen'], 'Home');
    expect(observer.containsKey('screenshot'), isFalse);
    expect(observer.containsKey('file'), isFalse);
    expect(observer['elements'], hasLength(1));
    expect(observer['elements'].single['id'], 'go');
    expect(observer['overlays'], hasLength(1));
    expect(observer['overlays'].single['id'], 'go');
  });
}
