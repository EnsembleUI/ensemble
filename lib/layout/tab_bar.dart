

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

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



abstract class BaseTabBar extends StatefulWidget with Invokable, HasController<TabBarController, TabBarState> {
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
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'tabPosition': (position) => _controller.tabPosition = Utils.optionalString(position),
      'margin': (margin) => _controller.margin = Utils.optionalInsets(margin),
      'tabPadding': (padding) => _controller.tabPadding = Utils.optionalInsets(padding),
      'tabFontSize': (fontSize) => _controller.tabFontSize = Utils.optionalInt(fontSize),
      'tabFontWeight': (fontWeight) => _controller.tabFontWeight = Utils.getFontWeight(fontWeight),
      'tabBackgroundColor': (bgColor) => _controller.tabBackgroundColor = Utils.getColor(bgColor),
      'activeTabColor': (color) => _controller.activeTabColor = Utils.getColor(color),
      'inactiveTabColor': (color) => _controller.inactiveTabColor = Utils.getColor(color),
      'indicatorColor': (color) => _controller.indicatorColor = Utils.getColor(color),
      'indicatorThickness': (thickness) => _controller.indicatorThickness = Utils.optionalInt(thickness),

      'selectedIndex': (index) => _controller.selectedIndex = Utils.getInt(index, fallback: 0),
      'onTabSelection': (action) => _controller.onTabSelection = Utils.getAction(action, initiator: this),
      'items': (items) => _controller.items = items,
    };
  }

}

class TabBarController extends WidgetController {
  String? tabPosition;
  EdgeInsets? margin;
  EdgeInsets? tabPadding;
  int? tabFontSize;
  FontWeight? tabFontWeight;
  Color? tabBackgroundColor;
  Color? activeTabColor;
  Color? inactiveTabColor;
  Color? indicatorColor;
  int? indicatorThickness;

  EnsembleAction? onTabSelection;


  int selectedIndex = 0;
  final List<TabItem> _items = [];

  set items(dynamic items) {
    if (items is YamlList) {
      for (YamlMap item in items) {
        _items.add(TabItem(
            Utils.getString(item['label'], fallback: ''),
            item['body'],
            icon: Utils.getIcon(item['icon']),
          )
        );
      }
    }
  }
}

class TabBarState extends WidgetState<BaseTabBar> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(
        initialIndex: widget._controller.selectedIndex,
        length: widget._controller._items.length,
        vsync: this
    );
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// override to handle Expanded properly
  @override
  Widget build(BuildContext context) {
    if (!widget._controller.visible || widget._controller._items.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget tabWidget;
    // only the TabBar
    if (widget is TabBarOnly) {
      tabWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildTabBar()
          ]
      );
    }
    // TabBar + body container
    else {
      bool isExpanded = widget._controller.expanded;

      // if Expanded is set, our content needs to stretch to the left-over height
      // Note we make each Builder unique, as it tends to re-use
      // the states (down the tree) from the previous Builder
      // https://stackoverflow.com/questions/55425804/using-builder-instead-of-statelesswidget
      Widget tabContent = Builder(key: UniqueKey(), builder: (BuildContext context) => buildSelectedTab());
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
          tabContent

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
      tabWidget = Padding(
        padding: widget._controller.margin!,
        child: tabWidget
      );
    }

    return tabWidget;
  }

  /// we overwrote build() so no implementation here.
  @override
  Widget buildWidget(BuildContext context) {
    throw UnimplementedError();
  }

  /// build the Tab Bar navigation part
  Widget buildTabBar() {
    TextStyle? tabStyle = TextStyle(
        fontSize: widget._controller.tabFontSize?.toDouble(),
        fontWeight: widget._controller.tabFontWeight
    );

    EdgeInsets labelPadding = widget._controller.tabPadding ?? const EdgeInsets.only(left: 0, right: 30, top: 0, bottom: 0);
    // default indicator is finicky and doesn't line up when label has padding.
    // Also we shouldn't allow vertical padding for indicator
    EdgeInsets indicatorPadding = EdgeInsets.only(left: labelPadding.left, right: labelPadding.right);

    // TODO: center-align labels in its compact form
    // Only stretch or left-align currently
    bool labelPosition = widget._controller.tabPosition == 'stretch' ? false : true;

    Widget tabBar = TabBar(
      labelPadding: labelPadding,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(
            width: widget._controller.indicatorThickness?.toDouble() ?? 2,
            color: widget._controller.indicatorColor ?? Theme.of(context).colorScheme.primary
        ),
        insets: indicatorPadding
      ),
      controller: _tabController,
      isScrollable: labelPosition,
      labelStyle: tabStyle,
      labelColor: widget._controller.activeTabColor ?? Theme.of(context).colorScheme.primary,
      unselectedLabelColor: widget._controller.inactiveTabColor ?? Colors.black87,

      tabs: widget._controller._items.map((e) => Tab(
          text: e.label,
          icon: e.icon != null ? ensemble.Icon.fromModel(e.icon!) : null)).toList(),
      onTap: (index) {
        setState(() {
          widget._controller.selectedIndex = index;
        });
        if (widget._controller.onTabSelection != null) {
          ScreenController().executeAction(context, widget._controller.onTabSelection!);
        }
      },
    );

    if (widget._controller.tabBackgroundColor != null) {
      return ColoredBox(
          color: widget._controller.tabBackgroundColor!,
          child: tabBar
      );
    }
    return tabBar;
  }

  Widget buildSelectedTab() {
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    if (scopeManager != null) {
      TabItem selectedTab = widget._controller._items[widget._controller.selectedIndex];
      return scopeManager.buildWidgetFromDefinition(selectedTab.body);
    }
    return const Text("Unknown widget for this Tab");
  }

}

class TabItem {
  TabItem(this.label, this.body, {this.icon});

  String label;
  dynamic body;
  IconModel? icon;

}