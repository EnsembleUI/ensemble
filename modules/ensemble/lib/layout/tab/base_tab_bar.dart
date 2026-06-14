import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/tv/tv_focus_order.dart';
import 'package:ensemble/framework/tv/tv_focus_widget.dart';
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

  // common method for both scrollable and simple Tabbar
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
    // TV Navigation: Use custom focusable tab buttons instead of Flutter TabBar
    // This follows flutter_pca's pattern where each tab is an individually focusable button
    if (Device().isTV) {
      return _buildTVTabBar();
    }

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
      tabBar = Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.controller.borderColor ?? Colors.transparent, // Customize as needed
            width: (widget.controller.borderWidth ?? 0.0).toDouble(),
          ),
          borderRadius: borderRadius ?? BorderRadius.zero,
        ),
        child: ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.zero,
            child: tabBar
        ),
      );
    }

    return tabBar;
  }

  /// Build TV-specific tab bar with individually focusable buttons.
  /// Uses flutter_pca-style TVFocusOrder coordinates for navigation.
  ///
  /// If tvRow is set on the controller, tabs participate in the main page focus grid.
  /// Otherwise, tabs are wrapped in their own FocusTraversalGroup.
  Widget _buildTVTabBar() {
    final items = widget.controller.items;
    final activeColor = widget.controller.activeTabColor ??
        Theme.of(context).colorScheme.primary;
    final inactiveColor = widget.controller.inactiveTabColor ?? Colors.black87;
    final indicatorColor = widget.controller.indicatorColor ?? activeColor;
    final backgroundColor = widget.controller.tabBackgroundColor;
    final indicatorThickness =
        widget.controller.indicatorThickness?.toDouble() ?? 2;

    // If tvOptions.row is set, tabs participate in main page grid at that row
    // Otherwise, tabs use row 0 in an isolated FocusTraversalGroup
    final tvRow = widget.controller.tvOptions?.row;
    final tabRow = tvRow ?? 0.0;

    debugPrint('[TV TabBar] Building ${items.length} tab buttons (tvRow=${tvRow ?? "isolated"})');

    // Use AnimatedBuilder to rebuild tabs when selection changes
    // This mirrors Flutter's TabBar which listens to tabController.animation
    Widget tabBar = AnimatedBuilder(
      animation: tabController,
      builder: (context, child) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(items.length, (index) {
              final tabItem = items[index];

              return _TVTabButton(
                key: ValueKey('tv_tab_$index'),
                tabItem: tabItem,
                index: index,
                tabRow: tabRow,
                isSelected: tabController.index == index,
                autofocus: index == 0, // First tab gets autofocus
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                indicatorColor: indicatorColor,
                indicatorThickness: indicatorThickness,
                tabFontSize: widget.controller.tabFontSize?.toDouble(),
                tabFontWeight: widget.controller.tabFontWeight,
                tabPadding: widget.controller.tabPadding,
                onTap: () {
                  debugPrint('[TV TabBar] Tab $index tapped, switching content');
                  tabController.animateTo(index);
                  onTabChanged(index);
                },
              );
            }),
          ),
        );
      },
    );

    // If tvRow is NOT set, wrap tabs in their own FocusTraversalGroup
    // to isolate them from page content navigation.
    // If tvRow IS set, tabs participate in the main page focus grid.
    if (tvRow == null) {
      tabBar = FocusTraversalGroup(
        policy: TVFocusOrderTraversalPolicy(),
        child: tabBar,
      );
    }

    if (backgroundColor != null) {
      tabBar = ColoredBox(color: backgroundColor, child: tabBar);
    }

    if (widget.controller.borderRadius != null) {
      final borderRadius = widget.controller.borderRadius?.getValue();
      tabBar = Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.controller.borderColor ?? Colors.transparent,
            width: (widget.controller.borderWidth ?? 0.0).toDouble(),
          ),
          borderRadius: borderRadius ?? BorderRadius.zero,
        ),
        child: ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.zero,
            child: tabBar
        ),
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
    final label = scopeManager!.dataContext.eval(tabItem.label);
    if (scopeManager != null && tabWidget != null) {
      final customWidget = scopeManager.buildWidgetFromDefinition(tabWidget);
      return Tab(
        child: customWidget,
      );
    }
    return Tab(
      text: label,
      icon:
          tabItem.icon != null ? ensemble.Icon.fromModel(tabItem.icon!) : null,
    );
  }
}

mixin TabBarAction on EWidgetState<BaseTabBar> {
  void changeTab(int index);
}

/// TV-specific focusable tab button using flutter_pca-style navigation.
/// Each tab uses TVFocusOrder coordinates.
/// If TabBar has tvRow set, tabs use that row in the main page grid.
/// Otherwise, tabs use row 0 within an isolated FocusTraversalGroup.
class _TVTabButton extends StatefulWidget {
  const _TVTabButton({
    super.key,
    required this.tabItem,
    required this.index,
    required this.tabRow,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.indicatorColor,
    required this.indicatorThickness,
    required this.onTap,
    this.autofocus = false,
    this.tabFontSize,
    this.tabFontWeight,
    this.tabPadding,
  });

  final TabItem tabItem;
  final int index;
  final double tabRow;
  final bool isSelected;
  final bool autofocus;
  final Color activeColor;
  final Color inactiveColor;
  final Color indicatorColor;
  final double indicatorThickness;
  final VoidCallback onTap;
  final double? tabFontSize;
  final FontWeight? tabFontWeight;
  final EdgeInsets? tabPadding;

  @override
  State<_TVTabButton> createState() => _TVTabButtonState();
}

class _TVTabButtonState extends State<_TVTabButton> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'TVTabButton_${widget.index}');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.tabPadding ??
        const EdgeInsets.only(left: 0, right: 30, top: 0, bottom: 0);

    // Build the tab content with InkWell for focus support
    Widget inkWell = InkWell(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      // Disable visual effects - we use indicator instead
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      highlightColor: Colors.transparent,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      onTap: () {
        debugPrint('[TV TabBar] Tab ${widget.index} tapped');
        widget.onTap();
      },
      child: Builder(
        builder: (builderContext) {
          // Get focus state from InkWell's Focus
          final hasFocus = Focus.maybeOf(builderContext)?.hasFocus ?? false;
          if (hasFocus) {
            debugPrint('[TV TabBar] Tab ${widget.index} focused (isSelected=${widget.isSelected})');
          }
          return Container(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tab content (icon + label)
                _buildTabContent(context, hasFocus),
                const SizedBox(height: 4),
                // Indicator line (shows when selected or focused)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: widget.indicatorThickness,
                  width: hasFocus ? 24 : (widget.isSelected ? 16 : 0),
                  decoration: BoxDecoration(
                    color: hasFocus
                        ? Colors.blue
                        : widget.isSelected
                            ? widget.indicatorColor
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(widget.indicatorThickness / 2),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Wrap with TVFocusWidget for D-pad navigation.
    // Uses tabRow from TabBar controller (either tvRow from YAML or 0 for isolated group).
    // Order = index for left/right navigation.
    // The selected tab is marked as entry point so it gets focus when entering the row.
    return TVFocusWidget(
      focusOrder: TVFocusOrder.withOptions(
        widget.tabRow,
        order: widget.index.toDouble(),
        isRowEntryPoint: widget.isSelected, // selected tab is the entry point
      ),
      child: inkWell,
    );
  }

  Widget _buildTabContent(BuildContext context, bool isFocused) {
    final textColor = isFocused
        ? Colors.white
        : widget.isSelected
            ? widget.activeColor
            : widget.inactiveColor;

    final textStyle = TextStyle(
      fontSize: widget.tabFontSize ?? 14,
      fontWeight: widget.tabFontWeight ?? (widget.isSelected ? FontWeight.w600 : FontWeight.normal),
      color: textColor,
    );

    // Build icon if present
    Widget? iconWidget;
    if (widget.tabItem.icon != null) {
      iconWidget = ensemble.Icon.fromModel(widget.tabItem.icon!);
    }

    // Build label
    final label = widget.tabItem.label ?? '';

    if (iconWidget != null && label.isNotEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(width: 8),
          Text(label, style: textStyle),
        ],
      );
    } else if (iconWidget != null) {
      return iconWidget;
    } else {
      return Text(label, style: textStyle);
    }
  }
}
