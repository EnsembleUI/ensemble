import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/layout/tab/base_tab_bar.dart';
import 'package:ensemble/layout/tab_bar.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/cupertino.dart';
import 'package:yaml/yaml.dart';

// the Controller for the TabBar
class TabBarController extends BoxController {
  String? tabPosition;
  String? tabAlignment;
  String? indicatorSize;
  String? tabType;
  EdgeInsets? tabPadding;
  int? tabFontSize;
  FontWeight? tabFontWeight;
  Color? tabBackgroundColor;
  Color? activeTabColor;
  Color? inactiveTabColor;
  Color? activeTabBackgroundColor;
  Color? indicatorColor;
  Color? dividerColor;
  int? indicatorThickness;

  EnsembleAction? onTabSelection;
  String? onTabSelectionHaptic;
  TabBarAction? tabBarAction;

  int selectedIndex = 0;

  final List<TabItem> _items = [];

  set items(dynamic items) {
    if (items is YamlList) {
      for (YamlMap item in items) {
        _items.add(TabItem(
            icon: Utils.getIcon(item['icon']),
            label: Utils.optionalString(item['label']),
            tabWidget: item['tabWidget'] ?? item['tabItem'],
            bodyWidget: item['bodyWidget'] ?? item['widget'] ?? item['body']));
      }
    }
  }

  List<TabItem> get items => _items;

  @override
  Map<String, Function> getBaseSetters() {
    var setters = super.getBaseSetters();
    setters.addAll({
      'items': (values) => items = values,
    });
    return setters;
  }
}

/// Model for a single tab item
class TabItem {
  TabItem({this.icon, this.label, this.tabWidget, this.bodyWidget}) {
    if (icon == null && label == null && tabWidget == null) {
      throw LanguageError(
          "Each tab requires either an icon, a label, or a custom tabWidget");
    }
  }

  IconModel? icon;
  String? label;
  dynamic tabWidget; // custom tab widget
  dynamic bodyWidget; // tab's body widget
}
