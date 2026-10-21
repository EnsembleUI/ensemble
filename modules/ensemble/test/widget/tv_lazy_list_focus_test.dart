import 'package:ensemble/framework/device.dart';
import 'package:ensemble/layout/grid_view.dart' as ensemble;
import 'package:ensemble/layout/list_view.dart' as ensemble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'test_utils.dart';

/// D-pad focus in lazy lists (ListView/GridView), which only build the items
/// near their viewport.
void main() {
  setUp(() => Device.debugOverrideIsTV(true));
  tearDown(() => Device.debugOverrideIsTV(null));

  /// A focusable item with TV coordinates, the shape of the app's news cards.
  Map<String, dynamic> item({
    required String label,
    required String row,
    String order = '0',
    String? autofocus,
  }) =>
      {
        'Row': {
          'onTap': {'navigateBack': <String, dynamic>{}},
          'styles': {
            'height': 100,
            if (autofocus != null) 'autofocus': autofocus,
            'tvOptions': {'row': row, 'order': order},
          },
          'children': [
            {
              'Text': {'text': label},
            },
          ],
        },
      };

  /// A one-item list above the content, like a screen's back button.
  ensemble.ListView header() => ensemble.ListView()
    ..initChildren(
        itemTemplate: YamlMap.wrap({
      'data': ['Header'],
      'name': 'h',
      'template': item(label: r'${h}', row: '0'),
    }));

  ensemble.GridView newsGrid() => ensemble.GridView()
    ..setProperty('horizontalTileCount', 5)
    ..setProperty('itemHeight', 100)
    ..initChildren(
        itemTemplate: YamlMap.wrap({
      'data': List.generate(60, (i) => i),
      'name': 'n',
      'indexId': 'i',
      'template': item(
        label: r'Item ${i}',
        row: r'${1 + Math.floor(i / 5)}',
        order: r'${i % 5}',
      ),
    }));

  ensemble.ListView autofocusList() => ensemble.ListView()
    ..initChildren(
        itemTemplate: YamlMap.wrap({
      'data': List.generate(40, (i) => i),
      'name': 'n',
      'indexId': 'i',
      'template': item(
        label: r'Item ${i}',
        row: r'${1 + i}',
        autofocus: r'${i == 0}',
      ),
    }));

  /// Rows of a header item plus a nested vertical list holding one item.
  ensemble.ListView nestedLists() => ensemble.ListView()
    ..initChildren(
        itemTemplate: YamlMap.wrap({
      'data': List.generate(20, (i) => i),
      'name': 'n',
      'indexId': 'i',
      'template': {
        'Column': {
          'children': [
            item(label: r'Head ${i}', row: r'${1 + 2 * i}'),
            {
              'ListView': {
                'styles': {'height': 100},
                'item-template': {
                  'data': [0],
                  'name': 'x',
                  'template': item(label: r'Inner ${i}', row: r'${2 + 2 * i}'),
                },
              },
            },
          ],
        },
      },
    }));

  Widget screen(Widget list) => TestUtils.wrapTestWidgetWithScope(Column(
        children: [
          SizedBox(height: 100, child: header()),
          SizedBox(height: 400, child: list),
        ],
      ));

  void useTestViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Label of the focused item (built items off screen included), or null.
  String? focusedLabel(WidgetTester tester) {
    for (final element
        in find.byType(InkWell, skipOffstage: false).evaluate()) {
      final focusNode = (element.widget as InkWell).focusNode;
      if (focusNode != null && focusNode.hasPrimaryFocus) {
        final text = find.descendant(
            of: find.byWidget(element.widget, skipOffstage: false),
            matching: find.byType(Text, skipOffstage: false));
        return tester.widget<Text>(text.first).data;
      }
    }
    return null;
  }

  void focusItem(WidgetTester tester, String label) {
    final inkWell = tester.widget<InkWell>(
        find.ancestor(of: find.text(label), matching: find.byType(InkWell)));
    inkWell.focusNode!.requestFocus();
  }

  ScrollPosition listPosition(WidgetTester tester, Type listType) {
    final scrollable = find.descendant(
        of: find.byType(listType), matching: find.byType(Scrollable));
    return tester.state<ScrollableState>(scrollable.first).position;
  }

  testWidgets('a held UP key scrolls through a lazy grid before leaving it',
      (tester) async {
    useTestViewport(tester);
    await tester.pumpWidget(screen(newsGrid()));
    await tester.pumpAndSettle();

    final grid = listPosition(tester, ensemble.GridView);
    grid.jumpTo(grid.maxScrollExtent);
    await tester.pumpAndSettle();
    focusItem(tester, 'Item 55');
    await tester.pumpAndSettle();

    // Android key repeat: one event every 50 ms while the key is held.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    var reachedFirstRow = false;
    for (var repeat = 0; repeat < 80; repeat++) {
      await tester.pump(const Duration(milliseconds: 50));
      final label = focusedLabel(tester);
      if (label == 'Item 0') reachedFirstRow = true;
      if (label == 'Header') {
        expect(reachedFirstRow, isTrue,
            reason: 'focus left the grid before reaching its first row');
        expect(grid.pixels, closeTo(0, 0.5),
            reason: 'focus left the grid while its first row was off screen');
        break;
      }
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowUp);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(reachedFirstRow, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a held DOWN key keeps the column and reaches the last row',
      (tester) async {
    useTestViewport(tester);
    await tester.pumpWidget(screen(newsGrid()));
    await tester.pumpAndSettle();
    focusItem(tester, 'Item 2');
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    for (var repeat = 0; repeat < 80; repeat++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(focusedLabel(tester), 'Item 57');
    expect(tester.takeException(), isNull);
  });

  testWidgets('DOWN moves into a list nested in the focused list',
      (tester) async {
    useTestViewport(tester);
    await tester.pumpWidget(screen(nestedLists()));
    await tester.pumpAndSettle();
    focusItem(tester, 'Head 0');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focusedLabel(tester), 'Inner 0');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focusedLabel(tester), 'Head 1');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'first-item autofocus does not take focus back when the item is '
      'rebuilt while scrolling', (tester) async {
    useTestViewport(tester);
    await tester.pumpWidget(screen(autofocusList()));
    await tester.pumpAndSettle();
    expect(focusedLabel(tester), 'Item 0');

    for (var i = 1; i <= 10; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(focusedLabel(tester), 'Item $i');
    }
    expect(find.text('Item 0'), findsNothing,
        reason: 'the test needs item 0 to be disposed by the lazy list');

    for (var i = 9; i >= 0; i--) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(focusedLabel(tester), 'Item $i');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'autofocus still moves focus into a list built while focus is '
      'outside it', (tester) async {
    useTestViewport(tester);
    var showList = false;
    late StateSetter setState;
    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
        StatefulBuilder(builder: (context, setter) {
      setState = setter;
      return Column(children: [
        SizedBox(height: 100, child: header()),
        if (showList) SizedBox(height: 400, child: autofocusList()),
      ]);
    })));
    await tester.pumpAndSettle();
    focusItem(tester, 'Header');
    await tester.pumpAndSettle();
    expect(focusedLabel(tester), 'Header');

    setState(() => showList = true);
    await tester.pumpAndSettle();
    expect(focusedLabel(tester), 'Item 0');
    expect(tester.takeException(), isNull);
  });
}
