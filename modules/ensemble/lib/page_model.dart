import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/data_utils.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/menu.dart';
import 'package:ensemble/framework/theme_manager.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/layout/app_scroller.dart';
import 'package:ensemble/layout/box/box_layout.dart';
import 'package:ensemble/layout/stack.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/model/item_template.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widget_registry.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:source_span/source_span.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:yaml/yaml.dart';
import 'framework/scope.dart';

abstract class PageModel {
  PageModel();

  static const String importToken = 'Import';
  final List<String> _reservedTokens = [
    importToken,
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

  //list of imports parsed but not evaluated yet as evaluation will be done in context during page/widget building
  List<ParsedCode>? importedCode;

  factory PageModel.fromYaml(YamlMap data) {
    try {
      if (data['ViewGroup'] != null) {
        return PageGroupModel._init(data);
      }
      return SinglePageModel._init(data);
    } on Error catch (e) {
      throw LanguageError("Invalid page definition.",
          recovery: "Please double check your page syntax.",
          detailedError:
              e.toString() + "\n" + (e.stackTrace?.toString() ?? ''));
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
    importedCode = Ensemble().getConfig()?.processImports(docMap[importToken]);
    // build a Map of the Custom Widgets
    customViewDefinitions = _buildCustomViewDefinitions(docMap);
  }

  // static Map<String,dynamic> buildContextFromCode(String name, String code, Map<String,dynamic>? context) {
  //   try {
  //     JSInterpreter.fromCode(code, context ??= {}).evaluate();
  //   } on JSException catch (e) {
  //     throw 'Error evaluating code library with name - $name Detailed Error: ${e.detailedError}. \n'
  //         'Note that the variables defined outside of functions in code library cannot access the global properties or '
  //         'methods of the ensemble object. For example, you cannot do \n'
  //         'var myVar = ensemble.storage.name;\n '
  //         ' The variables inside code libraries, however, can be used for storing values that are global across the app. ';
  //   }
  //   return context;
  // }
  // static Map<String,dynamic>? processImports(YamlList? imports, Map<String,dynamic>? context) {
  //   if ( imports == null ) return null;
  //   Map? globals = Ensemble().getConfig()?.getResources();
  //   Map<String,dynamic> context = {};
  //   globals?[ResourceArtifactEntry.Code.name]?.forEach((key,value) {
  //     if ( imports.contains(key) ) {
  //       if (value is String) {
  //         context[key] = buildContextFromCode(key, value, context);
  //       } else if (value is Map) {
  //         context[key] = value;
  //       } else {
  //         throw 'Invalid code definition for $key';
  //       }
  //     }
  //   });
  //   //we will update the globals so that any other screen that imports this code doesn't need to parse it again
  //   context.forEach((key,value) {
  //     globals?[ResourceArtifactEntry.Code.name]?[key] = value;
  //   });
  //   //now we add the context maps in a list exactly in the order of imports to make sure the last function/var overwirtes others in case of a name conflict
  //   Map<String, dynamic> importContext = {};
  //   for (var element in imports) {
  //     if ( context[element] != null ) {
  //       importContext.addAll(context[element]);
  //     }
  //   }
  //   return importContext;
  // }
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
    Map? globalWidgets = Ensemble().getConfig()?.getResources();
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

mixin HasStyles {
  String? _currentTheme;

  set currentTheme(String? theme) {
    if (theme == _currentTheme) {
      return;
    }
    _currentTheme = theme;
    stylesNeedResolving = true;
  }

  String? widgetType;

  //styles specified in the theme directly on the type e.g. Text or Button
  Map<String, dynamic>? _widgetTypeStyles;

  Map<String, dynamic>? get widgetTypeStyles => _widgetTypeStyles;

  set widgetTypeStyles(Map<String, dynamic>? styles) {
    _widgetTypeStyles = styles;
  }

  String?
      widgetId; //I know this is a potential repeat of the id field but this keeps it clean here
  //styles defined in the theme for a specific id e.g. #submitBtn where submitBtn is the id of the widget
  Map<String, dynamic>? _idStyles;

  Map<String, dynamic>? get idStyles => _idStyles;

  set idStyles(Map<String, dynamic>? styles) {
    _idStyles = styles;
  }

  //these are the inline styles set directly on the widget
  Map<String, dynamic>? _inlineStyles;

  Map<String, dynamic>? get inlineStyles => _inlineStyles;

  set inlineStyles(Map<String, dynamic>? styles) {
    _inlineStyles = styles;
  }

  //list of named styles, a widget may have a list of class names delimited by spaces like css
  List<String>? _classList;

  List<String>? get classList => _classList;

  set classList(List<String>? cl) {
    if (_classList == cl) return;
    _classList = cl;
    stylesNeedResolving = true;
  }

  //a string of class names delimited by spaces
  String? get className {
    return _classList?.join(' ');
  }

  set className(String? className) {
    classList = toClassList(className);
  }

  static List<String>? toClassList(String? className) {
    return DataUtils.splitSpaceDelimitedString(className);
  }

  //these are the styles resolved with what's set at the theme level and inline styles
  Map<String, dynamic>? _runtimeStyles;

  Map<String, dynamic>? get runtimeStyles => _runtimeStyles;

  set runtimeStyles(Map<String, dynamic>? styles) {
    _runtimeStyles = styles;
  }

  //styles that are overridden at runtime by the app code and were not in the original yaml or themes
  Map<String, dynamic>? _styleOverrides;

  Map<String, dynamic>? get styleOverrides => _styleOverrides;

  set styleOverrides(Map<String, dynamic>? styles) {
    _styleOverrides = styles;
  }

  //set this to true when the styles need to be resolved again. Main example is when classList is changed in app code. This is read in the buildWidget method of the widget state
  bool stylesNeedResolving = true;

  void resolveStyles(ScopeManager scopeManager, Invokable invokable,
      flutter.BuildContext context) {
    EnsembleTheme? theme = ThemeProvider.of(context)?.theme;
    currentTheme = theme?.name;
    if (stylesNeedResolving) {
      theme?.resolveAndApplyStyles(scopeManager, this, invokable);
      currentTheme = theme?.name;
      stylesNeedResolving = false;
    }
  }
}

/// represents an individual screen translated from the YAML definition
class SinglePageModel extends PageModel with HasStyles {
  SinglePageModel._init(YamlMap docMap) {
    _processModel(docMap);
  }

  ViewBehavior viewBehavior = ViewBehavior();
  HeaderModel? headerModel;
  final String type = 'View';
  ScreenOptions? screenOptions;
  WidgetModel? rootWidgetModel;
  FooterItems? footer;

  @override
  _processModel(YamlMap docMap) {
    super._processModel(docMap);

    if (docMap.containsKey("View")) {
      if (docMap['View'] != null) {
        YamlMap viewMap = docMap['View'];
        if (viewMap['options'] is YamlMap) {
          PageType pageType = viewMap['options']['type'] == PageType.modal.name
              ? PageType.modal
              : PageType.regular;
          screenOptions = ScreenOptions(pageType: pageType);
        }

        // set the view behavior
        viewBehavior.onLoad = EnsembleAction.from(viewMap['onLoad']);
        viewBehavior.onPause = EnsembleAction.from(viewMap['onPause']);
        viewBehavior.onResume = EnsembleAction.from(viewMap['onResume']);

        processHeader(viewMap['header'], viewMap['title']);

        if (viewMap['menu'] != null) {
          menu = Menu.fromYaml(viewMap['menu'], customViewDefinitions);
        }

        if (viewMap['styles'] is YamlMap) {
          inlineStyles = {};
          (viewMap['styles'] as YamlMap).forEach((key, value) {
            inlineStyles![key] = EnsembleThemeManager.yamlToDart(value);
          });
        }
        classList = HasStyles.toClassList(
            viewMap[ViewUtil.classNameAttribute] as String?);
        widgetType = type;
        widgetTypeStyles =
            EnsembleThemeManager().currentTheme()?.getWidgetTypeStyles(type);
        if (viewMap['footer'] != null &&
            viewMap['footer']['children'] != null) {
          Map<String, dynamic>? dragOptionsMap =
              Utils.getMap(viewMap['footer']['dragOptions']);
          WidgetModel? fixedContent = (dragOptionsMap?['fixedContent'] != null)
              ? ViewUtil.buildModel(
                  Utils.getYamlMap(dragOptionsMap?['fixedContent']),
                  customViewDefinitions)
              : null;
          YamlMap footerYamlMap = YamlMap.wrap({'footer': viewMap['footer']});
          footer = FooterItems(
              ViewUtil.buildModels(
                  viewMap['footer']['children'], customViewDefinitions),
              EnsembleThemeManager.yamlToDart(
                viewMap['footer']['styles'],
              ),
              HasStyles.toClassList(
                  viewMap['footer'][ViewUtil.classNameAttribute] as String?),
              dragOptionsMap,
              fixedContent,
              ViewUtil.buildModel(footerYamlMap, customViewDefinitions));
        }

        rootWidgetModel = buildRootModel(viewMap, customViewDefinitions);
      }
    }
  }

  void processHeader(YamlMap? headerData, String? legacyTitle) {
    WidgetModel? titleWidget;
    String? titleText = legacyTitle;
    WidgetModel? background;
    WidgetModel? leadingWidget;
    Map<String, dynamic>? styles;
    List<String>? classList;

    if (headerData != null) {
      if (headerData['titleWidget'] != null) {
        titleWidget = ViewUtil.buildModel(
            headerData['titleWidget'], customViewDefinitions);
      } else if (headerData['titleText'] != null) {
        titleText = headerData['titleText'].toString();
      } else {
        // we used to overload title as text or widget
        if (ViewUtil.isViewModel(headerData['title'], customViewDefinitions)) {
          titleWidget =
              ViewUtil.buildModel(headerData['title'], customViewDefinitions);
        } else {
          titleText = headerData['title']?.toString() ?? legacyTitle;
        }
      }

      if (headerData['leadingWidget'] != null) {
        leadingWidget = ViewUtil.buildModel(
            headerData['leadingWidget'], customViewDefinitions);
      }

      if (headerData['flexibleBackground'] != null) {
        background = ViewUtil.buildModel(
            headerData['flexibleBackground'], customViewDefinitions);
      }

      styles = EnsembleThemeManager.yamlToDart(headerData['styles']);
      classList = HasStyles.toClassList(
          headerData[ViewUtil.classNameAttribute] as String?);
    }

    if (titleWidget != null ||
        titleText != null ||
        background != null ||
        styles != null ||
        leadingWidget != null ||
        classList != null) {
      headerModel = HeaderModel(
          titleText: titleText,
          titleWidget: titleWidget,
          flexibleBackground: background,
          leadingWidget: leadingWidget,   
          inlineStyles: styles,
          classList: classList);
    }
  }

  @override
  void applyTheme(
      DataContext dataContext, Map<String, dynamic> inheritedStyles) {
    EnsembleTheme? theme = EnsembleThemeManager().currentTheme();
    if (theme == null) return;
    // runtimeStyles = theme
    //     .resolveStyles(dataContext, runtimeStyles, classList, inheritedStyles, {});
    // Map<String, dynamic> inheritableParentStyles =
    //     theme.getInheritableStyles(runtimeStyles ?? {});
    // headerModel?.styles = theme.resolveStyles(dataContext, headerModel?.styles,
    //     headerModel?.classList, inheritableParentStyles, {});
    // headerModel?.titleWidget
    //     ?.applyTheme(dataContext, headerModel!.styles ?? {});
    // footer?.styles = theme.resolveStyles(dataContext, footer?.styles,
    //     footer?.classList, inheritableParentStyles, {});
    // footer?.footerWidgetModel?.applyTheme(dataContext, footer!.styles ?? {});
    // rootWidgetModel?.applyTheme(dataContext, inheritableParentStyles);
  }

  // Root View is special and can have many attributes,
  // where as the root body (e.g Column) should be more restrictive
  // (e.g the whole body shouldn't be click-enable)
  // Let's manually select what can be specified here (really just styles/item-template/children)
  WidgetModel? buildRootModel(
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
      } else {
        return null;
      }
    }
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

  @override
  Map<String, dynamic> getStyles() {
    return runtimeStyles ?? {};
  }

  @override
  void setStyles(Map<String, dynamic> styles) {
    runtimeStyles = styles;
  }
}

class WidgetModel extends Object with HasStyles {
  final SourceSpan definition;
  final String type;
  final Map<String, dynamic> props;

  // a layout can either have children or itemTemplate, but not both
  final List<WidgetModel>? children;
  final Map? itemTemplate;

  String? getId() {
    return props['id'];
  }

  WidgetModel(
      this.definition,
      this.type,
      Map<String, dynamic>? widgetTypeStyles,
      Map<String, dynamic>? idStyles,
      Map<String, dynamic>? inlineStyles,
      List<String>? classList,
      this.props,
      {this.children,
      this.itemTemplate}) {
    this.idStyles = idStyles;
    this.widgetTypeStyles = widgetTypeStyles;
    this.inlineStyles = inlineStyles;
    this.classList = classList;
    widgetType = type; //yes I don't like it much as well
    widgetId = getId();
  }
}

/// special behaviors for RootView (View) and Custom Views
class ViewBehavior {
  ViewBehavior({this.onLoad, this.onPause, this.onResume});

  EnsembleAction? onLoad;
  EnsembleAction? onPause;
  EnsembleAction? onResume;
}

class HeaderModel extends Object with HasStyles {
  HeaderModel(
      {this.titleText,
      this.titleWidget,
      this.flexibleBackground,
      this.leadingWidget,
      inlineStyles,
      classList}) {
    this.inlineStyles = inlineStyles;
    this.classList = classList;
  }

  // header title can be text or a widget
  String? titleText;
  WidgetModel? titleWidget;
  WidgetModel? leadingWidget;

  WidgetModel? flexibleBackground;
}

class FooterItems extends Object with HasStyles {
  final List<WidgetModel> children;
  Map<String, dynamic>? inlineStyles;
  final List<String>? classList;
  final Map<String, dynamic>? dragOptions;
  final WidgetModel? fixedContent;
  final WidgetModel? footerWidgetModel;

  FooterItems(this.children, this.inlineStyles, this.classList,
      this.dragOptions, this.fixedContent, this.footerWidgetModel);
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
