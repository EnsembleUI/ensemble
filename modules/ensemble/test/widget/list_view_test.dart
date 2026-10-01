import 'package:ensemble/layout/list_view.dart' as ensemble;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

void main() {
  ensemble.ListView listViewWithItemTemplate({String? direction}) {
    final widget = ensemble.ListView();
    widget.initChildren(
      itemTemplate: {
        'data': [1, 2],
        'name': 'row',
        'template': {
          'Text': {'text': 'Cell'},
        },
      },
    );
    if (direction != null) {
      widget.setProperty('direction', direction);
    }
    return widget;
  }

  Axis scrollDirection(WidgetTester tester) {
    return tester
        .widget<CustomScrollView>(find.byType(CustomScrollView).first)
        .scrollDirection;
  }

  Future<void> pumpListView(WidgetTester tester, ensemble.ListView widget) {
    return tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      SizedBox(
        height: 400,
        width: 400,
        child: widget,
      ),
    ));
  }

  testWidgets('defaults to vertical scroll direction', (tester) async {
    await pumpListView(tester, listViewWithItemTemplate());
    await tester.pump();

    expect(scrollDirection(tester), Axis.vertical);
  });

  testWidgets('supports horizontal scroll direction', (tester) async {
    await pumpListView(
        tester, listViewWithItemTemplate(direction: 'horizontal'));
    await tester.pump();

    expect(scrollDirection(tester), Axis.horizontal);
  });

  testWidgets('supports explicit vertical scroll direction', (tester) async {
    await pumpListView(tester, listViewWithItemTemplate(direction: 'vertical'));
    await tester.pump();

    expect(scrollDirection(tester), Axis.vertical);
  });
}
