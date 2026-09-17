import 'dart:convert';

/// Builds the JavaScript snippet that launches Finicity Connect inside a
/// [JsWidget] WebView.
///
/// All externally influenced string values are embedded via [jsonEncode] so
/// they cannot break out of the generated script.
String buildFinicityConnectInstantiateScript({
  required String connectUri,
  required String widgetId,
  required int left,
  required int top,
  required String position,
  String? overlay,
}) {
  final overlayLine =
      overlay != null ? 'overlay: ${jsonEncode(overlay)},\n        ' : '';
  final uriLiteral = jsonEncode(connectUri);
  final widgetIdLiteral = jsonEncode(widgetId);
  final positionLiteral = jsonEncode(position);

  return '''
        window.finicityConnect.launch($uriLiteral, {
        $overlayLine success: (event) => {
          console.log('Yay! User went through Connect', event);
          event = {type:'success',data:event};
          handleMessage($widgetIdLiteral,JSON.stringify(event));
        },
         cancel: (event) => {
          console.log('The user cancelled the iframe', event);
          event = {type:'cancel',data:event};
          handleMessage($widgetIdLiteral,JSON.stringify(event));
         },
         error: (error) => {
          console.error('Some runtime error was generated during insideConnect ', error);
          event = {type:'error',data:error};
          handleMessage($widgetIdLiteral,JSON.stringify(error));
         },
         loaded: (event) => {
          console.log('This gets called only once after the iframe has finished loading ');
          event = {type:'loaded',data:event};
          handleMessage($widgetIdLiteral,JSON.stringify(event));
         },
         route: (event) => {
          console.log('This is called as the user navigates through Connect ', event);
          event = {type:'route',data:event};
          handleMessage($widgetIdLiteral,JSON.stringify(event));
         },
         user: (event) => {
          console.log('This is called as the user interacts with Connect ', event);
          event = {type:'user',data:event};
          handleMessage($widgetIdLiteral,JSON.stringify(event));
         }
        });
        const finIFrame = document.getElementById("finicityConnectIframe");
        if ( finIFrame ) {
          finIFrame.style.left = '${left}px';
          finIFrame.style.top = '${top}px';
          finIFrame.style.position = $positionLiteral;
        }
        ''';
}
