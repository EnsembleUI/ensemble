import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

class EnsembleGestureDetector extends StatefulWidget
    with
        HasController<EnsembleGestureController,
            _EnsembleGestureDetectorState> {
  EnsembleGestureDetector({
    super.key,
    required this.child,
    required this.onTap,
  });

  final dynamic child;
  final VoidCallback onTap;

  @override
  State<EnsembleGestureDetector> createState() =>
      _EnsembleGestureDetectorState();

  final EnsembleGestureController _controller = EnsembleGestureController();
  @override
  EnsembleGestureController get controller => _controller;
}

class _EnsembleGestureDetectorState
    extends WidgetState<EnsembleGestureDetector> {
  @override
  Widget buildWidget(BuildContext context) {
    return GestureDetector(
      child: widget.child,
      onTap: widget.onTap,
    );
  }
}

class EnsembleGestureController extends WidgetController {}
