import 'dart:developer';
import 'dart:math';
import 'package:ensemble/error_handling.dart';
import 'package:ensemble/framework/context.dart';
import 'package:ensemble/layout/Row.dart';
import 'package:ensemble/layout/hstack_builder.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/layout/Column.dart';
import 'package:yaml/yaml.dart';

class PageModel {
  static final List<String> reservedTokens = [
    'Import',
    'View',
    'Action',
    'API',
    'Functions'
  ];

  final DataContext eContext;
  String? title;
  Map<String, dynamic>? pageStyles;
  Map<String, YamlMap>? customWidgetDefinitions;
  Menu? menu;
  late WidgetModel rootWidgetModel;
  PageType pageType = PageType.full;
  Footer? footer;

  final List<String> layoutIDs = [];
  final Map<String, LayoutModel> layoutModels = {};


  PageModel (this.eContext, YamlMap data) {

    processAPI(data['API']);
    processModel(data);

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

      List<MenuItem> menuItems = [];
      for (final YamlMap item in (viewMap['menu']['items'] as YamlList)) {
        menuItems.add(MenuItem(
          item['label'],
          item['page'],
          icon: item['icon'],
          iconLibrary: item['iconLibrary'],
          selected: item['selected']==true || item['selected']=='true'));
      }
      MenuDisplay display = MenuDisplay.navBar;
      if (viewMap['menu']['display'] == MenuDisplay.drawer.name) {
        display = MenuDisplay.drawer;
      } else if (viewMap['menu']['display'] == MenuDisplay.navBar_left.name) {
        display = MenuDisplay.navBar_left;
      }

      // header widget
      WidgetModel? headerModel;
      if (viewMap['menu']['header'] != null) {
         headerModel = buildModel(viewMap['menu']['header'], eContext, {});
      }
      WidgetModel? footerModel;
      if (viewMap['menu']['footer'] != null) {
        headerModel = buildModel(viewMap['menu']['footer'], eContext, {});
      }

      menu = Menu(display, menuItems, headerModel: headerModel, footerModel: footerModel);
    }

    if (viewMap['styles'] is YamlMap) {
      pageStyles = {};
      (viewMap['styles'] as YamlMap).forEach((key, value) {
        pageStyles![key] = value;
      });
    }

    if (viewMap['footer'] != null && viewMap['footer']['children'] != null) {
      footer = Footer(PageModel.buildModels(viewMap['footer']['children'], eContext, {}));
    }

    // build a Map of the subviews' models first
    customWidgetDefinitions = createSubViewDefinitions(docMap);

    if (viewMap['type'] == null ||
        ![Column.type, Row.type, HStackBuilder.type].contains(viewMap['type'])) {
      throw LanguageError('Root widget type should only be Row or Column');
    }
    // View is special and can have many attributes,
    // where as the root body (e.g Column) should be more restrictive
    // (e.g the whole body shouldn't be click-enable)
    // Let's manually select what can be specified here (really just styles/item-template/children)
    YamlMap rootItemMap = YamlMap.wrap({
      'children': viewMap['children'],
      'item-template': viewMap['item-template'],
      'styles': viewMap['styles']
    });
    rootWidgetModel = PageModel.buildModelFromName(viewMap['type'], rootItemMap, eContext, customWidgetDefinitions!);
  }

  Map<String, YamlMap> createSubViewDefinitions(YamlMap docMap) {
    Map<String, YamlMap> subViewDefinitions = {};
    docMap.forEach((key, value) {
      if (!reservedTokens.contains(key)) {
        if (value == null || value['type'] == null) {
          throw LanguageError("SubView requires a widget 'type'");
        }
        subViewDefinitions[key] = value;

      }
    });
    return subViewDefinitions;
  }


  static List<WidgetModel> buildModels(YamlList models, DataContext eContext, Map<String, YamlMap> subViewDefinitions) {
    List<WidgetModel> rtn = [];
    for (dynamic item in models) {
      rtn.add(buildModel(item, eContext, subViewDefinitions));
    }
    return rtn;
  }


  // each model can be dynamic (Spacer) or YamlMap (Text: ....)
  static WidgetModel buildModel(dynamic item, DataContext eContext, Map<String, YamlMap> subViewDefinitions) {
    String? key;
    YamlMap? itemMap;

    // e.g Spacer
    if (item is String) {
      key = item;
    } else if (item is YamlMap){
      YamlMap model = item;
      key = model.keys.first.toString();
      itemMap = model[key];
    } else {
      throw LanguageError("Invalid token '$item'", recovery: 'Please review your definition');
    }

    // widget name may have optional ID
    List<String> keys = key.split('.');
    if (keys.isEmpty || keys.length > 2) {
      throw LanguageError("Too many tokens");
    }
    String widgetType = keys.last.trim();
    String? widgetId;
    if (keys.length == 2) {
      widgetId = keys.first.trim();
    }

    // first try to handle the widget as a SubView
    YamlMap? subViewMap = subViewDefinitions[widgetType];
    if (subViewMap != null) {
      String subViewWidgetType = subViewMap['type'];

      DataContext localizedContext = eContext.clone();

      // if subview has parameters
      if (subViewMap['parameters'] is YamlList && itemMap != null) {
        // add (and potentially overwrite) parameters to our data map
        for (var param in (subViewMap['parameters'] as YamlList)) {
          if (itemMap[param] != null) {
            localizedContext.addDataContextById(param, eContext.eval(itemMap[param]));

          }
        }
        //log("LocalizedMap: " + localizedArgs.toString());
      }
      return PageModel.buildModelFromName(subViewWidgetType, subViewMap, localizedContext, subViewDefinitions);
    }
    // regular widget
    else {
      // e.g Spacer or Spacer:
      if (itemMap == null) {
        return WidgetModel(widgetType, {}, {});
      }
      return PageModel.buildModelFromName(widgetType, itemMap, eContext, subViewDefinitions, widgetId: widgetId);
    }


  }

  static WidgetModel buildModelFromName(String widgetType, YamlMap itemMap, DataContext eContext, Map<String, YamlMap> subViewDefinitions, {String? widgetId}) {
    Map<String, dynamic> props = {};
    if (widgetId != null) {
      props['id'] = widgetId;
    }
    Map<String, dynamic> styles = {};
    List<WidgetModel>? children;
    ItemTemplate? itemTemplate;


    // go through each sub properties
    itemMap.forEach((key, value) {
      if (value != null) {
        if (key == 'styles') {
          // expand the style map
          (value as YamlMap).forEach((styleKey, styleValue) {
            styles[styleKey] = eContext.eval(styleValue);
          });
        } else if (key == "children") {
          children = buildModels(value, eContext, subViewDefinitions);
        } else if (key == "item-template") {
          // attempt to resolve the localized dataMap fed into the item template
          // we only take it if it resolves to a list
          List<dynamic>? localizedDataList;
          dynamic templateDataResult = eContext.eval(value['data']);
          if (templateDataResult is List<dynamic>) {
            localizedDataList = templateDataResult;
          }

          // item template should only have 1 root widget
          itemTemplate = ItemTemplate(
              value['data'],
              value['name'],
              value['template'],
              localizedDataList: localizedDataList);
        }
        // actions like onTap should evaluate its expressions upon the action only
        else if (key.toString().startsWith("on")) {
          props[key] = value;
        }
        // this is tricky. We only want to evaluate properties most likely, so need
        // a way to distinguish them
        else {
          props[key] = eContext.eval(value);
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


class WidgetModel {
  final String type;
  final Map<String, dynamic> styles;
  final Map<String, dynamic> props;

  // a layout can either have children or itemTemplate, but not both
  final List<WidgetModel>? children;
  final ItemTemplate? itemTemplate;

  WidgetModel(this.type, this.styles, this.props, {this.children, this.itemTemplate});
}

class CustomWidgetModel extends WidgetModel {
  CustomWidgetModel(
      String type,
      Map<String, dynamic> styles,
      Map<String, dynamic> props, {
        List<WidgetModel>? children,
        ItemTemplate? itemTemplate,
        this.parameters,
        this.inputs
  }) : super(type, styles, props, children: children, itemTemplate: itemTemplate);

  List<String>? parameters;
  Map<String, dynamic>? inputs;

}

class ItemTemplate {
  final String data;
  final String name;
  final YamlMap template;
  final List<dynamic>? localizedDataList;

  ItemTemplate(this.data, this.name, this.template, {this.localizedDataList});
}

class LayoutModel {
  LayoutModel(this.properties);
  final Map? properties;
}

class Menu {
  Menu(this.display, this.menuItems, { this.headerModel, this.footerModel });

  MenuDisplay display = MenuDisplay.navBar;
  List<MenuItem> menuItems;
  WidgetModel? headerModel;
  WidgetModel? footerModel;
}
enum MenuDisplay {
  navBar,       // bottom navigation bar. Default if not specified
  drawer,       // expansible/collapsible hamburger menu
  navBar_left,  // fixed navigation on the left of the screen
  navBar_right  // fixed navigation on the right of the screen
}


class MenuItem {
  MenuItem(this.label, this.page, {this.icon, this.iconLibrary, this.selected=false});

  final String? label;
  final String page;
  final String? icon;
  final String? iconLibrary;
  final bool selected;

}

class Footer {
  final List<WidgetModel> children;
  Footer(this.children);
}

enum PageType {
  full, modal
}