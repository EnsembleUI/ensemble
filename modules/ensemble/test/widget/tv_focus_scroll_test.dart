import 'package:ensemble/framework/tv/tv_focus_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the opt-in `keepVisible` reveal helper used by TV focus scrolling.
///
/// It must move the minimum amount required to reveal the target (matching
/// Flutter's default traversal), and it must not scroll a nested axis that the
/// caller excluded.
void main() {
  testWidgets(
    'ensureWidgetVisible scrolls a vertical list just enough to reveal the item',
    (tester) async {
      final controller = ScrollController();
      final itemKey = GlobalKey();
      addTearDown(controller.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          // A Column inside a SingleChildScrollView keeps every item built, so
          // the target's render object exists even while it is offscreen.
          body: SingleChildScrollView(
            controller: controller,
            child: Column(
              children: [
                for (var i = 0; i < 50; i++)
                  i == 40
                      ? SizedBox(key: itemKey, height: 100)
                      : SizedBox(height: 100, child: Text('item $i')),
              ],
            ),
          ),
        ),
      ));

      expect(controller.offset, 0);
      await tester.pump();

      // Item 40 spans content offset 4000..4100. A keepVisibleAtEnd reveal
      // places its bottom at the viewport bottom (600): offset 3500.
      await ensureWidgetVisible(itemKey.currentContext!);
      await tester.pumpAndSettle();

      expect(controller.offset, closeTo(3500, 1.0));
    },
  );

  testWidgets(
    'ensureWidgetVisible is a no-op when the item is already fully visible',
    (tester) async {
      final controller = ScrollController();
      final itemKey = GlobalKey();
      addTearDown(controller.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: controller,
            child: Column(
              children: [
                for (var i = 0; i < 50; i++)
                  i == 2
                      ? SizedBox(key: itemKey, height: 100)
                      : SizedBox(height: 100, child: Text('item $i')),
              ],
            ),
          ),
        ),
      ));

      await tester.pump();
      expect(controller.offset, 0);

      await ensureWidgetVisible(itemKey.currentContext!);
      await tester.pumpAndSettle();

      expect(controller.offset, 0);
    },
  );

  testWidgets(
    'ensureWidgetVisible leaves an excluded axis untouched',
    (tester) async {
      // A Row inside a horizontal SingleChildScrollView builds every child, so
      // the offscreen target exists; nesting it in a vertical list exercises
      // the nested-scrollable walk.
      final verticalController = ScrollController();
      final itemKey = GlobalKey();
      addTearDown(verticalController.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: ListView(
              controller: verticalController,
              children: [
                SizedBox(
                  height: 100,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var col = 0; col < 40; col++)
                          SizedBox(
                            key: col == 20 ? itemKey : null,
                            width: 100,
                            height: 100,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ));

      await tester.pump();
      expect(verticalController.offset, 0);
      expect(itemKey.currentContext, isNotNull);

      final horizontal = Scrollable.of(itemKey.currentContext!);
      expect(horizontal.position.pixels, 0);

      // Exclude vertical: the outer list must stay put while the inner lane
      // reveals the item horizontally.
      await ensureWidgetVisible(
        itemKey.currentContext!,
        includeVertical: false,
      );
      await tester.pumpAndSettle();

      expect(verticalController.offset, 0);
      expect(horizontal.position.pixels, greaterThan(0));
    },
  );
}
