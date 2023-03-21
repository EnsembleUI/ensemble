import 'dart:async';
import 'dart:developer';
import 'dart:ffi';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/page_group.dart';
import 'package:ensemble/framework/widget/camera_manager.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/framework/widget/toast.dart';
import 'package:ensemble/layout/ensemble_page_route.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/http_utils.dart';
import 'package:ensemble/framework/view/page.dart' as ensemble;
import 'package:ensemble/util/upload_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:yaml/yaml.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';

 
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

  /// get the ScopeManager given the context
  ScopeManager? _getScopeManager(BuildContext context) {
    // get the current scope of the widget that invoked this. It gives us
    // the data context to evaluate expression
    ScopeManager? scopeManager = ensemble.DataScopeWidget.getScope(context);

    // when context is at the root View, we can't reach the DataScopeWidget which is
    // actually a child of View. Let's just get the scopeManager directly.
    // TODO: find a better more consistent way of getting ScopeManager
    if (scopeManager == null && context.widget is ensemble.Page) {
      scopeManager = (context.widget as ensemble.Page).rootScopeManager;
    }

    // If we still can't find a ScopeManager, look into the PageGroupWidget
    // which extends the DataScopeWidget. We have to do this again since
    // Unfortunately look up only works by exact type (and not inherited type)
    scopeManager ??= PageGroupWidget.getScope(context);

    return scopeManager;
  }

  /// handle Action e.g invokeAPI
  void executeAction(BuildContext context, EnsembleAction action, {EnsembleEvent? event}) {
    ScopeManager? scopeManager = _getScopeManager(context);
    if (scopeManager != null) {
      executeActionWithScope(context, scopeManager, action, event: event);
    }
  }
  void executeActionWithScope(BuildContext context, ScopeManager scopeManager, EnsembleAction action, {EnsembleEvent? event}) {
    _executeAction(context, scopeManager.dataContext, action, scopeManager.pageData.apiMap, scopeManager, event: event);
  }

  /// internally execute an Action
  Future<void> _executeAction(BuildContext context, DataContext providedDataContext, EnsembleAction action, Map<String, YamlMap>? apiMap, ScopeManager? scopeManager,{EnsembleEvent? event}) async {
    /// Actions are short-live so we don't need a childScope, simply create a localized context from the given context
    /// Note that scopeManager may starts out without Invokable IDs (as widgets may yet to render), but at the time
    /// of API returns, they will be populated. For this reason, always rebuild data context from scope manager.
    /// For now we are OK as we don't send off the API until the screen has rendered.
    DataContext dataContext = providedDataContext.clone(newBuildContext: context);
    /*DataContext dataContext;
    if (scopeManager != null) {
      // start with data context from scope manager but overwrite with provided data context
      dataContext = scopeManager.dataContext.clone(newBuildContext: context);
      dataContext.copy(providedDataContext, replaced: true);
    } else {
      dataContext = providedDataContext.clone(newBuildContext: context);
    }*/

    // scope the initiator to *this* variable
    if (action.initiator != null) {
      dataContext.addInvokableContext('this', action.initiator!);
    }
    if ( event != null ) {
      dataContext.addInvokableContext('event', event);
    }

    if (action is InvokeAPIAction) {
      YamlMap? apiDefinition = apiMap?[action.apiName];
      if (apiDefinition != null) {
        // evaluate input arguments and add them to context
        if (apiDefinition['inputs'] is YamlList && action.inputs != null) {
          for (var input in apiDefinition['inputs']) {
            dynamic value = dataContext.eval(action.inputs![input]);
            if (value != null) {
              dataContext.addDataContextById(input, value);
            }
          }
        }

        // if invokeAPI has an ID, add it to context so we can bind to it
        // This is useful when the API is called in a loop, so binding to its API name won't work properly
        if (action.id != null && !dataContext.hasContext(action.id!)) {
          scopeManager!.dataContext.addInvokableContext(action.id!, APIResponse());
        }

        HttpUtils.invokeApi(apiDefinition, dataContext)
            .then((response) => _onAPIComplete(context, dataContext, action, apiDefinition, Response(response), apiMap, scopeManager))
            .onError((error, stackTrace) => processAPIError(context, dataContext, action, apiDefinition, error, apiMap, scopeManager));
      } else {
        throw RuntimeError("Unable to find api definition for ${action.apiName}");
      }
    } else if (action is BaseNavigateScreenAction) {
      // process input parameters
      Map<String, dynamic>? nextArgs = {};
      action.inputs?.forEach((key, value) {
        nextArgs[key] = dataContext.eval(value);
      });

      RouteOption? routeOption;
      if (action is NavigateScreenAction) {
        if (action.options?['clearAllScreens'] == true) {
          routeOption = RouteOption.clearAllScreens;
        } else if (action.options?['replaceCurrentScreen'] == true) {
          routeOption = RouteOption.replaceCurrentScreen;
        }
      }

      PageRouteBuilder routeBuilder = navigateToScreen(
          providedDataContext.buildContext,
          screenName: dataContext.eval(action.screenName),
          asModal: action.asModal,
          routeOption: routeOption,
          pageArgs: nextArgs);

      // process onModalDismiss
      if (action is NavigateModalScreenAction &&
          action.onModalDismiss != null &&
          routeBuilder is EnsembleModalPageRouteBuilder &&
          scopeManager != null) {
        // callback on modal pop
        routeBuilder.popped.whenComplete(() {
          executeActionWithScope(context, scopeManager, action.onModalDismiss!);
        });
      }

    }  else if (action is ShowCameraAction)
    {
      if(scopeManager != null) {
        CameraManager().openCamera(context, action);
      }
    } else if (action is ShowDialogAction) {
      if (scopeManager != null) {
        Widget widget = scopeManager.buildWidgetFromDefinition(action.widget);

        // get styles. TODO: make bindable
        Map<String, dynamic> dialogStyles = {};
        action.options?.forEach((key, value) {
          dialogStyles[key] = dataContext.eval(value);
        });

        bool useDefaultStyle = dialogStyles['style'] != 'none';
        BuildContext? dialogContext;

        showGeneralDialog(
            useRootNavigator: false,  // use inner-most MaterialApp (our App) as root so theming is ours
            context: context,
            barrierDismissible: true,
            barrierLabel: "Barrier",
            barrierColor: Colors.black54,   // this has some transparency so the bottom shown through

            pageBuilder: (context, animation, secondaryAnimation) {
              // save a reference to the builder's context so we can close it programmatically
              dialogContext = context;
              scopeManager.openedDialogs.add(dialogContext!);

              return Align(
                  alignment: Alignment(
                      Utils.getDouble(dialogStyles['horizontalOffset'], min: -1, max: 1, fallback: 0),
                      Utils.getDouble(dialogStyles['verticalOffset'], min: -1, max: 1, fallback: 0)
                  ),
                  child: Material(
                      color: Colors.transparent,
                      child: ConstrainedBox(
                          constraints: BoxConstraints(
                              minWidth: Utils.getDouble(dialogStyles['minWidth'], fallback: 0),
                              maxWidth: Utils.getDouble(dialogStyles['maxWidth'], fallback: double.infinity),
                              minHeight: Utils.getDouble(dialogStyles['minHeight'], fallback: 0),
                              maxHeight: Utils.getDouble(dialogStyles['maxHeight'], fallback: double.infinity)
                          ),
                          child: Container(
                              decoration: useDefaultStyle
                                ? const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.all(Radius.circular(5)),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: Colors.white38,
                                        blurRadius: 5,
                                        offset: Offset(0, 0),
                                      )
                                    ])
                                : null,
                              margin: useDefaultStyle ? const EdgeInsets.all(20) : null,
                              padding: useDefaultStyle ? const EdgeInsets.all(20) : null,
                              child: SingleChildScrollView (
                                child: widget,
                              )
                          )
                      )
                  )

              );
            }
        ).then((value) {
          // remove the dialog context since we are closing them
          scopeManager.openedDialogs.remove(dialogContext);

          // callback when dialog is dismissed
          if (action.onDialogDismiss != null) {
            executeActionWithScope(context, scopeManager, action.onDialogDismiss!);
          }
        });
      }
    } else if (action is CloseAllDialogsAction) {
      if (scopeManager != null) {
        for (var dialogContext in scopeManager.openedDialogs) {
          Navigator.pop(dialogContext);
        }
        scopeManager.openedDialogs.clear();
      }

    } else if (action is StartTimerAction) {

      // what happened if ScopeManager is null?
      if (scopeManager != null) {

        int delay = action.payload?.startAfter ??
            (action.payload?.repeat == true ? action.payload?.repeatInterval ?? 0 : 0);

        // we always execute at least once, delayed by startAfter and fallback to repeatInterval (or immediate if startAfter is 0)
        Timer(
            Duration(seconds: delay),
                () {
              // execute the action
              executeActionWithScope(context, scopeManager, action.onTimer);

              // if no repeat, execute onTimerComplete
              if (action.payload?.repeat != true) {
                if (action.onTimerComplete != null) {
                  executeActionWithScope(context, scopeManager, action.onTimerComplete!);
                }
              }
              // else repeating timer
              else if (action.payload?.repeatInterval != null) {
                /// repeatCount value of null means forever by default
                int? repeatCount;
                if (action.payload?.maxTimes != null) {
                  repeatCount = action.payload!.maxTimes! - 1;
                }
                if (repeatCount != 0) {
                  int counter = 0;
                  final timer = Timer.periodic(
                      Duration(seconds: action.payload!.repeatInterval!),
                          (timer) {
                        // execute the action
                        executeActionWithScope(context, scopeManager, action.onTimer);

                        // automatically cancel timer when repeatCount is reached
                        if (repeatCount != null && ++counter == repeatCount) {
                          timer.cancel();

                          // timer terminates, call onTimerComplete
                          if (action.onTimerComplete != null) {
                            executeActionWithScope(context, scopeManager, action.onTimerComplete!);
                          }
                        }
                      }
                  );

                  // save our timer to our PageData since user may want to cancel at anytime
                  // and also when we navigate away from the page
                  scopeManager.addTimer(action, timer);
                }
              }

            }
        );
      }


    } else if (action is StopTimerAction) {
      if (scopeManager != null) {
        try {
          scopeManager.removeTimer(action.id);
        } catch (e) {
          debugPrint('error when trying to stop timer with name ${action.id}. Error: ${e.toString()}');
        }
      }
    } else if (action is GetLocationAction) {
      executeGetLocationAction(scopeManager!, dataContext, context, action);
    } else if (action is ExecuteCodeAction) {
      action.inputs?.forEach((key, value) {
        dynamic val = dataContext.eval(value);
        if (val != null) {
          dataContext.addDataContextById(key, val);
        }
      });
      dataContext.evalCode(action.codeBlock,action.codeBlockSpan);

      if (action.onComplete != null && scopeManager != null) {
        executeActionWithScope(context, scopeManager, action.onComplete!);
      }
    } else if (action is ShowToastAction) {
      Widget? customToastBody;
      if (scopeManager != null && action.widget != null) {
        customToastBody = scopeManager.buildWidgetFromDefinition(action.widget);
      }
      ToastController().showToast(context, action, customToastBody);
    } else if ( action is OpenUrlAction ) {
      dynamic value = dataContext.eval(action.url);
      value ??= '';
      launchUrl(Uri.parse(value),mode: (action.openInExternalApp)?LaunchMode.externalApplication:LaunchMode.platformDefault );
    } else if (action is FileUploadAction) {

        List<File>? selectedFiles;
        const defaultMaxFileSize = 100000;
        const defaultOverMaxFileSizeMessage = 'The size of is which is larger than the maximum allowed';

        final rawFiles = scopeManager?.dataContext.eval(action.files) as List<dynamic>?;
        if (rawFiles == null) {
          if (action.onError != null) executeAction(context, action.onError!);
          return;
        }

        selectedFiles = rawFiles.map((data) => File.fromJson(data)).toList().cast<File>();
        if (selectedFiles.isEmpty) {
          if (action.onError != null) executeAction(context, action.onError!);
          return;
        }

        int totalSize = selectedFiles.fold<int>(0, (previousValue, element) => previousValue + element.size);
        totalSize = totalSize ~/ 1000;

        final message = Utils.translateWithFallback(
          'ensemble.input.overMaxFileSizeMessage', 
          action.overMaxFileSizeMessage ?? defaultOverMaxFileSizeMessage,
        );

        if (totalSize > (action.maxFileSize ?? defaultMaxFileSize)) {
          ToastController().showToast(context, ShowToastAction(type: ToastType.error, message: message, position: 'bottom'), null);
          if (action.onError != null) executeAction(context, action.onError!);
          return;
        }

        if (action.id != null && scopeManager != null) {
          scopeManager.dataContext.addInvokableContext(action.id!, APIResponse());
        }
        YamlMap? apiDefinition = apiMap?[action.uploadApi];
        if (apiDefinition == null) throw LanguageError('Unable to find api definition for ${action.uploadApi}');
        if (apiDefinition['inputs'] is YamlList && action.inputs != null) {
          for (var input in apiDefinition['inputs']) {
            dynamic value = dataContext.eval(action.inputs![input]);
            if (value != null) {
              dataContext.addDataContextById(input, value);
            }
          }
        }
        final response = await UploadUtils.uploadFiles(
          api: apiDefinition, 
          eContext: dataContext,
          files: selectedFiles,
          fieldName: action.fieldName,
          onError: action.onError == null ? null : (error) => executeAction(context, action.onError!),
        );
        if (response == null || action.id == null || scopeManager == null) return;
        
        final fileResponse = scopeManager.dataContext.getContextById(action.id!) as APIResponse;
        fileResponse.setAPIResponse(response);
        scopeManager.dispatch(ModelChangeEvent(APIBindingSource(action.id!), fileResponse));
        if (action.onComplete != null) executeAction(context, action.onComplete!);
        
    } else if (action is FilePickerAction) {
      FilePicker.platform.pickFiles(
        type: action.allowedExtensions == null ? FileType.any: FileType.custom,
        allowedExtensions: action.allowedExtensions,
        allowCompression: action.allowCompression ?? true,
        allowMultiple: action.allowMultiple ?? false,
      ).then((result) {
          if (result == null || result.files.isEmpty) return;
          final selectedFiles = result.files.map((file) => File.fromPlatformFile(file)).toList();
          final fileData = FileData(files: selectedFiles);
          if (action.id == null || scopeManager == null) return;
          scopeManager.dataContext.addDataContextById(action.id!, fileData);
          scopeManager.dispatch(ModelChangeEvent(SimpleBindingSource(action.id!), fileData));
      });
    } else if (action is NavigateBack) {
      if (scopeManager != null) {
        Navigator.of(context).maybePop();
      }
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
  void _onAPIComplete(BuildContext context, DataContext dataContext, InvokeAPIAction action, YamlMap apiDefinition, Response response, Map<String, YamlMap>? apiMap, ScopeManager? scopeManager) {
    // first execute API's onResponse code block
    EnsembleAction? onResponse = EnsembleAction.fromYaml(apiDefinition['onResponse'], initiator: action.initiator);
    if (onResponse != null) {
      processAPIResponse(context, dataContext, onResponse, response, apiMap, scopeManager, apiChangeHandler: dispatchAPIChanges, action: action, modifiableAPIResponse: true);
    }
    // dispatch changes even if we don't have onResponse
    else {
      dispatchAPIChanges(scopeManager, action, APIResponse(response: response));
    }

    // if our Action has onResponse, invoke that next
    if (action.onResponse != null) {
      processAPIResponse(context, dataContext, action.onResponse!, response, apiMap, scopeManager);
    }

  }

  void dispatchStorageChanges(BuildContext context, String key, dynamic value) {
    ScopeManager? scopeManager = _getScopeManager(context);
    if (scopeManager != null) {
      scopeManager.dispatch(ModelChangeEvent(StorageBindingSource(key), value));
    }
  }

  void dispatchAPIChanges(ScopeManager? scopeManager, InvokeAPIAction action, APIResponse apiResponse) {
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
            scopeManager.dispatch(ModelChangeEvent(APIBindingSource(action.id!), apiById));
          }
        }



      }
    }
  }

  /// Executing the onResponse action. Note that this can be
  /// the API's onResponse or a caller's onResponse (e.g. onPageLoad's onResponse)
  void processAPIResponse(BuildContext context, DataContext dataContext, EnsembleAction onResponseAction, Response response, Map<String, YamlMap>? apiMap, ScopeManager? scopeManager, {Function? apiChangeHandler, InvokeAPIAction? action, bool? modifiableAPIResponse}) {
    // execute the onResponse on the API definition
    APIResponse apiResponse = modifiableAPIResponse == true ?
    ModifiableAPIResponse(response: response) :
    APIResponse(response: response);

    DataContext localizedContext = dataContext.clone();
    localizedContext.addInvokableContext('response', apiResponse);
    _executeAction(context, localizedContext, onResponseAction, apiMap, scopeManager);

    if (modifiableAPIResponse == true) {
      // should be on Action's callback instead
      apiChangeHandler?.call(scopeManager, action, apiResponse);
    }
  }

  /// executing the onError action
  void processAPIError(BuildContext context, DataContext dataContext, InvokeAPIAction action, YamlMap apiDefinition, Object? error, Map<String, YamlMap>? apiMap, ScopeManager? scopeManager) {
    log("Error: $error");

    EnsembleAction? onErrorAction = EnsembleAction.fromYaml(apiDefinition['onError']);
    if (onErrorAction != null) {
      // probably want to include the error?
      _executeAction(context, dataContext, onErrorAction, apiMap, scopeManager);
    }

    // if our Action has onError, invoke that next
    if (action.onError != null) {
      _executeAction(context, dataContext, action.onError!, apiMap, scopeManager);
    }

    // silently fail if error handle is not defined? or should we alert user?
  }
  /// Navigate to another screen
  /// [screenName] - navigate to the screen if specified, otherwise to appHome
  /// [asModal] - shows the App in a regular or modal screen
  /// [replace] - whether to replace the current route on the stack, such that
  /// navigating back will skip the current route.
  /// [pageArgs] - Key/Value pairs to send to the screen if it takes input parameters
  PageRouteBuilder navigateToScreen(BuildContext context, {
    String? screenName,
    bool? asModal,
    RouteOption? routeOption,
    Map<String, dynamic>? pageArgs,
  }) {
    PageType pageType = asModal == true ? PageType.modal : PageType.regular;

    Widget screenWidget = getScreen(screenName: screenName, asModal: asModal, pageArgs: pageArgs);

    PageRouteBuilder route = getScreenBuilder(screenWidget, pageType: pageType);
    // push the new route and remove all existing screens. This is suitable for logging out.
    if (routeOption == RouteOption.clearAllScreens) {
      Navigator.pushAndRemoveUntil(context, route, (route) => false);
    } else if (routeOption == RouteOption.replaceCurrentScreen) {
      Navigator.pushReplacement(context, route);
    } else {
      Navigator.push(context, route);
    }
    return route;
  }

  /// get the screen widget. If screen is not specified, return the home screen
  Widget getScreen({
    Key? key,
    String? screenName,
    bool? asModal,
    Map<String, dynamic>? pageArgs,
  }) {
    PageType pageType = asModal == true ? PageType.modal : PageType.regular;
    return  Screen(
      key: key,
      appProvider: AppProvider(definitionProvider: Ensemble().getConfig()!.definitionProvider),
      screenPayload: ScreenPayload(
        screenName: screenName,
        pageType: pageType,
        arguments: pageArgs,
      ),
    );

  }

  void executeGetLocationAction(ScopeManager scopeManager, DataContext dataContext, BuildContext context, GetLocationAction action) {
    if (action.onLocationReceived != null) {
      Device().getLocationStatus().then((LocationStatus status) async {
        if (status == LocationStatus.ready) {
          // if recurring
          if (action.recurring == true) {
            StreamSubscription<Position> streamSubscription = Geolocator.getPositionStream(
                locationSettings: LocationSettings(
                    accuracy: LocationAccuracy.high,
                    distanceFilter: action.recurringDistanceFilter ?? 1000
                )
            ).listen((Position? location) {
              if (location != null) {
                log("on location updates");
                // update last location. TODO: consolidate this
                Device().updateLastLocation(location);

                _onLocationReceived(scopeManager, dataContext, context, action.onLocationReceived!, location);
              }
              else if (action.onError != null){
                DataContext localizedContext = dataContext.clone();
                localizedContext.addDataContextById('reason', 'unknown');
                _executeAction(context, localizedContext, action.onError!, null, scopeManager);
              }
            });
            scopeManager.addLocationListener(streamSubscription);
          }
          // one-time get location
          else {
            log("get location");
            _onLocationReceived(scopeManager, dataContext, context, action.onLocationReceived!, await Device().simplyGetLocation());
          }
        } else if (action.onError != null){
          DataContext localizedContext = dataContext.clone();
          localizedContext.addDataContextById('reason', status.name);
          _executeAction(context, localizedContext, action.onError!, null, scopeManager);
        }
      });
    }
  }

  void _onLocationReceived(ScopeManager scopeManager, DataContext dataContext, BuildContext context, EnsembleAction onLocationReceived, Position location) {
    DataContext localizedContext = dataContext.clone();
    localizedContext.addDataContextById('latitude', location.latitude);
    localizedContext.addDataContextById('longitude', location.longitude);
    _executeAction(context, localizedContext, onLocationReceived, null, scopeManager);
  }


  /// return a wrapper for the screen widget
  /// with custom animation for different pageType
  PageRouteBuilder getScreenBuilder(Widget screenWidget, {
    PageType? pageType
  }) {
    if (pageType == PageType.modal) {
      return EnsembleModalPageRouteBuilder(screenWidget: screenWidget);
    } else {
      return EnsemblePageRouteBuilder(screenWidget: screenWidget);
    }
  }

}

enum RouteOption {
  replaceCurrentScreen,
  clearAllScreens
}
