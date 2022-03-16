import 'package:ensemble/ensemble.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/http_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/view.dart';
import 'package:ensemble/widget/unknown_builder.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';


/// Singleton that holds the page model definition
/// and operations for the current screen
class ScreenController {
  final WidgetRegistry registry = WidgetRegistry.instance;

  // Singleton
  static final ScreenController _instance = ScreenController._internal();
  ScreenController._internal();
  factory ScreenController() {
    return _instance;
  }


  // This is wrong as the view will NOT be updated on navigation. Refactor.
  // For now we only use it once during the initial API call before loading the page
  // It should not be used subsequently
  View? initialView;

  // TODO: Back button will still use the curent page PageMode. Need to keep model state
  /// render the page from the definition and optional arguments (from previous pages)
  Widget renderPage(BuildContext context, String pageName, YamlMap data, {Map<String, dynamic>? args}) {
    PageModel pageModel = PageModel(data: data, args: args);

    Map<String, YamlMap>? apiMap = {};
    if (data['API'] != null) {
      (data['API'] as YamlMap).forEach((key, value) {
        apiMap[key] = value;
      });
    }

    PageData pageData = PageData(
      pageTitle: pageModel.title,
      pageStyles: pageModel.pageStyles,
      pageName: pageName,
      pageType: pageModel.pageType,
      datasourceMap: {},
      subViewDefinitions: pageModel.subViewDefinitions,
      args: args,
      apiMap: apiMap
    );

    return _buildPage(context, pageModel, pageData);


  }

  Widget? _buildFooter(BuildContext context, PageModel pageModel) {
    // Footer can only take 1 child by our design. Ignore the rest
    if (pageModel.footer != null && pageModel.footer!.children.isNotEmpty) {
      return AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 500),
          child: SizedBox(
            width: double.infinity,
            height: 110,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 32),
              child: _buildChildren(context, [pageModel.footer!.children.first]).first,
            )
          )
      );
    }
    return null;
  }

  /// navigation bar
  BottomNavigationBar? _buildNavigationBar(BuildContext context, PageModel pageModel) {
    if (pageModel.menuItems.length >= 2) {
      int selectedIndex = 0;
      List<BottomNavigationBarItem> navItems = [];
      for (int i=0; i<pageModel.menuItems.length; i++) {
        MenuItem item = pageModel.menuItems[i];
        navItems.add(BottomNavigationBarItem(
            icon: (item.icon == 'home' ? const Icon(Icons.home) : const Icon(Icons.account_box)),
            label: item.label));
        if (item.selected) {
          selectedIndex = i;
        }
      }
      return BottomNavigationBar(
          items: navItems,
          onTap: (index) => selectNavigationIndex(context, pageModel.menuItems[index]),
          currentIndex: selectedIndex);
    }
  }

  View _buildPage(BuildContext context, PageModel pageModel, PageData pageData) {
    // save the current view to look up when populating initial API load ONLY
    initialView = View(
        pageData,
        buildWidget(context, pageModel.rootWidgetModel),
        footer: _buildFooter(context, pageModel),
        navBar: _buildNavigationBar(context, pageModel));
    return initialView!;
  }


  List<Widget> _buildChildren(BuildContext context, List<WidgetModel> models) {
    List<Widget> children = [];
    for (WidgetModel model in models) {
      children.add(buildWidget(context, model));
    }
    return children;
  }

  /// build a widget from a given model
  Widget buildWidget(BuildContext context, WidgetModel model) {
    WidgetBuilderFunc builderFunc = WidgetRegistry.widgetBuilders[model.type]
        ?? UnknownBuilder.fromDynamic;
    ensemble.WidgetBuilder builder = builderFunc(
        model.props,
        model.styles,
        registry: registry);

    // first create the child widgets for layouts
    List<Widget>? layoutChildren;
    if (model.children != null) {
      layoutChildren = _buildChildren(context, model.children!);
    }

    // create the widget
    return builder.buildWidget(context: context, children: layoutChildren, itemTemplate: model.itemTemplate);
  }

  /// register listeners for data changes
  void registerDataListener(BuildContext context, String apiListener, Function callback) {
    ViewState? viewState = context.findRootAncestorStateOfType<ViewState>();
    if (viewState != null) {
      ActionResponse? action = viewState.widget.pageData.datasourceMap[apiListener];
      if (action == null) {
        action = ActionResponse();
        viewState.widget.pageData.datasourceMap[apiListener] = action;
      }
      action.addListener(callback);
    }
  }


  /// handle Action e.g invokeAPI
  void executeAction(BuildContext context, YamlMap payload) async {
    ViewState? viewState = context.findRootAncestorStateOfType<ViewState>();
    if (viewState != null) {

      if (payload["action"] == ActionType.invokeAPI.name) {
        String apiName = payload['name'];
        YamlMap? api = viewState.widget.pageData.apiMap?[apiName];
        if (api != null) {
          HttpUtils.invokeApi(api).then((result) => onActionResponse(context, apiName, result));
        }
      } else if (payload['action'] == ActionType.navigateScreen.name) {

        Map<String, dynamic>? nextArgs = {};
        if (payload['inputs'] is YamlMap) {
          Map<String, dynamic> tempArgs = viewState.widget.pageData.getPageData();
          // then add localized templated data (for now just go up 1 level)
          TemplatedState? templatedState = context.findRootAncestorStateOfType<TemplatedState>();
          if (templatedState != null) {
            tempArgs.addAll(templatedState.widget.localDataMap);
          }

          (payload['inputs'] as YamlMap).forEach((key, value) {
            nextArgs[key] = Utils.evalExpression(value, tempArgs);
          });
        }
        // args may be cleared out on hot reload. Check this
        Ensemble().navigateToPage(context, payload['name'], pageArgs: nextArgs);
      }

    }


  }

  /// return the View which is the Root of the page, where you have access to the PageData
  Map<String, YamlMap> getSubViewDefinitionsFromRootView(BuildContext context) {
    ViewState? viewState = context.findRootAncestorStateOfType<ViewState>();
    if (viewState != null) {
      return viewState.widget.pageData.subViewDefinitions ?? {};
    }
    return {};
  }

  /// e.g upon return of API result
  void onActionResponse(BuildContext context, String actionName, Map<String, dynamic> result) {
    ViewState? viewState = context.findRootAncestorStateOfType<ViewState>();
    // when API is invoked before the page is load, we don't have the context
    // of the page. In this case fallback to the initial View (which should
    // always be the correct one we want to populate?)
    viewState ??= initialView?.getState();

    if (viewState != null && viewState.mounted) {
      ActionResponse? action = viewState.widget.pageData.datasourceMap[actionName];
      if (action == null) {
        action = ActionResponse();
        viewState.widget.pageData.datasourceMap[actionName] = action;
      }
      action.resultData = result;
    }


  }




  void selectNavigationIndex(BuildContext context, MenuItem menuItem) {
    Ensemble().navigateToPage(context, menuItem.page, replace: true);
  }




}


enum ActionType { invokeAPI, navigateScreen }


//typedef ActionCallback = void Function(YamlMap inputMap);
