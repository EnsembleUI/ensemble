import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/layout/tab/base_tab_bar.dart';
import 'package:ensemble/layout/tab/tab_bar_controller.dart';
import 'package:ensemble/layout/tab_bar.dart';
import 'package:ensemble/screen_controller.dart';
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
      'navigateTo': (index) => _controller.tabBarAction?.changeTab(index),
      // legacy
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
          EnsembleAction.from(action, initiator: this),
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
    _initializeTabController();
    _updateKeys();

    // Ensure scroll controller is attached before using its offset
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // this should avoid trying to access the offset before the controller is attached
      if (_scrollController.hasClients && _scrollController.offset <= 0) {
        _updateActiveTab();
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        _updateActiveTab();
      }
    });
  }

  void _initializeTabController() {
    tabController = TabController(
      length: widget.controller.items.length,
      vsync: this,
    );
  }

  void _reinitializeTabController() {
    tabController.dispose();
    _initializeTabController();
  }

  void _updateKeys() {
    _keys.clear();
    for (int i = 0; i < widget.controller.items.length; i++) {
      _keys.add(GlobalKey(debugLabel: "key$i"));
    }
  }

  @override
  void didUpdateWidget(covariant ScrollableTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.tabBarAction = this;
    widget.controller.items = oldWidget.controller.items;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.tabBarAction = this;

    final isConditional = widget.controller.originalItems
        .any((element) => element.isVisible != null);

    if (!isConditional) return;

    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    if (scopeManager == null) return;

    for (var item in widget.controller.originalItems) {
      if (item.isVisible == null || (item.isVisible is! EvaluateVisible)) {
        continue;
      }
      scopeManager.listen(
        scopeManager,
        (item.isVisible! as EvaluateVisible).value,
        destination: BindingDestination(widget, 'items'),
        onDataChange: (event) {
          if (mounted) {
            handleConditionalTabs();
          }
        },
      );
    }

    handleConditionalTabs();
  }

  void handleConditionalTabs() {
    ScopeManager? scopeManager = ScreenController().getScopeManager(context);
    if (scopeManager == null) return;

    final visibleItems = <TabItem>[];
    for (var item in widget.controller.originalItems) {
      if (item.isVisible == null) {
        visibleItems.add(item);
        continue;
      }

      bool isTrue = false;
      if (item.isVisible! is BoolVisible) {
        isTrue = (item.isVisible as BoolVisible).value;
      } else {
        isTrue = evaluateCondition(
            scopeManager, (item.isVisible as EvaluateVisible).value);
      }

      if (isTrue) {
        visibleItems.add(item);
      }
    }

    widget.controller.updateVisibleItems(visibleItems);
    _reinitializeTabController();
    _updateKeys();
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
    if (index < 0 || index >= _keys.length) {
      return; // Guard against invalid indices
    }

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
    if (!_scrollController.hasClients) {
      // this gets executed when navivate away from the screen and should avoid the offset error
      return;
    }
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
