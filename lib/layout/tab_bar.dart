

import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/view.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

class EnsembleTabBar extends StatefulWidget with Invokable, HasController<TabBarController, TabBarState> {
  static const type = 'TabBar';
  EnsembleTabBar({Key? key}) : super(key: key);

  final TabBarController _controller = TabBarController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => TabBarState();

  @override
  Map<String, Function> getters() {
    return {};
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

class TabBarState extends WidgetState<EnsembleTabBar> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(length: widget._controller._items.length, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget buildWidget(BuildContext context) {
    if (widget._controller._items.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget rtn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildTabBar(),
        Padding(
            padding: const EdgeInsets.only(left: 0),
            // builder gives us dynamic height control vs TabBarView, but
            // is sub-optimal since it recreates the tab content on each pass.
            // This means onLoad API may be called multiple times in debug mode
            child: Builder(builder: (BuildContext context) => buildSelectedTab())
        )
      ],
    );

    if (widget._controller.margin != null) {
      rtn = Padding(
        padding: widget._controller.margin!,
        child: rtn
      );
    }

    return rtn;
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
      onTap: (index) => {
        setState(() {
          widget._controller.selectedIndex = index;
        })
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