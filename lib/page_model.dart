import 'dart:developer';
import 'dart:ui';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/layout/box_layout.dart';
import 'package:ensemble/layout/stack.dart';
import 'package:ensemble/provider.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widget_registry.dart';
import 'package:yaml/yaml.dart';

/// represents a screen translated from the YAML definition
class PageModel {
  static final List<String> reservedTokens = [
    'Import',
    'View',
    'Action',
    'API',
    'Functions',
    'App',
    'Model',
    'Variable',
    'Global'
  ];

  String? globalCode;
  Map<String, YamlMap>? apiMap;
  Map<String, dynamic>? customViewDefinitions;
  ViewBehavior viewBehavior = ViewBehavior();

  String? title;
  Map<String, dynamic>? pageStyles;
  Menu? menu;
  late WidgetModel rootWidgetModel;
  PageType pageType = PageType.regular;
  Footer? footer;

  PageModel._init (YamlMap data) {
    processAPI(data['API']);
    processModel(data);
  }

  factory PageModel.fromYaml(YamlMap data) {
    try {
      return PageModel._init(data);
    } on Error catch (e) {
      throw LanguageError(
          "Invalid page definition.",
          recovery: "Please double check your page syntax.",
          detailError: e.toString() + "\n" + (e.stackTrace?.toString() ?? '')
      );
    }
  }

  processAPI(YamlMap? map) {
    if (map != null) {
      apiMap = {};
      map.forEach((key, value) {
        apiMap![key] = value;
      });
    }
  }

  processModel(YamlMap docMap) {
    YamlMap viewMap = docMap['View'];
    title = viewMap['title'];
    pageType =
      viewMap['type'] == PageType.modal.name ?
      PageType.modal :
      PageType.regular;

    // build a Map of the Custom Widgets
    customViewDefinitions = buildCustomViewDefinitions(docMap);

    globalCode = Utils.optionalString(docMap['Global']);

    // set the view behavior
    viewBehavior.onLoad = Utils.getAction(viewMap['onLoad']);

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
      Map<String, dynamic>? menuStyles;
      if (viewMap['menu']['styles'] is YamlMap) {
        menuStyles = {};
        (viewMap['menu']['styles'] as YamlMap).forEach((key, value) {
          menuStyles![key] = value;
        });
      }
      WidgetModel? headerModel;
      if (viewMap['menu']['header'] != null) {
         headerModel = ViewUtil.buildModel(viewMap['menu']['header'], customViewDefinitions);
      }
      WidgetModel? footerModel;
      if (viewMap['menu']['footer'] != null) {
        footerModel = ViewUtil.buildModel(viewMap['menu']['footer'], customViewDefinitions);
      }
      menu = Menu(viewMap['menu']['display'], menuStyles, menuItems, headerModel: headerModel, footerModel: footerModel);
    }

    if (viewMap['styles'] is YamlMap) {
      pageStyles = {};
      (viewMap['styles'] as YamlMap).forEach((key, value) {
        pageStyles![key] = value;
      });
    }

    if (viewMap['footer'] != null && viewMap['footer']['children'] != null) {
      footer = Footer(ViewUtil.buildModels(viewMap['footer']['children'], customViewDefinitions));
    }

    rootWidgetModel = buildRootModel(viewMap, customViewDefinitions);
  }

  // Root View is special and can have many attributes,
  // where as the root body (e.g Column) should be more restrictive
  // (e.g the whole body shouldn't be click-enable)
  // Let's manually select what can be specified here (really just styles/item-template/children)
  WidgetModel buildRootModel(YamlMap viewMap, Map<String, dynamic>? customViewDefinitions) {
    WidgetModel? rootModel = getRootModel(viewMap, customViewDefinitions!);
    if (rootModel != null) {
      if (![Column.type, Row.type, Flex.type, EnsembleStack.type].contains(rootModel.type)) {
        throw LanguageError('Root widget type should only be Row, Column, Flex or Stack.');
      }
      return rootModel;
    }
    throw LanguageError("View requires a child widget !");
  }

  WidgetModel? getRootModel(YamlMap rootTree, Map<String, dynamic> customViewDefinitions) {
    for (String key in rootTree.keys) {
      // if a regular widget or custom widget
      if (WidgetRegistry.widgetMap[key] != null ||
          customViewDefinitions[key] != null) {
        YamlMap widgetMap = YamlMap.wrap({
          key: rootTree[key]
        });
        return ViewUtil.buildModel(widgetMap, customViewDefinitions);
      }
    }
    return null;
  }

  /// Create a map of Ensemble's custom widgets so WidgetModel can reference them
  Map<String, dynamic> buildCustomViewDefinitions(YamlMap docMap) {
    Map<String, dynamic> subViewDefinitions = {};
    docMap.forEach((key, value) {
      if (!reservedTokens.contains(key)) {
        if (value != null) {
          subViewDefinitions[key] = value;
        }


      }
    });
    return subViewDefinitions;
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
      this.widgetModel,
      Map<String, dynamic> props,
      {
        this.parameters,
        this.inputs
  }) : super('', {}, props);

  WidgetModel widgetModel;
  List<String>? parameters;
  Map<String, dynamic>? inputs;

  WidgetModel getModel() {
    return widgetModel;
  }

  ViewBehavior getViewBehavior() {
    return ViewBehavior(onLoad: Utils.getAction(props['onLoad']));
  }

}

/// special behaviors for RootView (View) and Custom Views
class ViewBehavior {
  ViewBehavior({this.onLoad});

  EnsembleAction? onLoad;
}

class ItemTemplate {
  final String data;
  final String name;
  final YamlMap template;
  List<dynamic>? initialValue;

  ItemTemplate(this.data, this.name, this.template, {this.initialValue});
}

class Menu {
  Menu(this.display, this.styles, this.menuItems, { this.headerModel, this.footerModel });

  Map<String, dynamic>? styles;
  String? display;
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

enum MenuItemDisplay {
  stacked,
  sideBySide
}


class MenuItem {
  MenuItem(this.label, this.page, {this.icon, this.iconLibrary, this.selected=false});

  final String? label;
  final String page;
  final dynamic icon;
  final String? iconLibrary;
  final bool selected;

}

class Footer {
  final List<WidgetModel> children;
  Footer(this.children);
}

enum PageType {
  regular, modal
}

/// provider that gets passed into every screen
class AppProvider {
  AppProvider({
    required this.definitionProvider
  });
  DefinitionProvider definitionProvider;

  Future<YamlMap> getDefinition({ScreenPayload? payload}) {
    return definitionProvider.getDefinition(screenId: payload?.screenId, screenName: payload?.screenName);
  }
}

/// payload to pass to the Screen
class ScreenPayload {
  ScreenPayload({
    this.screenId,
    this.screenName,
    this.arguments,
    this.type
  });

  // screen ID is optional as the App always have a default screen
  String? screenId;

  // screenName is also optional, and refer to the friendly readable name
  String? screenName;

  // screen arguments to be added to the screen context
  Map<String, dynamic>? arguments;

  PageType? type;
}

class DeviceInfo {
  DeviceInfo(this.platform, { required this.size, required this.safeAreaSize, this.browserInfo});

  DevicePlatform platform;
  Size size;
  SafeAreaSize safeAreaSize;
  WebBrowserInfo? browserInfo;
}
class SafeAreaSize {
  SafeAreaSize(this.top, this.bottom);
  int top;
  int bottom;
}
enum DevicePlatform {
  web, android, ios, macos, windows, other
}