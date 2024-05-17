import 'dart:developer';
import 'dart:io';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/stub/auth_context_manager.dart';
import 'package:ensemble/framework/stub/oauth_controller.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/stub_widgets.dart';
import 'package:ensemble_auth/signin/auth_manager.dart';
import 'package:ensemble_auth/signin/google_auth_manager.dart';
import 'package:ensemble_auth/signin/signin_utils.dart';
import 'package:ensemble_auth/signin/widget/google/google_sign_in_button.dart';
import 'package:ensemble_auth/signin/widget/sign_in_button.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SignInWithGoogleImpl extends StatefulWidget
    with
        Invokable,
        HasController<SignInWithGoogleController, SignInWithGoogleImplState>
    implements SignInWithGoogle {
  static const defaultLabel = 'Sign in with Google';

  SignInWithGoogleImpl({super.key});

  final SignInWithGoogleController _controller = SignInWithGoogleController();

  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => SignInWithGoogleImplState();

  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> methods() => {};

  @override
  Map<String, Function> setters() => {
        'widget': (widgetDef) => _controller.widgetDef = widgetDef,
        'provider': (value) =>
            _controller.provider = SignInProvider.values.from(value),
        'onAuthenticated': (action) => _controller.onAuthenticated =
            EnsembleAction.fromYaml(action, initiator: this),
        'onSignedIn': (action) => _controller.onSignedIn =
            EnsembleAction.fromYaml(action, initiator: this),
        'onError': (action) => _controller.onError =
            EnsembleAction.fromYaml(action, initiator: this),
        'scopes': (value) => _controller.scopes =
            Utils.getListOfStrings(value) ?? _controller.scopes,
      };
}

class SignInWithGoogleController extends SignInButtonController {
  dynamic widgetDef;
  List<String> scopes = [];

  SignInProvider? provider;
  EnsembleAction? onAuthenticated;
  EnsembleAction? onSignedIn;
  EnsembleAction? onError;
}

class SignInWithGoogleImplState extends WidgetState<SignInWithGoogleImpl> {
  @override
  void initState() {
    super.initState();
    GoogleAuthManager().registerSignInListener(
        scopes: widget._controller.scopes,
        onAccountChanged: (account) async {
          if (account != null) {
            var googleAuthentication = await account.authentication;

            // at this point the user is authenticated.
            // On non-Web, Authorization is automatic with authentication.
            // On Web, Authorization has to be done separately, and has
            //  to be triggered manually by the user (e.g. button click)
            // TODO: authorize for Web

            await _onAuthenticated(account, googleAuthentication);
          } else {
            // _onLogOut();
          }
        });
  }

  Future<void> _onAuthenticated(GoogleSignInAccount account,
      GoogleSignInAuthentication googleAuthentication) async {
    AuthenticatedUser user = SignInUtils.fromGoogleUser(account,
        provider: widget._controller.provider);

    String? idToken = googleAuthentication.idToken;
    if (idToken == null) {
      throw RuntimeError('Unable to retrieve an idToken for Google Sign In');
    }

    // dispatch onAuthenticated since we have now authenticated the user
    if (widget._controller.onAuthenticated != null) {
      await ScreenController().executeAction(
          context, widget._controller.onAuthenticated!,
          event: EnsembleEvent(widget,
              data: {'user': user, 'idToken': idToken}));
    }

    // Sign in with a custom Server
    if (widget._controller.provider == SignInProvider.server) {
      if (widget._controller.signInServerAPI == null) {
        throw LanguageError(
            "'signInServerAPI' is required when the provider is 'server' type.");
      }
      await AuthManager().signInWithServerCredential(context,
          user: user,
          idToken: idToken,
          signInAPI: widget._controller.signInServerAPI!);
    }
    // sign in locally or with Firebase
    else {
      // Note that access token is not available on Web
      AuthToken? token;
      if (googleAuthentication.accessToken != null) {
        token = AuthToken(
            tokenType: TokenType.bearerToken,
            token: googleAuthentication.accessToken!);
      }
      idToken = await AuthManager().signInWithSocialCredential(context,
          user: user, idToken: idToken, token: token);
    }

    // trigger the callback. This can be used to sign in on the server
    if (widget._controller.onSignedIn != null) {
      ScreenController().executeAction(context, widget._controller.onSignedIn!,
          event: EnsembleEvent(widget, data: {
            'user': user,

            // server can verify and decode to get user info
            'idToken': idToken,

            // server can exchange this for accessToken/refreshToken
            'serverAuthCode': account.serverAuthCode
          }));
    }
  }

  // Future<void> _onLogOut() {
  //   AuthManager().signOut(context)
  // }

  Future<void> _handleSignIn() async {
    try {
      // sign out so user can switch to another account
      // when clicking on the button multiple times
      // await _googleSignIn.signOut();

      await GoogleAuthManager().signIn();
    } catch (error) {
      log(error.toString());
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    Widget? displayWidget;
    if (widget._controller.widgetDef != null) {
      displayWidget = DataScopeWidget.getScope(context)
          ?.buildWidgetFromDefinition(widget._controller.widgetDef);
    }

    return buildGoogleSignInButton(
        mobileWidget: displayWidget ??
            SignInButton(
                defaultLabel: SignInWithGoogleImpl.defaultLabel,
                iconName: 'google_logo.svg',
                buttonController: widget._controller,
                onTap: _handleSignIn),
        onPressed: _handleSignIn);
  }
}
