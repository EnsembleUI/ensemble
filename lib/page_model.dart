import 'dart:developer';
import 'dart:ui';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/menu.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/layout/app_scroller.dart';
import 'package:ensemble/layout/box/box_layout.dart';
import 'package:ensemble/layout/stack.dart';
import 'package:ensemble/provider.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widget_registry.dart';
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import 'framework/scope.dart';

abstract class PageModel {
  PageModel();

  final List<String> _reservedTokens = [
    'Import',
    'View',
    'ViewGroup',
    'Action',
    'API',
    'Socket',
    'Functions',
    'App',
    'Model',
    'Variable',
    'Global',
    'Menu',
  ];

  Menu? menu;
  Map<String, YamlMap>? apiMap;
  Map<String, EnsembleSocket> socketData = {};
  Map<String, dynamic>? customViewDefinitions;
  String? globalCode;
  SourceSpan? globalCodeSpan;

  factory PageModel.fromYaml(YamlMap data) {
    try {
      if (data['ViewGroup'] != null) {
        return PageGroupModel._init(data);
      }
      return SinglePageModel._init(data);
    } on Error catch (e) {
      throw LanguageError("Invalid page definition.",
          recovery: "Please double check your page syntax.",
          detailError: e.toString() + "\n" + (e.stackTrace?.toString() ?? ''));
    }
  }
  void _processModel(YamlMap docMap) {
    _processAPI(docMap['API']);
    _processSocket(docMap['Socket']);
    YamlNode? globalCodeNode = docMap.nodes['Global'];
    if (globalCodeNode != null) {
      globalCode = Utils.optionalString(globalCodeNode.value);
      globalCodeSpan = ViewUtil.getDefinition(globalCodeNode);
    }

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

  void _processSocket(YamlMap? map) {
    if (map == null) return;
    map.forEach((key, value) {
      socketData[key] = EnsembleSocket.fromYaml(payload: value);
    });
    SocketService.socketData = socketData;
  }

  /// Create a map of Ensemble's custom widgets so WidgetModel can reference them
  Map<String, dynamic> _buildCustomViewDefinitions(YamlMap docMap) {
    Map<String, dynamic> subViewDefinitions = {};

    // first get the custom widgets from Global
    YamlMap? globalWidgets = Ensemble().getConfig()?.getResources();
    globalWidgets?['Widgets']?.forEach((key, value) {
      if (value != null) {
        subViewDefinitions[key] = value;
      }
    });

    // then add custom widgets on the page. They will
    // override global scope if the name is duplicate
    docMap.forEach((key, value) {
      if (!_reservedTokens.contains(key)) {
        if (value != null) {
          subViewDefinitions[key] = value;
        }
      }
    });
    return subViewDefinitions;
  }
}

/// a screen list grouped together by a menu
class PageGroupModel extends PageModel {
  PageGroupModel._init(YamlMap docMap) {
    _processModel(docMap);
  }

  @override
  void _processModel(YamlMap docMap) {
    super._processModel(docMap);

    menu = Menu.fromYaml(docMap['ViewGroup'], customViewDefinitions);
  }
}

/// represents an individual screen translated from the YAML definition
class SinglePageModel extends PageModel {
  SinglePageModel._init(YamlMap docMap) {
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
      screenOptions = ScreenOptions(pageType: pageType);
    }

    // set the view behavior
    viewBehavior.onLoad = EnsembleAction.fromYaml(viewMap['onLoad']);
    viewBehavior.onResume = EnsembleAction.fromYaml(viewMap['onResume']);

    processHeader(viewMap['header'], viewMap['title']);

    if (viewMap['menu'] != null) {
      menu = Menu.fromYaml(viewMap['menu'], customViewDefinitions);
    }

    if (viewMap['styles'] is YamlMap) {
      pageStyles = {};
      (viewMap['styles'] as YamlMap).forEach((key, value) {
        pageStyles![key] = value;
      });
    }

    if (viewMap['footer'] != null && viewMap['footer']['children'] != null) {
      footer = Footer(
        ViewUtil.buildModels(
            viewMap['footer']['children'], customViewDefinitions),
        Utils.getMap(
          viewMap['footer']['styles'],
        ),
        Utils.getMap(viewMap['footer']['dragOptions']),
      );
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

    if (titleWidget != null ||
        titleText != null ||
        background != null ||
        styles != null) {
      headerModel = HeaderModel(
          titleText: titleText,
          titleWidget: titleWidget,
          flexibleBackground: background,
          styles: styles);
    }
  }

  // Root View is special and can have many attributes,
  // where as the root body (e.g Column) should be more restrictive
  // (e.g the whole body shouldn't be click-enable)
  // Let's manually select what can be specified here (really just styles/item-template/children)
  WidgetModel buildRootModel(
      YamlMap viewMap, Map<String, dynamic>? customViewDefinitions) {
    if (viewMap['body'] != null) {
      return ViewUtil.buildModel(viewMap['body'], customViewDefinitions);
    }
    // backward compatible
    else {
      WidgetModel? rootModel = getRootModel(viewMap, customViewDefinitions);
      if (rootModel != null) {
        if (![
          Column.type,
          Row.type,
          Flex.type,
          EnsembleStack.type,
          AppScroller.type,
        ].contains(rootModel.type)) {
          throw LanguageError(
              'Root widget type should only be Row, Column, Flex or Stack.');
        }
        return rootModel;
      }
    }
    throw LanguageError("View requires a child widget !");
  }

  WidgetModel? getRootModel(
      YamlMap rootTree, Map<String, dynamic>? customViewDefinitions) {
    for (MapEntry<dynamic, dynamic> entry in rootTree.entries) {
      if (WidgetRegistry.legacyWidgetMap[entry.key] != null ||
          customViewDefinitions?[entry.key] != null) {
        return ViewUtil.buildModel(entry, customViewDefinitions);
      }
    }
    return null;
    /*
    for (String key in rootTree.keys) {
      // if a regular widget or custom widget
      if (WidgetRegistry.widgetMap[key] != null ||
          customViewDefinitions[key] != null) {
        if ( rootTree[key] is YamlNode ) {
          print('YAML node.line=${rootTree[key].span.start.line} and the node=${key}');
        }
        YamlMap widgetMap = YamlMap.wrap({
          key: rootTree[key]
        });
        for ( String nodeKey in widgetMap.keys ) {
          print('YAMLNode.key=$nodeKey');
        }
        return ViewUtil.buildModel(widgetMap, customViewDefinitions);
      }
    }
    return null;

     */
  }
}

class WidgetModel {
  final SourceSpan definition;
  final String type;
  final Map<String, dynamic> styles;
  final Map<String, dynamic> props;

  // a layout can either have children or itemTemplate, but not both
  final List<WidgetModel>? children;
  final ItemTemplate? itemTemplate;

  WidgetModel(this.definition, this.type, this.styles, this.props,
      {this.children, this.itemTemplate});
}

class CustomWidgetModel extends WidgetModel {
  CustomWidgetModel(this.widgetModel, Map<String, dynamic> props,
      {this.parameters, this.inputs})
      : super(widgetModel.definition, '', {}, props);

  WidgetModel widgetModel;
  List<String>? parameters;
  Map<String, dynamic>? inputs;

  WidgetModel getModel() {
    return widgetModel;
  }

  ViewBehavior getViewBehavior() {
    return ViewBehavior(
        onLoad: EnsembleAction.fromYaml(props['onLoad']),
        onResume: EnsembleAction.fromYaml(props['onResume']));
  }
}

/// special behaviors for RootView (View) and Custom Views
class ViewBehavior {
  ViewBehavior({this.onLoad, this.onResume});

  EnsembleAction? onLoad;
  EnsembleAction? onResume;
}

class ItemTemplate {
  dynamic data;
  final String name;
  final dynamic template;
  List<dynamic>? initialValue;

  ItemTemplate(
    this.data,
    this.name,
    this.template, {
    this.initialValue,
  });
}

class HeaderModel {
  HeaderModel(
      {this.titleText, this.titleWidget, this.flexibleBackground, this.styles});

  // header title can be text or a widget
  String? titleText;
  WidgetModel? titleWidget;

  WidgetModel? flexibleBackground;
  Map<String, dynamic>? styles;
}

class Footer {
  final List<WidgetModel> children;
  final Map<String, dynamic>? styles;
  final Map<String, dynamic>? dragOptions;
  Footer(this.children, this.styles, this.dragOptions);
}

enum PageType { regular, modal }

/// provider that gets passed into every screen
class AppProvider {
  AppProvider({required this.definitionProvider});
  DefinitionProvider definitionProvider;

  Future<ScreenDefinition> getDefinition({ScreenPayload? payload}) {
    return definitionProvider.getDefinition(
        screenId: payload?.screenId, screenName: payload?.screenName);
  }
}

/// payload to pass to the Screen
class ScreenPayload {
  ScreenPayload(
      {this.screenId,
      this.screenName,
      this.arguments,
      this.pageType,
      this.isExternal = false});

  // screen ID is optional as the App always have a default screen
  String? screenId;
  // screenName is also optional, and refer to the friendly readable name
  String? screenName;

  // screen arguments to be added to the screen context
  Map<String, dynamic>? arguments;

  PageType? pageType;

  // check if screen is externally provided. i.e not ensemble screen.
  bool isExternal;
}

/// rendering options for the screenc
class ScreenOptions {
  ScreenOptions({this.pageType});

  PageType? pageType = PageType.regular;
}
