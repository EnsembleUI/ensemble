import 'package:ensemble/framework/action.dart';
import 'package:ensemble/layout/tab/base_tab_bar.dart';
import 'package:ensemble/layout/tab/tab_bar_controller.dart';
import 'package:ensemble/layout/tab_bar.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:developer';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;

class ScrollableTabBar extends BaseTabBar {
  static const type = 'ScrollableTabBar';

  @override
  State<StatefulWidget> createState() => ScrollableTabBarState();

  final _controller = TabBarController();

  @override
  TabBarController get controller => _controller;

  @override
  Map<String, Function> getters() {
    return {
      'selectedIndex': () => _controller.selectedIndex,
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'changeTabItem': (index) => _controller.tabBarAction?.changeTab(index),
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'id': (value) => _controller.id = Utils.optionalString(value),
      'tabPosition': (position) =>
          _controller.tabPosition = Utils.optionalString(position),
      'tabAlignment': (alignment) =>
          _controller.tabAlignment = Utils.optionalString(alignment),
      'indicatorSize': (type) =>
          _controller.indicatorSize = Utils.optionalString(type),
      'margin': (margin) => _controller.margin = Utils.optionalInsets(margin),
      'tabPadding': (padding) =>
          _controller.tabPadding = Utils.optionalInsets(padding),
      'tabFontSize': (fontSize) =>
          _controller.tabFontSize = Utils.optionalInt(fontSize),
      'tabFontWeight': (fontWeight) =>
          _controller.tabFontWeight = Utils.getFontWeight(fontWeight),
      'tabBackgroundColor': (bgColor) =>
          _controller.tabBackgroundColor = Utils.getColor(bgColor),
      'activeTabColor': (color) =>
          _controller.activeTabColor = Utils.getColor(color),
      'inactiveTabColor': (color) =>
          _controller.inactiveTabColor = Utils.getColor(color),
      'activeTabBackgroundColor': (color) =>
          _controller.activeTabBackgroundColor = Utils.getColor(color),
      'dividerColor': (color) =>
          _controller.dividerColor = Utils.getColor(color),
      'indicatorColor': (color) =>
          _controller.indicatorColor = Utils.getColor(color),
      'indicatorThickness': (thickness) =>
          _controller.indicatorThickness = Utils.optionalInt(thickness),
      'selectedIndex': (index) =>
          _controller.selectedIndex = Utils.getInt(index, min: 0, fallback: 0),
      'onTabSelection': (action) => _controller.onTabSelection =
          EnsembleAction.fromYaml(action, initiator: this),
      'onTabSelectionHaptic': (value) =>
          _controller.onTabSelectionHaptic = Utils.optionalString(value),
    };
  }
}

class ScrollableTabBarState extends BaseTabBarState {
  static const scrollAnimationDuration = 300;

  // manage the scrolling and which tab should be selected
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _keys = [];
  final Map<GlobalKey, double> _visibilityFractions = {};

  // when selecting a tab manually, use this to make sure the selectedTab calculation doesn't kick in
  bool _manualTabSelection = false;

  @override
  void initState() {
    super.initState();
    tabController =
        TabController(length: widget.controller.items.length, vsync: this);
    // create unique global keys for each tab for detecting scrolling into view, plus for manually scroll to view.
    for (int i = 0; i < widget.controller.items.length; i++) {
      _keys.add(GlobalKey(debugLabel: "key$i"));
    }
  }

  @override
  void dispose() {
    tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // changing the tab index by clicking on the TabBar
  @override
  void onTabChanged(int index) {
    _manualTabSelection = true;
    Scrollable.ensureVisible(_keys[index].currentContext!,
            duration: const Duration(milliseconds: scrollAnimationDuration))
        .then((_) {
      // delay by the same duration++ so onVisibilityChanged don't get triggered in between
      Future.delayed(
              const Duration(milliseconds: scrollAnimationDuration + 100))
          .then((_) {
        _manualTabSelection = false;
      });
    });
  }

  // request to change tab index programmatically
  @override
  void changeTab(int index) {
    // TODO: implement changeTab
  }

  Widget buildTabBody(TabItem item) {
    if (item.bodyWidget == null || scopeManager == null) {
      return const SizedBox.shrink();
    }
    return scopeManager!.buildWidgetFromDefinition(item.bodyWidget);
  }

  void onVisibilityChanged(VisibilityInfo info) {
    // ignore manual tab selection so we don't do extra work
    if (_manualTabSelection) {
      return;
    }
    log("onVisibility changed");
    // log('Widget ${info.key}. Fraction ${info.visibleFraction}. Bounds: ${info.visibleBounds.toString()}');
    _visibilityFractions[info.key as GlobalKey] = info.visibleFraction;
    _updateActiveTab();
  }

  void _updateActiveTab() {
    int selectedTab = 0;
    if (_scrollController.offset <= 0) {
      selectedTab = 0;
    } else if (_scrollController.offset >=
        _scrollController.position.maxScrollExtent) {
      selectedTab = tabController.length - 1;
    } else {
      // find tab indexes with the max fraction (should be identical if more than one e.g. 100%)
      double maxFraction = _visibilityFractions.values
          .fold(0.0, (prev, elem) => elem > prev ? elem : prev);
      List<int> maxVisibleTabs = _visibilityFractions.entries
          .where((entry) => entry.value == maxFraction)
          .map((entry) => _keys.indexOf(entry.key))
          .toList();

      if (maxVisibleTabs.isNotEmpty) {
        if (maxVisibleTabs.length == 1) {
          selectedTab = maxVisibleTabs[0];
        } else {
          bool isScrollingDown =
              _scrollController.position.userScrollDirection ==
                  ScrollDirection.forward;
          maxVisibleTabs.sort();
          // when scrolling down, probably make sense to pick the last entry with the highest fraction, and vice versa
          selectedTab =
              isScrollingDown ? maxVisibleTabs.last : maxVisibleTabs.first;
        }
      }
    }

    if (selectedTab != tabController.index) {
      log("Tab changed from ${tabController.index} to $selectedTab.");
      tabController.animateTo(selectedTab);
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    if (widget.controller.items.isEmpty) {
      return const SizedBox.shrink();
    }

    List<Widget> tabWidgets = [];
    for (int i = 0; i < widget.controller.items.length; i++) {
      tabWidgets.add(SliverToBoxAdapter(
          child: VisibilityDetector(
              key: _keys[i],
              onVisibilityChanged: onVisibilityChanged,
              child: buildTabBody(widget.controller.items[i]))));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      buildTabBar(),
      Expanded(
          child: CustomScrollView(
              controller: _scrollController, slivers: tabWidgets))
    ]);
  }

// @override
// Widget buildTabBar() {
//   return TabBar(
//       controller: tabController,
//       onTap: onTabChanged,
//       tabs: widget.controller.items.map((tabItem) {
//         return Tab(
//           icon: tabItem.icon == null
//               ? null
//               : ensemble.Icon.fromModel(tabItem.icon!),
//           text: tabItem.label,
//         );
//       }).toList(),
//
//       tabAlignment: TabAlignment.startOffset,
//       isScrollable: true,
//
//
//   );
// }
}
