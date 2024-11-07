import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/tab/tab_bar_controller.dart';
import 'package:ensemble/layout/tab_bar.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;

abstract class BaseTabBarState extends EWidgetState<BaseTabBar>
    with TickerProviderStateMixin, TabBarAction {
  late TabController tabController;

  // execute when a tab has (already) changed. Use this to run extra logic (and don't modify the tabController again
  void onTabChanged(int index);

  /// Common method to evaluate visibility conditions
  bool evaluateCondition(ScopeManager scopeManager, String expression) {
    try {
      final expression0 = scopeManager.dataContext.eval(expression);
      return expression0 is bool ? expression0 : false;
    } catch (e) {
      throw LanguageError('Failed to eval $expression');
    }
  }
  
  /// build the Tab Bar navigation part
  Widget buildTabBar() {
    TextStyle? tabStyle = TextStyle(
        fontSize: widget.controller.tabFontSize?.toDouble(),
        fontWeight: widget.controller.tabFontWeight);

    EdgeInsets labelPadding = widget.controller.tabPadding ??
        const EdgeInsets.only(left: 0, right: 30, top: 0, bottom: 0);
    // default indicator is finicky and doesn't line up when label has padding.
    // Also we shouldn't allow vertical padding for indicator

    // It's disabled due to underline indicator shrinking problem
    // EdgeInsets indicatorPadding = const EdgeInsets.only(bottom: 0);

    // TODO: center-align labels in its compact form
    // Only stretch or left-align currently
    bool labelPosition =
        widget.controller.tabPosition == 'stretch' ? false : true;

    double indicatorThickness =
        widget.controller.indicatorThickness?.toDouble() ?? 2;

    final indicatorSize =
        TabBarIndicatorSize.values.from(widget.controller.indicatorSize);
    final tabAlignment =
        TabAlignment.values.from(widget.controller.tabAlignment) ??
            TabAlignment.start;

    Widget tabBar = TabBar(
        labelPadding: labelPadding,
        dividerColor: widget.controller.dividerColor ?? Colors.transparent,
        indicator: indicatorThickness == 0
            ? BoxDecoration(
                color: widget.controller.activeTabBackgroundColor ??
                    Colors.transparent,
              )
            : UnderlineTabIndicator(
                borderSide: BorderSide(
                    width: indicatorThickness,
                    color: widget.controller.indicatorColor ??
                        Theme.of(context).colorScheme.primary),
              ),
        controller: tabController,
        isScrollable: labelPosition,
        tabAlignment: tabAlignment,
        indicatorSize: indicatorSize,
        labelStyle: tabStyle,
        labelColor: widget.controller.activeTabColor ??
            Theme.of(context).colorScheme.primary,
        unselectedLabelColor:
            widget.controller.inactiveTabColor ?? Colors.black87,
        tabs: _buildTabs(widget.controller.items),
        onTap: onTabChanged);

    if (widget.controller.tabBackgroundColor != null) {
      tabBar = ColoredBox(
          color: widget.controller.tabBackgroundColor!, child: tabBar);
    }

    if (widget.controller.borderRadius != null) {
      final borderRadius = widget.controller.borderRadius?.getValue();
      tabBar = ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: tabBar,
      );
    }

    return tabBar;
  }

  List<Widget> _buildTabs(List<TabItem> items) {
    List<Widget> tabItems = [];
    for (final tabItem in items) {
      ScopeManager? scopeManager = DataScopeWidget.getScope(context);
      tabItems.add(_buildTabWidget(scopeManager, tabItem));
    }
    return tabItems;
  }

  Widget _buildTabWidget(ScopeManager? scopeManager, TabItem tabItem) {
    final tabWidget = tabItem.tabWidget;
    if (scopeManager != null && tabWidget != null) {
      final customWidget = scopeManager.buildWidgetFromDefinition(tabWidget);
      return Tab(
        child: customWidget,
      );
    }
    return Tab(
      text: tabItem.label,
      icon:
          tabItem.icon != null ? ensemble.Icon.fromModel(tabItem.icon!) : null,
    );
  }
}

mixin TabBarAction on EWidgetState<BaseTabBar> {
  void changeTab(int index);
}
