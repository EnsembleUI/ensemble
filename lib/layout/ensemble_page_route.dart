import 'package:flutter/material.dart';

class EnsemblePageRoute extends MaterialPageRoute {
  EnsemblePageRoute({
    required builder,
    this.replace=false}) : super(builder:builder);

  final bool replace;

  @override
  Duration get transitionDuration => Duration(milliseconds: (replace ? 0 : 300));

}