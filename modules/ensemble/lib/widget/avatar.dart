import 'dart:math';

import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/colored_box_placeholder.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/model/shared_models.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/image.dart' as framework;
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/image.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

class Avatar extends EnsembleWidget<AvatarController> {
  static const type = 'Avatar';

  const Avatar._(super.controller, {super.key});

  factory Avatar.build(dynamic controller) => Avatar._(
      controller is AvatarController ? controller : AvatarController());

  @override
  State<StatefulWidget> createState() => AvatarState();
}

class AvatarController extends EnsembleBoxController {
  AvatarController() {
    clipContent = true;
  }

  String? name;
  TextStyle? nameTextStyle;

  String? source;
  BoxFit? fit;
  Color? placeholderColor;

  GroupTemplate? groupTemplate;

  AvatarVariant? variant;
  EnsembleAction? onTap;
  String? onTapHaptic;

  @override
  List<String> passthroughSetters() => ['group-template'];

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() => Map<String, Function>.from(super.setters())
    ..addAll({
      'name': (value) => name = Utils.optionalString(value),
      'nameTextStyle': (value) => nameTextStyle = Utils.getTextStyle(value),
      'source': (value) => source = Utils.optionalString(value),
      'fit': (value) => fit = Utils.getBoxFit(value),
      'placeholderColor': (value) => placeholderColor = Utils.getColor(value),
      'variant': (value) => variant = AvatarVariant.values.from(value),
      'onTap': (func) => onTap = EnsembleAction.fromYaml(func, initiator: this),
      'onTapHaptic': (value) => onTapHaptic = Utils.optionalString(value),
      'group-template': (value) => setGroupAvatar(value)
    });

  void setGroupAvatar(dynamic groupData) {
    if (groupData is! Map && groupData is! YamlMap) return;

    dynamic data = groupData['data'];
    String? name = groupData['name'];

    if (data == null || name == null) return;
    dynamic avatarMap;
    if (groupData?['template'] != null) {
      avatarMap = {'Avatar': groupData?['template'] ?? {}};
    }
    dynamic surplus;
    if (groupData?['surplus'] != null) {
      surplus = SurplusData(
        backgroundColor:
            Utils.getColor(groupData?['surplus']['backgroundColor']),
        height: Utils.optionalDouble(groupData?['surplus']['height']),
        width: Utils.optionalDouble(groupData?['surplus']['width']),
        onTap: EnsembleAction.fromYaml(groupData?['surplus']['onTap']),
        textStyle: Utils.getTextStyle(groupData?['surplus']['textStyle']),
        variant: AvatarVariant.values.from(groupData?['surplus']['variant']),
        visible:
            Utils.getBool(groupData?['surplus']['visible'], fallback: true),
      );
    }

    groupTemplate = GroupTemplate(
      data: data,
      name: name,
      max: Utils.optionalInt(groupData['max']),
      offset: Utils.getDouble(groupData['offset'], fallback: 30),
      avatarWidget: avatarMap == null ? null : YamlMap.wrap(avatarMap),
      surplusData: surplus,
    );
  }
}

class AvatarState extends EnsembleWidgetState<Avatar>
    with TemplatedWidgetState {
  static const defaultSize = 40.0;
  double? groupHeight;
  double? groupWidth;
  List<Widget> groupAvatar = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerGroupAvatarListener(context);
  }

  void _registerGroupAvatarListener(BuildContext context) {
    if (widget.controller.groupTemplate != null) {
      registerItemTemplate(
        context,
        widget.controller.groupTemplate!,
        evaluateInitialValue: true,
        onDataChanged: (dataList) {
          final avatars = _buildAvatarPayload(dataList);
          setState(() {
            groupAvatar = avatars;
          });
        },
      );
    }
  }

  List<Widget> _buildAvatarPayload(List dataList) {
    List<Widget> avatarData = [];

    GroupTemplate? itemTemplate = widget.controller.groupTemplate;
    ScopeManager? myScope = getScopeManager();
    if (myScope != null && itemTemplate != null) {
      for (dynamic dataItem in dataList) {
        ScopeManager dataScope = myScope.createChildScope();
        groupHeight = Utils.optionalDouble(
            itemTemplate.avatarWidget['Avatar']['styles']['height']);
        groupWidth = Utils.optionalDouble(
            itemTemplate.avatarWidget['Avatar']['styles']['width']);
        dataScope.dataContext.addDataContextById(itemTemplate.name, dataItem);
        final avatar = dataScope
            .buildWidgetWithScopeFromDefinition(itemTemplate.avatarWidget);
        avatarData.add(avatar);
      }
    }
    return avatarData;
  }

  @override
  Widget buildWidget(BuildContext context) {
    return widget.controller.groupTemplate == null
        ? _buildAvatar()
        : _buildGroupAvatar();
  }

  Widget _buildGroupAvatar() {
    final groupTemplate = widget.controller.groupTemplate;
    int? maxAvatars = groupTemplate?.max;
    double leftOffset = groupTemplate?.offset ?? 30.0;

    int surplusCount =
        maxAvatars == null ? 0 : max(0, groupAvatar.length - maxAvatars);

    Widget surplusBuilder() {
      return Padding(
        padding: EdgeInsets.only(
            left: maxAvatars == null
                ? min(
                    MediaQuery.of(context).size.width,
                    leftOffset * groupAvatar.length,
                  )
                : leftOffset * maxAvatars),
        child: Container(
          width: groupTemplate?.surplusData?.width ?? defaultSize,
          height: groupTemplate?.surplusData?.height ?? defaultSize,
          decoration: BoxDecoration(
            color: groupTemplate?.surplusData?.backgroundColor,
            borderRadius: _getVariantDefaultBorderRadius(
                    groupTemplate?.surplusData?.variant)
                ?.getValue(),
          ),
          child: Center(
            child: Text(
              '+$surplusCount',
              style: groupTemplate?.surplusData?.textStyle,
            ),
          ),
        ),
      );
    }

    Widget? surplus =
        groupTemplate?.surplusData?.visible == true ? surplusBuilder() : null;
    if (groupTemplate?.surplusData?.onTap != null && surplus != null) {
      surplus = InkWell(
        onTap: () {
          ScreenController().executeAction(
            context,
            groupTemplate!.surplusData!.onTap!,
            event: EnsembleEvent(widget.controller),
          );
        },
        child: surplus,
      );
    }
    final numAvatars =
        min(groupAvatar.length, maxAvatars ?? groupAvatar.length);
    final width = leftOffset * (numAvatars - 1) + (groupWidth ?? defaultSize);
    return SizedBox(
      width: surplus == null
          ? width
          : width + (groupTemplate?.surplusData?.width ?? defaultSize),
      height: groupHeight ?? defaultSize,
      child: Stack(
        children: [
          for (var i = 0; i < numAvatars; i++)
            Transform.translate(
              offset: Offset(i * leftOffset, 0),
              child: groupAvatar[i],
            ),
          if (surplusCount > 0) surplus ?? const SizedBox.shrink()
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    String? source = widget.controller.source?.trim();
    Widget content = EnsembleBoxWrapper(
        widget: source != null && source.isNotEmpty
            ? _buildImage(source)
            : _buildFallback(),
        boxController: widget.controller,
        ignoresMargin: true,
        fallbackWidth: width,
        fallbackHeight: height,
        fallbackBorderRadius: _getVariantDefaultBorderRadius());

    if (widget.controller.onTap != null) {
      content = GestureDetector(
        child: content,
        onTap: () {
          if (widget.controller.onTapHaptic != null) {
            ScreenController().executeAction(
              context,
              HapticAction(
                type: widget.controller.onTapHaptic!,
                onComplete: null,
              ),
            );
          }

          ScreenController().executeAction(context, widget.controller.onTap!,
              event: EnsembleEvent(widget.controller));
        },
      );
    }
    if (widget.controller.margin != null) {
      content = Padding(padding: widget.controller.margin!, child: content);
    }
    return content;
  }

  EBorderRadius? _getVariantDefaultBorderRadius([AvatarVariant? variant]) {
    switch (variant ?? widget.controller.variant) {
      case AvatarVariant.square:
        return null;
      case AvatarVariant.rounded:
        return EBorderRadius.all(10);
      case AvatarVariant.circle:
      default:
        return EBorderRadius.all(9999);
    }
  }

  Widget _buildImage(String source) => framework.Image(
      source: source,
      fit: widget.controller.fit,
      networkCacheManager: EnsembleImageCacheManager.instance,
      placeholderBuilder: (_, __) =>
          ColoredBoxPlaceholder(color: widget.controller.placeholderColor),
      errorBuilder: (_) => _buildFallback());

  /// build the initial or an empty box
  Widget _buildFallback() {
    String? initial;
    String? name = widget.controller.name?.trim();
    if (name != null && name.isNotEmpty) {
      List<String> tokens = name.split(RegExp(r'\s+'));
      initial = tokens[0][0].toUpperCase();
      if (tokens.length > 1) {
        initial += tokens[tokens.length - 1][0].toUpperCase();
      }
    }

    var textStyle = widget.controller.nameTextStyle ??
        TextStyle(fontSize: min(width, height) * .5);
    return initial != null
        ? Align(child: Text(initial, style: textStyle))
        : const SizedBox.shrink();
  }

  double get width =>
      (widget.controller.width ?? widget.controller.height)?.toDouble() ??
      defaultSize;

  double get height =>
      (widget.controller.height ?? widget.controller.width)?.toDouble() ??
      defaultSize;
}

enum AvatarVariant { circle, square, rounded }

class GroupTemplate extends ItemTemplate {
  GroupTemplate({
    required dynamic data,
    required String name,
    dynamic template,
    this.max,
    required this.avatarWidget,
    this.surplusData,
    this.offset = 30,
  }) : super(data, name, template);

  final int? max;
  final double offset;
  final dynamic avatarWidget;
  final SurplusData? surplusData;
}

class SurplusData {
  final Color? backgroundColor;
  final double? width;
  final double? height;
  final EnsembleAction? onTap;
  final TextStyle? textStyle;
  final AvatarVariant? variant;
  final bool visible;

  SurplusData({
    this.backgroundColor,
    this.width,
    this.height,
    this.onTap,
    this.textStyle,
    this.variant,
    this.visible = true,
  });
}
