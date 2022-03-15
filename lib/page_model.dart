
import 'dart:collection';
import 'dart:convert';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/unknown_builder.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:ensemble/util/yaml_util.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter/cupertino.dart';

class PageModel {
  String? title;
  Map<String, dynamic>? pageStyles;
  Map<String, dynamic>? args;
  Map<String, YamlMap>? subViewDefinitions;
  List<MenuItem> menuItems = [];
  List<WidgetModel> widgetModels = [];
  PageType pageType = PageType.full;
  Footer? footer;

  final List<String> layoutIDs = [];
  final Map<String, LayoutModel> layoutModels = {};



  PageModel ({YamlMap? data, this.args}) {
    if (data != null) {
      processAPI(data['API']);
      processModel(data);
    }

    //processView(pageMap['View']);
    //processLayout(pageMap['Layout']);
  }

  processAPI(YamlMap? apiMap) {

  }

  processModel(YamlMap docMap) {
    YamlMap viewMap = docMap['View'];
    title = viewMap['title'];
    pageType =
      viewMap['type'] == PageType.modal.name ?
      PageType.modal :
      PageType.full;

    if (viewMap['menu']?['items'] is YamlList) {
      for (final YamlMap item in (viewMap['menu']['items'] as YamlList)) {
        menuItems.add(MenuItem(item['label'], item['page'], icon: item['icon'], selected: item['selected']==true || item['selected']=='true'));
      }
    }

    if (viewMap['styles'] is YamlMap) {
      pageStyles = {};
      (viewMap['styles'] as YamlMap).forEach((key, value) {
        pageStyles![key] = value;
      });
    }


    if (viewMap['footer'] != null && viewMap['footer']['children'] != null) {
      footer = Footer(buildModels(viewMap['footer']['children'], args, {}));
    }

    // build a Map of the subviews' models first
    subViewDefinitions = createSubViewDefinitions(docMap, args);

    widgetModels = buildModels(viewMap['children'], args, subViewDefinitions!);
  }

  Map<String, YamlMap> createSubViewDefinitions(YamlMap docMap, Map<String, dynamic>? args) {
    Map<String, YamlMap> subViewDefinitions = {};
    docMap.forEach((key, value) {
      if ((key as String).endsWith('.View')) {
        String keyName = key.split('.').first.trim();
        if (value['body'] != null) {
          subViewDefinitions[keyName] = value;
        }
      }
    });
    return subViewDefinitions;
  }


  static List<WidgetModel> buildModels(YamlList models, Map<String, dynamic>? args, Map<String, YamlMap> subViewDefinitions) {
    List<WidgetModel> rtn = [];
    for (dynamic item in models) {
      rtn.add(buildModel(item, args, subViewDefinitions));
    }
    return rtn;
  }


  // each model can be dynamic (Spacer) or YamlMap (Text: ....)
  static WidgetModel buildModel(dynamic item, Map<String, dynamic>? args, Map<String, YamlMap> subViewDefinitions) {
    // e.g Spacer or a SubModel
    if (item is String) {
      // sub-model without any parameters
      if (subViewDefinitions[item] != null) {
        return buildModel(subViewDefinitions[item]!['body'], args, subViewDefinitions);
      }
      // e.g Spacer
      return WidgetModel(item, {}, {});
    }

    // item is YamlMap
    YamlMap model = item as YamlMap;

    // e.g if key is specified but not value e.g 'Spacer:'
    if (model.values.first == null) {
      return WidgetModel(model.keys.first, {}, {});
    }


    // widget key may have optional ID
    List<String> keys = model.keys.first.toString().split('.');
    if (keys.isEmpty || keys.length > 2) {
      throw Exception("Invalid Widget Definition");
    }

    Map<String, dynamic> props = {};
    Map<String, dynamic> styles = {};
    List<WidgetModel>? children;
    ItemTemplate? itemTemplate;

    String widgetType = keys.last.trim();
    if (keys.length == 2) {
      props['id'] = keys.first.trim();
    }

    // if this is a subView, process it
    if (subViewDefinitions[widgetType] != null) {
      Map<String, dynamic> localizedArgs = {};
      localizedArgs.addAll(args ?? {});

      // if subview has parameters, and invoker specifies values for these parameters
      if (subViewDefinitions[widgetType]!['parameters'] is YamlList && model.values.isNotEmpty) {
        // add (and overwrite) parameters to our data map
        for (var param in (subViewDefinitions[widgetType]!['parameters'] as YamlList)) {
          if (model.values.first[param] != null) {
            localizedArgs[param] = Utils.evalExpression(model.values.first[param], args);
          }
        }
        //print("LocalizedMap: " + localizedArgs.toString());
      }
      return buildModel(subViewDefinitions[widgetType]!['body'], localizedArgs, subViewDefinitions);
    }
    // else go through properties/styles/item-template for this widget
    else {
      // go through each sub properties
      model.values.first.forEach((key, value) {
        if (value != null) {
          if (key == 'styles') {
            // expand the style map
            (value as YamlMap).forEach((styleKey, styleValue) {
              styles[styleKey] = Utils.evalExpression(styleValue, args);
            });
          } else if (key == "children") {
            children = buildModels(value, args, subViewDefinitions);
          } else if (key == "item-template") {
            // attempt to resolve the localized dataMap fed into the item template
            // we only take it if it resolves to a list
            List<dynamic>? localizedDataList;
            dynamic templateDataResult = Utils.evalExpression(
                value['data'], args);
            if (templateDataResult is List<dynamic>) {
              localizedDataList = templateDataResult;
            }

            // item template should only have 1 root widget
            itemTemplate = ItemTemplate(
                value['data'],
                value['name'],
                value['template'],
                localizedDataList);
          }
          // actions like onTap should evaluate its expressions upon the action only
          else if (key.toString().startsWith("on")) {
            props[key] = value;
          }
          // this is tricky. We only want to evaluate properties most likely, so need
          // a way to distinguish them
          else {
            props[key] = Utils.evalExpression(value, args);
          }
        }
      });

      return WidgetModel(
          widgetType,
          styles,
          props,
          children: children,
          itemTemplate: itemTemplate);
    }
  }

}



class WidgetModel {
  final String type;
  final Map<String, dynamic> styles;
  final Map<String, dynamic> props;

  // a layout can either have children or itemTemplate, but not both
  final List<WidgetModel>? children;
  final ItemTemplate? itemTemplate;

  WidgetModel(this.type, this.styles, this.props, {this.children, this.itemTemplate});
}

class ItemTemplate {
  final String data;
  final String name;
  final YamlMap template;
  final List<dynamic>? localizedDataList;

  ItemTemplate(this.data, this.name, this.template, this.localizedDataList);
}

class LayoutModel {
  LayoutModel(this.properties);
  final Map? properties;
}

class MenuItem {
  MenuItem(this.label, this.page, {this.icon, this.selected=false});

  final String label;
  final String page;
  final String? icon;
  final bool selected;

}

class Footer {
  final List<WidgetModel> children;
  Footer(this.children);
}

enum PageType {
  full, modal
}