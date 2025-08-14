import 'package:flutter/material.dart';

/// Utility class to safely handle text selection operations
/// This prevents the common Flutter error: 'attached': is not true
class TextSelectionHelper {
  /// Safely sets a collapsed text selection
  static bool safeSetCollapsedSelection(
    TextEditingController controller,
    int offset, {
    bool checkMounted = true,
    bool usePostFrame = false,
  }) {
    try {
      // Basic validation
      if (controller.text.isEmpty ||
          offset < 0 ||
          offset > controller.text.length) {
        return false;
      }

      // Check if controller is valid
      if (!controller.hasListeners) {
        return false;
      }

      // Set selection immediately or defer to post frame
      if (usePostFrame) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _setSelectionSafely(controller, offset);
        });
        return true;
      } else {
        return _setSelectionSafely(controller, offset);
      }
    } catch (e) {
      debugPrint('TextSelectionHelper: Failed to set collapsed selection: $e');
      return false;
    }
  }

  /// Safely sets a text selection from position
  static bool safeSetSelectionFromPosition(
    TextEditingController controller,
    int offset, {
    bool checkMounted = true,
    bool usePostFrame = false,
  }) {
    try {
      // Basic validation
      if (controller.text.isEmpty ||
          offset < 0 ||
          offset > controller.text.length) {
        return false;
      }

      // Check if controller is valid
      if (!controller.hasListeners) {
        return false;
      }

      // Set selection immediately or defer to post frame
      if (usePostFrame) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _setSelectionFromPositionSafely(controller, offset);
        });
        return true;
      } else {
        return _setSelectionFromPositionSafely(controller, offset);
      }
    } catch (e) {
      debugPrint(
          'TextSelectionHelper: Failed to set selection from position: $e');
      return false;
    }
  }

  /// Safely preserves cursor position during text changes
  static bool safePreserveCursor(
    TextEditingController controller, {
    bool checkMounted = true,
    bool usePostFrame = false,
  }) {
    try {
      if (controller.text.isEmpty) {
        return false;
      }

      final currentSelection = controller.selection;
      if (!currentSelection.isValid) {
        return false;
      }

      final offset = currentSelection.baseOffset;
      if (offset < 0 || offset > controller.text.length) {
        return false;
      }

      // Use post frame callback to ensure widget is fully built
      if (usePostFrame) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _setSelectionFromPositionSafely(controller, offset);
        });
        return true;
      } else {
        return _setSelectionFromPositionSafely(controller, offset);
      }
    } catch (e) {
      debugPrint('TextSelectionHelper: Failed to preserve cursor: $e');
      return false;
    }
  }

  /// Internal method to safely set collapsed selection
  static bool _setSelectionSafely(
      TextEditingController controller, int offset) {
    try {
      if (controller.text.isNotEmpty && offset <= controller.text.length) {
        controller.selection = TextSelection.collapsed(offset: offset);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('TextSelectionHelper: Internal selection failed: $e');
      return false;
    }
  }

  /// Internal method to safely set selection from position
  static bool _setSelectionFromPositionSafely(
      TextEditingController controller, int offset) {
    try {
      if (controller.text.isNotEmpty && offset <= controller.text.length) {
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: offset),
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('TextSelectionHelper: Internal position selection failed: $e');
      return false;
    }
  }

  /// Validates if a text selection operation is safe to perform
  static bool isSelectionSafe(
    TextEditingController controller,
    int offset, {
    bool checkMounted = true,
  }) {
    try {
      return controller.text.isNotEmpty &&
          offset >= 0 &&
          offset <= controller.text.length &&
          controller.hasListeners;
    } catch (e) {
      return false;
    }
  }
}
