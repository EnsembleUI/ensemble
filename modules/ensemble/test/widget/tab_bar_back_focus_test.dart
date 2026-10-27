import 'package:ensemble/framework/device.dart';
import 'package:ensemble/layout/tab/tab_bar_controller.dart';
import 'package:ensemble/layout/tab_bar.dart';
import 'package:ensemble/widget/carousel.dart' as ensemble;
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'test_utils.dart';

/// TV focus label used by the tap-enabled box wrapper (`_TapEnabledWrapper`),
/// i.e. the focus node of a focusable widget inside a tab body.
const String bodyFocusLabelPrefix = 'TapEnabledWrapper_';

/// TV focus label used by each tab strip button.
const String tabButtonFocusLabelPrefix = 'TVTabButton_';

/// A focusable tab body: a tap-enabled Row with TV focus coordinates, so in TV
/// mode it gets a real focus node that can hold focus inside the tab content.
Map<String, dynamic> bodyDefinition(String text) => {
      'Row': {
        'styles': {
          'tvOptions': {'row': 9, 'order': 0},
        },
        // Never executed: the body only needs to be tap-enabled so TV mode
        // wraps it in a focusable node.
        'onTap': {'navigateBack': <String, dynamic>{}},
        'children': [
          {
            'Text': {'text': text},
          },
        ],
      },
    };

YamlList tabItems({int count = 3}) => YamlList.wrap([
      for (var i = 1; i <= count; i++)
        {
          'label': 'Tab $i',
          'body': bodyDefinition('Body $i'),
        },
    ]);

/// Every goBack event that reached an ancestor above the TabBar, i.e. that the
/// TabBar did not consume and that normal navigation would therefore receive.
class BackSpy {
  final List<KeyEvent> events = [];

  bool get sawKeyDown =>
      events.any((event) => event is KeyDownEvent);

  Widget wrap(Widget child) => Focus(
        onKeyEvent: (node, event) {
          if (event.logicalKey == LogicalKeyboardKey.goBack) {
            events.add(event);
          }
          return KeyEventResult.ignored;
        },
        child: child,
      );
}

FocusNode _nodeWithLabel(WidgetTester tester, String prefix) {
  return tester.binding.focusManager.rootScope.descendants.firstWhere(
      (node) => node.debugLabel?.startsWith(prefix) ?? false,
      orElse: () => throw StateError('no focus node labelled $prefix*'));
}

String? _primaryLabel(WidgetTester tester) =>
    tester.binding.focusManager.primaryFocus?.debugLabel;

Future<FocusNode> _focusBodyContent(WidgetTester tester) async {
  final node = _nodeWithLabel(tester, bodyFocusLabelPrefix);
  node.requestFocus();
  await tester.pump();
  return node;
}

Future<void> _pressBackDown(WidgetTester tester) => tester.sendKeyDownEvent(
      LogicalKeyboardKey.goBack,
      // Back has no counterpart in PhysicalKeyboardKey, so the simulator needs
      // an explicit physical key to build the event.
      physicalKey: PhysicalKeyboardKey.escape,
    );

Future<void> _repeatBack(WidgetTester tester) => tester.sendKeyRepeatEvent(
      LogicalKeyboardKey.goBack,
      physicalKey: PhysicalKeyboardKey.escape,
    );

Future<void> _releaseBack(WidgetTester tester) => tester.sendKeyUpEvent(
      LogicalKeyboardKey.goBack,
      physicalKey: PhysicalKeyboardKey.escape,
    );

void main() {
  setUp(() {
    // TabBar only builds its D-pad focusable strip on TV.
    Device.debugOverrideIsTV(true);
  });

  tearDown(() {
    Device.debugOverrideIsTV(null);
  });

  testWidgets('Back in tab content focuses the selected tab, not the page',
      (tester) async {
    final spy = BackSpy();
    final tabBar = TabBarContainer()
      ..setProperty('items', tabItems())
      ..setProperty('tabFocusOnBack', true);

    await tester.pumpWidget(
        TestUtils.wrapTestWidgetWithScope(spy.wrap(tabBar)));
    await tester.pumpAndSettle();

    await _focusBodyContent(tester);
    expect(_primaryLabel(tester), startsWith(bodyFocusLabelPrefix));

    await _pressBackDown(tester);

    // Focus returned to the (selected) tab strip and the press was consumed.
    expect(_primaryLabel(tester), '${tabButtonFocusLabelPrefix}0');
    expect(spy.events, isEmpty);

    // A held Back button may generate repeat downs after focus has moved.
    // They belong to this same physical press and must not escape to navigation.
    await _repeatBack(tester);
    expect(_primaryLabel(tester), '${tabButtonFocusLabelPrefix}0');
    expect(spy.events, isEmpty);

    await _releaseBack(tester);
    expect(_primaryLabel(tester), '${tabButtonFocusLabelPrefix}0');
    expect(spy.events, isEmpty);

    // Back did not select, reselect, or rebuild the tab.
    expect(tabBar.controller.selectedIndex, 0);
    expect(find.text('Body 1'), findsOneWidget);

    // The next Back press is on the strip, so the TabBar must not consume it:
    // the page keeps whatever Back behavior it already had.
    await _pressBackDown(tester);
    expect(spy.sawKeyDown, isTrue);
    expect(_primaryLabel(tester), '${tabButtonFocusLabelPrefix}0');
    expect(tabBar.controller.selectedIndex, 0);
    await _releaseBack(tester);
    expect(spy.events.whereType<KeyUpEvent>(), hasLength(1));
  });

  testWidgets('missed Back key-up does not prevent the next focus return',
      (tester) async {
    final spy = BackSpy();
    final outsideFocus = FocusNode(debugLabel: 'OutsideTabBar');
    addTearDown(outsideFocus.dispose);
    final tabBar = TabBarContainer()
      ..setProperty('items', tabItems())
      ..setProperty('tabFocusOnBack', true);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      spy.wrap(
        Column(
          children: [
            tabBar,
            Focus(focusNode: outsideFocus, child: const SizedBox(height: 20)),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await _focusBodyContent(tester);
    await _pressBackDown(tester);
    expect(_primaryLabel(tester), '${tabButtonFocusLabelPrefix}0');

    // Move outside the TabBar before release, so its sequence handler misses
    // the key-up and retains a stale handled flag.
    outsideFocus.requestFocus();
    await tester.pump();
    expect(outsideFocus.hasFocus, isTrue);
    await _releaseBack(tester);

    final deliveredDowns = spy.events.whereType<KeyDownEvent>().length;
    await _focusBodyContent(tester);
    await _pressBackDown(tester);

    // The fresh press clears the stale sequence and still receives ordinary
    // body handling instead of escaping to page navigation.
    expect(_primaryLabel(tester), '${tabButtonFocusLabelPrefix}0');
    expect(spy.events.whereType<KeyDownEvent>(), hasLength(deliveredDowns));
    await _releaseBack(tester);
  });

  testWidgets('Back in tab content targets the selected tab, not the focused one',
      (tester) async {
    final spy = BackSpy();
    final tabBar = TabBarContainer()
      ..setProperty('items', tabItems())
      // Autofocus lands on tab 0 while tab 2 is the selected tab.
      ..setProperty('autofocus', true)
      ..setProperty('selectedIndex', 2)
      ..setProperty('tabFocusOnBack', true);

    await tester.pumpWidget(
        TestUtils.wrapTestWidgetWithScope(spy.wrap(tabBar)));
    await tester.pumpAndSettle();

    expect(_primaryLabel(tester), '${tabButtonFocusLabelPrefix}0');

    await _focusBodyContent(tester);
    await _pressBackDown(tester);

    expect(_primaryLabel(tester), '${tabButtonFocusLabelPrefix}2');
    expect(tabBar.controller.selectedIndex, 2);
    expect(find.text('Body 3'), findsOneWidget);
  });

  testWidgets('Back in tab content targets a tab selected at runtime',
      (tester) async {
    final spy = BackSpy();
    final tabBar = TabBarContainer()
      ..setProperty('items', tabItems())
      ..setProperty('tabFocusOnBack', true);

    await tester.pumpWidget(
        TestUtils.wrapTestWidgetWithScope(spy.wrap(tabBar)));
    await tester.pumpAndSettle();

    final state = tester.state<TabBarState>(find.byType(TabBarContainer));
    state.changeTab(2);
    await tester.pumpAndSettle();
    expect(find.text('Body 3'), findsOneWidget);

    await _focusBodyContent(tester);
    await _pressBackDown(tester);

    expect(_primaryLabel(tester), '${tabButtonFocusLabelPrefix}2');
    expect(tabBar.controller.selectedIndex, 2);
    expect(spy.events, isEmpty);
  });

  testWidgets('Back ignores repeats, key-up and other keys', (tester) async {
    final spy = BackSpy();
    final tabBar = TabBarContainer()
      ..setProperty('items', tabItems())
      ..setProperty('tabFocusOnBack', true);

    await tester.pumpWidget(
        TestUtils.wrapTestWidgetWithScope(spy.wrap(tabBar)));
    await tester.pumpAndSettle();

    final state = tester.state<TabBarState>(find.byType(TabBarContainer));
    await _focusBodyContent(tester);

    expect(state.handleTabBodyBackKey(const KeyRepeatEvent(
      logicalKey: LogicalKeyboardKey.goBack,
      physicalKey: PhysicalKeyboardKey.escape,
      timeStamp: Duration.zero,
    )), KeyEventResult.ignored);
    expect(_primaryLabel(tester), startsWith(bodyFocusLabelPrefix));

    expect(state.handleTabBodyBackKey(const KeyUpEvent(
      logicalKey: LogicalKeyboardKey.goBack,
      physicalKey: PhysicalKeyboardKey.escape,
      timeStamp: Duration.zero,
    )), KeyEventResult.ignored);
    expect(_primaryLabel(tester), startsWith(bodyFocusLabelPrefix));

    expect(state.handleTabBodyBackKey(const KeyDownEvent(
      logicalKey: LogicalKeyboardKey.escape,
      physicalKey: PhysicalKeyboardKey.escape,
      timeStamp: Duration.zero,
    )), KeyEventResult.ignored);
    expect(_primaryLabel(tester), startsWith(bodyFocusLabelPrefix));

    expect(state.handleTabBodyBackKey(const KeyUpEvent(
      logicalKey: LogicalKeyboardKey.goBack,
      physicalKey: PhysicalKeyboardKey.escape,
      timeStamp: Duration.zero,
    )), KeyEventResult.ignored);

    // Only the plain Back key-down moves focus.
    expect(state.handleTabBodyBackKey(const KeyDownEvent(
      logicalKey: LogicalKeyboardKey.goBack,
      physicalKey: PhysicalKeyboardKey.escape,
      timeStamp: Duration.zero,
    )), KeyEventResult.handled);
    // Focus changes are applied by the focus manager on the next frame.
    await tester.pump();
    expect(_primaryLabel(tester), '${tabButtonFocusLabelPrefix}0');
  });

  testWidgets('Default behavior leaves Back inside tab content untouched',
      (tester) async {
    final spy = BackSpy();
    final tabBar = TabBarContainer()..setProperty('items', tabItems());

    await tester.pumpWidget(
        TestUtils.wrapTestWidgetWithScope(spy.wrap(tabBar)));
    await tester.pumpAndSettle();

    expect(tabBar.controller.tabFocusOnBack, isFalse);

    await _focusBodyContent(tester);
    await _pressBackDown(tester);

    expect(spy.sawKeyDown, isTrue);
    expect(_primaryLabel(tester), startsWith(bodyFocusLabelPrefix));
  });

  testWidgets('Hidden tabs are never targeted', (tester) async {
    final spy = BackSpy();
    final tabBar = TabBarContainer()
      ..setProperty(
          'items',
          YamlList.wrap([
            {
              'label': 'Always',
              'body': bodyDefinition('Body always'),
            },
            {
              'label': 'Hidden',
              'visible': false,
              'body': bodyDefinition('Body hidden'),
            },
            {
              'label': 'Last',
              'body': bodyDefinition('Body last'),
            },
          ]))
      ..setProperty('selectedIndex', 1)
      ..setProperty('tabFocusOnBack', true);

    await tester.pumpWidget(
        TestUtils.wrapTestWidgetWithScope(spy.wrap(tabBar)));
    await tester.pumpAndSettle();

    // Visible index 1 is 'Last'; the hidden tab must not shift focus.
    expect(find.text('Body last'), findsOneWidget);
    expect(find.text('Hidden'), findsNothing);

    await _focusBodyContent(tester);
    await _pressBackDown(tester);

    expect(_primaryLabel(tester), '${tabButtonFocusLabelPrefix}1');
    expect(find.text('Hidden'), findsNothing);
  });

  testWidgets('Back-to-selected-tab is inert when the strip is not TV focusable',
      (tester) async {
    // Non-TV: no D-pad strip is built, so Back must reach the platform as
    // before even when the option is enabled.
    Device.debugOverrideIsTV(false);

    final spy = BackSpy();
    final tabBar = TabBarContainer()
      ..setProperty('items', tabItems())
      ..setProperty('tabFocusOnBack', true);

    await tester.pumpWidget(
        TestUtils.wrapTestWidgetWithScope(spy.wrap(tabBar)));
    await tester.pumpAndSettle();

    final state = tester.state<TabBarState>(find.byType(TabBarContainer));
    expect(state.focusSelectedTab(), isFalse);
    expect(state.handleTabBodyBackKey(const KeyDownEvent(
      logicalKey: LogicalKeyboardKey.goBack,
      physicalKey: PhysicalKeyboardKey.escape,
      timeStamp: Duration.zero,
    )), KeyEventResult.ignored);
    expect(find.text('Body 1'), findsOneWidget);
  });

  testWidgets('Back reveals the selected tab when the strip has scrolled away',
      (tester) async {
    final spy = BackSpy();
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final tabBar = TabBarContainer()
      ..setProperty('items', tabItems())
      ..setProperty('tabFocusOnBack', true);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      spy.wrap(
        SizedBox(
          height: 400,
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                tabBar,
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Focus starts inside the content and the user scrolls the page down, so
    // the strip is no longer on screen.
    await _focusBodyContent(tester);
    await tester.pumpAndSettle();
    scrollController.jumpTo(500);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Tab 1')).top, lessThan(0));

    await _pressBackDown(tester);
    await tester.pumpAndSettle();

    expect(_primaryLabel(tester), '${tabButtonFocusLabelPrefix}0');
    // The strip is revealed, so the focus ring is actually visible.
    expect(tester.getRect(find.text('Tab 1')).top, greaterThanOrEqualTo(0));
  });

  testWidgets('Back scrolls the tab content back to its top', (tester) async {
    final spy = BackSpy();
    final page = ScrollController();
    addTearDown(page.dispose);
    final tabBar = TabBarContainer()
      ..setProperty(
          'items',
          YamlList.wrap([
            {
              'label': 'Tab 1',
              'body': {
                'Column': {
                  'styles': {'scrollable': true},
                  'children': [
                    {
                      'Spacer': {'styles': {'size': 1500}},
                    },
                    {
                      'Row': {
                        'styles': {'scrollable': true},
                        'children': [
                          {'Spacer': {'styles': {'size': 1500}}},
                          bodyDefinition('Bottom'),
                        ],
                      },
                    },
                  ],
                },
              },
            },
          ]))
      ..setProperty('expanded', true)
      ..setProperty('tabFocusOnBack', true);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      spy.wrap(SizedBox(
        height: 400,
        child: SingleChildScrollView(
          controller: page,
          child: Column(children: [
            const SizedBox(height: 100),
            SizedBox(height: 300, child: Column(children: [tabBar])),
            const SizedBox(height: 1000),
          ]),
        ),
      )),
    ));
    await tester.pumpAndSettle();

    final scrollables = tester.stateList<ScrollableState>(find.descendant(
        of: find.byType(TabBarContainer),
        matching: find.byType(Scrollable)));
    final content = scrollables.firstWhere((state) =>
        axisDirectionToAxis(state.axisDirection) == Axis.vertical);
    final lane = scrollables.lastWhere((state) =>
        axisDirectionToAxis(state.axisDirection) == Axis.horizontal);

    await _focusBodyContent(tester);
    lane.position.jumpTo(lane.position.maxScrollExtent);
    content.position.jumpTo(content.position.maxScrollExtent);
    page.jumpTo(50);
    await tester.pumpAndSettle();
    expect(content.position.pixels, greaterThan(0));
    expect(lane.position.pixels, greaterThan(0));

    await _pressBackDown(tester);
    await tester.pumpAndSettle();

    expect(_primaryLabel(tester), '${tabButtonFocusLabelPrefix}0');
    expect(content.position.pixels, content.position.minScrollExtent);
    expect(lane.position.pixels, lane.position.maxScrollExtent);
    expect(page.offset, 50);
    expect(spy.events, isEmpty);
  });

  testWidgets('Back leaves a vertical carousel on its selected slide',
      (tester) async {
    final tabBar = TabBarContainer()
      ..setProperty(
          'items',
          YamlList.wrap([
            {
              'label': 'Tab 1',
              'body': {
                'Carousel': {
                  'styles': {
                    'layout': 'single',
                    'direction': 'vertical',
                    'height': 250,
                    'enableLoop': false,
                  },
                  'children': [
                    bodyDefinition('Slide 1'),
                    bodyDefinition('Slide 2'),
                  ],
                },
              },
            },
          ]))
      ..setProperty('tabFocusOnBack', true);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(tabBar));
    await tester.pumpAndSettle();

    final carousel = tester.widget<ensemble.Carousel>(find.byType(ensemble.Carousel));
    final pager = tester.stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((state) => state.position is PageMetrics);
    pager.position.jumpTo(pager.position.viewportDimension);
    await tester.pumpAndSettle();
    final slideFocus = tester
        .widgetList<InkWell>(find.ancestor(
            of: find.text('Slide 2'), matching: find.byType(InkWell)))
        .firstWhere((widget) => widget.focusNode != null)
        .focusNode!;
    slideFocus.requestFocus();
    await tester.pumpAndSettle();
    expect(carousel.controller.currentIndex, 1);

    await _pressBackDown(tester);
    await tester.pumpAndSettle();

    expect(_primaryLabel(tester), '${tabButtonFocusLabelPrefix}0');
    expect(carousel.controller.currentIndex, 1);
    expect((pager.position as PageMetrics).page, closeTo(1, 0.01));
  });

  testWidgets('Back works with indexed tab content', (tester) async {
    final spy = BackSpy();
    final tabBar = TabBarContainer()
      ..setProperty('items', tabItems())
      ..setProperty('useIndexedTab', true)
      ..setProperty('tabFocusOnBack', true);

    await tester.pumpWidget(
        TestUtils.wrapTestWidgetWithScope(spy.wrap(tabBar)));
    await tester.pumpAndSettle();

    await _focusBodyContent(tester);
    await _pressBackDown(tester);

    expect(_primaryLabel(tester), '${tabButtonFocusLabelPrefix}0');
    expect(spy.events, isEmpty);
  });

  testWidgets('expanded Back-enabled TabBar keeps its Flex layout',
      (tester) async {
    final spy = BackSpy();
    final tabBar = TabBarContainer()
      ..setProperty('items', tabItems())
      ..setProperty('expanded', true)
      ..setProperty('tabFocusOnBack', true);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      spy.wrap(Column(children: [tabBar])),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tab 1'), findsOneWidget);
    expect(find.text('Body 1'), findsOneWidget);

    await _focusBodyContent(tester);
    await _pressBackDown(tester);
    expect(_primaryLabel(tester), '${tabButtonFocusLabelPrefix}0');
    expect(spy.events, isEmpty);
    await _releaseBack(tester);
    expect(spy.events, isEmpty);

    // A distinct second physical press remains available for page navigation.
    await _pressBackDown(tester);
    expect(spy.sawKeyDown, isTrue);
    await _releaseBack(tester);
  });

  testWidgets('Registry drops tab nodes that disappear at runtime',
      (tester) async {
    final spy = BackSpy();
    final tabBar = TabBarContainer()
      ..setProperty('items', tabItems())
      ..setProperty('selectedIndex', 2)
      ..setProperty('tabFocusOnBack', true);

    await tester.pumpWidget(
        TestUtils.wrapTestWidgetWithScope(spy.wrap(tabBar)));
    await tester.pumpAndSettle();

    final state = tester.state<TabBarState>(find.byType(TabBarContainer));

    // Hide the last tab while the page is live.
    tabBar.controller.originalItems[2].isVisible = BoolVisible(false);
    state.handleConditionalTabs();
    await tester.pumpAndSettle();

    expect(find.text('Tab 3'), findsNothing);
    // The out-of-range selection falls back to the first tab.
    expect(tabBar.controller.selectedIndex, 0);

    await _focusBodyContent(tester);
    await _pressBackDown(tester);

    // Focuses a live tab rather than a disposed node from the removed tab.
    expect(tester.takeException(), isNull);
    expect(_primaryLabel(tester), '${tabButtonFocusLabelPrefix}0');
  });

  test('Back-to-selected-tab is opt-in and off by default', () {
    final controller = TabBarController();

    expect(controller.tabFocusOnBack, isFalse);

    controller.getBaseSetters()['tabFocusOnBack']!(true);
    expect(controller.tabFocusOnBack, isTrue);
  });

  test('Back-to-selected-tab resolves from styles like other TV options', () {
    final tabBar = TabBarContainer();

    // `styles:` keys are applied through the widget's settable properties, so
    // the option must be listed there to be usable from YAML.
    expect(Invokable.getSettableProperties(tabBar),
        contains('tabFocusOnBack'));
  });
}
