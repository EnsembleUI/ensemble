// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:ensemble/action/navigation_action.dart';
import 'package:ensemble/action/upload_files_action.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/permissions_manager.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/camera_manager.dart';
import 'package:ensemble/framework/stub/contacts_manager.dart';
import 'package:ensemble/framework/stub/file_manager.dart';
import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:ensemble/framework/stub/plaid_link_manager.dart';
import 'package:ensemble/framework/theme/theme_loader.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/page.dart' as ensemble;
import 'package:ensemble/framework/view/page_group.dart';
import 'package:ensemble/framework/widget/modal_screen.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/framework/widget/toast.dart';
import 'package:ensemble/layout/ensemble_page_route.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/notification_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:walletconnect_dart/walletconnect_dart.dart';
import 'package:web_socket_client/web_socket_client.dart';
import 'package:yaml/yaml.dart';

import 'framework/widget/wallet_connect_modal.dart';

/// Singleton that holds the page model definition
/// and operations for the current screen
class ScreenController {
  // Singleton
  static final ScreenController _instance = ScreenController._internal();

  ScreenController._internal();

  factory ScreenController() {
    return _instance;
  }

  /// get the ScopeManager given the context
  ScopeManager? getScopeManager(BuildContext context) {
    // get the current scope of the widget that invoked this. It gives us
    // the data context to evaluate expression
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);

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
  Future<void> executeAction(BuildContext context, EnsembleAction action,
      {EnsembleEvent? event}) {
    ScopeManager? scopeManager = getScopeManager(context);
    if (scopeManager != null) {
      return executeActionWithScope(context, scopeManager, action,
          event: event);
    } else {
      throw Exception('Cannot find ScopeManager to execute action');
    }
  }

  Future<void> executeActionWithScope(
      BuildContext context, ScopeManager scopeManager, EnsembleAction action,
      {EnsembleEvent? event}) {
    return nowExecuteAction(
        context, action, scopeManager.pageData.apiMap, scopeManager,
        event: event);
  }

  /// internally execute an Action
  Future<void> nowExecuteAction(BuildContext context, EnsembleAction action,
      Map<String, YamlMap>? apiMap, ScopeManager providedScopeManager,
      {EnsembleEvent? event}) async {
    // create a new ephemeral scope to append common data.
    // ScopeManager scopeManager =
    //     providedScopeManager.createChildScope(ephemeral: true);
    // if (action.initiator != null) {
    //   scopeManager.dataContext.addInvokableContext('this', action.initiator!);
    // }
    // if (event != null) {
    //   scopeManager.dataContext.addInvokableContext('event', event);
    // }

    // temporary until a proper fix. Overwrite the original scope itself
    // since action requires the original scope to update the data.
    // The below will cause "this" and "event" to permanently attach to the
    // context
    ScopeManager scopeManager = providedScopeManager;
    if (action.initiator != null) {
      scopeManager.dataContext.addInvokableContext('this', action.initiator!);
    }
    if (event != null) {
      scopeManager.dataContext.addInvokableContext('event', event);
    }

    /// TODO: The below Actions should be move to their execute() functions
    if (action is NavigateExternalScreen) {
      return action.execute(context, scopeManager);
    } else if (action is BaseNavigateScreenAction) {
      // process input parameters
      Map<String, dynamic>? nextArgs = {};
      action.inputs?.forEach((key, value) {
        nextArgs[key] = scopeManager.dataContext.eval(value);
      });

      RouteOption? routeOption;
      if (action is NavigateScreenAction) {
        if (action.options?['clearAllScreens'] == true) {
          routeOption = RouteOption.clearAllScreens;
        } else if (action.options?['replaceCurrentScreen'] == true) {
          routeOption = RouteOption.replaceCurrentScreen;
        }
      }

      /// TODO: if the initiator widget has been re-build or removed
      /// (e.g visible=false), the context is no longer valid. See if
      /// all Actions need the context or just navigateScreen and refactor
      if (!context.mounted) {
        context = scopeManager.dataContext.buildContext;
      }

      PageRouteBuilder routeBuilder = navigateToScreen(
        context,
        screenName: scopeManager.dataContext.eval(action.screenName),
        asModal: action.asModal,
        routeOption: routeOption,
        pageArgs: nextArgs,
        transition: action.transition,
        isExternal: action.isExternal,
      );

      if (action is NavigateScreenAction && action.onNavigateBack != null) {
        routeBuilder.popped.then((data) {
          // animating transition while executing this Action causes stutter
          // if we do some heaviy processing. Delay it
          Future.delayed(
              const Duration(milliseconds: 300),
              () => executeActionWithScope(
                  context, scopeManager, action.onNavigateBack!,
                  event: EnsembleEvent(null, data: data)));
        });
      } else if (action is NavigateModalScreenAction &&
          action.onModalDismiss != null &&
          routeBuilder.fullscreenDialog) {
        // callback on modal pop
        routeBuilder.popped.whenComplete(() {
          executeActionWithScope(context, scopeManager, action.onModalDismiss!);
        });
      }
    } else if (action is ShowDialogAction) {
      Widget widget = scopeManager.buildWidgetFromDefinition(action.widget);

      // get styles. TODO: make bindable
      Map<String, dynamic> dialogStyles = {};
      action.options?.forEach((key, value) {
        dialogStyles[key] = scopeManager.dataContext.eval(value);
      });

      bool useDefaultStyle = dialogStyles['style'] != 'none';
      BuildContext? dialogContext;

      showGeneralDialog(
          useRootNavigator: false,
          // use inner-most MaterialApp (our App) as root so theming is ours
          context: context,
          barrierDismissible: true,
          barrierLabel: "Barrier",
          barrierColor: Colors.black54,
          // this has some transparency so the bottom shown through

          pageBuilder: (context, animation, secondaryAnimation) {
            // save a reference to the builder's context so we can close it programmatically
            dialogContext = context;
            scopeManager.openedDialogs.add(dialogContext!);

            return Align(
                alignment: Alignment(
                    Utils.getDouble(dialogStyles['horizontalOffset'],
                        min: -1, max: 1, fallback: 0),
                    Utils.getDouble(dialogStyles['verticalOffset'],
                        min: -1, max: 1, fallback: 0)),
                child: Material(
                    color: Colors.transparent,
                    child: ConstrainedBox(
                        constraints: BoxConstraints(
                            minWidth: Utils.getDouble(dialogStyles['minWidth'],
                                fallback: 0),
                            maxWidth: Utils.getDouble(dialogStyles['maxWidth'],
                                fallback: double.infinity),
                            minHeight: Utils.getDouble(
                                dialogStyles['minHeight'],
                                fallback: 0),
                            maxHeight: Utils.getDouble(
                                dialogStyles['maxHeight'],
                                fallback: double.infinity)),
                        child: Container(
                            decoration: useDefaultStyle
                                ? const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(5)),
                                    boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color: Colors.white38,
                                          blurRadius: 5,
                                          offset: Offset(0, 0),
                                        )
                                      ])
                                : null,
                            margin: useDefaultStyle
                                ? const EdgeInsets.all(20)
                                : null,
                            padding: useDefaultStyle
                                ? const EdgeInsets.all(20)
                                : null,
                            child: SingleChildScrollView(
                              child: widget,
                            )))));
          }).then((value) {
        // remove the dialog context since we are closing them
        scopeManager.openedDialogs.remove(dialogContext);

        // callback when dialog is dismissed
        if (action.onDialogDismiss != null) {
          executeActionWithScope(
              context, scopeManager, action.onDialogDismiss!);
        }
      });
    } else if (action is CloseAllDialogsAction) {
      for (var dialogContext in scopeManager.openedDialogs) {
        Navigator.pop(dialogContext);
      }
      scopeManager.openedDialogs.clear();
    } else if (action is PlaidLinkAction) {
      final linkToken = action.getLinkToken(scopeManager.dataContext).trim();
      if (linkToken.isNotEmpty) {
        GetIt.I<PlaidLinkManager>().openPlaidLink(
          linkToken,
          (linkSuccess) {
            if (action.onSuccess != null) {
              executeActionWithScope(
                context,
                scopeManager,
                action.onSuccess!,
                event: EnsembleEvent(
                  action.initiator,
                  data: linkSuccess,
                ),
              );
            }
          },
          (linkEvent) {
            if (action.onEvent != null) {
              executeActionWithScope(
                context,
                scopeManager,
                action.onEvent!,
                event: EnsembleEvent(
                  action.initiator,
                  data: linkEvent,
                ),
              );
            }
          },
          (linkExit) {
            if (action.onExit != null) {
              executeActionWithScope(
                context,
                scopeManager,
                action.onExit!,
                event: EnsembleEvent(
                  action.initiator,
                  data: linkExit,
                ),
              );
            }
          },
        );
      } else {
        throw RuntimeError(
            "openPlaidLink action requires the plaid's link_token.");
      }
    } else if (action is AppSettingAction) {
      final settingType = action.getTarget(scopeManager.dataContext);
      AppSettings.openAppSettings(type: settingType);
    } else if (action is PhoneContactAction) {
      GetIt.I<ContactManager>().getPhoneContacts((contacts) {
        if (action.getOnSuccess(scopeManager.dataContext) != null) {
          final contactsData =
              contacts.map((contact) => contact.toJson()).toList();

          executeActionWithScope(
            context,
            scopeManager,
            action.getOnSuccess(scopeManager.dataContext)!,
            event: EnsembleEvent(
              action.initiator,
              data: {'contacts': contactsData},
            ),
          );
        }
      }, (error) {
        if (action.getOnError(scopeManager.dataContext) != null) {
          executeActionWithScope(
            context,
            scopeManager,
            action.getOnError(scopeManager.dataContext)!,
            event: EnsembleEvent(action.initiator!, data: {'error': error}),
          );
        }
      });
    } else if (action is ShowCameraAction) {
      GetIt.I<CameraManager>().openCamera(context, action, scopeManager);
    } else if (action is StartTimerAction) {
      // validate
      bool isRepeat = action.isRepeat(scopeManager.dataContext);
      int? repeatInterval = action.getRepeatInterval(scopeManager.dataContext);
      if (isRepeat && repeatInterval == null) {
        throw LanguageError(
            "${ActionType.startTimer.name}'s repeatInterval needs a value when repeat is on");
      }

      int delay = action.getStartAfter(scopeManager.dataContext) ??
          (isRepeat ? repeatInterval! : 0);

      // we always execute at least once, delayed by startAfter and fallback to repeatInterval (or immediate if startAfter is 0)
      Timer(Duration(seconds: delay), () {
        // execute the action
        executeActionWithScope(context, scopeManager, action.onTimer);

        // if no repeat, execute onTimerComplete
        if (!isRepeat) {
          if (action.onTimerComplete != null) {
            executeActionWithScope(
                context, scopeManager, action.onTimerComplete!);
          }
        }
        // else repeating timer
        else if (repeatInterval != null) {
          int? maxTimes = action.getMaxTimes(scopeManager.dataContext);

          /// repeatCount value of null means forever by default
          int? repeatCount = maxTimes != null ? maxTimes - 1 : null;
          if (repeatCount != 0) {
            int counter = 0;
            final timer =
                Timer.periodic(Duration(seconds: repeatInterval), (timer) {
              // execute the action
              executeActionWithScope(context, scopeManager, action.onTimer);

              // automatically cancel timer when repeatCount is reached
              if (repeatCount != null && ++counter == repeatCount) {
                timer.cancel();

                // timer terminates, call onTimerComplete
                if (action.onTimerComplete != null) {
                  executeActionWithScope(
                      context, scopeManager, action.onTimerComplete!);
                }
              }
            });

            // save our timer to our PageData since user may want to cancel at anytime
            // and also when we navigate away from the page
            scopeManager.addTimer(action, timer);
          }
        }
      });
    } else if (action is StopTimerAction) {
      try {
        scopeManager.removeTimer(action.id);
      } catch (e) {
        debugPrint(
            'error when trying to stop timer with name ${action.id}. Error: ${e.toString()}');
      }
    } else if (action is GetLocationAction) {
      executeGetLocationAction(
          scopeManager, scopeManager.dataContext, context, action);
    } else if (action is ExecuteCodeAction) {
      action.inputs?.forEach((key, value) {
        dynamic val = scopeManager.dataContext.eval(value);
        if (val != null) {
          scopeManager.dataContext.addDataContextById(key, val);
        }
      });
      // code execution relies on the correct Context for proper execution.
      // It looks up the context from ScopeManager which maybe incorrect.
      // Here we adjust the correct context
      DataContext newDataContext =
          scopeManager.dataContext.clone(newBuildContext: context);
      newDataContext.evalCode(action.codeBlock, action.codeBlockSpan);

      if (action.onComplete != null) {
        executeActionWithScope(context, scopeManager, action.onComplete!);
      }
    } else if (action is ShowToastAction) {
      Widget? customToastBody;
      if (action.widget != null) {
        customToastBody = scopeManager.buildWidgetFromDefinition(action.widget);
      }
      ToastController().showToast(context, action, customToastBody,
          dataContext: scopeManager.dataContext);
    } else if (action is OpenUrlAction) {
      dynamic value = scopeManager.dataContext.eval(action.url);
      value ??= '';
      launchUrl(Uri.parse(value),
          mode: (action.openInExternalApp)
              ? LaunchMode.externalApplication
              : LaunchMode.platformDefault);
    } else if (action is FileUploadAction) {
      await uploadFiles(
          action: action,
          context: context,
          dataContext: scopeManager.dataContext,
          apiMap: apiMap,
          scopeManager: scopeManager);
    } else if (action is FilePickerAction) {
      GetIt.I<FileManager>().pickFiles(context, action, scopeManager);
    } else if (action is WalletConnectAction) {
      //  TODO store session:  WalletConnectSession? session = await sessionStorage.getSession();

      BuildContext? dialogContext;

      final WalletConnect walletConnect = WalletConnect(
        bridge: 'https://bridge.walletconnect.org',
        clientMeta: PeerMeta(
          name: action.appName,
          description: action.appDescription,
          url: action.appUrl,
          icons:
              action.appIconUrl != null ? <String>[action.appIconUrl!] : null,
        ),
      );

      if (action.id != null) {
        scopeManager.dataContext
            .addDataContextById(action.id!, WalletData(walletConnect));
      }

      if (walletConnect.connected) {
        // TODO works when session is stored
        return;
      }

      walletConnect.on('connect', (SessionStatus? session) {
        if (dialogContext != null) {
          Navigator.pop(dialogContext!);
        }
        updateWalletData(action, scopeManager, context);
      });
      walletConnect.on('session_update', (Object? session) {
        if (dialogContext != null) {
          Navigator.pop(dialogContext!);
        }
        updateWalletData(action, scopeManager, context);
      });
      walletConnect.on('disconnect', (Object? session) {
        updateWalletData(action, scopeManager, context);
      });

      try {
        walletConnect.createSession(onDisplayUri: (String uri) async {
          if (kIsWeb) {
            showDialog(
              context: context,
              builder: (context) {
                dialogContext = context;
                return WalletConnectModal(qrData: uri);
              },
            );
            return;
          }
          launchUrlString(uri, mode: LaunchMode.externalApplication);
        });
      } on Exception catch (_) {
        if (action.onError != null) executeAction(context, action.onError!);
        throw LanguageError('Unable to create wallet connect session');
      }
    } else if (action is NotificationAction) {
      notificationUtils.context = context;
      notificationUtils.onRemoteNotification = action.onReceive;
      notificationUtils.onRemoteNotificationOpened = action.onTap;
    } else if (action is ShowNotificationAction) {
      scopeManager.dataContext.addDataContext(Ensemble.externalDataContext);
      notificationUtils.showNotification(
        scopeManager.dataContext.eval(action.title),
        scopeManager.dataContext.eval(action.body),
      );
    } else if (action is RequestNotificationAction) {
      final isEnabled = await notificationUtils.initNotifications() ?? false;

      if (isEnabled && action.onAccept != null) {
        executeAction(context, action.onAccept!);
      }

      if (!isEnabled && action.onReject != null) {
        executeAction(context, action.onReject!);
      }
    } else if (action is AuthorizeOAuthAction) {
      // TODO
    } else if (action is CheckPermission) {
      Permission? type = action.getType(scopeManager.dataContext);
      if (type == null) {
        throw RuntimeError('checkPermission requires a type.');
      }
      bool? result = await PermissionsManager().hasPermission(type);
      if (result == true) {
        if (action.onAuthorized != null) {
          executeAction(context, action.onAuthorized!);
        }
      } else if (result == false) {
        if (action.onDenied != null) {
          executeAction(context, action.onDenied!);
        }
      } else {
        if (action.onNotDetermined != null) {
          executeAction(context, action.onNotDetermined!);
        }
      }
    } else if (action is ConnectSocketAction) {
      dynamic resolveURI(String uri) {
        final result = scopeManager.dataContext.eval(uri);
        return Uri.tryParse(result);
      }

      for (var element in action.inputs?.entries ?? const Iterable.empty()) {
        dynamic value = scopeManager.dataContext.eval(element.value);
        scopeManager.dataContext.addDataContextById(element.key, value);
      }
      final socketName = action.name;
      final socketService = SocketService();
      final (WebSocket socket, EnsembleSocket data) =
          socketService.connect(socketName, resolveURI);
      final connectionStateSub = socket.connection.listen(
        (event) {
          if (event is Connected || event is Reconnected) {
            if (data.onSuccess != null) {
              ScreenController().executeAction(context, data.onSuccess!);
            }

            if (action.onSuccess != null) {
              ScreenController().executeAction(context, action.onSuccess!);
            }
            return;
          }
          if (event is Disconnected && data.onDisconnect != null) {
            ScreenController().executeAction(context, data.onDisconnect!);
            return;
          }
          if (event is Reconnecting && data.onReconnecting != null) {
            ScreenController().executeAction(context, data.onReconnecting!);
            return;
          }
        },
      );

      final subscription = socket.messages.listen((message) {
        if (data.onReceive == null) return;

        scopeManager.dataContext
            .addInvokableContext(socketName, EnsembleSocketInvokable(message));
        scopeManager.dispatch(
            ModelChangeEvent(SimpleBindingSource(socketName), message));
        ScreenController().executeAction(context, data.onReceive!);
      });
      socketService.setSubscription(socketName, subscription);
      socketService.setConnectionSubscription(socketName, connectionStateSub);
    } else if (action is DisconnectSocketAction) {
      final socketService = SocketService();
      await socketService.disconnect(action.name);
    } else if (action is MessageSocketAction) {
      final socketService = SocketService();
      final message = scopeManager.dataContext.eval(action.message);
      socketService.message(action.name, message);
    }
    // catch-all. All Actions should just be using this
    else {
      action.execute(context, scopeManager);
    }
  }

  void updateWalletData(WalletConnectAction action, ScopeManager? scopeManager,
      BuildContext context) {
    if (action.id != null && scopeManager != null) {
      final walletData = scopeManager.dataContext.getContextById(action.id!);
      scopeManager.dispatch(
          ModelChangeEvent(SimpleBindingSource(action.id!), walletData));
      if (action.onComplete != null) executeAction(context, action.onComplete!);
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

  void dispatchStorageChanges(BuildContext context, String key, dynamic value) {
    ScopeManager? scopeManager = getScopeManager(context);
    if (scopeManager != null) {
      scopeManager.dispatch(ModelChangeEvent(StorageBindingSource(key), value));
    }
  }

  void dispatchSystemStorageChanges(
      BuildContext context, String key, dynamic value,
      {required String storagePrefix}) {
    getScopeManager(context)?.dispatch(ModelChangeEvent(
        SystemStorageBindingSource(key, storagePrefix: storagePrefix), value));
  }

  /// Navigate to another screen
  /// [screenName] - navigate to the screen if specified, otherwise to appHome
  /// [asModal] - shows the App in a regular or modal screen
  /// [replace] - whether to replace the current route on the stack, such that
  /// navigating back will skip the current route.
  /// [pageArgs] - Key/Value pairs to send to the screen if it takes input parameters
  PageRouteBuilder navigateToScreen(
    BuildContext context, {
    String? screenId,
    String? screenName,
    bool? asModal,
    RouteOption? routeOption,
    Map<String, dynamic>? pageArgs,
    Map<String, dynamic>? transition,
    bool isExternal = false,
  }) {
    PageType pageType = asModal == true ? PageType.modal : PageType.regular;

    Widget screenWidget = getScreen(
      screenId: screenId,
      screenName: screenName,
      asModal: asModal,
      pageArgs: pageArgs,
      isExternal: isExternal,
    );

    Map<String, dynamic>? defaultTransitionOptions =
        Theme.of(context).extension<EnsembleThemeExtension>()?.transitions ??
            {};

    final _pageType = pageType == PageType.modal ? 'modal' : 'page';

    final transitionType = PageTransitionTypeX.fromString(
        transition?['type'] ?? defaultTransitionOptions[_pageType]?['type']);
    final alignment = Utils.getAlignment(transition?['alignment'] ??
        defaultTransitionOptions[_pageType]?['alignment']);
    final duration = Utils.getInt(
        transition?['duration'] ??
            defaultTransitionOptions[_pageType]?['duration'],
        fallback: 250);

    PageRouteBuilder route = getScreenBuilder(
      screenWidget,
      pageType: pageType,
      transitionType: transitionType,
      alignment: alignment,
      duration: duration,
    );
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
    String? screenId,
    String? screenName,
    bool? asModal,
    Map<String, dynamic>? pageArgs,
    required bool isExternal,
  }) {
    PageType pageType = asModal == true ? PageType.modal : PageType.regular;
    return Screen(
      key: key,
      appProvider: AppProvider(
          definitionProvider: Ensemble().getConfig()!.definitionProvider),
      screenPayload: ScreenPayload(
        screenId: screenId,
        screenName: screenName,
        pageType: pageType,
        arguments: pageArgs,
        isExternal: isExternal,
      ),
    );
  }

  void executeGetLocationAction(ScopeManager scopeManager,
      DataContext dataContext, BuildContext context, GetLocationAction action) {
    if (action.onLocationReceived != null) {
      GetIt.I<LocationManager>()
          .getLocationStatus()
          .then((LocationStatus status) async {
        if (status == LocationStatus.ready) {
          // if recurring
          if (action.recurring == true) {
            StreamSubscription<LocationData> streamSubscription =
                GetIt.I<LocationManager>()
                    .getPositionStream(
                        distanceFilter: action.recurringDistanceFilter ?? 1000)
                    .map((position) => LocationData(
                        latitude: position.latitude,
                        longitude: position.longitude))
                    .listen((LocationData? location) {
              if (location != null) {
                // update last location. TODO: consolidate this
                Device().updateLastLocation(location);

                _onLocationReceived(scopeManager, dataContext, context,
                    action.onLocationReceived!, location);
              } else if (action.onError != null) {
                DataContext localizedContext = dataContext.clone();
                localizedContext.addDataContextById('reason', 'unknown');
                nowExecuteAction(context, action.onError!,
                    scopeManager.pageData.apiMap, scopeManager);
              }
            });
            scopeManager.addLocationListener(streamSubscription);
          }
          // one-time get location
          else {
            _onLocationReceived(
                scopeManager,
                dataContext,
                context,
                action.onLocationReceived!,
                await GetIt.I<LocationManager>().simplyGetLocation());
          }
        } else if (action.onError != null) {
          DataContext localizedContext = dataContext.clone();
          localizedContext.addDataContextById('reason', status.name);
          nowExecuteAction(context, action.onError!,
              scopeManager.pageData.apiMap, scopeManager);
        }
      });
    }
  }

  void _onLocationReceived(
      ScopeManager scopeManager,
      DataContext dataContext,
      BuildContext context,
      EnsembleAction onLocationReceived,
      LocationData location) {
    scopeManager.dataContext.addDataContextById('latitude', location.latitude);
    scopeManager.dataContext
        .addDataContextById('longitude', location.longitude);
    nowExecuteAction(context, onLocationReceived, scopeManager.pageData.apiMap,
        scopeManager);
  }

  /// return a wrapper for the screen widget
  /// with custom animation for different pageType
  PageRouteBuilder getScreenBuilder(
    Widget screenWidget, {
    PageType? pageType,
    PageTransitionType? transitionType,
    Alignment? alignment,
    int? duration,
  }) {
    const enableTransition =
        bool.fromEnvironment('transitions', defaultValue: true);

    if (!enableTransition) {
      return EnsemblePageRouteNoTransitionBuilder(screenWidget: screenWidget);
    }

    if (pageType == PageType.modal) {
      return EnsemblePageRouteBuilder(
        child: ModalScreen(screenWidget: screenWidget),
        transitionType: transitionType ?? PageTransitionType.bottomToTop,
        alignment: alignment ?? Alignment.center,
        fullscreenDialog: true,
        opaque: false,
        duration: Duration(milliseconds: duration ?? 250),
        barrierDismissible: true,
        barrierColor: Colors.black54,
      );
    } else {
      return EnsemblePageRouteBuilder(
        child: screenWidget,
        transitionType: transitionType ?? PageTransitionType.fade,
        alignment: alignment ?? Alignment.center,
        duration: Duration(milliseconds: duration ?? 250),
      );
    }
  }
}

enum RouteOption { replaceCurrentScreen, clearAllScreens }
