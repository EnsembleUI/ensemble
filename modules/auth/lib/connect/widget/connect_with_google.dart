import 'package:ensemble/action/invoke_api_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/stub/oauth_controller.dart';
import 'package:ensemble/framework/stub/token_manager.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/stub_widgets.dart';
import 'package:ensemble_auth/connect/OAuthController.dart';
import 'package:ensemble_auth/connect/widget/connect.dart';
import 'package:ensemble_auth/signin/widget/sign_in_button.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ConnectWithGoogleImpl extends StatefulWidget
    with
        Invokable,
        HasController<ConnectWithGoogleController, ConnectWithGoogleState>
    implements ConnectWithGoogle {
  static const defaultLabel = 'Continue with Google';
  ConnectWithGoogleImpl({super.key});

  final ConnectWithGoogleController _controller = ConnectWithGoogleController();
  @override
  ConnectWithGoogleController get controller => _controller;

  @override
  State<StatefulWidget> createState() => ConnectWithGoogleState();


  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'tokenExchangeAPI': (apiAction) => _controller.tokenExchangeAPI =
          apiAction == null ? null : InvokeAPIAction.fromYaml(
              initiator: this, payload: apiAction),
      'onInitiated': (action) => _controller.onInitiated =
          EnsembleAction.fromYaml(action, initiator: this),
      'onCanceled': (action) => _controller.onCanceled =
          EnsembleAction.fromYaml(action, initiator: this),
      'onAuthorized': (action) => _controller.onAuthorized =
          EnsembleAction.fromYaml(action, initiator: this),
      'onError': (action) => _controller.onError =
          EnsembleAction.fromYaml(action, initiator: this),
    };
  }
}

class ConnectWithGoogleController extends ConnectController {

}

class ConnectWithGoogleState extends WidgetState<ConnectWithGoogleImpl> {
  Widget? _displayWidget;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget._controller.widgetDef != null) {
      _displayWidget = DataScopeWidget.getScope(context)
          ?.buildWidgetFromDefinition(widget._controller.widgetDef);
    }
  }


  @override
  Widget buildWidget(BuildContext context) {
    return _displayWidget != null
        ? ConnectWidgetContainer(widget: _displayWidget!, onTap: startAuthFlow)
        : SignInButton(
            defaultLabel: ConnectWithGoogleImpl.defaultLabel,
            iconName: 'google_logo.svg',
            buttonController: widget._controller,
            onTap: startAuthFlow);
  }

  Future<void> startAuthFlow() async {
    List<String> scopes = [];
    if (widget._controller.initialScopes != null) {
      scopes.addAll(widget._controller.initialScopes!);
    }

    if (widget._controller.onInitiated != null) {
      ScreenController()
          .executeAction(context, widget._controller.onInitiated!);
    }

    OAuthServiceToken? token;
    try {
      // Server doesn't always need to return a token if they don't want to,
      // but we have code to create an empty token as needed.
      // So null token here means some error occurs along the way
      token = await OAuthControllerImpl().authorize(
          context,
          OAuthService.google,
          scope: ConnectUtils.getScopesAsString(scopes),
          forceNewTokens: true,   // this always force the flow again
          tokenExchangeAPI: widget._controller.tokenExchangeAPI);

      // dispatch success
      if (token != null && widget._controller.onAuthorized != null) {
        ScreenController()
            .executeAction(context, widget._controller.onAuthorized!);
        return;
      }
    } catch (e) {
      if (e is PlatformException && e.code == 'CANCELED') {
        if (widget._controller.onCanceled != null) {
          ScreenController()
              .executeAction(context, widget._controller.onCanceled!);
        }
        return;
      }
    }

    // dispatch error
    if (widget._controller.onError != null && token == null) {
      ScreenController()
          .executeAction(context, widget._controller.onError!);
    }
  }

}
