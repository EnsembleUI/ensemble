
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/cupertino.dart';




/// base controller for Column/Row
class BoxLayoutController extends BoxController {
  EnsembleAction? onTap;

  bool scrollable = false;
  bool autoFit = false;
  String? mainAxis;
  String? crossAxis;
  String? mainAxisSize;
  int? maxWidth;
  int? maxHeight;
  int? gap;

  String? fontFamily;
  int? fontSize;



  List<Widget>? children;

  // applicable to Flex container only
  String? direction;
  // applicable only for ListView
  EnsembleAction? onItemTap;
  Color? sepratorColor;
  double? sepratorWidth;
  EdgeInsets? sepratorPadding;
  int selectedItemIndex= -1;


  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> setters = super.getBaseSetters();
    setters.addAll({
      'scrollable': (value) => scrollable = Utils.getBool(value, fallback: false),
      'autoFit': (value) =>  autoFit = Utils.getBool(value, fallback: false),
      'mainAxis': (value) => mainAxis = Utils.optionalString(value),
      'crossAxis': (value) => crossAxis = Utils.optionalString(value),
      'mainAxisSize': (value) => mainAxisSize = Utils.optionalString(value),
      'maxWidth': (value) => maxWidth = Utils.optionalInt(value),
      'maxHeight': (value) => maxHeight = Utils.optionalInt(value),
      'gap': (value) => gap = Utils.optionalInt(value),

      'fontFamily': (value) => fontFamily = Utils.optionalString(value),
      'fontSize': (value) =>  fontSize = Utils.optionalInt(value),

    });
    return setters;
  }
}