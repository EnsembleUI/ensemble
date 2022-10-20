import 'dart:math';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/parser/newjs_interpreter.dart';
import 'package:flutter/material.dart';
import 'package:js_widget/js_widget.dart';
import 'dart:convert';

class FinicityConnectController extends WidgetController {
  int width = 10;
  int height = 10;
  String id = 'finicityConnect';
  String uri = '';
  EnsembleAction? onSuccess, onCancel, onError, onRoute, onLoaded, onUser;
}
class FinicityConnect extends StatefulWidget with Invokable, HasController<FinicityConnectController, FinicityConnectState> {
  static const type = 'FinicityConnect';
  FinicityConnect({Key? key}) : super(key: key);

  static const defaultSize = 200;

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
    return {
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'id': (value) => _controller.id = Utils.getString(value, fallback: _controller.id),
      'width': (value) => _controller.width = Utils.getInt(value, fallback: defaultSize),
      'height': (value) => _controller.height = Utils.getInt(value, fallback: defaultSize),
      'uri': (value) => _controller.uri = Utils.getString(value, fallback: _controller.uri),
      'onSuccess': (funcDefinition) => _controller.onSuccess = Utils.getAction(funcDefinition, initiator: this),
      'onCancel': (funcDefinition) => _controller.onCancel = Utils.getAction(funcDefinition, initiator: this),
      'onError': (funcDefinition) => _controller.onError = Utils.getAction(funcDefinition, initiator: this),
      'onRoute': (funcDefinition) => _controller.onRoute = Utils.getAction(funcDefinition, initiator: this),
      'onUser': (funcDefinition) => _controller.onUser = Utils.getAction(funcDefinition, initiator: this),
      'onLoaded': (funcDefinition) => _controller.onLoaded = Utils.getAction(funcDefinition, initiator: this),
    };
  }
}
class FinicityConnectState extends WidgetState<FinicityConnect> {
  void executeAction(Map event) {
    EnsembleAction? action;

    if ( event['type'] == 'success' ) {
      action = widget._controller.onSuccess;
    } else if ( event['type'] == 'cancel' ) {
      action = widget._controller.onCancel;
    } else if ( event['type'] == 'error' ) {
      action = widget._controller.onError;
    } else if ( event['type'] == 'loaded' ) {
      action = widget._controller.onLoaded;
    } else if ( event['type'] == 'route' ) {
      action = widget._controller.onRoute;
    } else if ( event['type'] == 'user' ) {
      action = widget._controller.onUser;
    }
    if ( action != null ) {
      action.inputs ??= {};
      action.inputs!['event'] = (event['data'] == null) ? {}: event['data'];
      ScreenController().executeAction(context, action!);
    }
  }
  @override
  Widget buildWidget(BuildContext context) {
    if ( widget.controller.uri == '')  {
      return Text("Still Loading...");
    }
    return JsWidget(
      id: widget.controller.id,
      createHtmlTag: () => '<div></div>',
      listener: (String msg) {
        print('I got the message inside finicity!!!!');
        print('and the message is $msg!');
        executeAction(json.decode(msg));
      },
      scriptToInstantiate: (String c) {

        return '''window.finicityConnect.launch("$c", {
        selector: '#connect-container',
        overlay: 'rgba(255,255,255, 0)',
        success: (event) => {
          console.log('Yay! User went through Connect', event);
          event = {type:'success',data:event};
          handleMessage('${widget.controller.id}',JSON.stringify(event));
        },
         cancel: (event) => {
          console.log('The user cancelled the iframe', event);
          event = {type:'cancel',data:event};
          handleMessage('${widget.controller.id}',JSON.stringify(event));
         },
         error: (error) => {
          console.error('Some runtime error was generated during insideConnect ', error);
          event = {type:'error',data:error};
          handleMessage('${widget.controller.id}',JSON.stringify(error));
         },
         loaded: (event) => {
          console.log('This gets called only once after the iframe has finished loading ');
          event = {type:'loaded',data:event};
          handleMessage('${widget.controller.id}',JSON.stringify(event));
         },
         route: (event) => {
          console.log('This is called as the user navigates through Connect ', event);
          event = {type:'route',data:event};
          handleMessage('${widget.controller.id}',JSON.stringify(event));
         },
         user: (event) => {
          console.log('This is called as the user interacts with Connect ', event);
          event = {type:'user',data:event};
          handleMessage('${widget.controller.id}',JSON.stringify(event));
         }
        
        
        });
        ''';
        //return 'if (typeof ${widget.controller.chartVar} !== "undefined") ${widget.controller.chartVar}.destroy();${widget.controller.chartVar} = new Chart(document.getElementById("${widget.controller.chartId}"), $c);${widget.controller.chartVar}.update();';
      },
      size: Size(widget.controller.width.toDouble(), widget.controller.height.toDouble()),
      data: widget.controller.uri,
      scripts: const [
        "https://connect2.finicity.com/assets/sdk/finicity-connect.min.js",
      ],
    );
  }
}