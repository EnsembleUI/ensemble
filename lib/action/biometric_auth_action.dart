// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

class AuthenticateByBiometric extends EnsembleAction {
  EnsembleAction? onAuthenticated;
  EnsembleAction? onAuthenticationFailed;
  EnsembleAction? onSensorNotAvailable;
  EnsembleAction? onSensorNotConfigured;
  EnsembleAction? onError;
  bool? allowConfiguration;
  String? label;
  String? androidTitle;

  AuthenticateByBiometric({
    this.onAuthenticated,
    this.onAuthenticationFailed,
    this.allowConfiguration,
    this.androidTitle,
    this.onError,
    this.onSensorNotAvailable,
    this.label,
    this.onSensorNotConfigured,
  });

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    if (kIsWeb) {
      print('authenticateByBiometric only works on native device');
      return;
    }
    try {
      final LocalAuthentication auth = LocalAuthentication();

      await auth.getAvailableBiometrics();
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;

      final bool canAuthenticate = await auth.isDeviceSupported();
      if (!(canAuthenticate || canAuthenticateWithBiometrics)) {
        if (onSensorNotAvailable == null) return;
        ScreenController().executeAction(context, onSensorNotAvailable!);
        return;
      }
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: label ?? 'Please authenticate',
        options: AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: allowConfiguration ?? true,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
      if (didAuthenticate) {
        if (onAuthenticated == null) return;
        ScreenController().executeAction(context, onAuthenticated!);
      } else {
        if (onAuthenticationFailed == null) return;
        ScreenController().executeAction(context, onAuthenticationFailed!);
      }
    } on PlatformException catch (e) {
      if (e.code == "auth_in_progess") return;

      if (e.code == auth_error.biometricOnlyNotSupported) {
        if (onSensorNotAvailable == null) return;
        ScreenController().executeAction(context, onSensorNotAvailable!);
      } else if (e.code == auth_error.notAvailable) {
        if (onSensorNotConfigured == null) return;
        ScreenController().executeAction(context, onSensorNotConfigured!);
      } else {
        if (onError == null) return;
        ScreenController().executeAction(context, onError!);
      }
    }
    return;
  }

  static EnsembleAction? fromMap({Map? payload}) {
    if (payload == null || payload['onAuthenticated'] == null) {
      print("authenticateByBiometric: onAuthenticated is required");
      return null;
    }
    return AuthenticateByBiometric(
      onAuthenticated: EnsembleAction.fromYaml(payload['onAuthenticated']),
      onAuthenticationFailed:
          EnsembleAction.fromYaml(payload['onAuthenticationFailed']),
      onError: EnsembleAction.fromYaml(payload['onError']),
      onSensorNotAvailable:
          EnsembleAction.fromYaml(payload['onSensorNotAvailable']),
      androidTitle: Utils.optionalString(payload['androidTitle']),
      allowConfiguration: Utils.optionalBool(payload['allowConfiguration']),
      label: Utils.optionalString(payload['label']),
      onSensorNotConfigured:
          EnsembleAction.fromYaml(payload['onSensorNotConfigured']),
    );
  }
}
