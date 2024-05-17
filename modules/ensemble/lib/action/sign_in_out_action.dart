import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/auth_context_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';

/// Verify if the user is currently signed in
class VerifySignInAction extends EnsembleAction {
  VerifySignInAction({super.initiator, this.onSignedIn, this.onNotSignedIn});

  final EnsembleAction? onSignedIn;
  final EnsembleAction? onNotSignedIn;

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    if (GetIt.instance.isRegistered<AuthContextManager>()) {
      var authContext = GetIt.instance<AuthContextManager>();
      return authContext.getSignedInUser().then((user) {
        // dispatched onSignedIn
        if (user != null && onSignedIn != null) {
          ScreenController().executeAction(context, onSignedIn!,
              event: EnsembleEvent(initiator, data: {user: user}));
        }

        // dispatch onNotSignedIn
        if (user == null && onNotSignedIn != null) {
          ScreenController().executeAction(context, onNotSignedIn!,
              event: EnsembleEvent(initiator));
        }
      });
    }
    // dispatch onNotSignedIn
    if (onNotSignedIn != null) {
      ScreenController().executeAction(context, onNotSignedIn!,
          event: EnsembleEvent(initiator));
    }
  }
}

/// sign the user out
class SignOutAction extends EnsembleAction {
  SignOutAction({super.initiator, this.onComplete});

  final EnsembleAction? onComplete;

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    if (GetIt.instance.isRegistered<AuthContextManager>()) {
      var authContext = GetIt.instance<AuthContextManager>();
      await authContext.signOut().then((_) => _executeOnComplete(context));
    }
    return _executeOnComplete(context);
  }

  Future _executeOnComplete(BuildContext context) {
    if (onComplete != null) {
      return ScreenController()
          .executeAction(context, onComplete!, event: EnsembleEvent(initiator));
    }
    return Future.value(null);
  }
}

/// TODO: expose this?? doesn't have a good use-case yet
/// Sign in the user with server credentials. This is meant to be used in
/// conjunction with Social-Media sign in.
/// Sign-in flow with the Server:
/// 1. client go through Social Sign in (Google, Firebase, ...) to retrieve the idToken
/// 2. client sends the idToken to the server
/// 3. server verifies idToken authenticity and extract the user info from it
/// 4. server returns a required set of serverCredentials (JWT bearer token, cookie, ...)
/// 5. client sign the user into Ensemble with the idToken and the server credentials.
/// 6. client includes the server credentials on API calls to the server
class SignInAction extends EnsembleAction {
  SignInAction(
      {super.initiator,
      required this.idToken,
      required this.serverCredentials});

  // can be used to store e.g. bearer token, cookies, ...
  // It just have to be something so server can identify the client.
  final Map serverCredentials;
  final String idToken;

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) {
    // TODO: implement execute
    return super.execute(context, scopeManager);
  }
}
