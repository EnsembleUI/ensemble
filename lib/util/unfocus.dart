import 'package:flutter/material.dart';

/// [Unfocus] - A gesture detector widget
///
/// It hides the keyboard when tapping outside of non intractive widgetss
class Unfocus extends StatelessWidget {
  const Unfocus({
    Key? key,
    required this.child,
  }) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
