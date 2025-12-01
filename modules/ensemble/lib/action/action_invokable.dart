import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

/// expose Ensemble Actions as Invokables
abstract class ActionInvokable with Invokable {
  ActionInvokable(this.buildContext);

  final BuildContext buildContext;

  @override
  Map<String, Function> methods() {
    return _generateFromActionTypes([
      ActionType.callExternalMethod,
      ActionType.callNativeMethod,
      ActionType.share,
      ActionType.rateApp,
      ActionType.copyToClipboard,
      ActionType.getDeviceToken,
      ActionType.getPhoneContacts,
      ActionType.getPhoneContactPhoto,
      ActionType.showBottomModal,
      ActionType.dismissBottomModal,
      ActionType.showBottomSheet,
      ActionType.dismissBottomSheet,
      ActionType.showDialog,
      ActionType.logEvent,
      ActionType.navigateViewGroup,
      ActionType.showToast,
      ActionType.setLocale,
      ActionType.clearLocale,
      ActionType.openAppSettings,
      ActionType.deviceSecurity,
      ActionType.connectivityListener,
      ActionType.requestNotificationAccess,
      ActionType.showLocalNotification,
      ActionType.showDialog,
      ActionType.dismissDialog,
      ActionType.closeAllDialogs,
      ActionType.executeActionGroup,
      ActionType.takeScreenshot,
      ActionType.saveFile,
      ActionType.controlDeviceBackNavigation,
      ActionType.closeApp,
      ActionType.getLocation,
      ActionType.pickFiles,
      ActionType.openPlaidLink,
      ActionType.updateBadgeCount,
      ActionType.clearBadgeCount,
      ActionType.getNetworkInfo,
      ActionType.checkPermission,
      ActionType.sendVerificationCode,
      ActionType.validateVerificationCode,
      ActionType.resendVerificationCode,
      ActionType.bluetoothStartScan,
      ActionType.bluetoothConnect,
      ActionType.bluetoothDisconnect,
      ActionType.bluetoothSubscribeCharacteristic,
      ActionType.bluetoothUnsubscribeCharacteristic,
      ActionType.setSecureStorage,
      ActionType.clearSecureStorage,
      ActionType.initializeStripe,
      ActionType.showPaymentSheet,
    ]);
  }

  Map<String, Function> _generateFromActionTypes(List<ActionType> actionTypes) {
    Map<String, Function> functions = {};
    for (ActionType actionType in actionTypes) {
      functions[actionType.name] = ([dynamic payload]) {
        // payload is optional but must be a Map if specified
        if (payload != null && payload is! Map) {
          throw LanguageError("${actionType.name} has an invalid payload.");
        }

        EnsembleAction? action =
            EnsembleAction.fromActionType(actionType, payload: payload);
        return action?.execute(buildContext, _getScopeManager(buildContext));
      };
    }
    return functions;
  }

  ScopeManager _getScopeManager(BuildContext context) {
    ScopeManager? scopeManager = ScreenController().getScopeManager(context);
    if (scopeManager == null) {
      throw LanguageError("Cannot look up ScopeManager");
    }
    return scopeManager;
  }
}
