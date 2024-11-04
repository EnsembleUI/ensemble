import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/material.dart';
import 'package:accordion/accordion.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:yaml/yaml.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensembleIcon;

// HeaderStyleComposite class to handle header styling
class HeaderStyleComposite extends WidgetCompositeProperty {
  HeaderStyleComposite(super.widgetController) {
    backgroundColor = this.backgroundColor;
    backgroundColorOpened = this.backgroundColorOpened;
    borderColor = this.borderColor;
    borderColorOpened = this.borderColorOpened;
    borderWidth = this.borderWidth;
    borderRadius = this.borderRadius;
    padding = this.padding;
  }

  Color? backgroundColor;
  Color? backgroundColorOpened;
  Color? borderColor;
  Color? borderColorOpened;
  double? borderWidth;
  double? borderRadius;
  EdgeInsets? padding;

  factory HeaderStyleComposite.from(WidgetController controller, dynamic payload) {
    HeaderStyleComposite composite = HeaderStyleComposite(controller);
    if (payload is Map) {
      composite.backgroundColor = Utils.getColor(payload['backgroundColor']);
      composite.backgroundColorOpened = Utils.getColor(payload['backgroundColorOpened']);
      composite.borderColor = Utils.getColor(payload['borderColor']);
      composite.borderColorOpened = Utils.getColor(payload['borderColorOpened']);
      composite.borderWidth = Utils.optionalDouble(payload['borderWidth']);
      composite.borderRadius = Utils.optionalDouble(payload['borderRadius']);
      composite.padding = Utils.optionalInsets(payload['padding']);
    }
    return composite;
  }

  @override
  Map<String, Function> setters() => {
    'backgroundColor': (value) => backgroundColor = Utils.getColor(value),
    'backgroundColorOpened': (value) => backgroundColorOpened = Utils.getColor(value),
    'borderColor': (value) => borderColor = Utils.getColor(value),
    'borderColorOpened': (value) => borderColorOpened = Utils.getColor(value),
    'borderWidth': (value) => borderWidth = Utils.optionalDouble(value),
    'borderRadius': (value) => borderRadius = Utils.optionalDouble(value),
    'padding': (value) => padding = Utils.optionalInsets(value),
  };

  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> methods() => {};
}

// BodyStyleComposite class to handle body styling
class BodyStyleComposite extends WidgetCompositeProperty {
  BodyStyleComposite(super.widgetController) {
    backgroundColor = this.backgroundColor;
    borderColor = this.borderColor;
    borderWidth = this.borderWidth;
    borderRadius = this.borderRadius;
    horizontalPadding = this.horizontalPadding;
    verticalPadding = this.verticalPadding;
  }

  Color? backgroundColor;
  Color? borderColor;
  double? borderWidth;
  double? borderRadius;
  double? horizontalPadding;
  double? verticalPadding;

  factory BodyStyleComposite.from(WidgetController controller, dynamic payload) {
    BodyStyleComposite composite = BodyStyleComposite(controller);
    if (payload is Map) {
      composite.backgroundColor = Utils.getColor(payload['backgroundColor']);
      composite.borderColor = Utils.getColor(payload['borderColor']);
      composite.borderWidth = Utils.optionalDouble(payload['borderWidth']);
      composite.borderRadius = Utils.optionalDouble(payload['borderRadius']);
      composite.horizontalPadding = Utils.optionalDouble(payload['horizontalPadding']);
      composite.verticalPadding = Utils.optionalDouble(payload['verticalPadding']);
    }
    return composite;
  }

  @override
  Map<String, Function> setters() => {
    'backgroundColor': (value) => backgroundColor = Utils.getColor(value),
    'borderColor': (value) => borderColor = Utils.getColor(value),
    'borderWidth': (value) => borderWidth = Utils.optionalDouble(value),
    'borderRadius': (value) => borderRadius = Utils.optionalDouble(value),
    'horizontalPadding': (value) => horizontalPadding = Utils.optionalDouble(value),
    'verticalPadding': (value) => verticalPadding = Utils.optionalDouble(value),
  };

  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> methods() => {};
}

class EnsembleAccordion extends StatefulWidget
    with
        Invokable,
        HasController<EnsembleAccordionController, EnsembleAccordionState> {
  static const type = 'Accordion';

  EnsembleAccordion({Key? key}) : super(key: key);

  final EnsembleAccordionController _controller = EnsembleAccordionController();

  @override
  EnsembleAccordionController get controller => _controller;

  @override
  State<StatefulWidget> createState() => EnsembleAccordionState();

  @override
  Map<String, Function> getters() {
    return {
      'openSections': () => _controller.openSections,
      'headerStyle': () => controller.headerStyle,
      'bodyStyle': () => _controller.bodyStyle,
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'items': (value) => _controller.items = List<Map>.from(value),
      'limitExpandedToOne': (value) => _controller.limitExpandedToOne = Utils.getBool(value, fallback: true),
      'initialOpeningSequenceDelay': (value) =>
          _controller.initialOpeningSequenceDelay = Utils.optionalInt(value),
      'headerStyle': (value) => _controller.headerStyle = HeaderStyleComposite.from(controller, value),
      'bodyStyle': (value) => _controller.bodyStyle = BodyStyleComposite.from(controller, value),
      'leftIcon': (value) => _controller.leftIcon = value,
      'rightIcon': (value) => _controller.rightIcon = value,
      'flipLeftIconIfOpen': (value) =>
          _controller.flipLeftIconIfOpen = Utils.optionalBool(value),
      'flipRightIconIfOpen': (value) =>
          _controller.flipRightIconIfOpen = Utils.optionalBool(value),
      'paddingListTop': (value) =>
          _controller.paddingListTop = Utils.getDouble(value, fallback: 0.0),
      'paddingListBottom': (value) =>
          _controller.paddingListBottom = Utils.getDouble(value, fallback: 0.0),
      'paddingListHorizontal': (value) => _controller.paddingListHorizontal =
          Utils.getDouble(value, fallback: 0.0),
      'paddingBetweenOpenSections': (value) =>
          _controller.paddingBetweenOpenSections = Utils.optionalDouble(value),
      'paddingBetweenClosedSections': (value) => _controller
          .paddingBetweenClosedSections = Utils.optionalDouble(value),
      'disableScrolling': (value) =>
          _controller.disableScrolling = Utils.getBool(value, fallback: false),
      'openAndCloseAnimation': (value) =>
          _controller.openAndCloseAnimation = Utils.optionalBool(value),
      'scaleWhenAnimating': (value) =>
          _controller.scaleWhenAnimating = Utils.optionalBool(value),
      'accordionId': (value) =>
          _controller.accordionId = Utils.optionalString(value),
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'openSection': (int index) => _controller.openSection(index),
      'closeSection': (int index) => _controller.closeSection(index),
    };
  }
}

class EnsembleAccordionController extends WidgetController {
  List<Map> items = [];
  bool limitExpandedToOne = true;
  int? initialOpeningSequenceDelay;
  HeaderStyleComposite? _headerStyle;
  BodyStyleComposite? _bodyStyle;

  HeaderStyleComposite get headerStyle =>
      _headerStyle ??= HeaderStyleComposite(this);

  BodyStyleComposite get bodyStyle => 
      _bodyStyle ??= BodyStyleComposite(this);
  
  set headerStyle(HeaderStyleComposite style) => _headerStyle = style;
  set bodyStyle(BodyStyleComposite style) => _bodyStyle = style;

  dynamic leftIcon;
  dynamic rightIcon;
  bool? flipLeftIconIfOpen;
  bool? flipRightIconIfOpen;
  double paddingListTop = 0.0;
  double paddingListBottom = 0.0;
  double paddingListHorizontal = 0.0;
  double? paddingBetweenOpenSections;
  double? paddingBetweenClosedSections;
  bool disableScrolling = false;
  bool? openAndCloseAnimation;
  bool? scaleWhenAnimating;
  String? accordionId;

  final ValueNotifier<List<int>> _openSections = ValueNotifier<List<int>>([]);
  List<int> get openSections => _openSections.value;

  void openSection(int index) {
    if (limitExpandedToOne) {
      _openSections.value = [index];
    } else {
      final newOpenSections = List<int>.from(_openSections.value);
      if (!newOpenSections.contains(index)) {
        newOpenSections.add(index);
      }
      _openSections.value = newOpenSections;
    }
    notifyListeners();
  }

  void closeSection(int index) {
    final newOpenSections = List<int>.from(_openSections.value);
    newOpenSections.remove(index);
    _openSections.value = newOpenSections;
    notifyListeners();
  }
}

class EnsembleAccordionState extends EWidgetState<EnsembleAccordion> {

  @override
  void initState() {
    super.initState();
    final initialOpenSections = <int>[];
    for (int i = 0; i < widget.controller.items.length; i++) {
      if (widget.controller.items[i]['isOpen'] == true) {
        initialOpenSections.add(i);
      }
    }
    widget.controller._openSections.value = initialOpenSections;
  }

  @override
  Widget buildWidget(BuildContext context) {
    return Accordion(
      maxOpenSections: widget.controller.limitExpandedToOne ? 1 : widget.controller.items.length,
      initialOpeningSequenceDelay:
          widget.controller.initialOpeningSequenceDelay ?? 0,
      headerBackgroundColor:
          widget.controller.headerStyle.backgroundColor,
      headerBackgroundColorOpened:
          widget.controller.headerStyle.backgroundColorOpened,
      headerBorderColor: widget.controller.headerStyle.borderColor,
      headerBorderColorOpened:
          widget.controller.headerStyle.borderColorOpened,
      headerBorderWidth: widget.controller.headerStyle.borderWidth ?? 1.0,
      headerBorderRadius: widget.controller.headerStyle.borderRadius ?? 0.0,
      flipLeftIconIfOpen: widget.controller.flipLeftIconIfOpen ?? false,
      flipRightIconIfOpen: widget.controller.flipRightIconIfOpen ?? true,
      contentBackgroundColor:
          widget.controller.bodyStyle.backgroundColor,
      contentBorderColor: widget.controller.bodyStyle.borderColor,
      contentBorderWidth: widget.controller.bodyStyle.borderWidth ?? 1.0,
      contentBorderRadius: widget.controller.bodyStyle.borderRadius ?? 0.0,
      contentHorizontalPadding:
          widget.controller.bodyStyle.horizontalPadding ?? 0.0,
      contentVerticalPadding: widget.controller.bodyStyle.verticalPadding ?? 0.0,
      paddingListTop: widget.controller.paddingListTop,
      paddingListBottom: widget.controller.paddingListBottom,
      paddingListHorizontal: widget.controller.paddingListHorizontal,
      headerPadding: widget.controller.headerStyle.padding ?? EdgeInsets.zero,
      paddingBetweenOpenSections:
          widget.controller.paddingBetweenOpenSections ?? 0.0,
      paddingBetweenClosedSections:
          widget.controller.paddingBetweenClosedSections ?? 0.0,
      disableScrolling: widget.controller.disableScrolling,
      openAndCloseAnimation: widget.controller.openAndCloseAnimation ?? true,
      scaleWhenAnimating: widget.controller.scaleWhenAnimating ?? true,
      leftIcon: _buildIcon(widget.controller.leftIcon),
      rightIcon: _buildIcon(widget.controller.rightIcon),
      accordionId: widget.controller.accordionId ?? 'default_accordion',
      children: List.generate(widget.controller.items.length, (index) {
        final item = widget.controller.items[index];
        final isOpen = widget.controller.openSections.contains(index);
        return AccordionSection(
          isOpen: isOpen,
          headerBackgroundColor:
              Utils.getColor(item['styles']?['headerStyle']?['backgroundColor']) ??
                  widget.controller.headerStyle.backgroundColor,
          headerBackgroundColorOpened:
              Utils.getColor(
                  item['styles']?['headerStyle']?['backgroundColorOpened']) ??
                  widget.controller.headerStyle.backgroundColorOpened,
          headerBorderColor: Utils.getColor(
                  item['styles']?['headerStyle']?['borderColor']) ??
              widget.controller.headerStyle.borderColor,
          headerBorderColorOpened: Utils.getColor(
                  item['styles']?['headerStyle']?['borderColorOpened']) ??
              widget.controller.headerStyle.borderColorOpened,
          headerBorderWidth:
              Utils.optionalDouble(item['styles']?['headerStyle']?['borderWidth']) ??
                  widget.controller.headerStyle.borderWidth,
          headerBorderRadius:
              Utils.optionalDouble(item['styles']?['headerStyle']?['borderRadius']) ??
                  widget.controller.headerStyle.borderRadius,
          headerPadding:
              Utils.optionalInsets(item['styles']?['headerStyle']?['padding']) ??
                  widget.controller.headerStyle.padding,
          contentBackgroundColor:
              Utils.getColor(item['styles']?['bodyStyle']?['backgroundColor']) ??
                  widget.controller.bodyStyle.backgroundColor,
          contentBorderColor:
              Utils.getColor(item['styles']?['bodyStyle']?['borderColor']) ??
                  widget.controller.bodyStyle.borderColor,
          contentBorderWidth:
              Utils.optionalDouble(item['styles']?['bodyStyle']?['borderWidth']) ??
                  widget.controller.bodyStyle.borderWidth,
          contentBorderRadius:
              Utils.optionalDouble(item['styles']?['bodyStyle']?['borderRadius']) ??
                  widget.controller.bodyStyle.borderRadius,
          contentHorizontalPadding:
              Utils.optionalDouble(
                      item['styles']?['bodyStyle']?['horizontalPadding']) ??
                  widget.controller.bodyStyle.horizontalPadding,
          contentVerticalPadding:
              Utils.optionalDouble(
                      item['styles']?['bodyStyle']?['verticalPadding']) ??
                  widget.controller.bodyStyle.verticalPadding,
          leftIcon: _buildIcon(item['leftIcon']) ??
              _buildIcon(widget.controller.leftIcon),
          rightIcon: _buildIcon(item['rightIcon']) ??
              _buildIcon(widget.controller.rightIcon),
          paddingBetweenOpenSections: Utils.optionalDouble(
                  item['styles']?['paddingBetweenOpenSections']) ??
              widget.controller.paddingBetweenOpenSections,
          paddingBetweenClosedSections: Utils.optionalDouble(
                  item['styles']?['paddingBetweenClosedSections']) ??
              widget.controller.paddingBetweenClosedSections,
          header: _buildChildWidget(context, item['header']) ??
              Text('Section $index'),
          content: _buildChildWidget(context, item['body']) ??
              Text('body for section $index'),
          onOpenSection: () {
            widget.controller.openSection(index);
            if (item['onOpenSection'] != null) {
              final onOpenAction = EnsembleAction.from(item['onOpenSection'], initiator: widget);
              ScreenController().executeAction(
                context,
                onOpenAction!,
                event: EnsembleEvent(widget, data: {'index': index}),
              );
            }
          },
          onCloseSection: () {
            widget.controller.closeSection(index);
            if (item['onCloseSection'] != null) {
              final onCloseAction = EnsembleAction.from(item['onCloseSection'], initiator: widget);
              ScreenController().executeAction(
                context,
                onCloseAction!,
                event: EnsembleEvent(widget, data: {'index': index}),
              );
            }
          },
        );
      }),
    );
  }

  Widget? _buildIcon(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Map && value['Icon'] != null) {
      final iconModel = Utils.getIcon(value['Icon']);
      if (iconModel != null) {
        return ensembleIcon.Icon.fromModel(iconModel);
      }
    }
    return null;
  }

  Widget? _buildChildWidget(BuildContext context, dynamic widgetDefinition) {
    if (widgetDefinition == null) {
      return null;
    }
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    if (scopeManager != null) {
      return scopeManager.buildWidgetFromDefinition(widgetDefinition);
    } else {
      throw LanguageError('Failed to build widget');
    }
  }
}