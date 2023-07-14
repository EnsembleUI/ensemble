import 'dart:developer';
import 'dart:convert';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;

class EnsembleSignInWithApple extends StatefulWidget
    with
        Invokable,
        HasController<SignInWithAppleController, SignInWithAppleState> {
  static const type = 'SignInWithApple';

  EnsembleSignInWithApple({super.key});

  final SignInWithAppleController _controller = SignInWithAppleController();

  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => SignInWithAppleState();

  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> methods() => {};

  @override
  Map<String, Function> setters() => {
        // 'widget': (widgetDef) => _controller.widgetDef = widgetDef,
        'onAuthenticated': (action) => _controller.onAuthenticated =
            EnsembleAction.fromYaml(action, initiator: this),
        'onError': (action) => _controller.onError =
            EnsembleAction.fromYaml(action, initiator: this)
      };
}

class SignInWithAppleController extends WidgetController {
  // dynamic widgetDef;
  EnsembleAction? onAuthenticated;
  EnsembleAction? onError;
}

class SignInWithAppleState extends WidgetState<EnsembleSignInWithApple> {
  // Widget? displayWidget;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // build the display widget
    // displayWidget = DataScopeWidget.getScope(context)
    //     ?.buildWidgetFromDefinition(widget._controller.widgetDef);
  }

  @override
  Widget buildWidget(BuildContext context) {
    return SignInWithAppleButton(
      onPressed: () async {
        try {
          final credential =
              await SignInWithApple.getAppleIDCredential(scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ]);
          _onAuthenticated(credential);
        } catch (e) {
          log(e.toString());
          if (widget._controller.onError != null) {
            ScreenController()
                .executeAction(context, widget._controller.onError!);
          }
        }
      },
    );
  }

  void _onAuthenticated(AuthorizationCredentialAppleID credential) {
    if (credential.identityToken == null) {
      throw RuntimeError('Invalid token.');
    }

    // Apple don't have any access token related.

    // update the user information in storage.
    // Note that Apple only send the name and email the first time, so it's
    // important not to accidentally clear them  out unless the user id is different.
    // Also note on Android the userIdentifier is not specified, so we need
    // to use the idToken's sub as the user ID
    final storage = StorageManager();
    String? name;
    String? userId = _getUserId(credential.identityToken!);
    if (userId != null && userId != storage.getUserId()) {
      var names = [credential.givenName, credential.familyName]
          .where((name) => name != null && name.isNotEmpty)
          .toList();
      if (names.isNotEmpty) {
        name = names.join(' ');
      }

      StorageManager()
          .updateUser(context, userId, name: name, email: credential.email);
    }

    // trigger the callback
    if (widget._controller.onAuthenticated != null) {
      ScreenController().executeAction(
          context,
          widget._controller.onAuthenticated!,
          event: EnsembleEvent(widget, data: {
            'id': userId,
            'name': name,
            'email': credential.email,

            // server can verify and decode to get user info, useful for Sign In
            'idToken': credential.identityToken
          }));
    }


  }

  /// simply decode the idToken and get the sub to use as userId.
  /// Note that we are not trying to verify the authenticity here. That
  /// should be done on the server for Sign in purpose. We just try to find
  /// a unique user ID that will be the same across logins
  String? _getUserId(String idToken) {
    try {
      List<String> parts = idToken.split(".");
      var payload = json
          .decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      return payload['sub'];
    } catch (e) {
      log('Cannot retrieve user ID from token');
    }
    return null;
  }

}
