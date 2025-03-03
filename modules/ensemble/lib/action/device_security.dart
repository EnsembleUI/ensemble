import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:root_jailbreak_sniffer/rjsniffer.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter_security_checker/flutter_security_checker.dart';
import 'package:ensemble/framework/event.dart';

class DeviceSecurity extends EnsembleAction with Invokable {
  EnsembleAction? onSuccess;
  EnsembleAction? onError;

  DeviceSecurity({
    this.onSuccess,
    this.onError,
  });

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    if (kIsWeb) {
      _handleSuccess(context, false, false, false,false,
          'This information is not available on the web');
      return;
    }

    try {
      // Check if the device is rooted, debugged, or an emulator
      bool isRooted = await Rjsniffer.amICompromised() ?? false;
      bool isDebugged = await Rjsniffer.amIDebugged() ?? false;
      bool isEmulator = await Rjsniffer.amIEmulator() ?? false;
      bool hasCorrectlyInstalled = await FlutterSecurityChecker.hasCorrectlyInstalled;

      _handleSuccess(context, isRooted, isDebugged, isEmulator, hasCorrectlyInstalled, 'success');
    } catch (e) {
      _handleError(context, e);
    }
  }

  void _handleSuccess(BuildContext context, bool isRooted, bool isDebugged,
      bool isEmulator, bool hasCorrectlyInstalled, String message) {
    if (onSuccess != null) {
      ScreenController().executeAction(
        context,
        onSuccess!,
        event: EnsembleEvent(
          this,
          data: {
            'debugged': isDebugged,
            'rooted': isRooted,
            'emulator': isEmulator,
            'correctlyInstalled': hasCorrectlyInstalled,
            'message': message,
          },
        ),
      );
    }
  }

  void _handleError(BuildContext context, dynamic error) {
    if (onError != null) {
      ScreenController().executeAction(
        context,
        onError!,
        event: EnsembleEvent(
          this,
          error: error.toString(),
        ),
      );
    }
  }

  static EnsembleAction? fromMap({Map? payload}) {
    if (payload == null) {
      print("DeviceSecurity: payload is required");
      return null;
    }
    return DeviceSecurity(
      onSuccess: EnsembleAction.from(payload['onSuccess']),
      onError: EnsembleAction.from(payload['onError']),
    );
  }

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}
