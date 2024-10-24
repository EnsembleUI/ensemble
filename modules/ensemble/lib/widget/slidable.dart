import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/widget/icon.dart' as iconframework;

class EnsembleSlidable extends StatefulWidget
    with
        Invokable,
        HasController<EnsembleSlidableController, EnsembleSlidableState> {
  static const type = 'Slidable';

  EnsembleSlidable({Key? key}) : super(key: key);

  final EnsembleSlidableController _controller = EnsembleSlidableController();

  @override
  EnsembleSlidableController get controller => _controller;

  @override
  State<StatefulWidget> createState() => EnsembleSlidableState();

  @override
  Map<String, Function> getters() {
    return {
      'startDrawer': () => _controller.startDrawer,
      'endDrawer': () => _controller.endDrawer,
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'groupTag': (value) => _controller.groupTag = value,
      'enabled': (value) =>
          _controller.enabled = Utils.getBool(value, fallback: true),
      'closeOnScroll': (value) =>
          _controller.closeOnScroll = Utils.getBool(value, fallback: true),
      'direction': (value) =>
          _controller.direction = Axis.values.from(value) ?? Axis.horizontal,
      'dragStartBehavior': (value) => _controller.dragStartBehavior =
          DragStartBehavior.values.from(value) ?? DragStartBehavior.down,
      'useTextDirection': (value) =>
          _controller.useTextDirection = Utils.getBool(value, fallback: true),
      'startDrawer': (value) => _controller.startDrawer =
          SlidableDrawerComposite.from(_controller, value),
      'endDrawer': (value) => _controller.endDrawer =
          SlidableDrawerComposite.from(_controller, value),
      'child': (value) => _controller.child = value,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }
}

class EnsembleSlidableController extends BoxController {
  String? groupTag;
  bool enabled = true;
  bool closeOnScroll = true;
  Axis? direction;
  DragStartBehavior? dragStartBehavior;
  bool useTextDirection = true;

  SlidableDrawerComposite? _startDrawer;
  SlidableDrawerComposite? _endDrawer;

  SlidableDrawerComposite get startDrawer =>
      _startDrawer ??= SlidableDrawerComposite(this);
  SlidableDrawerComposite get endDrawer =>
      _endDrawer ??= SlidableDrawerComposite(this);

  set startDrawer(SlidableDrawerComposite? drawer) => _startDrawer = drawer;
  set endDrawer(SlidableDrawerComposite? drawer) => _endDrawer = drawer;

  dynamic child;
}

class EnsembleSlidableState extends EWidgetState<EnsembleSlidable> {
  @override
  Widget buildWidget(BuildContext context) {
    return Slidable(
      groupTag: widget.controller.groupTag,
      enabled: widget.controller.enabled,
      closeOnScroll: widget.controller.closeOnScroll,
      direction: widget.controller.direction ?? Axis.horizontal,
      dragStartBehavior:
          widget.controller.dragStartBehavior ?? DragStartBehavior.down,
      useTextDirection: widget.controller.useTextDirection,
      startActionPane: _buildActionPane(context, widget.controller.startDrawer),
      endActionPane: _buildActionPane(context, widget.controller.endDrawer),
      child: _buildChildWidget(context, widget.controller.child),
    );
  }

  ActionPane? _buildActionPane(
      BuildContext context, SlidableDrawerComposite? drawerComposite) {
    if (drawerComposite == null || drawerComposite.children.isEmpty)
      return null;

    ActionPaneOptionsComposite options = drawerComposite.options;
    List<Widget> children =
        _buildSlidableActions(context, drawerComposite.children);

    return ActionPane(
      extentRatio: options.extentRatio,
      motion: options.getMotion(),
      openThreshold: options.openThreshold,
      closeThreshold: options.closeThreshold,
      children: children,
    );
  }

  List<Widget> _buildSlidableActions(
      BuildContext context, List<dynamic> actionsDefinition) {
    if (actionsDefinition.isEmpty) return [];
    return actionsDefinition.map<Widget>((action) {
      final IconData? icon = _getIconData(action['icon']);
      final String? label = action['label'];

      // Ensure at least one of icon or label is provided
      if (icon == null && (label == null || label.isEmpty)) {
        return const SizedBox
            .shrink(); // Return an empty widget if both are missing
      }

      return SlidableAction(
        onPressed: (context) {
          if (action['onTap'] != null) {
            final onPressedAction =
                EnsembleAction.from(action['onTap'], initiator: widget);
            if (onPressedAction != null) {
              ScreenController().executeAction(
                context,
                onPressedAction,
                event: EnsembleEvent(widget),
              );
            } else {
              debugPrint('Warning: Failed to create action from onTap handler');
            }
          }
        },
        backgroundColor:
            Utils.getColor(action['backgroundColor']) ?? Colors.blue,
        foregroundColor:
            Utils.getColor(action['foregroundColor']) ?? Colors.white,
        icon: icon,
        label: label,
        padding: Utils.getInsets(action['padding'],
            fallback: const EdgeInsets.all(0)),
        spacing: Utils.getDouble(action['spacing'], fallback: 4.0),
        autoClose: Utils.getBool(action['autoClose'], fallback: true),
        flex: Utils.getInt(action['flex'], fallback: 1),
        borderRadius:
            Utils.getBorderRadius(action['borderRadius'])?.getValue() ??
                BorderRadius.zero,
      );
    }).toList();
  }

  IconData? _getIconData(dynamic value) {
    if (value == null) return null;

    IconModel? iconModel = Utils.getIcon(value);
    if (iconModel != null) {
      return iconframework.Icon(
        iconModel.icon,
        library: iconModel.library,
        size: iconModel.size,
        color: iconModel.color,
      ).icon;
    }

    return iconframework.Icon(value).icon;
  }

  Widget _buildChildWidget(BuildContext context, dynamic widgetDefinition) {
    if (widgetDefinition == null) {
      return const SizedBox.shrink();
    }
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    if (scopeManager != null) {
      return scopeManager.buildWidgetFromDefinition(widgetDefinition);
    } else {
      throw LanguageError('Failed to build widget');
    }
  }
}

class ActionPaneOptionsComposite extends WidgetCompositeProperty {
  ActionPaneOptionsComposite(ChangeNotifier widgetController)
      : super(widgetController);

  double extentRatio = 0.25;
  String motion = 'scroll';
  double? openThreshold;
  double? closeThreshold;

  factory ActionPaneOptionsComposite.from(
      ChangeNotifier widgetController, dynamic payload) {
    ActionPaneOptionsComposite composite =
        ActionPaneOptionsComposite(widgetController);
    if (payload is Map) {
      composite.extentRatio =
          Utils.getDouble(payload['extentRatio'], fallback: 0.25);
      composite.motion = Utils.optionalString(payload['motion']) ?? 'scroll';
      composite.openThreshold = Utils.optionalDouble(payload['openThreshold']);
      composite.closeThreshold =
          Utils.optionalDouble(payload['closeThreshold']);
    }
    return composite;
  }

  @override
  Map<String, Function> setters() => {
        'extentRatio': (value) =>
            extentRatio = Utils.getDouble(value, fallback: 0.25),
        'motion': (value) =>
            motion = Utils.getString(value, fallback: 'scroll'),
        'openThreshold': (value) => openThreshold = Utils.optionalDouble(value),
        'closeThreshold': (value) =>
            closeThreshold = Utils.optionalDouble(value),
      };

  @override
  Map<String, Function> getters() => {
        'extentRatio': () => extentRatio,
        'motion': () => motion,
        'openThreshold': () => openThreshold,
        'closeThreshold': () => closeThreshold,
      };

  Widget getMotion() {
    switch (motion) {
      case 'scroll':
        return const ScrollMotion();
      case 'stretch':
        return const StretchMotion();
      case 'behind':
        return const BehindMotion();
      case 'drawer':
        return const DrawerMotion();
      default:
        return const ScrollMotion();
    }
  }

  @override
  Map<String, Function> methods() => {};
}

class SlidableDrawerComposite extends WidgetCompositeProperty {
  SlidableDrawerComposite(ChangeNotifier widgetController)
      : super(widgetController);

  ActionPaneOptionsComposite? _options;
  ActionPaneOptionsComposite get options =>
      _options ??= ActionPaneOptionsComposite(widgetController);
  set options(ActionPaneOptionsComposite value) => _options = value;

  List<dynamic> children = [];

  factory SlidableDrawerComposite.from(
      ChangeNotifier widgetController, dynamic payload) {
    SlidableDrawerComposite composite =
        SlidableDrawerComposite(widgetController);
    if (payload is Map) {
      if (payload['options'] != null) {
        composite.options = ActionPaneOptionsComposite.from(
            widgetController, payload['options']);
      }
      if (payload['children'] != null) {
        composite.children = List.from(payload['children']);
      }
    }
    return composite;
  }

  @override
  Map<String, Function> setters() => {
        'options': (value) =>
            options = ActionPaneOptionsComposite.from(widgetController, value),
        'children': (value) => children = List.from(value),
      };

  @override
  Map<String, Function> getters() => {
        'options': () => options,
        'children': () => children,
      };

  @override
  Map<String, Function> methods() => {};
}
