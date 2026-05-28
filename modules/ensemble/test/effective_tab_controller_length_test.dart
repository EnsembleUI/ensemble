import 'package:ensemble/layout/tab/tab_bar_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('effectiveTabControllerLength', () {
    test('uses placeholder length 1 when no tabs are visible', () {
      expect(effectiveTabControllerLength(0), 1);
    });

    test('matches visible tab count when at least one tab is visible', () {
      expect(effectiveTabControllerLength(1), 1);
      expect(effectiveTabControllerLength(4), 4);
    });
  });
}
