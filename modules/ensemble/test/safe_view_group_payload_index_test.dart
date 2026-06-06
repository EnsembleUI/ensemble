import 'package:ensemble/framework/view/page_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveNavigateViewGroupTabIndex', () {
    test('clamps when menu length is known', () {
      expect(resolveNavigateViewGroupTabIndex(5, 3), 2);
      expect(resolveNavigateViewGroupTabIndex(-1, 2), 0);
    });

    test('preserves raw index when menu length is unknown', () {
      expect(resolveNavigateViewGroupTabIndex(5, 0), 5);
      expect(resolveNavigateViewGroupTabIndex(-1, 0), -1);
    });
  });

  group('safeViewGroupPayloadIndex', () {
    test('clamps to valid range for positive lengths', () {
      expect(safeViewGroupPayloadIndex(-1, 3), 0);
      expect(safeViewGroupPayloadIndex(0, 3), 0);
      expect(safeViewGroupPayloadIndex(2, 3), 2);
      expect(safeViewGroupPayloadIndex(3, 3), 2);
      expect(safeViewGroupPayloadIndex(99, 1), 0);
    });

    test('returns 0 when payload is empty', () {
      expect(safeViewGroupPayloadIndex(0, 0), 0);
      expect(safeViewGroupPayloadIndex(5, 0), 0);
    });
  });
}
