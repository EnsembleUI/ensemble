import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/stub/auth_context_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/widget/stub_widgets.dart';
import 'package:ensemble_auth/signin/auth_manager.dart';
import 'package:flutter/material.dart';

class SignInWithCustomTokenImpl implements SignInWithCustomToken {
  @override
  Future<void> signInWithCustomToken(BuildContext context,
      {required SignInWithCustomTokenAction action}) async {
    try {
      final jwtToken = action.jwtToken;
      if (jwtToken == null || jwtToken == "") {
        throw LanguageError(
            "signInWithCustomToken requires jwtToken as 'token' parameter.",
            recovery: "Fix: pass valid jwtToken as 'token' under signInWithCustomToken");
      }
      final idToken = await AuthManager()
          .signInWithCustomToken(context, jwtToken: jwtToken);
      if (idToken != null) {
        if (action.onAuthenticated != null) {
          AuthenticatedUser? currentUser = AuthManager().getCurrentUser();
          ScreenController().executeAction(context, action.onAuthenticated!,
              event: EnsembleEvent(null,
                  data: {'user': currentUser, 'idToken': idToken}));
        }
      }
    } catch (e) {
      if (action.onError != null) {
        ScreenController().executeAction(context, action.onError!,
            event: EnsembleEvent(null, error: {'error': e.toString()}));
      }
    }
  }
}
