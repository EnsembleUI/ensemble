import 'dart:convert';
import 'dart:developer';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/error_handling.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/http_utils.dart';
import 'package:ensemble/framework/widget/view.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/unknown_builder.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
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

  // TODO: Back button will still use the curent page PageMode. Need to keep model state
  /// render the page from the definition and optional arguments (from previous pages)
  Widget renderPage(DataContext dataContext, YamlMap data) {
    PageModel pageModel = PageModel(data);

    // add all the API names to our context as Invokable, even though their result
    // will be null. This is so we can always reference it API responses come back
    pageModel.apiMap?.forEach((key, value) {
      // have to be careful here. API response on page load may exists,
      // don't overwrite if that is the case
      if (!dataContext.hasContext(key)) {
        dataContext.addInvokableContext(key, APIResponse());
      }
    });

    /// Upon hot reload a new View is being created, but since the key
    /// is the same as the previously identify View, Flutter did not
    /// switch the View properly. Here we are just making sure every View
    /// will always be unique.
    /// TODO: a better way is to copy data to the new View so we don't waste time creating new one (Use pageName as key?)
    View initialView = View(
        key: UniqueKey(),
        dataContext: dataContext,
        pageModel: pageModel);
    log("View created ${initialView.hashCode}");
    return initialView;


  }


  /*
  pageModel.rootWidgetModel
        scopeManager.buildWidget(pageModel.rootWidgetModel),
        menu: pageModel.menu,
        footer: _buildFooter(scopeManager, pageModel)
   */

  @Deprecated('Use ScopeManager.buildWidget()')
  List<Widget> _buildChildren(DataContext eContext, List<WidgetModel> models) {
    List<Widget> children = [];
    for (WidgetModel model in models) {
      children.add(buildWidget(eContext, model));
    }
    return children;
  }

  /// build a widget from a given model
  @Deprecated('Use ScopeManager.buildWidget()')
  Widget buildWidget(DataContext eContext, WidgetModel model) {
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

  /// handle Action e.g invokeAPI
  void executeAction(BuildContext context, EnsembleAction action) {
    // get the current scope of the widget that invoked this. It gives us
    // the data context to evaluate expression
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    if (scopeManager != null) {
      _executeAction(context, scopeManager.dataContext, action, scopeManager.pageData.apiMap);
    }
  }

  /// internally execute an Action
  void _executeAction(BuildContext context, DataContext providedDataContext, EnsembleAction action, Map<String, YamlMap>? apiMap) {
    // scope the initiator to *this* variable
    DataContext dataContext = providedDataContext.clone();
    if (action.initiator != null) {
      dataContext.addInvokableContext('this', action.initiator!);
    }

    if (action is InvokeAPIAction) {
      YamlMap? apiDefinition = apiMap?[action.apiName];
      if (apiDefinition != null) {
        // input params
        Map<String, dynamic>? params = {};
        action.inputs?.forEach((key, value) {
          params[key] = dataContext.eval(value);
        });
        HttpUtils.invokeApi(apiDefinition, dataContext, inputParams: params)
            .then((response) => _onAPIComplete(context, dataContext, action, apiDefinition, response, apiMap))
            .onError((error, stackTrace) => processAPIError(context, dataContext, apiDefinition, error, apiMap));
      }
    } else if (action is NavigateScreenAction) {
      // process input parameters
      Map<String, dynamic>? nextArgs = {};
      action.inputs?.forEach((key, value) {
        nextArgs[key] = dataContext.eval(value);
      });
      // args may be cleared out on hot reload. Check this
      Ensemble().navigateToPage(
          context, action.screenName, pageArgs: nextArgs);

    } else if (action is ExecuteCodeAction) {
      dataContext.evalCode(action.codeBlock);
    }
  }

  /// executing a code block
  /// also scope the Initiator to *this* variable
  /*void executeCodeBlock(DataContext dataContext, Invokable initiator, String codeBlock) {
    // scope the initiator to *this* variable
    DataContext localizedContext = dataContext.clone();
    localizedContext.addInvokableContext('this', initiator);
    localizedContext.evalCode(codeBlock);
  }*/

  /// e.g upon return of API result
  void _onAPIComplete(BuildContext context, DataContext dataContext, InvokeAPIAction action, YamlMap apiDefinition, Response response, Map<String, YamlMap>? apiMap) {
    // first execute API's onResponse code block
    EnsembleAction? onResponse = Utils.getAction(apiDefinition['onResponse'], initiator: action.initiator);
    if (onResponse is InvokeAPIAction) {
      processAPIResponse(context, dataContext, onResponse, response, apiMap);
    }

    // if our Action has onResponse, invoke that next
    if (action.onResponse is InvokeAPIAction) {
      processAPIResponse(context, dataContext, action.onResponse as InvokeAPIAction, response, apiMap);
    }


    // update the API response in our DataContext and fire changes to all listeners
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    if (scopeManager != null) {
      // make sure we don't override the key here, as all the scopes referenced the same API
      dynamic api = scopeManager.dataContext.getContextById(action.apiName);
      if (api == null || api is! Invokable) {
        throw RuntimeException("Unable to update API Binding as it doesn't exists");
      }
      // update the API response so all references get it
      (api as APIResponse).setAPIResponse(response);

      // dispatch changes
      scopeManager.dispatch(ModelChangeEvent(action.apiName, api));
    }




    // TODO: Legacy listeners, to be removed once refactored
    // only support JSON result for now
    /*Map<String, dynamic> jsonBody = json.decode(response.body);
    // update data source, which will dispatch changes to its listeners
    ActionResponse? action = scopeManager.pageData.datasourceMap[actionName];
    if (action == null) {
      action = ActionResponse();
      scopeManager.pageData.datasourceMap[actionName] = action;
    }
    action.resultData = jsonBody;*/


  }

  /// Executing the onResponse on the API definition
  /// Note that this is executed AFTER our widgets have been rendered, such that
  /// we can reference any widgets here in the code block
  /// TODO: don't rely on order of execution
  void processAPIResponse(BuildContext context, DataContext dataContext, InvokeAPIAction apiAction, Response response, Map<String, YamlMap>? apiMap) {
    // execute the onResponse on the API definition
    DataContext localizedContext = dataContext.clone();
    localizedContext.addInvokableContext('response', APIResponse(response: response));
    _executeAction(context, localizedContext, apiAction, apiMap);
  }

  void processAPIError(BuildContext context, DataContext dataContext, YamlMap apiDefinition, Object? error, Map<String, YamlMap>? apiMap) {
    EnsembleAction? onErrorAction = Utils.getAction(apiDefinition['onError']);
    if (onErrorAction != null) {
      // probably want to include the error?
      _executeAction(context, dataContext, onErrorAction, apiMap);
    }

    // silently fail if error handle is not defined? or should we alert user?
  }

  void processCodeBlock(DataContext eContext, String codeBlock) {
    try {
      eContext.evalCode(codeBlock);
    } catch (e) {
      print ("Code block exception: " + e.toString());
    }
  }






}
