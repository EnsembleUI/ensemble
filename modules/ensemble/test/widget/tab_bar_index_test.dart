import 'package:ensemble/layout/tab/tab_bar_controller.dart';
import 'package:ensemble/layout/tab_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'test_utils.dart';

YamlList twoTabItems() {
  return YamlList.wrap([
    {
      'label': 'One',
      'body': {
        'Text': {'text': 'Tab One'},
      },
    },
    {
      'label': 'Two',
      'body': {
        'Text': {'text': 'Tab Two'},
      },
    },
  ]);
}

void main() {
  testWidgets('useIndexedTab renders the selected tab body', (tester) async {
    final tabBar = TabBarContainer();
    tabBar.setProperty('items', twoTabItems());
    tabBar.setProperty('useIndexedTab', true);
    tabBar.setProperty('selectedIndex', 1);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(tabBar));
    await tester.pumpAndSettle();

    expect(find.text('Tab Two'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resets selectedIndex when visible items shrink below it',
      (tester) async {
    final tabBar = TabBarContainer();
    tabBar.setProperty('items', YamlList.wrap([
      {
        'label': 'Always',
        'body': {
          'Text': {'text': 'Always visible'},
        },
      },
      {
        'label': 'Hidden',
        'visible': false,
        'body': {
          'Text': {'text': 'Hidden tab'},
        },
      },
    ]));
    tabBar.setProperty('selectedIndex', 1);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(tabBar));
    await tester.pumpAndSettle();

    expect(tabBar.controller.selectedIndex, 0);
    expect(find.text('Always visible'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('TabBarController items setter accepts TabItem list', () {
    final controller = TabBarController();
    controller.items = [
      TabItem(
        label: 'A',
        bodyWidget: {
          'Text': {'text': 'A'},
        },
      ),
      TabItem(
        label: 'B',
        bodyWidget: {
          'Text': {'text': 'B'},
        },
      ),
    ];

    expect(controller.items, hasLength(2));
    expect(controller.items.first.label, 'A');
  });
}
