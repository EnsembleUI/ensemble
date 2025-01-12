import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/auth_context_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';

void _triggerEventAction(
  BuildContext context,
  EnsembleAction? action,
  Invokable? initiator,
  String eventName,
  Map<String, dynamic> data,
) {
  if (action != null) {
    ScreenController().executeAction(
      context,
      action,
      event: EnsembleEvent(initiator, data: data),
    );
  }
}

void _handleError(
  BuildContext context,
  EnsembleAction? onError,
  Invokable? initiator,
  String error,
) {
  _triggerEventAction(
    context,
    onError,
    initiator,
    'onError',
    {'error': error},
  );
}

/// Action to send a phone verification code via the [AuthContextManager].
/// - [phoneNumber] must be provided
/// - [onSuccess] is executed when the code is sent successfully
/// - [onError] is executed when there is a failure
class SendPhoneVerificationCodeAction extends EnsembleAction {
  final String phoneNumber;
  final EnsembleAction? onSuccess;
  final EnsembleAction? onError;

  SendPhoneVerificationCodeAction({
    super.initiator,
    required this.phoneNumber,
    this.onSuccess,
    this.onError,
  });

  factory SendPhoneVerificationCodeAction.fromYaml({
    Invokable? initiator,
    Map? payload,
  }) {
    final phoneNumberValue = payload?['phoneNumber'];
    if (phoneNumberValue == null || phoneNumberValue.toString().isEmpty) {
      throw LanguageError('phoneNumber is required in the YAML payload.');
    }

    return SendPhoneVerificationCodeAction(
      initiator: initiator,
      phoneNumber: phoneNumberValue,
      onSuccess: EnsembleAction.from(payload?['onSuccess']),
      onError: EnsembleAction.from(payload?['onError']),
    );
  }

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    if (GetIt.instance.isRegistered<AuthContextManager>()) {
      final AuthContextManager authManager =
          GetIt.instance<AuthContextManager>();

      final localPhoneNumber = Utils.getString(
        scopeManager.dataContext.eval(phoneNumber),
        fallback: '',
      );

      if (localPhoneNumber.isEmpty) {
        _handleError(context, onError, initiator, 'Phone number is required');
        return;
      }

      await authManager.sendPhoneVerificationCode(
        phoneNumber: localPhoneNumber,
        onSuccess: (String verificationId, int? resendToken) {
          _triggerEventAction(
            context,
            onSuccess,
            initiator,
            'onSuccess',
            {
              'verificationId': verificationId,
              'resendToken': resendToken,
            },
          );
        },
        onError: (String error) {
          _handleError(context, onError, initiator, error);
        },
      );
    } else {
      _handleError(context, onError, initiator, 'Auth module is not enabled');
    }
  }
}

/// Action to verify the phone code using the [AuthContextManager].
/// - [code] and [verificationId] must be provided
/// - [onSuccess] is executed when verification succeeds
/// - [onError] is executed when there is a failure
class VerifyPhoneCodeAction extends EnsembleAction {
  final String code;
  final String verificationId;
  final EnsembleAction? onSuccess;
  final EnsembleAction? onError;

  VerifyPhoneCodeAction({
    super.initiator,
    required this.code,
    required this.verificationId,
    this.onSuccess,
    this.onError,
  });

  factory VerifyPhoneCodeAction.fromYaml({
    Invokable? initiator,
    Map? payload,
  }) {
    final codeValue = payload?['code'];
    final verificationIdValue = payload?['verificationId'];

    if (codeValue == null || codeValue.toString().isEmpty) {
      throw LanguageError('code is required in the YAML payload.');
    }
    if (verificationIdValue == null || verificationIdValue.toString().isEmpty) {
      throw LanguageError('verificationId is required in the YAML payload.');
    }

    return VerifyPhoneCodeAction(
      initiator: initiator,
      code: codeValue,
      verificationId: verificationIdValue,
      onSuccess: EnsembleAction.from(payload?['onSuccess']),
      onError: EnsembleAction.from(payload?['onError']),
    );
  }

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    if (GetIt.instance.isRegistered<AuthContextManager>()) {
      final AuthContextManager authManager =
          GetIt.instance<AuthContextManager>();

      final localCode = Utils.getString(
        scopeManager.dataContext.eval(code),
        fallback: '',
      );
      final localVerificationId = Utils.getString(
        scopeManager.dataContext.eval(verificationId),
        fallback: '',
      );

      if (localCode.isEmpty) {
        _handleError(
            context, onError, initiator, 'Verification code is required');
        return;
      }

      if (localVerificationId.isEmpty) {
        _handleError(
            context, onError, initiator, 'Verification ID is required');
        return;
      }

      await authManager.verifyPhoneCode(
        smsCode: localCode,
        verificationId: localVerificationId,
        onError: (String error) {
          _handleError(context, onError, initiator, error);
        },
        onSuccess: (AuthenticatedUser user) {
          _triggerEventAction(
            context,
            onSuccess,
            initiator,
            'onSuccess',
            {'user': user},
          );
        },
      );
    } else {
      _handleError(context, onError, initiator, 'Auth module is not enabled');
    }
  }
}

/// Action to resend a phone verification code using the [AuthContextManager].
/// - [phoneNumber] and [resendToken] must be provided
/// - [onSuccess] is executed when the code is resent successfully
/// - [onError] is executed when there is a failure
class ResendPhoneVerificationCodeAction extends EnsembleAction {
  final String phoneNumber;
  final String resendToken;
  final EnsembleAction? onSuccess;
  final EnsembleAction? onError;

  ResendPhoneVerificationCodeAction({
    super.initiator,
    required this.phoneNumber,
    required this.resendToken,
    this.onSuccess,
    this.onError,
  });

  factory ResendPhoneVerificationCodeAction.fromYaml({
    Invokable? initiator,
    Map? payload,
  }) {
    final phoneNumberValue = payload?['phoneNumber'];
    final resendTokenValue = payload?['resendToken'];

    if (phoneNumberValue == null || phoneNumberValue.toString().isEmpty) {
      throw LanguageError('phoneNumber is required in the YAML payload.');
    }
    if (resendTokenValue == null || resendTokenValue.toString().isEmpty) {
      throw LanguageError('resendToken is required in the YAML payload.');
    }

    return ResendPhoneVerificationCodeAction(
      initiator: initiator,
      phoneNumber: phoneNumberValue,
      resendToken: resendTokenValue,
      onSuccess: EnsembleAction.from(payload?['onSuccess']),
      onError: EnsembleAction.from(payload?['onError']),
    );
  }

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    if (GetIt.instance.isRegistered<AuthContextManager>()) {
      final AuthContextManager authManager =
          GetIt.instance<AuthContextManager>();

      final localPhoneNumber = Utils.getString(
        scopeManager.dataContext.eval(phoneNumber),
        fallback: '',
      );
      final localResendToken = Utils.getInt(
        scopeManager.dataContext.eval(resendToken),
        fallback: 0,
      );

      if (localPhoneNumber.isEmpty) {
        _handleError(context, onError, initiator, 'Phone number is required');
        return;
      }
      if (localResendToken == 0) {
        _handleError(context, onError, initiator, 'Invalid resend token');
        return;
      }

      await authManager.resendPhoneVerificationCode(
        phoneNumber: localPhoneNumber,
        resendToken: localResendToken,
        onSuccess: (String verificationId, int? newResendToken) {
          _triggerEventAction(
            context,
            onSuccess,
            initiator,
            'onSuccess',
            {
              'verificationId': verificationId,
              'resendToken': newResendToken,
            },
          );
        },
        onError: (String error) {
          _handleError(context, onError, initiator, error);
        },
      );
    } else {
      _handleError(context, onError, initiator, 'Auth module is not enabled');
    }
  }
}
