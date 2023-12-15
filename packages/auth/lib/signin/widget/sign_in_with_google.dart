import 'dart:developer';
import 'dart:io';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/stub/oauth_controller.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/stub_widgets.dart';
import 'package:ensemble_auth/signin/auth_manager.dart';
import 'package:ensemble_auth/signin/widget/google/google_sign_in_button.dart';
import 'package:ensemble_auth/signin/widget/sign_in_button.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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
        'provider': (value) => _controller.provider =
            SignInProvider.values.from(value),
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
  late GoogleSignIn _googleSignIn;
  Widget? displayWidget;

  @override
  void initState() {
    super.initState();

    _googleSignIn = GoogleSignIn(
        clientId: getClientId(),
        serverClientId: getServerClientId(),
        scopes: widget._controller.scopes);
    _googleSignIn.onCurrentUserChanged.listen((account) async {
      if (account != null) {
        var googleAuthentication = await account.authentication;

        // at this point the user is authenticated.
        // On non-Web, Authorization is automatic with authentication.
        // On Web, Authorization has to be done separately, and has
        //  to be triggered manually by the user (e.g. button click)
        // TODO: authorize for Web
        bool isAuthorized = true;
        if (kIsWeb) {
          isAuthorized =
              await _googleSignIn.canAccessScopes(widget._controller.scopes);
        }
        await _onAuthenticated(account, googleAuthentication);
      } else {
        //log("TO BE IMPLEMENTED: log out");
      }
    });
  }

  Future<void> _onAuthenticated(GoogleSignInAccount account,
      GoogleSignInAuthentication googleAuthentication) async {

    AuthenticatedUser user = AuthenticatedUser(
        client: SignInClient.google,
        provider: widget._controller.provider,
        id: account.id,
        name: account.displayName,
        email: account.email,
        photo: account.photoUrl);

    // trigger the callback. This can be used to sign in on the server
    if (widget._controller.onAuthenticated != null) {
      ScreenController()
          .executeAction(context, widget._controller.onAuthenticated!,
          event: EnsembleEvent(widget, data: {
            'user': user,

            // server can verify and decode to get user info, useful for Sign In
            'idToken': googleAuthentication.idToken,

            // server can exchange this for accessToken/refreshToken
            'serverAuthCode': account.serverAuthCode
          }));
    }

    /// we don't sign in with Custom provider. User can call their server
    /// to create the server, then onResponse they can manually call signIn
    if (widget._controller.provider != SignInProvider.server) {
      AuthToken? token;
      if (googleAuthentication.accessToken != null) {
        token = AuthToken(
            tokenType: TokenType.bearerToken,
            token: googleAuthentication.accessToken!);
      }
      await AuthManager().signInWithCredential(
          context,
          user: user,
          idToken: googleAuthentication.idToken,
          token: token);

      // trigger onSignIn callback
      if (widget._controller.onSignedIn != null) {
        ScreenController()
            .executeAction(context, widget._controller.onSignedIn!,
            event: EnsembleEvent(widget, data: {
              'user': user
            }));
      }

    }

  }

  Future<void> _handleSignIn() async {
    try {
      // sign out so user can switch to another account
      // when clicking on the button multiple times
      await _googleSignIn.signOut();

      await _googleSignIn.signIn();
    } catch (error) {
      log(error.toString());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // build the display widget
    if (widget._controller.widgetDef != null) {
      displayWidget = DataScopeWidget.getScope(context)
          ?.buildWidgetFromDefinition(widget._controller.widgetDef);
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    return buildGoogleSignInButton(
        mobileWidget: displayWidget ?? SignInButton(
            defaultLabel: SignInWithGoogleImpl.defaultLabel,
            iconName: 'google_logo.svg',
            buttonController: widget._controller,
            onTap: _handleSignIn),
        onPressed: _handleSignIn);
  }

  String getClientId() {
    SignInCredential? credential =
        Ensemble().getSignInServices()?.signInCredentials?[OAuthService.google];
    String? clientId;
    if (kIsWeb) {
      clientId = credential?.webClientId;
    } else if (Platform.isAndroid) {
      clientId = credential?.androidClientId;
    } else if (Platform.isIOS) {
      clientId = credential?.iOSClientId;
    }
    if (clientId != null) {
      return clientId;
    }
    throw LanguageError("Google SignIn provider is required.",
        recovery: "Please check your configuration.");
  }

  // serverClientId is not supported on Web
  String? getServerClientId() => kIsWeb
      ? null
      : Ensemble()
          .getSignInServices()
          ?.signInCredentials?[OAuthService.google]
          ?.serverClientId;
}
