import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/theme/default_theme.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/ensemble_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// managing Toast dialogs
class ToastController {
  static final FToast _toast = FToast();

  late DataContext _dataContext;
  // Singleton
  static final ToastController _instance = ToastController._internal();
  ToastController._internal() {
    //_toast.init(Utils.globalAppKey.currentContext!);
  }

  factory ToastController() {
    return _instance;
  }

  void showToast(BuildContext context, DataContext dataContext,
      ShowToastAction toastAction, Widget? customToastBody) {
    _dataContext = dataContext;
    _toast.init(context);
    _toast.removeQueuedCustomToasts();

    ToastGravity toastGravity;
    Alignment? taostAlignment = toastAction.getAlignment(_dataContext);

    if (taostAlignment == Alignment.topCenter) {
      toastGravity = ToastGravity.TOP;
    } else if (taostAlignment == Alignment.topLeft) {
      toastGravity = ToastGravity.TOP_LEFT;
    } else if (taostAlignment == Alignment.center) {
      toastGravity = ToastGravity.CENTER;
    } else if (taostAlignment == Alignment.centerLeft) {
      toastGravity = ToastGravity.CENTER_LEFT;
    } else if (taostAlignment == Alignment.centerRight) {
      toastGravity = ToastGravity.CENTER_RIGHT;
    } else if (taostAlignment == Alignment.bottomCenter) {
      toastGravity = ToastGravity.BOTTOM;
    } else if (taostAlignment == Alignment.bottomLeft) {
      toastGravity = ToastGravity.BOTTOM_LEFT;
    } else if (taostAlignment == Alignment.bottomRight) {
      toastGravity = ToastGravity.BOTTOM_RIGHT;
    } else {
      // default
      toastGravity = ToastGravity.TOP_RIGHT;
    }
    int? duration = toastAction.getDuration(_dataContext);

    _toast.showToast(
        gravity: toastGravity,
        toastDuration: duration != null
            ? Duration(seconds: duration)
            : const Duration(days: 99),
        child: getToastWidget(context, toastAction, customToastBody));
  }

  Widget getToastWidget(BuildContext context, ShowToastAction toastAction,
      Widget? customToastBody) {
    EdgeInsets padding = Utils.getInsets(toastAction.styles?['padding'],
        fallback: const EdgeInsets.symmetric(vertical: 20, horizontal: 22));
    Color? bgColor = Utils.getColor(toastAction.styles?['backgroundColor']);
    EBorderRadius? borderRadius =
        Utils.getBorderRadius(toastAction.styles?['borderRadius']);
    Color? shadowColor = Utils.getColor(toastAction.styles?['shadowColor']);
    double? shadowRadius =
        Utils.optionalDouble(toastAction.styles?['shadowRadius'], min: 0);
    Offset? shadowOffset = Utils.getOffset(toastAction.styles?['shadowOffset']);

    Widget? content = customToastBody;
    if (content == null) {
      if (toastAction.title == null && toastAction.message == null) {
        throw LanguageError(
            "${ActionType.showToast.name} requires either a title/message or a valid widget to render.");
      }
      // render the message as the body
      IconData icon;
      ToastType? toastType = toastAction.getType(_dataContext);
      if (toastType == ToastType.success) {
        icon = Icons.check_circle_outline;
        bgColor ??= DesignSystem.successBackgroundColor;
      } else if (toastType == ToastType.error) {
        icon = Icons.error_outline;
        bgColor ??= DesignSystem.errorBackgroundColor;
      } else if (toastType == ToastType.warning) {
        icon = Icons.warning;
        bgColor ??= DesignSystem.warningBackgroundColor;
      } else {
        // info by default
        icon = Icons.info;
        bgColor ??= Colors.white.withOpacity(.9);
      }

      const double closeButtonRadius = 10;

      String? message = DataScopeWidget.getScope(context)
          ?.dataContext
          .eval(toastAction.message);

      content = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon),
          const SizedBox(width: 18),
          if (message != null && message.isNotEmpty)
            Flexible(
              child: Text(
                message!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (toastAction.getDismissible(_dataContext) != false)
            InkWell(
              child: const CircleAvatar(
                backgroundColor: Colors.transparent,
                radius: closeButtonRadius,
                child: Icon(Icons.close, size: closeButtonRadius * 2 - 2),
              ),
              onTap: () => _toast.removeQueuedCustomToasts(),
            )
        ],
      );
    }

    // wrapper container for background/border...
    Widget container = Container(
        padding: padding,
        decoration: BoxDecoration(
            color: bgColor,
            borderRadius: borderRadius?.getValue() ??
                const BorderRadius.all(Radius.circular(8)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                blurStyle: BlurStyle.outer,
                color: shadowColor ?? Colors.black26,
                blurRadius: shadowRadius ?? 3,
                offset: shadowOffset ?? const Offset(0, 0),
              )
            ]),
        child: content);

    return container;
  }
}
