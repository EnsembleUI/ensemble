import 'package:ensemble/layout/tab/tab_bar_controller.dart';
import 'package:ensemble/layout/tab_bar.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:flutter/material.dart';
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
  testWidgets('TabBar item testId identifies and taps the tab', (tester) async {
    final tabBar = TabBarContainer();
    tabBar.setProperty(
        'items',
        YamlList.wrap([
          {
            'label': 'One',
            'body': {
              'Text': {'text': 'Tab One'},
            },
          },
          {
            'label': 'Two',
            'testId': 'secondTab',
            'body': {
              'Text': {'text': 'Tab Two'},
            },
          },
        ]));

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(tabBar));
    await tester.pumpAndSettle();

    final tabFinder = find.byKey(const ValueKey('secondTab'));
    expect(tabFinder, findsOneWidget);
    await tester.tap(tabFinder);
    await tester.pumpAndSettle();
    expect(find.text('Tab Two'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    tabBar.setProperty(
        'items',
        YamlList.wrap([
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

  testWidgets('preserves selected tab when a conditional tab is inserted',
      (tester) async {
    final tabBar = TabBarContainer();
    tabBar.setProperty(
        'items',
        YamlList.wrap([
          {
            'label': 'One',
            'body': {
              'Text': {'text': 'Tab One'},
            },
          },
          {
            'label': 'News',
            'visible': r'${state.showNews}',
            'body': {
              'Text': {'text': 'News'},
            },
          },
          {
            'label': 'Two',
            'body': {
              'Text': {'text': 'Tab Two'},
            },
          },
        ]));

    final mockBuildContext = MockBuildContext();
    final scopeManager = ScopeManager(
      DataContext(buildContext: mockBuildContext),
      PageData(),
    );
    scopeManager.dataContext.addDataContextById('state', {'showNews': false});

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DataScopeWidget(
          scopeManager: scopeManager,
          child: tabBar,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(find.text('Tab Two'), findsOneWidget);

    final state = {'showNews': true};
    scopeManager.dataContext.addDataContextById('state', state);
    scopeManager.dispatch(ModelChangeEvent(
      SimpleBindingSource('state'),
      state,
      bindingScope: scopeManager,
    ));
    await tester.pumpAndSettle();

    expect(tabBar.controller.selectedIndex, 2);
    expect(find.text('Tab Two'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the selected tab when the parent rebuilds its items',
      (tester) async {
    TabBarContainer buildTabs(bool showNews) {
      final tabBar = TabBarContainer();
      tabBar.setProperty(
          'items',
          YamlList.wrap([
            {
              'label': 'One',
              'body': {
                'Text': {'text': 'Tab One'},
              },
            },
            {
              'label': 'News',
              'visible': showNews,
              'body': {
                'Text': {'text': 'News'},
              },
            },
            {
              'label': 'Two',
              'testId': 'secondTab',
              'body': {
                'Text': {'text': 'Tab Two'},
              },
            },
          ]));
      tabBar.setProperty('useIndexedTab', true);
      return tabBar;
    }

    var showNews = false;
    StateSetter? updateParent;
    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      StatefulBuilder(builder: (context, setState) {
        updateParent = setState;
        return buildTabs(showNews);
      }),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('secondTab')));
    await tester.pumpAndSettle();
    expect(find.text('Tab Two'), findsOneWidget);

    // Rebuild with a newly inserted tab, like the app does when async data
    // makes its News tab visible.
    updateParent!(() => showNews = true);
    await tester.pumpAndSettle();

    expect(find.text('Tab Two'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rebuild refreshes cached indexed tab content', (tester) async {
    TabBarContainer buildTabs(String secondTabText) {
      final tabBar = TabBarContainer();
      tabBar.setProperty('useIndexedTab', true);
      tabBar.setProperty(
          'items',
          YamlList.wrap([
            {
              'label': 'One',
              'body': {
                'Text': {'text': 'Tab One'},
              },
            },
            {
              'label': 'Two',
              'testId': 'secondTab',
              'body': {
                'Text': {'text': secondTabText},
              },
            },
          ]));
      return tabBar;
    }

    var secondTabText = 'Original body';
    StateSetter? updateParent;
    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      StatefulBuilder(builder: (context, setState) {
        updateParent = setState;
        return buildTabs(secondTabText);
      }),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('secondTab')));
    await tester.pumpAndSettle();
    expect(find.text('Original body'), findsOneWidget);

    updateParent!(() => secondTabText = 'Updated body');
    await tester.pumpAndSettle();

    expect(find.text('Updated body'), findsOneWidget);
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

  test(
      'TabBar keeps legacy autofocus and accepts the existing autofocus option',
      () {
    final controller = TabBarController();

    expect(controller.autofocus, isTrue);

    controller.getBaseSetters()['autofocus']!(false);

    expect(controller.autofocus, isFalse);
  });

  test('TabBar does not reveal the whole bar unless enabled', () {
    final controller = TabBarController();

    expect(controller.revealTabBarOnFocus, isFalse);

    controller.getBaseSetters()['revealTabBarOnFocus']!(true);

    expect(controller.revealTabBarOnFocus, isTrue);
  });

  test('TabBar recognizes flex-based stretched layouts', () {
    final controller = TabBarController();

    expect(controller.isStretched, isFalse);

    controller.getBaseSetters()['flexMode']!('expanded');
    expect(controller.isStretched, isTrue);

    controller.getBaseSetters()['flexMode']!('none');
    expect(controller.isStretched, isFalse);
  });
}
