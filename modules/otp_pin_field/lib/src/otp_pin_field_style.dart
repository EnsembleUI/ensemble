import 'package:flutter/material.dart';

class OtpPinFieldStyle {
  final TextStyle textStyle;
  final double fieldPadding;
  final Color activeFieldBackgroundColor;
  final Color defaultFieldBackgroundColor;
  final Color activeFieldBorderColor;
  final Color defaultFieldBorderColor;
  final Color filledFieldBackgroundColor;
  final Color filledFieldBorderColor;
  final double fieldBorderRadius;
  final double fieldBorderWidth;

  const OtpPinFieldStyle({
    this.textStyle = const TextStyle(fontSize: 18.0, color: Colors.black),
    this.activeFieldBorderColor = Colors.black,
    this.defaultFieldBorderColor = Colors.black45,
    this.activeFieldBackgroundColor = Colors.transparent,
    this.defaultFieldBackgroundColor = Colors.transparent,
    this.filledFieldBackgroundColor = Colors.transparent,
    this.filledFieldBorderColor = Colors.transparent,
    this.fieldPadding = 10.0,
    this.fieldBorderRadius = 2.0,
    this.fieldBorderWidth = 2.0,
  });
}
