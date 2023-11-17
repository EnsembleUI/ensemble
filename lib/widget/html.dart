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

class CSSProperties {}

class CSSStyle {
  String selector;
  CSSProperties properties;

  CSSStyle._({required this.selector, required this.properties});

  factory CSSStyle.fromMap(dynamic map) {
    return CSSStyle._(
      selector: '',
      properties: CSSProperties(),
    );
  }

  Style parseStyle() {
    return Style();
  }
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
        _controller.styles = Utils //
                    .getList(value)
                ?.map((e) => CSSStyle.fromMap(Utils.getMap(e)?['style']))
                .toList() ??
            [];
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

  List<CSSStyle> styles = [];
}

class HtmlState extends framework.WidgetState<EnsembleHtml> {
  @override
  Widget buildWidget(BuildContext context) {
    return BoxWrapper(
      boxController: widget._controller,
      widget: Html(
        // style: {
        //   '#hello': Style(border: Border.all(width: 2, color: Colors.red)),
        // },
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
