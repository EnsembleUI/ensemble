import 'package:ensemble/framework/view/page_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  group('resolveNavigateViewGroupIndex', () {
    test('clamps when menu has tabs', () {
      expect(resolveNavigateViewGroupIndex(99, 3), 2);
      expect(resolveNavigateViewGroupIndex(-1, 3), 0);
      expect(resolveNavigateViewGroupIndex(1, 3), 1);
    });

    test('returns raw index when menu length is zero', () {
      expect(resolveNavigateViewGroupIndex(5, 0), 5);
      expect(resolveNavigateViewGroupIndex(-1, 0), -1);
    });
  });
}
