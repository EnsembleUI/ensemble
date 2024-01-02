import 'package:flutter/cupertino.dart';

/// use at the View root to enable SelectableText across the entire page
class HasSelectableText extends InheritedWidget {
  const HasSelectableText({super.key, required super.child});

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }
}
