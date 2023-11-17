import 'package:change_case/change_case.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart' as framework;
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:ensemble/framework/action.dart' as ensemble;
import 'package:yaml/yaml.dart';

class CSSStyle {
  // Map<String, Style> css;
  StringBuffer css;

  CSSStyle._({required this.css});

  factory CSSStyle.fromYaml(List<YamlMap> yaml) {
    final Map<String, Map<String, dynamic>> _css = {};
    final List<MapEntry<String, Map<String, dynamic>>> valuesToAdd = [];
    final _cssBuffer = StringBuffer();

    for (final entity in yaml) {
      final map = Utils.getMap(entity['style']);

      valuesToAdd.add(
        MapEntry(
          map?['selector'],
          Utils.getMap(map?['properties']) ?? {},
        ),
      );
    }

    _css.addEntries(valuesToAdd);
    _css.forEach((key, value) {
      _cssBuffer.write('$key: {\n');
      value.forEach((key, value) {
        _cssBuffer.write('  ${key.toParamCase()}: $value;\n');
      });
      _cssBuffer.write('}\n\n');
    });

    print(_cssBuffer);

    final style = Style.fromCss(
      _cssBuffer.toString(),
      (css, errors) {
        print(errors);
        print(css);

        return null;
      },  
    );

    print(style);

    return CSSStyle._(css: _cssBuffer);
  }

  // MapEntry<String, Style> parseStyle() {
  //   return MapEntry(
  //     selector,
  //     properties.parseProperties(),
  //   );
  // }
}

/// widget to render Html content
class EnsembleHtml extends StatefulWidget
    with Invokable, HasController<HtmlController, HtmlState> {
  static const type = 'Html';
  EnsembleHtml({Key? key}) : super(key: key);

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
  Map<String, Function> setters() {
    return {
      'text': (newValue) => _controller.text = Utils.optionalString(newValue),
      'onLinkTap': (funcDefinition) => _controller.onLinkTap =
          ensemble.EnsembleAction.fromYaml(funcDefinition, initiator: this),
      'cssStyles': (value) {
        _controller.styles =
            CSSStyle.fromYaml(Utils.getListOfYamlMap(value) ?? []);
      },
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }
}

class HtmlController extends BoxController {
  String? text;
  ensemble.EnsembleAction? onLinkTap;

  CSSStyle? styles;
}

class HtmlState extends framework.WidgetState<EnsembleHtml> {
  @override
  Widget buildWidget(BuildContext context) {
    return BoxWrapper(
      boxController: widget._controller,
      widget: Html(
        style: Style.fromCss(
          widget._controller.styles?.css.toString() ?? '',
          (css, errors) {
            print(errors);
            print(css);

            return null;
          },
        ),
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
