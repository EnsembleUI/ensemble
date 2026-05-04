
import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';

import 'package:ensemble/layout/tab/base_tab_bar.dart';
import 'package:ensemble/layout/tab/tab_bar_controller.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

/// TabBar navigation only
class TabBarOnly extends BaseTabBar {
  static const type = 'TabBarOnly';
  TabBarOnly({super.key});
}

/// full TabBar container
class TabBarContainer extends BaseTabBar {
  static const type = 'TabBar';
  TabBarContainer({super.key});
}

abstract class BaseTabBar extends StatefulWidget
    with Invokable, HasController<TabBarController, TabBarState> {
  BaseTabBar({Key? key}) : super(key: key);

  final TabBarController _controller = TabBarController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => TabBarState();

  @override
  Map<String, Function> getters() {
    return {
      'selectedIndex': () => _controller.selectedIndex,
    };
  }

  @override
  List<String> passthroughSetters() => ['items'];

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
      'persistentTabBar': (value) =>
      _controller.persistentTabBar = Utils.getBool(value, fallback: false),
      'useIndexedTab': (value) =>
      _controller.useIndexedTab = Utils.getBool(value, fallback: false),
    };
  }
}

class TabBarState extends BaseTabBarState {
  // Cache for indexed tab building mode
  late List<Widget?> _cache;

  @override
  void initState() {
    super.initState();
    _initializeTabController();
  }

  void _initializeTabController() {
    final safeIndex = _getValidInitialIndex();
    if (widget.controller.useIndexedTab) {
      _cache = List<Widget?>.filled(widget.controller.items.length, null);
    }
    tabController = TabController(
      initialIndex: safeIndex,
      length: widget.controller.items.length,
      vsync: this,
    );
    tabController.addListener(notifyListener);
  }

  int _getValidInitialIndex() {
    // ensure the selectedIndex is valid, otherwise reset
    return widget._controller.selectedIndex < widget.controller.items.length
        ? widget._controller.selectedIndex
        : 0;
  }

  void notifyListener() {
    ScopeManager? scopeManager = ScreenController().getScopeManager(context);
    if (widget._controller.selectedIndex == tabController.index ||
        scopeManager == null ||
        widget._controller.id == null) return;
    scopeManager.dispatch(
      ModelChangeEvent(
        WidgetBindingSource(widget._controller.id!, property: 'selectedIndex'),
        tabController.index,
        bindingScope: scopeManager,
      ),
    );
  }

  @override
  void dispose() {
    tabController.removeListener(notifyListener);
    tabController.dispose();
    super.dispose();
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
  }

  void _reinitializeTabController() {
    tabController.removeListener(notifyListener);
    tabController.dispose();
    // If a tab became hidden and the previously-selected index is now out of
    // bounds, reset it before recreating the TabController and rebuilding,
    // otherwise buildSelectedTab() will throw a RangeError.
    if (widget._controller.selectedIndex >= widget._controller.items.length) {
      widget._controller.selectedIndex = 0;
    }
    _initializeTabController();
  }

  @override
  void didUpdateWidget(covariant BaseTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.tabBarAction = this;
    widget.controller.items = oldWidget.controller.items;
  }

  // extra logic when a tab has been changed
  @override
  void onTabChanged(int index) {
    if (widget.controller.selectedIndex == index) {
      return;
    }

    // If using indexed tab mode, build the tab on-demand before switching
    if (widget.controller.useIndexedTab) {
      final scopeManager = DataScopeWidget.getScope(context);
      if (scopeManager != null &&
          index < _cache.length &&
          _cache[index] == null) {
        final items = widget.controller.items;
        if (index < items.length) {
          _cache[index] = _buildTabAt(scopeManager, items[index]);
        }
      }
    }

    setState(() {
      widget.controller.selectedIndex = index;
    });
    if (widget.controller.onTabSelection != null) {
      if (widget.controller.onTabSelectionHaptic != null) {
        ScreenController().executeAction(
          context,
          HapticAction(
            type: widget.controller.onTabSelectionHaptic!,
            onComplete: null,
          ),
        );
      }
      ScreenController()
          .executeAction(context, widget.controller.onTabSelection!);
    }
  }

  // request to change tab programmatically
  @override
  void changeTab(int index) {
    if (widget._controller.selectedIndex == index) {
      return;
    }
    tabController.animateTo(index);
    setState(() {
      widget._controller.selectedIndex = index;
    });
  }

  /// override to handle Expanded properly
  @override
  Widget build(BuildContext context) {
    if (widget._controller.items.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget tabWidget;
    // only the TabBar
    if (widget is TabBarOnly) {
      tabWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [buildTabBar()]);
    }
    // TabBar + body container
    else {
      bool isExpanded = widget._controller.expanded;

      // if Expanded is set, our content needs to stretch to the left-over height
      // Note we make each Builder unique, as it tends to re-use
      // the states (down the tree) from the previous Builder
      // https://stackoverflow.com/questions/55425804/using-builder-instead-of-statelesswidget

      // Use indexed tab building if enabled, otherwise use classic single-tab rendering.
      Widget tabContent = widget._controller.useIndexedTab
          ? _buildTabBodies(context)
          : Builder(
        key: UniqueKey(),
        builder: (BuildContext context) {
          if (widget._controller.persistentTabBar) {
            return SingleChildScrollView(child: buildSelectedTab());
          }
          return buildSelectedTab();
        },
      );
      if (isExpanded) {
        tabContent = Expanded(child: tabContent);
      }

      tabWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildTabBar(),
          // builder gives us dynamic height control vs TabBarView, but
          // is sub-optimal since it recreates the tab content on each pass.
          // This means onLoad API may be called multiple times in debug mode
          tabContent,

          // This cause Expanded child to fail
          // Padding(
          //     padding: const EdgeInsets.only(left: 0),
          //     child: Builder(builder: (BuildContext context) => buildSelectedTab())
          // )
        ],
      );
      // if Expanded is set, stretch our column to left-over height
      if (isExpanded) {
        tabWidget = Expanded(child: tabWidget);
      }
    }

    if (widget._controller.margin != null) {
      tabWidget =
          Padding(padding: widget._controller.margin!, child: tabWidget);
    }

    return tabWidget;
  }

  /// we overwrote build() so no implementation here.
  @override
  Widget buildWidget(BuildContext context) {
    throw UnimplementedError();
  }

  Widget buildSelectedTab() {
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    if (scopeManager != null) {
      TabItem selectedTab =
      widget._controller.items[widget._controller.selectedIndex];
      return scopeManager.buildWidgetFromDefinition(selectedTab.bodyWidget);
    }
    return const Text("Unknown widget for this Tab");
  }

  /// Builds tabs on-demand with caching (used when useIndexedTab is true).
  /// - Non-expanded: Column + Offstage for hidden tabs (zero-height)
  /// - Expanded: IndexedStack (bounded height)
  Widget _buildTabBodies(BuildContext context) {
    final scopeManager = DataScopeWidget.getScope(context);
    if (scopeManager == null) return const Text('Unknown widget for this Tab');

    final items = widget._controller.items;
    final selectedIndex = widget._controller.selectedIndex;

    // Ensure cache size matches current item count
    if (_cache.length != items.length) {
      _cache = List<Widget?>.filled(items.length, null);
    }

    // Build the selected tab now if not already cached
    _cache[selectedIndex] ??= _buildTabAt(scopeManager, items[selectedIndex]);

    // Non-expanded: lives in unconstrained scroll context
    // Use Column + Offstage to zero-out hidden tabs
    if (!widget._controller.expanded) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(items.length, (i) {
          return Offstage(
            offstage: i != selectedIndex,
            child: _cache[i] ?? const SizedBox.shrink(),
          );
        }),
      );
    }

    // Expanded: bounded height is provided by Expanded wrapper
    // IndexedStack is safe here and stacks children in bounded space
    return IndexedStack(
      index: selectedIndex,
      children: List.generate(
        items.length,
            (i) => _cache[i] ?? const SizedBox.shrink(),
      ),
    );
  }

  /// Build a single tab at given index
  Widget _buildTabAt(ScopeManager scopeManager, TabItem tab) {
    if (tab.bodyWidget == null) return const SizedBox.shrink();
    return scopeManager.buildWidgetFromDefinition(tab.bodyWidget);
  }
}

