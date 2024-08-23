import 'dart:developer';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/apiproviders/http_api_provider.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/config.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:yaml/yaml.dart';
import 'package:http/http.dart' as http;

import '../framework/apiproviders/api_provider.dart';

class InvokeAPIAction extends EnsembleAction {
  InvokeAPIAction(
      {super.initiator,
      required this.apiName,
      this.id,
      super.inputs,
      this.onResponse,
      this.onError});

  String? id;
  final String apiName;
  EnsembleAction? onResponse;
  EnsembleAction? onError;

  factory InvokeAPIAction.fromYaml({Invokable? initiator, Map? payload}) {
    if (payload == null || payload['name'] == null) {
      throw LanguageError(
          "${ActionType.invokeAPI.name} requires the 'name' of the API.");
    }

    return InvokeAPIAction(
        initiator: initiator,
        apiName: payload['name'],
        id: Utils.optionalString(payload['id']),
        inputs: Utils.getMap(payload['inputs']),
        onResponse:
            EnsembleAction.from(payload['onResponse'], initiator: initiator),
        onError: EnsembleAction.from(payload['onError'], initiator: initiator));
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) {
    var evalApiName = scopeManager.dataContext.eval(apiName);
    var cloneAction = InvokeAPIAction(
        apiName: evalApiName,
        initiator: initiator,
        id: id,
        inputs: inputs,
        onResponse: onResponse,
        onError: onError);
    return InvokeAPIController().execute(
        cloneAction, context, scopeManager, scopeManager.pageData.apiMap);
  }
}

class InvokeAPIController {
  Future<Response> executeWithContext(
      BuildContext context, InvokeAPIAction action,
      {Map<String, dynamic>? additionalInputs}) {
    ScopeManager? foundScopeManager =
        ScreenController().getScopeManager(context);
    if (foundScopeManager != null) {
      // we need an ephemeral scope to append data to
      ScopeManager scopeManager =
          foundScopeManager.createChildScope(ephemeral: true);

      // add additional data if specified
      DataContext dataContext = scopeManager.dataContext;
      if (additionalInputs != null) {
        dataContext.addDataContext(additionalInputs);
      }

      return execute(
          action, context, scopeManager, scopeManager.pageData.apiMap);
    }
    throw Exception('Unable to execute API from context');
  }

  APIProvider getAPIProvider(BuildContext context, YamlMap apiDefinition) {
    String? provider = apiDefinition['type'];
    return APIProviders.of(context).getProvider(provider);
  }

  Future<Response> execute(InvokeAPIAction action, BuildContext context,
      ScopeManager scopeManager, Map<String, YamlMap>? apiMap) async {
    YamlMap? apiDefinition = apiMap?[action.apiName];
    if (apiDefinition != null) {
      ScopeManager apiScopeManager =
          scopeManager.newCreateChildScope(ephemeral: true);
      // evaluate input arguments and add them to context
      if (apiDefinition['inputs'] is YamlList && action.inputs != null) {
        for (var input in apiDefinition['inputs']) {
          dynamic value =
              apiScopeManager.dataContext.eval(action.inputs![input]);
          if (value != null) {
            apiScopeManager.dataContext.addToThisContext(input, value);
          }
        }
      }

      // if invokeAPI has an ID, add it to context so we can bind to it
      // This is useful when the API is called in a loop, so binding to its API name won't work properly
      //this is added to the parent so that the id of the API is visible outside the API block
      if (action.id != null &&
          !scopeManager.dataContext.hasContext(action.id!)) {
        scopeManager.dataContext.addInvokableContext(action.id!, APIResponse());
      }

      dynamic errorResponse;
      try {
        final APIResponse? oldResponse =
            scopeManager.dataContext.getContextById(action.apiName);
        final Response? responseObj = oldResponse?.getAPIResponse();
        responseObj?.apiState = APIState.loading;

        final isSameAPIRequest = action.apiName == responseObj?.apiName;
        final responseToDispatch = (isSameAPIRequest && responseObj != null)
            ? responseObj
            : HttpResponse.updateState(apiState: APIState.loading);
        dispatchAPIChanges(
          scopeManager,
          action,
          APIResponse(response: responseToDispatch),
        );

        Response response;
        void responseListener(Response response) {
          if (response.isOkay) {
            _onAPIComplete(context, action, apiDefinition, response, apiMap,
                apiScopeManager);
          } else {
            errorResponse = response;
            _onAPIError(context, action, apiDefinition, errorResponse, apiMap,
                apiScopeManager);
          }
        }

        APIProvider apiProvider = getAPIProvider(context, apiDefinition);
        if (AppConfig(context, apiScopeManager.dataContext.getAppId())
                .isMockResponse() &&
            apiDefinition['mockResponse'] != null) {
          response = await apiProvider.invokeMockAPI(
              apiScopeManager.dataContext, apiDefinition['mockResponse']);
        } else if (apiDefinition['listenForChanges'] == true &&
            apiProvider is LiveAPIProvider) {
          response = await (apiProvider as LiveAPIProvider).subscribeToApi(
              context,
              apiDefinition,
              apiScopeManager.dataContext,
              action.apiName,
              responseListener);
        } else {
          response = await getAPIProvider(context, apiDefinition).invokeApi(
              context,
              apiDefinition,
              apiScopeManager.dataContext,
              action.apiName);
        }
        responseListener(response);
        return response;
        // if (response.isOkay) {
        //   _onAPIComplete(context, action, apiDefinition, response, apiMap,
        //       apiScopeManager);
        //   return response;
        // }
        // errorResponse = response;
      } catch (error) {
        errorResponse = error;
        _onAPIError(context, action, apiDefinition, errorResponse, apiMap,
            apiScopeManager);
        debugPrint(error.toString());
        return errorResponse;
      }
    } else {
      throw RuntimeError("Unable to find api definition for ${action.apiName}");
    }
  }

  /// e.g upon return of API result
  void _onAPIComplete(
      BuildContext context,
      InvokeAPIAction action,
      YamlMap apiDefinition,
      Response response,
      Map<String, YamlMap>? apiMap,
      ScopeManager scopeManager) {
    // first execute API's onResponse code block
    EnsembleAction? onResponse = EnsembleAction.from(
        apiDefinition['onResponse'],
        initiator: action.initiator);
    if (onResponse != null) {
      response.apiState = APIState.success;
      _processOnResponse(context, onResponse, response, apiMap, scopeManager,
          apiChangeHandler: dispatchAPIChanges,
          action: action,
          modifiableAPIResponse: true);
    }
    // dispatch changes even if we don't have onResponse
    else {
      response.apiState = APIState.success;
      dispatchAPIChanges(scopeManager, action, APIResponse(response: response));
    }

    // if our Action has onResponse, invoke that next
    if (action.onResponse != null) {
      _processOnResponse(
          context, action.onResponse!, response, apiMap, scopeManager);
    }
  }

  /// Executing the onResponse action. Note that this can be
  /// the API's onResponse or a caller's onResponse (e.g. onPageLoad's onResponse)
  void _processOnResponse(
      BuildContext context,
      EnsembleAction onResponseAction,
      Response response,
      Map<String, YamlMap>? apiMap,
      ScopeManager apiScopeManager,
      {Function? apiChangeHandler,
      InvokeAPIAction? action,
      bool? modifiableAPIResponse}) {
    // execute the onResponse on the API definition
    APIResponse apiResponse = modifiableAPIResponse == true
        ? ModifiableAPIResponse(response: response)
        : APIResponse(response: response);

    /// Here we received the ephemeral apiScopeManager. But we are now inside
    /// the onResponse clauses which append more data specific to onResponse
    /// only, so create a child ephemeral scope
    ScopeManager scopeManager =
        apiScopeManager.createChildScope(ephemeral: true);
    scopeManager.dataContext.addInvokableContext('response', apiResponse);
    scopeManager.dataContext.addInvokableContext(
        'event', EnsembleEvent(action?.initiator, data: apiResponse));

    // we are inside the API's onResponse, but by this time we have not
    // dispatch changes to the API yet, since we allow the user to modify it.
    // For this reason, add the apiName to this localized context so it
    // can be accessed down the chain of this API's onResponse ONLY.
    if (modifiableAPIResponse == true && action != null) {
      scopeManager.dataContext.addInvokableContext(action.apiName, apiResponse);
    }

    // we are not waiting for nested Actions to complete
    ScreenController()
        .nowExecuteAction(context, onResponseAction, apiMap, scopeManager);

    if (modifiableAPIResponse == true) {
      // should be on Action's callback instead
      // Note that we use the original apiScopeManager here
      apiChangeHandler?.call(apiScopeManager, action, apiResponse);
    }
  }

  /// executing the onError action
  void _onAPIError(
      BuildContext context,
      InvokeAPIAction action,
      YamlMap apiDefinition,
      dynamic errorResponse,
      Map<String, YamlMap>? apiMap,
      ScopeManager apiScopeManager) {
    /// Create child scope applicable for onError only
    ScopeManager scopeManager =
        apiScopeManager.createChildScope(ephemeral: true);

    String? errorStr;
    dynamic data;
    if (errorResponse is HttpResponse) {
      errorResponse.apiState = APIState.error;
      APIResponse apiResponse = APIResponse(response: errorResponse);
      scopeManager.dataContext.addInvokableContext('response', apiResponse);
      errorStr = errorResponse.reasonPhrase;
      data = apiResponse;

      /// dispatch changes.Note that here we send update with the original
      /// scopeManager, NOT the ephemeral onError one.
      dispatchAPIChanges(
          apiScopeManager, action, APIResponse(response: errorResponse));
    } else {
      errorStr = errorResponse is Error ? errorResponse.toString() : null;
    }
    var apiEvent = EnsembleEvent(action.initiator,
        error: errorStr ?? 'API Error', data: data);

    EnsembleAction? onErrorAction =
        EnsembleAction.from(apiDefinition['onError']);
    if (onErrorAction != null) {
      ScreenController().nowExecuteAction(
          context, onErrorAction, apiMap, scopeManager,
          event: apiEvent);
    }

    // if our Action has onError, invoke that next
    if (action.onError != null) {
      ScreenController().nowExecuteAction(
          context, action.onError!, apiMap, scopeManager,
          event: apiEvent);
    }

    // silently fail if error handle is not defined? or should we alert user?
  }

  void dispatchAPIChanges(ScopeManager? scopeManager, InvokeAPIAction action,
      APIResponse apiResponse) {
    // update the API response in our DataContext and fire changes to all listeners.
    // Make sure we don't override the key here, as all the scopes referenced the same API
    if (scopeManager != null) {
      dynamic api = scopeManager.dataContext.getContextById(action.apiName);
      if (api == null || api is! Invokable) {
        throw RuntimeException(
            "Unable to update API Binding as it doesn't exists");
      }
      Response? _response = apiResponse.getAPIResponse();
      if (_response != null) {
        _response.apiName = action.apiName;
        // for convenience, the result of the API contain the API response
        // so it can be referenced from anywhere.
        // Here we set the response and dispatch changes
        if (api is APIResponse) {
          api.setAPIResponse(_response);
          scopeManager.dispatch(
              ModelChangeEvent(APIBindingSource(action.apiName), api));
        }

        // if the API has an ID, update its reference and se
        if (action.id != null) {
          dynamic apiById = scopeManager.dataContext.getContextById(action.id!);
          if (apiById is APIResponse) {
            apiById.setAPIResponse(_response);
            scopeManager.dispatch(
                ModelChangeEvent(APIBindingSource(action.id!), apiById));
          }
        }
      }
    }
  }
}
