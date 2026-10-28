import 'package:device_info_plus/device_info_plus.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/tv/tv_scrollbar_widget.dart';
import 'package:ensemble/layout/list_view.dart' as ensemble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'test_utils.dart';

const _boxColor = Color(0xFF232323);

void main() {
  setUpAll(() {
    DeviceInfoCapability.androidInfo = AndroidDeviceInfo.fromMap({
      'version': {
        'codename': 'REL',
        'incremental': '1',
        'previewSdkInt': 0,
        'release': '14',
        'sdkInt': 34,
      },
      'board': '',
      'bootloader': '',
      'brand': '',
      'device': '',
      'display': '',
      'fingerprint': '',
      'hardware': '',
      'host': '',
      'id': '',
      'manufacturer': '',
      'model': '',
      'product': '',
      'tags': '',
      'type': '',
      'isPhysicalDevice': false,
      'systemFeatures': ['android.software.leanback'],
      'serialNumber': '',
      'isLowRamDevice': false,
      'freeDiskSize': 0,
      'totalDiskSize': 0,
      'physicalRamSize': 0,
      'availableRamSize': 0,
    });
  });

  ensemble.ListView scrollbarList(Map<String, dynamic> scrollbarOptions) {
    final widget = ensemble.ListView();
    widget.initChildren(
      itemTemplate: {
        'data': List.generate(60, (i) => i),
        'name': 'row',
        'template': {
          'Text': {'text': 'Row'},
        },
      },
    );
    widget.setProperty('backgroundColor', '0xFF232323');
    widget.setProperty('borderRadius', 9);
    widget.setProperty('tvOptions', {
      'row': 1,
      'scrollbarOptions': {
        'width': 3,
        'focusedWidth': 6,
        ...scrollbarOptions,
      },
    });
    return widget;
  }

  Future<void> pump(WidgetTester tester, ensemble.ListView widget) async {
    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(height: 300, width: 200, child: widget),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  Finder box() => find.byWidgetPredicate((w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).color == _boxColor);

  Finder scrollbarInkWell() => find.descendant(
      of: find.byType(TVScrollbarWidget), matching: find.byType(InkWell));

  testWidgets('scrollbar stays inside the box by default', (tester) async {
    await pump(tester, scrollbarList({}));

    expect(find.byType(TVScrollbarWidget), findsOneWidget);
    expect(find.ancestor(of: find.byType(TVScrollbarWidget), matching: box()),
        findsOneWidget);
    expect(tester.getSize(box()).width, 200);
    expect(tester.widget<InkWell>(scrollbarInkWell()).focusColor, isNull);
  });

  testWidgets('focusHighlightColor is passed to the scrollbar InkWell',
      (tester) async {
    await pump(tester, scrollbarList({'focusHighlightColor': 'transparent'}));

    expect(tester.widget<InkWell>(scrollbarInkWell()).focusColor,
        Colors.transparent);
  });

  testWidgets('unknown placement falls back to inside', (tester) async {
    await pump(tester, scrollbarList({'placement': 'sideways', 'gap': 4}));

    expect(find.ancestor(of: find.byType(TVScrollbarWidget), matching: box()),
        findsOneWidget);
    expect(tester.getSize(box()).width, 200);
  });

  testWidgets('placement outside puts the scrollbar beside the box after gap',
      (tester) async {
    await pump(tester, scrollbarList({'placement': 'outside', 'gap': 4}));

    expect(find.byType(TVScrollbarWidget), findsOneWidget);
    expect(find.ancestor(of: find.byType(TVScrollbarWidget), matching: box()),
        findsNothing);

    final boxRect = tester.getRect(box());
    final barRect = tester.getRect(scrollbarInkWell());
    expect(boxRect.width, 200 - 4 - 6);
    expect(barRect.left, boxRect.right + 4);
    expect(barRect.height, boxRect.height);
  });

  testWidgets('outside box keeps its width when the scrollbar takes focus',
      (tester) async {
    await pump(tester, scrollbarList({'placement': 'outside', 'gap': 4}));
    final before = tester.getRect(box());
    expect(before.width, 200 - 4 - 6);

    final state =
        tester.state<TVScrollbarWidgetState>(find.byType(TVScrollbarWidget));
    state.requestFocusOnScrollbar();
    await tester.pumpAndSettle();

    expect(tester.getSize(scrollbarInkWell()).width, 6);
    expect(tester.getRect(box()), before);
  });

  // 30 rows of focus-only cells (TV row, no onTap), like match events.
  ensemble.ListView focusOnlyRowsList(
      {int columns = 1, String position = 'right'}) {
    final widget = ensemble.ListView();
    widget.initChildren(
      itemTemplate: {
        'data': List.generate(30, (i) => i),
        'name': 'row',
        'template': YamlMap.wrap({
          'Row': {
            'children': [
              for (var c = 0; c < columns; c++)
                {
                  'Column': {
                    'styles': {
                      'width': 90,
                      'height': 50,
                      'backgroundColor': '0xFF333333',
                      'tvOptions': {'row': r'${row}', 'order': c},
                    },
                    'children': [
                      {
                        'Text': {'text': 'Cell $c/\${row}'},
                      },
                    ],
                  },
                },
            ],
          },
        }),
      },
    );
    widget.setProperty('tvOptions', {
      'scrollbarOptions': {'position': position},
    });
    return widget;
  }

  bool focusIsOnRow(WidgetTester tester, String text) {
    final focused = tester.binding.focusManager.primaryFocus?.context;
    return focused != null &&
        find
            .descendant(
                of: find.byElementPredicate((e) => identical(e, focused)),
                matching: find.text(text))
            .evaluate()
            .isNotEmpty;
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  testWidgets('LEFT on the scrollbar returns to the row it was entered from',
      (tester) async {
    await pump(tester, focusOnlyRowsList());
    final row1 = tester.binding.focusManager.rootScope.descendants
        .where((node) => node.debugLabel == 'TVFocusOnlyWrapper')
        .firstWhere((node) => node.rect.top >= 50);
    row1.requestFocus();
    await tester.pumpAndSettle();
    expect(focusIsOnRow(tester, 'Cell 0/1'), isTrue);

    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(tester.binding.focusManager.primaryFocus?.debugLabel, 'TVScrollbar');

    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(focusIsOnRow(tester, 'Cell 0/1'), isTrue);
  });

  testWidgets('LEFT after scrolling with the scrollbar focuses a visible row',
      (tester) async {
    await pump(tester, focusOnlyRowsList());
    tester.binding.focusManager.rootScope.descendants
        .firstWhere((node) => node.debugLabel == 'TVFocusOnlyWrapper')
        .requestFocus();
    await tester.pumpAndSettle();

    await press(tester, LogicalKeyboardKey.arrowRight);
    // Each DOWN scrolls 60px (20% of 300): Row 4 is then the top full row.
    for (var i = 0; i < 3; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    await press(tester, LogicalKeyboardKey.arrowLeft);

    expect(focusIsOnRow(tester, 'Cell 0/4'), isTrue);
  });

  testWidgets('LEFT after scrolling prefers the visible cell nearest the bar',
      (tester) async {
    await pump(tester, focusOnlyRowsList(columns: 2));
    tester.binding.focusManager.rootScope.descendants
        .firstWhere((node) => node.debugLabel == 'TVFocusOnlyWrapper')
        .requestFocus();
    await tester.pumpAndSettle();

    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focusIsOnRow(tester, 'Cell 1/0'), isTrue);
    await press(tester, LogicalKeyboardKey.arrowRight);
    for (var i = 0; i < 3; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    await press(tester, LogicalKeyboardKey.arrowLeft);

    expect(focusIsOnRow(tester, 'Cell 1/4'), isTrue);
  });

  testWidgets('LEFT after the entered row was disposed focuses a visible row',
      (tester) async {
    await pump(tester, focusOnlyRowsList());
    final row0 = tester.binding.focusManager.rootScope.descendants
        .firstWhere((node) => node.debugLabel == 'TVFocusOnlyWrapper');
    row0.requestFocus();
    await tester.pumpAndSettle();

    await press(tester, LogicalKeyboardKey.arrowRight);
    // 600px: Row 11 is the top full row and Row 0 is past the cache extent.
    for (var i = 0; i < 10; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(row0.context?.mounted, isNot(true));
    await press(tester, LogicalKeyboardKey.arrowLeft);

    expect(focusIsOnRow(tester, 'Cell 0/11'), isTrue);
  });

  testWidgets('RIGHT on a left scrollbar returns to the row it was entered from',
      (tester) async {
    await pump(tester, focusOnlyRowsList(position: 'left'));
    final row1 = tester.binding.focusManager.rootScope.descendants
        .where((node) => node.debugLabel == 'TVFocusOnlyWrapper')
        .firstWhere((node) => node.rect.top >= 50);
    row1.requestFocus();
    await tester.pumpAndSettle();

    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(tester.binding.focusManager.primaryFocus?.debugLabel, 'TVScrollbar');

    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focusIsOnRow(tester, 'Cell 0/1'), isTrue);
  });

  testWidgets('outside with position left places the scrollbar first',
      (tester) async {
    await pump(tester,
        scrollbarList({'placement': 'outside', 'gap': 4, 'position': 'left'}));

    final boxRect = tester.getRect(box());
    final barRect = tester.getRect(scrollbarInkWell());
    expect(barRect.right, lessThanOrEqualTo(boxRect.left - 4));
    expect(boxRect.right, 200);
  });
}
