import 'package:flutter/material.dart';

/// [Unfocus] - A gesture detector widget
///
/// It hides the keyboard when tapping outside of non intractive widgetss
class Unfocus extends StatelessWidget {
  const Unfocus({
    Key? key,
    required this.child,
    this.isUnfocus = true,
  }) : super(key: key);

  final Widget child;
  final bool isUnfocus;

  @override
  Widget build(BuildContext context) {
    // If false, Just return the child
    if (!isUnfocus) return child;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
