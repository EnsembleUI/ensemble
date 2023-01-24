import 'dart:developer';
import 'dart:ui';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/layout/app_scroller.dart';
import 'package:ensemble/layout/box_layout.dart';
import 'package:ensemble/layout/stack.dart';
import 'package:ensemble/provider.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widget_registry.dart';
import 'package:yaml/yaml.dart';

abstract class PageModel {
  PageModel();

  final List<String> _reservedTokens = [
    'Import',
    'View',
    'Action',
    'API',
    'Functions',
    'App',
    'Model',
    'Variable',
    'Global',
    'Menu'
  ];

  Menu? menu;
  Map<String, YamlMap>? apiMap;
  Map<String, dynamic>? customViewDefinitions;
  String? globalCode;

  factory PageModel.fromYaml(YamlMap data) {
    try {
      if (data['Menu'] != null) {
        return PageGroupModel._init(data);
      }
      return SinglePageModel._init(data);
    } on Error catch (e) {
      throw LanguageError(
          "Invalid page definition.",
          recovery: "Please double check your page syntax.",
          detailError: e.toString() + "\n" + (e.stackTrace?.toString() ?? '')
      );
    }
  }
  void _processModel(YamlMap docMap) {
    _processAPI(docMap['API']);

    globalCode = Utils.optionalString(docMap['Global']);

    // build a Map of the Custom Widgets
    customViewDefinitions = _buildCustomViewDefinitions(docMap);
  }

  void _processAPI(YamlMap? map) {
    if (map != null) {
      apiMap = {};
      map.forEach((key, value) {
        apiMap![key] = value;
      });
    }
  }

  /// Create a map of Ensemble's custom widgets so WidgetModel can reference them
  Map<String, dynamic> _buildCustomViewDefinitions(YamlMap docMap) {
    Map<String, dynamic> subViewDefinitions = {};
    docMap.forEach((key, value) {
      if (!_reservedTokens.contains(key)) {
        if (value != null) {
          subViewDefinitions[key] = value;
        }


      }
    });
    return subViewDefinitions;
  }

  void _processMenu(YamlMap menuData) {
    if (menuData['items'] is YamlList) {
      List<MenuItem> menuItems = [];
      for (final YamlMap item in (menuData['items'] as YamlList)) {
        menuItems.add(MenuItem(
            item['label'],
            item['page'],
            icon: item['icon'],
            iconLibrary: item['iconLibrary'],
            selected: item['selected']==true || item['selected']=='true'));
      }
      Map<String, dynamic>? menuStyles = ViewUtil.getMap(menuData['styles']);

      WidgetModel? menuHeaderModel;
      if (menuData['header'] != null) {
        menuHeaderModel = ViewUtil.buildModel(menuData['header'], customViewDefinitions);
      }
      WidgetModel? menuFooterModel;
      if (menuData['footer'] != null) {
        menuFooterModel = ViewUtil.buildModel(menuData['footer'], customViewDefinitions);
      }
      menu = Menu(menuData['display'], menuStyles, menuItems, headerModel: menuHeaderModel, footerModel: menuFooterModel);
    }
  }


}

/// a screen list grouped together by a menu
class PageGroupModel extends PageModel {
  PageGroupModel._init (YamlMap docMap) {
    _processModel(docMap);
  }

  @override
  void _processModel(YamlMap docMap) {
    super._processModel(docMap);

    _processMenu(docMap['Menu']);
  }
}


/// represents an individual screen translated from the YAML definition
class SinglePageModel extends PageModel {
  SinglePageModel._init (YamlMap docMap) {
    _processModel(docMap);
  }


  ViewBehavior viewBehavior = ViewBehavior();
  HeaderModel? headerModel;

  Map<String, dynamic>? pageStyles;
  ScreenOptions? screenOptions;
  late WidgetModel rootWidgetModel;
  Footer? footer;




  @override
  _processModel(YamlMap docMap) {
    super._processModel(docMap);

    YamlMap viewMap = docMap['View'];

    if (viewMap['options'] is YamlMap) {
      PageType pageType = viewMap['options']['type'] == PageType.modal.name
          ? PageType.modal
          : PageType.regular;
      String? closeButtonPosition =
          viewMap['options']?['closeButtonPosition'] == 'start'
              ? 'start'
              : 'end';
      screenOptions = ScreenOptions(
          pageType: pageType, closeButtonPosition: closeButtonPosition);
    }

    // set the view behavior
    viewBehavior.onLoad = Utils.getAction(viewMap['onLoad']);

    processHeader(viewMap['header'], viewMap['title']);

    if (viewMap['menu'] != null) {
      _processMenu(viewMap['menu']);
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

  void processHeader(YamlMap? headerData, String? legacyTitle) {
    WidgetModel? titleWidget;
    String? titleText = legacyTitle;
    WidgetModel? background;
    Map<String, dynamic>? styles;

    if (headerData != null) {
      if (ViewUtil.isViewModel(headerData['title'], customViewDefinitions)) {
        titleWidget =
            ViewUtil.buildModel(headerData['title'], customViewDefinitions);
      } else {
        titleText = headerData['title']?.toString() ?? legacyTitle;
      }

      if (headerData['flexibleBackground'] != null) {
        background = ViewUtil.buildModel(
            headerData['flexibleBackground'], customViewDefinitions);
      }

      styles = ViewUtil.getMap(headerData['styles']);
    }

    if (titleWidget != null || titleText != null || background != null || styles != null) {
      headerModel = HeaderModel(titleText: titleText, titleWidget: titleWidget, flexibleBackground: background, styles: styles);
    }
  }

  // Root View is special and can have many attributes,
  // where as the root body (e.g Column) should be more restrictive
  // (e.g the whole body shouldn't be click-enable)
  // Let's manually select what can be specified here (really just styles/item-template/children)
  WidgetModel buildRootModel(YamlMap viewMap, Map<String, dynamic>? customViewDefinitions) {
    WidgetModel? rootModel = getRootModel(viewMap, customViewDefinitions!);
    if (rootModel != null) {
      if (![Column.type, Row.type, Flex.type, EnsembleStack.type, AppScroller.type].contains(rootModel.type)) {
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

class HeaderModel {
  HeaderModel({this.titleText, this.titleWidget, this.flexibleBackground, this.styles});

  // header title can be text or a widget
  String? titleText;
  WidgetModel? titleWidget;

  WidgetModel? flexibleBackground;
  Map<String, dynamic>? styles;
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
  bottomNavBar,   // bottom navigation bar. Default if not specified
  drawer,         // hamburger drawer menu
  leftNavBar,     // fixed navigation to the left. Only recommend for Web

  // legacy for backward compatible
  navBar,         // bottom nav bar
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
    this.pageType
  });

  // screen ID is optional as the App always have a default screen
  String? screenId;

  // screenName is also optional, and refer to the friendly readable name
  String? screenName;

  // screen arguments to be added to the screen context
  Map<String, dynamic>? arguments;

  PageType? pageType;
}

/// rendering options for the screenc
class ScreenOptions {
  ScreenOptions({this.pageType, this.closeButtonPosition});

  PageType? pageType = PageType.regular;

  // applicable only for modal pages (start/end)
  String? closeButtonPosition = 'end';
}
