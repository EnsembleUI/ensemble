
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart' as framework;
import 'package:ensemble/widget/helpers/controllers.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter_html/flutter_html.dart';


/// widget to render Html content
class EnsembleHtml extends StatefulWidget with Invokable, HasController<HtmlController, HtmlState> {
  static const type = 'Html';
  EnsembleHtml({Key? key}) : super(key: key);

  final HtmlController _controller = HtmlController();
  @override
  HtmlController get controller => _controller;

  @override
  HtmlState createState() => HtmlState();


  @override
  Map<String, Function> getters() {
    return {
      'text': () => _controller.text
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'text': (newValue) => _controller.text = Utils.optionalString(newValue),
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

}


class HtmlController extends WidgetController {
  String? text;
}


class HtmlState extends framework.WidgetState<EnsembleHtml> {
  @override
  Widget buildWidget(BuildContext context) {

    return Html(
      data: widget._controller.text ?? '',
      onLinkTap: ((url, context, attributes, element) {
        if (url != null) {
          launchUrl(Uri.parse(url));
        }
      }),
    );
  }



}