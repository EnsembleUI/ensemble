import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/ensemble_context.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/http_utils.dart';
import 'package:ensemble/view.dart';
import 'package:ensemble/widget/unknown_builder.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:ensemble/widget/widget.dart';
import 'package:flutter/material.dart';
import 'package:sdui/invokables/invokable.dart';
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
    PageModel pageModel = PageModel(data: data, pageArguments: args);

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
      eContext: pageModel.eContext,
      apiMap: apiMap
    );

    return _buildPage(context, pageModel, pageData);


  }

  Widget? _buildFooter(EnsembleContext eContext, PageModel pageModel) {
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
              child: _buildChildren(eContext, [pageModel.footer!.children.first]).first,
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
        buildWidget(pageData.getEnsembleContext(), pageModel.rootWidgetModel),
        footer: _buildFooter(pageData.getEnsembleContext(), pageModel),
        navBar: _buildNavigationBar(context, pageModel));
    return initialView!;
  }


  List<Widget> _buildChildren(EnsembleContext eContext, List<WidgetModel> models) {
    List<Widget> children = [];
    for (WidgetModel model in models) {
      children.add(buildWidget(eContext, model));
    }
    return children;
  }

  /// build a widget from a given model
  Widget buildWidget(EnsembleContext eContext, WidgetModel model) {

    Function? widgetInstance = WidgetRegistry.widgetMap[model.type];
    if (widgetInstance != null) {
      Invokable widget = widgetInstance.call();

      // set props and styles on the widget. At this stage the widget
      // has not been attached, so no worries about ValueNotifier
      for (String key in model.props.keys) {
        if (widget.getSettableProperties().contains(key)) {
          widget.setProperty(key, model.props[key]);
        }
      }
      for (String key in model.styles.keys) {
        if (widget.getSettableProperties().contains(key)) {
          widget.setProperty(key, model.styles[key]);
        }
      }
      // save a mapping to the widget ID to our context
      if (model.props.containsKey('id')) {
        eContext.addInvokableContext(model.props['id'], widget);
      }

      // build children and pass itemTemplate for Containers
      if (widget is UpdatableContainer) {
        List<Widget>? layoutChildren;
        if (model.children != null) {
          layoutChildren = _buildChildren(eContext, model.children!);
        }
        (widget as UpdatableContainer).initChildren(children: layoutChildren, itemTemplate: model.itemTemplate);
      }

      return widget as HasController;
    } else {
      WidgetBuilderFunc builderFunc = WidgetRegistry.widgetBuilders[model.type]
          ?? UnknownBuilder.fromDynamic;
      ensemble.WidgetBuilder builder = builderFunc(
          model.props,
          model.styles,
          registry: registry);

      // first create the child widgets for layouts
      List<Widget>? layoutChildren;
      if (model.children != null) {
        layoutChildren = _buildChildren(eContext, model.children!);
      }

      // create the widget
      return builder.buildWidget(children: layoutChildren, itemTemplate: model.itemTemplate);
    }

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
      EnsembleContext eContext = viewState.widget.pageData.getEnsembleContext();

      if (payload["action"] == ActionType.invokeAPI.name) {
        String apiName = payload['name'];
        YamlMap? api = viewState.widget.pageData.apiMap?[apiName];
        if (api != null) {
          HttpUtils.invokeApi(api, eContext: eContext)
              .then((result) => onAPIResponse(context, api, apiName, result))
              .onError((error, stackTrace) => onApiError(context, api, error));
        }
      } else if (payload['action'] == ActionType.navigateScreen.name) {

        Map<String, dynamic>? nextArgs = {};
        if (payload['inputs'] is YamlMap) {
          EnsembleContext localizedContext = eContext.clone();

          // then add localized templated data (for now just go up 1 level)
          TemplatedState? templatedState = context.findRootAncestorStateOfType<TemplatedState>();
          if (templatedState != null) {
            localizedContext.addDataContext(templatedState.widget.localDataMap);
          }

          (payload['inputs'] as YamlMap).forEach((key, value) {
            nextArgs[key] = localizedContext.eval(value);
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
  void onAPIResponse(BuildContext context, YamlMap apiPayload, String actionName, Map<String, dynamic> result) {
    ViewState? viewState = context.findRootAncestorStateOfType<ViewState>();
    // when API is invoked before the page is load, we don't have the context
    // of the page. In this case fallback to the initial View (which should
    // always be the correct one we want to populate?)
    viewState ??= initialView?.getState();

    if (viewState != null && viewState.mounted) {
      // process API response
      if (apiPayload['onResponse'] != null) {
        processCodeBlock(apiPayload['onResponse'].toString());
      }

      // update data source, which will dispatch changes to its listeners
      ActionResponse? action = viewState.widget.pageData.datasourceMap[actionName];
      if (action == null) {
        action = ActionResponse();
        viewState.widget.pageData.datasourceMap[actionName] = action;
      }
      action.resultData = result;
    }


  }

  void onApiError(BuildContext context, YamlMap apiPayload, Object? error) {
    if (apiPayload['onError'] != null) {
      processCodeBlock(apiPayload['onError'].toString());
    }

    // silently fail if error handle is not defined? or should we alert user?
  }

  void processCodeBlock(String codeBlock) {
    Match? match = RegExp("//.*@code\n").matchAsPrefix(codeBlock);
    if (match != null) {
      String code = codeBlock.substring(match.end);
      print(">>$code<<");
    }
  }




  void selectNavigationIndex(BuildContext context, MenuItem menuItem) {
    Ensemble().navigateToPage(context, menuItem.page, replace: true);
  }






}


enum ActionType { invokeAPI, navigateScreen }


//typedef ActionCallback = void Function(YamlMap inputMap);
