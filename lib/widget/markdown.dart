
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart' as framework;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class Markdown extends StatefulWidget with Invokable, HasController<MarkdownController, MarkdownState> {
  static const type = 'Markdown';
  Markdown({Key? key}) : super(key: key);

  final MarkdownController _controller = MarkdownController();
  @override
  MarkdownController get controller => _controller;

  @override
  MarkdownState createState() => MarkdownState();


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
      'textStyle': (style) => _controller.textStyle = Utils.getTextStyle(style),
      'linkStyle': (style) => _controller.linkStyle = Utils.getTextStyle(style),
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }




}


class MarkdownController extends framework.WidgetController {
  String? text;

  TextStyle? textStyle;
  TextStyle? linkStyle;
  //TextStyle? codeStyle
}


class MarkdownState extends framework.WidgetState<Markdown> {
  @override
  Widget build(BuildContext context) {
    if (!widget._controller.visible) {
      return const SizedBox.shrink();
    }

    // built styles from default Material3 text styles, then apply overrides
    MarkdownStyleSheet styles = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: widget._controller.textStyle,
      a: widget._controller.linkStyle,
    );

    return MarkdownBody(
      data: widget._controller.text ?? '',
      styleSheet: styles,
      onTapLink: openUrl,
    );
  }

  void openUrl(String text, String? url, String? title) {
    if (url != null && url.isNotEmpty) {
      launchUrl(Uri.parse(url));
    }
  }


}