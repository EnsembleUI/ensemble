import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/ensemble.dart';

class ExternalWidget extends EnsembleWidget<ExternalWidgetController> {
  static const type = 'ExternalWidget';

  const ExternalWidget._(super.controller, {super.key});

  factory ExternalWidget.build([dynamic controller]) =>
      ExternalWidget._(controller is ExternalWidgetController
          ? controller
          : ExternalWidgetController());

  @override
  State<StatefulWidget> createState() => ExternalWidgetState();
}

class ExternalWidgetController extends EnsembleWidgetController {
  String name = '';
  Map<String, dynamic>? payload;
  Map<String, EnsembleAction?> events = {};

  @override
  Map<String, Function> getters() => {
        'name': () => name,
        'payload': () => payload,
        ...events.map((key, _) => MapEntry(key, () => events[key])),
      };

  @override
  Map<String, Function> setters() => Map<String, Function>.from(super.setters())
    ..addAll({
      'name': (value) => name = Utils.getString(value, fallback: ''),
      'payload': (value) => payload = Utils.getMap(value),
      'events': (value) {
        if (value is Map) {
          value.forEach((key, actionValue) {
            if (key is String) {
              events[key] = EnsembleAction.from(actionValue, initiator: this);
            }
          });
        }
      },
    });
}

class ExternalWidgetState extends EnsembleWidgetState<ExternalWidget> {
  @override
  Widget buildWidget(BuildContext context) {
    final controller = widget.controller;

    if (controller.name.isEmpty) {
      throw RuntimeError("ExternalWidget requires a 'name' property");
    }

    final builder = Ensemble().externalWidgets[controller.name];
    if (builder == null) {
      throw RuntimeError("External widget '${controller.name}' not found");
    }

    final payload = Map<String, dynamic>.from(controller.payload ?? {});

    // Add all event handlers to the payload
    // This allows the external widget to call back into Ensemble
    controller.events.forEach((eventName, action) {
      if (action != null) {
        payload[eventName] = (dynamic value) {
          if (mounted) {
            ScreenController().executeAction(
              context,
              action,
              event: EnsembleEvent(widget.controller, data: {'value': value}),
            );
          }
        };
      }
    });

    return builder(context, payload);
  }
}
