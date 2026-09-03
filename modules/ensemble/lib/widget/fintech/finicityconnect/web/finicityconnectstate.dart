import 'package:ensemble/widget/fintech/finicityconnect/finicityconnect.dart';
import 'package:ensemble/widget/fintech/finicity_connect_script.dart';
import 'package:flutter/material.dart';
import 'package:js_widget/js_widget.dart';
import 'dart:convert';

class FinicityConnectState extends FinicityConnectStateBase {
  @override
  Widget buildWidget(BuildContext context) {
    if (widget.controller.uri == '') {
      return const Text("");
    }
    String width = '100%';
    if (widget.controller.width != 0) {
      width = '${widget.controller.width}px';
    }
    String height = '100%';
    if (widget.controller.height != 0) {
      height = '${widget.controller.height}px';
    }
    return JsWidget(
      id: widget.controller.id!,
      createHtmlTag: () => '<div></div>',
      listener: (String msg) {
        print('message inside finicity and the message is $msg!');
        executeAction(json.decode(msg));
      },
      scriptToInstantiate: (String connectUri) {
        return buildFinicityConnectInstantiateScript(
          connectUri: connectUri,
          widgetId: widget.controller.id!,
          left: widget.controller.left,
          top: widget.controller.top,
          position: widget.controller.position,
          overlay: widget.controller.overlay?.toString(),
        );
      },
      size: Size(widget.controller.width.toDouble(),
          widget.controller.height.toDouble()),
      data: widget.controller.uri,
      scripts: const [
        "https://connect2.finicity.com/assets/sdk/finicity-connect.min.js",
      ],
    );
  }
}
