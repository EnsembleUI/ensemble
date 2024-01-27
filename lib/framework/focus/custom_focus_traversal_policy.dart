import 'package:flutter/cupertino.dart';

/// A traversal policy that is designed for managing horizontal focusable widgets (e.g. Carousel / Row)
/// 1. Left/Right traversal will be trapped within this group (stop at index "0" and index "length-1")
/// 2. Up/Down will delegate to the default traversal magic
class HorizontalFocusTraversalPolicy extends FocusTraversalPolicy
    with DirectionalFocusTraversalPolicyMixin {

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    if (direction == TraversalDirection.left ||
        direction == TraversalDirection.right) {
      return _inDirectionHorizontal(currentNode, direction);
    }
    return _inDirectionVertical(currentNode, direction);
  }

  bool _inDirectionVertical(FocusNode currentNode, TraversalDirection direction) {
    /// haven't look too deep into the logic, but the default scope data optimization
    /// doesn't really work. In fact it sometimes cause the up/down button to
    /// be skipped (tried to focus on the previously focused code)
    /// Disable it for now.
    if (currentNode.nearestScope != null) {
      invalidateScopeData(currentNode.nearestScope!);
    }
    return super.inDirection(currentNode, direction);
  }

  bool _inDirectionHorizontal(FocusNode currentNode, TraversalDirection direction) {
    final FocusNode? nextNode = _findNextHorizontalFocusNode(currentNode, direction);
    if (nextNode != null) {
      // use the default focus callback to focus and scroll as needed
      requestFocusCallback(
        nextNode,
        alignmentPolicy: direction == TraversalDirection.left
            ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
            : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      return true;
    }
    return false;
  }

  /// Travel to our nearest FocusTraversalGroup to find the focusable widgets
  /// within this group only (vs default logic of all focusable widgets)
  FocusNode? _findNextHorizontalFocusNode(
      FocusNode currentNode, TraversalDirection direction) {
    if (direction != TraversalDirection.left &&
        direction != TraversalDirection.right) return null;

    for (var traversalGroup in currentNode.ancestors) {
      traversalGroup.traversalChildren;
    }


    List<FocusNode> focusableNodes =
        currentNode.ancestors.first.traversalChildren.toList(growable: false);
    int currentNodeIndex = focusableNodes.indexOf(currentNode);
    int nextIndex = direction == TraversalDirection.left
        ? currentNodeIndex - 1
        : currentNodeIndex + 1;
    if (nextIndex >= 0 && nextIndex < focusableNodes.length) {
      return focusableNodes[nextIndex];
    }
    return null;
  }

  bool inVerticalDirection(
      FocusNode currentNode, TraversalDirection direction) {

    return currentNode.ancestors.first.ancestors.first.focusInDirection(direction);

  }

  @override
  Iterable<FocusNode> sortDescendants(
      Iterable<FocusNode> descendants, FocusNode currentNode) {
    return descendants;
  }
}
