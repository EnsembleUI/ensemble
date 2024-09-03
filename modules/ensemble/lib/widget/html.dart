import 'package:change_case/change_case.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart' as framework;
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:ensemble/framework/action.dart' as ensemble;
import 'package:yaml/yaml.dart';

class CSSStyle {
  CSSStyle._({required this.cssBuffer, required this.cssMap});

  factory CSSStyle.fromYaml(List<Map> yaml) {
    final Map<String, Map<String, dynamic>> rtnCssMap = {};
    final List<MapEntry<String, Map<String, dynamic>>> valuesToAdd = [];
    final StringBuffer rtnCssBuffer = StringBuffer();

    for (final entity in yaml) {
      final map = Utils.getMap(entity);

      valuesToAdd.add(
        MapEntry(
          map?['selector'],
          Utils.getMap(map?['properties']) ?? {},
        ),
      );
    }

    rtnCssMap.addEntries(valuesToAdd);
    rtnCssMap.forEach((key, value) {
      rtnCssBuffer.write('$key {\n');
      value.forEach((key, value) {
        rtnCssBuffer.write('  ${key.toParamCase()}: $value;\n');
      });
      rtnCssBuffer.write('}\n\n');
    });

    return CSSStyle._(cssBuffer: rtnCssBuffer, cssMap: rtnCssMap);
  }

  StringBuffer cssBuffer;
  Map<String, Map<String, dynamic>> cssMap;

  void updateMaxLines(String selector, int maxLines) {
    cssMap[selector]?['maxLines'] = maxLines;
  }

  Map<String, Style> getStyle() {
    Map<String, Style> style = Style.fromCss(
      cssBuffer.toString(),
      (css, errors) {
        debugPrint(errors.toString());
        debugPrint(css);

        return null;
      },
    );

    // Need to check if the parameters are maxLines, textOverflow or textTransform as they are not being parsed by fromCss method, so need to insert them manually
    cssMap.forEach((key, value) {
      RegExp pattern = RegExp(r'\b(?:maxLines|textOverflow|textTransform)\b');
      bool containsMatch = value.keys.any((e) => pattern.hasMatch(e));

      if (containsMatch) {
        style[key] = style[key]!.copyWith(
          maxLines: value['maxLines'],
          textOverflow: TextOverflow.values.asNameMap()[value['textOverflow']],
          textTransform:
              TextTransform.values.asNameMap()[value['textTransform']],
        );
      }
    });

    return style;
  }
}

/// widget to render Html content
class EnsembleHtml extends StatefulWidget
    with Invokable, HasController<HtmlController, HtmlState> {
  EnsembleHtml({Key? key}) : super(key: key);

  static const type = 'Html';

  final HtmlController _controller = HtmlController();

  @override
  HtmlController get controller => _controller;

  @override
  HtmlState createState() => HtmlState();

  @override
  Map<String, Function> getters() {
    return {'text': () => _controller.text};
  }

  @override
  Map<String, Function> methods() {
    return {
      // Updates the max lines for a given selector. Takes two attributes as selector and maxLines
      'updateMaxLines': controller.htmlAction!.updateMaxLines,
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'text': (newValue) => _controller.text = Utils.optionalString(newValue),
      'onLinkTap': (funcDefinition) => _controller.onLinkTap =
          ensemble.EnsembleAction.from(funcDefinition, initiator: this),
      'cssStyles': (value) {
        _controller.cssStyle = CSSStyle.fromYaml(
          Utils.getListOfMap(value) ?? [],
        );
      },
    };
  }
}

class HtmlController extends BoxController {
  CSSStyle? cssStyle;
  ensemble.EnsembleAction? onLinkTap;
  String? text;

  // Added action so it becomes easy to add additional methods in future
  HtmlAction? htmlAction;
}

mixin HtmlAction on framework.EWidgetState<EnsembleHtml> {
  void updateMaxLines(String selector, int maxLines);
}

class HtmlState extends framework.EWidgetState<EnsembleHtml> with HtmlAction {
  @override
  void updateMaxLines(String selector, int maxLines) {
    // Need to add it here to be able to do setState
    setState(() {
      widget.controller.cssStyle?.updateMaxLines(selector, maxLines);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    widget.controller.htmlAction = this;
  }

  @override
  void didUpdateWidget(covariant EnsembleHtml oldWidget) {
    super.didUpdateWidget(oldWidget);

    widget.controller.htmlAction = this;
  }

  @override
  Widget buildWidget(BuildContext context) {
    return BoxWrapper(
      boxController: widget._controller,
      widget: Html(
        style: widget._controller.cssStyle?.getStyle() ?? {},
        data: widget._controller.text ?? '',
        onLinkTap: ((url, attributes, element) {
          if (widget.controller.onLinkTap != null) {
            ScreenController().executeAction(
                context, widget.controller.onLinkTap!,
                event: EnsembleEvent(widget,
                    data: {'url': url, 'attributes': attributes}));
          } else if (url != null) {
            launchUrl(Uri.parse(url));
          }
        }),
      ),
    );
  }
}
