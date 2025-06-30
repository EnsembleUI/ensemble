import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart' as framework;
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';

import 'package:yaml/yaml.dart';

class Markdown extends StatefulWidget
    with Invokable, HasController<MarkdownController, MarkdownState> {
  static const type = 'Markdown';
  Markdown({Key? key}) : super(key: key);

  final MarkdownController _controller = MarkdownController();
  @override
  MarkdownController get controller => _controller;

  @override
  MarkdownState createState() => MarkdownState();

  @override
  Map<String, Function> getters() {
    return {'text': () => _controller.text};
  }

  @override
  Map<String, Function> setters() {
    return {
      'text': (newValue) => _controller.text = Utils.optionalString(newValue),
      'textStyle': (style) => _controller.textStyle = Utils.getTextStyle(style),
      'linkStyle': (style) => _controller.linkStyle = Utils.getTextStyle(style),
      'colorFilter': (value) => _controller.colorFilter = Utils.getColor(value),
      'blendMode': (value) => _controller.blendMode = Utils.getBlendMode(value),
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }
}

class MarkdownController extends WidgetController {
  String? text;

  TextStyle? textStyle;
  TextStyle? linkStyle;
  Color? colorFilter;
  BlendMode blendMode = BlendMode.modulate;
  //TextStyle? codeStyle
}

class MarkdownState extends framework.EWidgetState<Markdown> {
  @override
  Widget buildWidget(BuildContext context) {
    // built styles from default Material3 text styles, then apply overrides
    MarkdownStyleSheet styles =
        MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: widget._controller.textStyle,
      a: widget._controller.linkStyle ??
          TextStyle(color: ThemeManager().getPrimaryColor(context)),
    );

    Widget rtn =  MarkdownBody(
      data: widget._controller.text ?? '',
      styleSheet: styles,
      onTapLink: openUrl,
    );
    if(widget._controller.colorFilter != null){
       bool isBlack = widget._controller.colorFilter!.value == 0xFF000000 ||
                     widget._controller.colorFilter!.value == 0x00000000;
      if (isBlack && widget._controller.blendMode == BlendMode.modulate) {
        rtn = ColorFiltered(
          colorFilter: Utils.getGreyScale(),
          child: rtn,
        );
      } else {
        rtn = ColorFiltered(
          colorFilter: ColorFilter.mode(widget._controller.colorFilter!, widget._controller.blendMode),
          child: rtn,
        );
      }
    }
    return rtn;
  }

  void openUrl(String text, String? url, String? title) {
    if (url != null && url.isNotEmpty) {
      // special handler for screen navigation
      if (url.startsWith(ActionType.navigateScreen.name) ||
          url.startsWith(ActionType.navigateModalScreen.name)) {
        handleScreenNavigation(url);
      } else {
        launchUrl(Uri.parse(url));
      }
    }
  }

  void handleScreenNavigation(String raw) async {
    // very specific syntax [screen name](navigateScreen:MyScreen,inputs:{name:Peter,occupation:engineer})
    // no spaces as Markdown don't expect any spaces in the URL
    // We only expect 1 or 2 tokens, separated by 1 comma.
    String? firstToken;
    String? secondToken;
    int index = raw.indexOf(',');
    if (index == -1) {
      firstToken = raw;
    } else {
      firstToken = raw.substring(0, index);
      secondToken = raw.substring(index + 1);
    }

    bool? asModal;
    String? screenName;
    Map<String, dynamic>? inputs;

    // get screen name
    List<String> keyValues = firstToken.split(':');
    if (keyValues.length == 2) {
      if (keyValues[0] == ActionType.navigateScreen.name) {
        asModal = false;
      } else if (keyValues[0] == ActionType.navigateModalScreen.name) {
        asModal = true;
      }
      screenName = keyValues[1];
    }

    // get inputs
    /*if (secondToken != null) {
      index = secondToken.indexOf(':');
      if (index != -1 && secondToken.substring(0, index) == 'inputs') {
        try {
          // can't parse YAML as markdown expects no spaces. TODO: figure out new syntax
          inputs = Utils.parseYamlMap(await loadYaml(secondToken.substring(index+1)));
        } on FormatException catch (e) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: LanguageError("Invalid screen navigation syntax. Inputs is not a map"),
            library: 'Markdown',
            context: ErrorSummary('Markdown error'),
          ));
        }
      }
    }*/

    if (asModal != null && screenName != null) {
      ScreenController().navigateToScreen(
        context,
        screenName: screenName,
        asModal: asModal,
        //pageArgs: inputs
      );
    } else {
      FlutterError.reportError(FlutterErrorDetails(
        exception:
            LanguageError("Invalid screen navigation syntax in Markdown"),
        library: 'Markdown',
        context: ErrorSummary('Markdown error'),
      ));
    }
  }
}
