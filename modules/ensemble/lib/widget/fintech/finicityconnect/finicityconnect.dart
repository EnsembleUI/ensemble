import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/widget/fintech/finicityconnect/finicityconnectstate.dart';

class FinicityConnectController extends WidgetController {
  FinicityConnectController() {
    id = 'finicityConnect';
  }
  double width = 450;
  double height = 500;
  String uri = '';
  EnsembleAction? onSuccess, onCancel, onError, onRoute, onLoaded, onUser;
  String? overlay;
  int left = 0;
  int top = 0;
  String position = 'absolute';
}

class FinicityConnect extends StatefulWidget
    with
        Invokable,
        HasController<FinicityConnectController, FinicityConnectState> {
  static const type = 'FinicityConnect';
  FinicityConnect({Key? key}) : super(key: key);

  static const double defaultSize = 200;

  final FinicityConnectController _controller = FinicityConnectController();
  @override
  FinicityConnectController get controller => _controller;

  @override
  State<StatefulWidget> createState() => FinicityConnectState();

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
      'id': (value) =>
          _controller.id = Utils.getString(value, fallback: _controller.id!),
      'width': (value) =>
          _controller.width = Utils.getDouble(value, fallback: defaultSize),
      'height': (value) =>
          _controller.height = Utils.getDouble(value, fallback: defaultSize),
      'left': (value) =>
          _controller.left = Utils.getInt(value, fallback: _controller.left),
      'top': (value) =>
          _controller.top = Utils.getInt(value, fallback: _controller.top),
      'position': (value) => _controller.position =
          Utils.getString(value, fallback: _controller.position),
      'uri': (value) =>
          _controller.uri = Utils.getString(value, fallback: _controller.uri),
      'onSuccess': (funcDefinition) => _controller.onSuccess =
          EnsembleAction.from(funcDefinition, initiator: this),
      'onCancel': (funcDefinition) => _controller.onCancel =
          EnsembleAction.from(funcDefinition, initiator: this),
      'onError': (funcDefinition) => _controller.onError =
          EnsembleAction.from(funcDefinition, initiator: this),
      'onRoute': (funcDefinition) => _controller.onRoute =
          EnsembleAction.from(funcDefinition, initiator: this),
      'onUser': (funcDefinition) => _controller.onUser =
          EnsembleAction.from(funcDefinition, initiator: this),
      'onLoaded': (funcDefinition) => _controller.onLoaded =
          EnsembleAction.from(funcDefinition, initiator: this),
      'overlay': (value) => _controller.overlay = value,
    };
  }
}

abstract class FinicityConnectStateBase extends WidgetState<FinicityConnect> {
  void executeAction(Map event) {
    EnsembleAction? action;

    if (event['type'] == 'success') {
      action = widget._controller.onSuccess;
    } else if (event['type'] == 'cancel') {
      action = widget._controller.onCancel;
    } else if (event['type'] == 'error') {
      action = widget._controller.onError;
    } else if (event['type'] == 'loaded') {
      action = widget._controller.onLoaded;
    } else if (event['type'] == 'route') {
      action = widget._controller.onRoute;
    } else if (event['type'] == 'user') {
      action = widget._controller.onUser;
    }
    if (action != null) {
      action.inputs ??= {};
      action.inputs!['event'] = (event['data'] == null) ? {} : event['data'];
      ScreenController().executeAction(context, action);
    }
  }
}
