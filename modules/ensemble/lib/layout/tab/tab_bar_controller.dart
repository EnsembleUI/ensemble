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

  List<TabItem> _originalItems = [];
  List<TabItem> _visibleItems = [];

  set items(dynamic items) {
    if (items is YamlList) {
      _originalItems = [];
      for (YamlMap item in items) {
        _originalItems.add(TabItem(
          icon: Utils.getIcon(item['icon']),
          label: Utils.optionalString(item['label']),
          tabWidget: item['tabWidget'] ?? item['tabItem'],
          bodyWidget: item['bodyWidget'] ?? item['widget'] ?? item['body'],
          isVisible: _setVisible(item['visible']),
        ));
      }
    } else if (items is List<TabItem>) {
      _originalItems = List.from(items);
    }
    _visibleItems = List.from(_originalItems);
  }

  List<TabItem> get items => _visibleItems;
  List<TabItem> get originalItems => _originalItems;

  void updateVisibleItems(List<TabItem> newVisibleItems) {
    _visibleItems = newVisibleItems;
    notifyListeners();
  }

  @override
  Map<String, Function> getBaseSetters() {
    var setters = super.getBaseSetters();
    setters.addAll({
      'items': (values) => items = values,
    });
    return setters;
  }

  Visible? _setVisible(dynamic value) {
    if (value is bool) return BoolVisible(value);
    if (value is String) return EvaluateVisible(value);
    return null;
  }
}

/// Model for a single tab item
class TabItem {
  TabItem(
      {this.icon,
      this.label,
      this.tabWidget,
      this.bodyWidget,
      this.isVisible}) {
    if (icon == null && label == null && tabWidget == null) {
      throw LanguageError(
          "Each tab requires either an icon, a label, or a custom tabWidget");
    }
  }

  IconModel? icon;
  String? label;
  dynamic tabWidget; // custom tab widget
  dynamic bodyWidget; // tab's body widget
  Visible? isVisible;
}

sealed class Visible {}

class EvaluateVisible extends Visible {
  final String value;

  EvaluateVisible(this.value);
}

class BoolVisible extends Visible {
  final bool value;

  BoolVisible(this.value);
}
