import 'package:ensemble/framework/action.dart';
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
class SendVerificationCodeAction extends EnsembleAction {
  /// Provider selected by the YAML payload.
  final String provider;
  /// Verification or provider method selected by the action.
  final String method;
  /// Phone number used by verification-code flows.
  final String? phoneNumber;
  /// Action executed when the operation succeeds.
  final EnsembleAction? onSuccess;
  /// Action executed when the operation fails.
  final EnsembleAction? onError;

  /// Creates a [SendVerificationCodeAction] action.
  SendVerificationCodeAction({
    super.initiator,
    required this.provider,
    required this.method,
    this.phoneNumber,
    this.onSuccess,
    this.onError,
  });

  /// Creates a [SendVerificationCodeAction] from a YAML or map action payload.
  factory SendVerificationCodeAction.fromYaml({
    Invokable? initiator,
    Map? payload,
  }) {
    return SendVerificationCodeAction(
      initiator: initiator,
      provider: payload?['provider'] ?? 'firebase',
      method: payload?['method'] ?? 'phone',
      phoneNumber: payload?['phoneNumber'] ?? '',
      onSuccess: EnsembleAction.from(payload?['onSuccess']),
      onError: EnsembleAction.from(payload?['onError']),
    );
  }

  /// Runs this action and performs the send verification code operation.
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

      await authManager.sendVerificationCode(
        provider: provider,
        method: method,
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
    }
  }
}

/// Action to verify the phone code using the [AuthContextManager].
/// - [code] and [verificationId] must be provided
/// - [onSuccess] is executed when verification succeeds
/// - [onError] is executed when there is a failure
class ValidateVerificationCodeAction extends EnsembleAction {
  /// Provider selected by the YAML payload.
  final String provider;
  /// Verification or provider method selected by the action.
  final String method;
  /// Verification code entered by the user.
  final String code;
  /// Provider verification session identifier.
  final String verificationId;
  /// Action executed when the operation succeeds.
  final EnsembleAction? onSuccess;
  /// Action executed when the operation fails.
  final EnsembleAction? onError;
  /// Action executed when verification fails after a provider response.
  final EnsembleAction? onVerificationFailure;

  /// Creates a [ValidateVerificationCodeAction] action.
  ValidateVerificationCodeAction({
    super.initiator,
    required this.provider,
    required this.method,
    required this.code,
    required this.verificationId,
    this.onSuccess,
    this.onError,
    this.onVerificationFailure,
  });

  /// Creates a [ValidateVerificationCodeAction] from a YAML or map action payload.
  factory ValidateVerificationCodeAction.fromYaml({
    Invokable? initiator,
    Map? payload,
  }) {
    return ValidateVerificationCodeAction(
      initiator: initiator,
      code: payload?['code'] ?? '',
      provider: payload?['provider'] ?? 'firebase',
      method: payload?['method'] ?? 'phone',
      verificationId: payload?['verificationId'] ?? '',
      onSuccess: EnsembleAction.from(payload?['onSuccess']),
      onError: EnsembleAction.from(payload?['onError']),
      onVerificationFailure:
          EnsembleAction.from(payload?['onVerificationFailure']),
    );
  }

  /// Runs this action and performs the validate verification code operation.
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

      await authManager.validateVerificationCode(
        provider: provider,
        method: method,
        smsCode: localCode,
        verificationId: localVerificationId,
        onError: (String error) {
          _handleError(context, onError, initiator, error);
        },
        onVerificationFailure: (String error) {
          _triggerEventAction(
            context,
            onVerificationFailure,
            initiator,
            'onVerificationFailure',
            {'error': error},
          );
        },
        onSuccess: (AuthenticatedUser user, String idToken) {
          _triggerEventAction(
            context,
            onSuccess,
            initiator,
            'onSuccess',
            {'user': user, 'idToken': idToken},
          );
        },
      );
    }
  }
}

/// Action to resend a phone verification code using the [AuthContextManager].
/// - [phoneNumber] and [resendToken] must be provided
/// - [onSuccess] is executed when the code is resent successfully
/// - [onError] is executed when there is a failure
class ResendVerificationCodeAction extends EnsembleAction {
  /// Phone number used by verification-code flows.
  final String? phoneNumber;
  /// Provider token used to resend a verification code.
  final String resendToken;
  /// Provider selected by the YAML payload.
  final String provider;
  /// Verification or provider method selected by the action.
  final String method;
  /// Action executed when the operation succeeds.
  final EnsembleAction? onSuccess;
  /// Action executed when the operation fails.
  final EnsembleAction? onError;

  /// Creates a [ResendVerificationCodeAction] action.
  ResendVerificationCodeAction({
    super.initiator,
    this.phoneNumber,
    required this.resendToken,
    required this.provider,
    required this.method,
    this.onSuccess,
    this.onError,
  });

  /// Creates a [ResendVerificationCodeAction] from a YAML or map action payload.
  factory ResendVerificationCodeAction.fromYaml({
    Invokable? initiator,
    Map? payload,
  }) {
    return ResendVerificationCodeAction(
      initiator: initiator,
      provider: payload?['provider'] ?? 'firebase',
      method: payload?['method'] ?? 'phone',
      phoneNumber: payload?['phoneNumber'] ?? '',
      resendToken: payload?['resendToken'] ?? 0,
      onSuccess: EnsembleAction.from(payload?['onSuccess']),
      onError: EnsembleAction.from(payload?['onError']),
    );
  }

  /// Runs this action and performs the resend verification code operation.
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

      await authManager.resendVerificationCode(
        provider: provider,
        method: method,
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
    }
  }
}
