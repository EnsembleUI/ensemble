

import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/view.dart';
import 'package:ensemble/framework/widget/widget.dart';
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
      'selectedIndex': (index) => _controller.selectedIndex = Utils.getInt(index, fallback: 0),
      'items': (items) => _controller.items = items,
    };
  }

}

class TabBarController extends WidgetController {
  int selectedIndex = 0;
  final List<TabItem> _items = [];

  set items(dynamic items) {
    if (items is YamlList) {
      for (YamlMap item in items) {
        _items.add(TabItem(item['label'], item['body']));
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
  Widget build(BuildContext context) {
    if (widget._controller._items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,         // collapse the label to the left
          indicatorSize: TabBarIndicatorSize.label,
          unselectedLabelColor: Colors.black87,
          labelColor: Theme.of(context).colorScheme.primary,
          tabs: widget._controller._items.map((e) => Tab(text: e.label)).toList(),
          onTap: (index) => {
            setState(() {
              widget._controller.selectedIndex = index;
            })
          },
        ),
        Padding(
            padding: const EdgeInsets.only(left: 0),
            child: Builder(builder: (BuildContext context) => buildSelectedTab())
        )
      ],
    );
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
  TabItem(this.label, this.body, {this.icon, this.iconLibrary});

  String label;
  dynamic body;
  String? icon;
  String? iconLibrary;

}