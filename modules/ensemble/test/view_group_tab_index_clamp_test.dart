import 'package:ensemble/framework/view/page_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('clampViewGroupTabIndex', () {
    test('clamps negative indices to 0', () {
      expect(clampViewGroupTabIndex(-1, 3), 0);
      expect(clampViewGroupTabIndex(-100, 2), 0);
    });

    test('leaves in-range indices unchanged', () {
      expect(clampViewGroupTabIndex(0, 3), 0);
      expect(clampViewGroupTabIndex(2, 3), 2);
    });

    test('clamps indices beyond the last tab', () {
      expect(clampViewGroupTabIndex(3, 3), 2);
      expect(clampViewGroupTabIndex(99, 1), 0);
    });

    test('returns 0 when menu item count is zero', () {
      expect(clampViewGroupTabIndex(5, 0), 0);
    });
  });
}
