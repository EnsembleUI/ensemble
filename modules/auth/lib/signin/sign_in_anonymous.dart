import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/stub/auth_context_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/widget/stub_widgets.dart';
import 'package:ensemble_auth/signin/auth_manager.dart';
import 'package:flutter/material.dart';

class SignInAnonymousImpl implements SignInAnonymous {
  @override
  Future<void> signInAnonymously(BuildContext context,
      {required SignInAnonymousAction action}) async {
    final isAuthenticated = await AuthManager().signInAnonymously(context);
    if (isAuthenticated != null) {
      if (action.onAuthenticated != null) {
        AuthenticatedUser? currentUser = AuthManager().getCurrentUser();
        ScreenController().executeAction(context, action.onAuthenticated!,
            event: EnsembleEvent(null, data: {'user': currentUser}));
      } else {
        if (action.onError != null) {
          ScreenController().executeAction(context, action.onError!);
        }
      }
    }
  }
}
