import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PopupMenu extends StatefulWidget
    with Invokable, HasController<PopupMenuController, PopupMenuState> {
  static const type = "PopupMenu";
  PopupMenu({Key? key}) : super(key: key);

  final PopupMenuController _controller = PopupMenuController();
  @override
  PopupMenuController get controller => _controller;

  @override
  State<StatefulWidget> createState() => PopupMenuState();

  @override
  Map<String, Function> setters() {
    return {
      'widget': (widgetDef) => _controller.widgetDef = widgetDef,
      'onItemSelect': (action) => _controller.onItemSelect =
          EnsembleAction.from(action, initiator: this),
      'items': (input) =>
          _controller.items = _getItems(input) ?? _controller.items,
    };
  }

  List<PopupMenuItem>? _getItems(dynamic input) {
    List<PopupMenuItem>? items;
    if (input is List) {
      items = [];
      for (var element in input) {
        if (element is Map) {
          items.add(PopupMenuItem(
              label: Utils.getString(element['label'], fallback: ''),
              value: element['value']));
        } else {
          items.add(PopupMenuItem(label: element.toString()));
        }
      }
    }
    return items;
  }

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }
}

class PopupMenuController extends WidgetController {
  dynamic widgetDef;
  EnsembleAction? onItemSelect;
  List<PopupMenuItem> items = [];
}

class PopupMenuState extends WidgetState<PopupMenu> {
  late Widget anchorWidget;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // build the anchor widget
    var w = DataScopeWidget.getScope(context)
        ?.buildWidgetFromDefinition(widget._controller.widgetDef);
    if (w == null) {
      throw LanguageError('PopupMenu requires a widget to render the anchor.');
    }
    anchorWidget = w;
  }

  @override
  Widget buildWidget(BuildContext context) {
    return MenuAnchor(
        builder: (context, controller, child) => TapOverlay(
            widget: anchorWidget,
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            }),
        menuChildren: List<MenuItemButton>.generate(
            widget._controller.items.length,
            (index) => MenuItemButton(
                onPressed: widget._controller.onItemSelect != null
                    ? () => onItemSelect(widget._controller.items[index])
                    : null,
                child: Text(widget._controller.items[index].label))));
  }

  void onItemSelect(PopupMenuItem item) {
    ScreenController().executeAction(context, widget._controller.onItemSelect!,
        event:
            EnsembleEvent(widget, data: {'value': item.value ?? item.label}));
  }
}

class PopupMenuItem {
  PopupMenuItem({required this.label, this.value});

  final String label;
  final dynamic value;
}
