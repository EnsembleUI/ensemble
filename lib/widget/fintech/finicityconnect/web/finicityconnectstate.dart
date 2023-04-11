import 'package:ensemble/widget/fintech/finicityconnect/finicityconnect.dart';
import 'package:flutter/material.dart';
import 'package:js_widget/js_widget.dart';
import 'dart:convert';

class FinicityConnectState extends FinicityConnectStateBase {
  String getScriptToInstantiate(
      String c, String width, String height, String overlay) {
    return '''
        window.finicityConnect.launch("$c", {
        $overlay
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
        const finIFrame = document.getElementById("finicityConnectIframe");
        if ( finIFrame ) {
          finIFrame.style.left = '${widget.controller.left}px';
          finIFrame.style.top = '${widget.controller.top}px';
          finIFrame.style.position = '${widget.controller.position}';
          //finIFrame.style.width = '$width';
          //finIFrame.style.height = '$height';
        }
        ''';
  }

  @override
  Widget buildWidget(BuildContext context) {
    if (widget.controller.uri == '') {
      return const Text("");
    }
    String overlay = '';
    if (widget.controller.overlay != null) {
      overlay = 'overlay: ${widget.controller.overlay!},';
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
      scriptToInstantiate: (String c) {
        return getScriptToInstantiate(c, width, height, overlay);
        //return 'if (typeof ${widget.controller.chartVar} !== "undefined") ${widget.controller.chartVar}.destroy();${widget.controller.chartVar} = new Chart(document.getElementById("${widget.controller.chartId}"), $c);${widget.controller.chartVar}.update();';
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
