import 'dart:developer';
import 'dart:convert';
import 'dart:io';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/stub/auth_context_manager.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/stub_widgets.dart' as ensemble;
import 'package:ensemble_auth/signin/auth_manager.dart';
import 'package:ensemble_auth/signin/widget/sign_in_button.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SignInWithAppleImpl extends StatefulWidget
    with
        Invokable,
        HasController<SignInWithAppleController, SignInWithAppleState>
    implements ensemble.SignInWithApple {
  static const defaultLabel = 'Sign in with Apple';

  SignInWithAppleImpl({super.key});

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
        'provider': (value) =>
            _controller.provider = SignInProvider.values.from(value),
        'onAuthenticated': (action) => _controller.onAuthenticated =
            EnsembleAction.fromYaml(action, initiator: this),
        'onSignedIn': (action) => _controller.onSignedIn =
            EnsembleAction.fromYaml(action, initiator: this),
        'onError': (action) => _controller.onError =
            EnsembleAction.fromYaml(action, initiator: this),

        // styles only apply to default button
        'buttonStyle': (value) => _controller.buttonStyle =
            SignInWithAppleButtonStyle.values.from(value)
      };
}

class SignInWithAppleController extends SignInButtonController {
  SignInProvider? provider;
  EnsembleAction? onAuthenticated;
  EnsembleAction? onSignedIn;
  EnsembleAction? onError;

  // these styles apply only to default button
  SignInWithAppleButtonStyle? buttonStyle;
}

class SignInWithAppleState extends WidgetState<SignInWithAppleImpl> {
  @override
  Widget buildWidget(BuildContext context) {
    var button = AppleSignInButton(
        buttonController: widget._controller,
        onTap: () async {
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
        });

    // TODO: add support for Android / Web
    if (kIsWeb || Platform.isAndroid) {
      return IgnorePointer(
          child: Stack(children: [
        button,
        Positioned.fill(child: Container(color: Colors.grey.withOpacity(0.7)))
      ]));
    }
    return button;
  }

  void _onAuthenticated(AuthorizationCredentialAppleID credential) async {
    if (credential.identityToken == null) {
      throw RuntimeError('Invalid token.');
    }
    AuthenticatedUser user = _getAuthenticatedUser(credential);

    if (widget._controller.onAuthenticated != null) {
      await ScreenController().executeAction(
          context, widget._controller.onAuthenticated!,
          event: EnsembleEvent(widget,
              data: {'user': user, 'idToken': credential.identityToken}));
    }

    if (widget._controller.provider != SignInProvider.server) {
      // Apple don't have any access token related.
      await AuthManager().signInWithSocialCredential(context,
          user: user, idToken: credential.identityToken!);

      // trigger onSignIn callback
      if (widget._controller.onSignedIn != null) {
        ScreenController()
            .executeAction(context, widget._controller.onSignedIn!,
                event: EnsembleEvent(widget, data: {
                  'user': user,
                  'idToken': credential.identityToken,
                }));
      }
    }
  }

  /// Note that Apple only send the name and email the first time, so it's
  /// important not to accidentally clear them out unless the user id is different.
  AuthenticatedUser _getAuthenticatedUser(
      AuthorizationCredentialAppleID credential) {
    // on Android the userIdentifier is not specified, so we need
    // to use the idToken's sub as the user ID
    String? userId =
        credential.userIdentifier ?? _getUserId(credential.identityToken!);
    if (userId == null) {
      throw RuntimeError(
          'Error: The required user id is not provided by Apple.');
    }
    // combine first/last to display name
    String? name;
    var names = [credential.givenName, credential.familyName]
        .where((name) => name != null && name.isNotEmpty)
        .toList();
    if (names.isNotEmpty) {
      name = names.join(' ');
    }
    String? email = credential.email;

    // Apple only send the name and email the first time,
    // so if the user id is the same, use the old the info if needed to.
    AuthenticatedUser? currentUser = AuthManager().getCurrentUser();
    if (userId == currentUser?.id) {
      if (name == null || name.isEmpty) {
        name = currentUser!.name;
      }
      if (email == null || email.isEmpty) {
        email = currentUser!.email;
      }
    }

    return AuthenticatedUser(
        client: SignInClient.apple,
        provider: widget._controller.provider,
        id: userId,
        name: name,
        email: email);
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
