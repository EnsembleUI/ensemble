import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:safe_device/safe_device.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter_security_checker/flutter_security_checker.dart';
import 'package:ensemble/framework/event.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;

class DeviceSecurity extends EnsembleAction with Invokable {
  EnsembleAction? onSuccess;
  EnsembleAction? onError;
  String? packageName;
  String? signature;

  DeviceSecurity({
    this.onSuccess,
    this.onError,
    this.packageName,
    this.signature,
  });

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    if (kIsWeb) {
      _handleSuccess(context, false, false, false, false, false, false,
          'This information is not available on the web');
      return;
    }

    try {
      // Check if the device is rooted, debugged, or an emulator
      bool isRooted = await SafeDevice.isJailBroken;
      bool isDebugged = await SafeDevice.isDevelopmentModeEnable;
      bool isEmulator = !await SafeDevice.isRealDevice;
      bool hasCorrectlyInstalled =
          await FlutterSecurityChecker.hasCorrectlyInstalled;

      String localPackageName = Utils.getString(
        scopeManager.dataContext.eval(packageName),
        fallback: '',
      );

      String localSignature = Utils.getString(
        scopeManager.dataContext.eval(signature),
        fallback: '',
      );

      // Get the current package name and signature
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentPackageName = packageInfo.packageName;
      String currentSignature = packageInfo.buildSignature;

      // Verify package name and signature if they were provided
      bool isPackageValid = currentPackageName == localPackageName;
      bool isSignatureValid =
          Platform.isIOS ? true : currentSignature == localSignature;

      _handleSuccess(context, isRooted, isDebugged, isEmulator,
          hasCorrectlyInstalled, isPackageValid, isSignatureValid, 'success');
    } catch (e) {
      _handleError(context, e);
    }
  }

  void _handleSuccess(
      BuildContext context,
      bool isRooted,
      bool isDebugged,
      bool isEmulator,
      bool hasCorrectlyInstalled,
      bool isPackageValid,
      bool isSignatureValid,
      String message) {
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
            'isPackageValid': isPackageValid,
            'isSignatureValid': isSignatureValid,
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
      packageName: payload['packageName'],
      signature: payload['signature'],
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
