import 'package:device_info_plus/device_info_plus.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/tv/tv_scrollbar_widget.dart';
import 'package:ensemble/layout/list_view.dart' as ensemble;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('outside places the scrollbar beside the box after the gap',
      (tester) async {
    await pump(tester, scrollbarList({'outside': true, 'gap': 4}));

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
    await pump(tester, scrollbarList({'outside': true, 'gap': 4}));
    final before = tester.getRect(box());
    expect(before.width, 200 - 4 - 6);

    final state =
        tester.state<TVScrollbarWidgetState>(find.byType(TVScrollbarWidget));
    state.requestFocusOnScrollbar();
    await tester.pumpAndSettle();

    expect(tester.getSize(scrollbarInkWell()).width, 6);
    expect(tester.getRect(box()), before);
  });

  testWidgets('outside with position left places the scrollbar first',
      (tester) async {
    await pump(
        tester, scrollbarList({'outside': true, 'gap': 4, 'position': 'left'}));

    final boxRect = tester.getRect(box());
    final barRect = tester.getRect(scrollbarInkWell());
    expect(barRect.right, lessThanOrEqualTo(boxRect.left - 4));
    expect(boxRect.right, 200);
  });
}
