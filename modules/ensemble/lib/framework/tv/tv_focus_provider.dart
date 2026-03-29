import 'package:flutter/material.dart';

/// Abstract interface for TV focus navigation systems.
///
/// This allows Ensemble to integrate with a host app's focus system
/// (e.g., flutter_pca's PageFocusWidget) instead of using its own.
///
/// When a host app provides a [TVFocusProvider], Ensemble widgets will use
/// the host's focus system, enabling seamless D-pad navigation between
/// host app content and Ensemble content.
///
/// ## Why This Exists
///
/// When Ensemble is embedded in a host app (like flutter_pca), both apps have
/// their own TV focus systems. Without integration, they operate as separate
/// grids with no way to navigate between them.
///
/// By providing a [TVFocusProvider], the host app can:
/// 1. Register Ensemble widgets in its own focus grid
/// 2. Enable seamless UP/DOWN/LEFT/RIGHT navigation across the entire app
/// 3. Maintain a single source of truth for focus state
///
/// ## Usage in Host App
///
/// ```dart
/// // 1. Create your provider implementation
/// class MyFocusProvider implements TVFocusProvider {
///   @override
///   Widget wrapFocusable({
///     required double row,
///     required double order,
///     required Widget child,
///     bool isRowEntryPoint = false,
///     KeyEventResult Function(FocusNode)? onBackPressed,
///   }) {
///     return PageFocusWidget(
///       focusOrder: PageFocusOrder(row, order, isRowEntryPoint: isRowEntryPoint),
///       onBackPressed: onBackPressed,
///       child: child,
///     );
///   }
/// }
///
/// // 2. Provide it to Ensemble
/// EnsembleWrapper(
///   tvFocusProvider: MyFocusProvider(),
///   child: EnsembleScreen(...),
/// )
/// ```
abstract class TVFocusProvider {
  /// Creates a focusable widget wrapper with the given coordinates.
  ///
  /// Parameters:
  /// - [row]: Vertical position in the focus grid (0, 1, 2, ...)
  /// - [order]: Horizontal position within the row (0, 1, 2, ...)
  /// - [isRowEntryPoint]: If true, this is the preferred focus target when
  ///   navigating INTO this row from another row. Useful for tabs where
  ///   the selected tab should receive focus.
  /// - [child]: The widget to make focusable. Should contain an InkWell
  ///   or similar focusable widget.
  /// - [onBackPressed]: Optional callback for Android TV back button.
  ///
  /// The returned widget should:
  /// - Handle D-pad key events (UP/DOWN/LEFT/RIGHT)
  /// - Participate in the host app's focus traversal grid
  /// - Support auto-scrolling to keep focused item visible
  Widget wrapFocusable({
    required double row,
    required double order,
    required Widget child,
    bool isRowEntryPoint = false,
    KeyEventResult Function(FocusNode node)? onBackPressed,
  });

  /// Optional: Row offset for Ensemble content.
  ///
  /// Ensemble's YAML-defined `tvRow` values are relative (0, 1, 2...).
  /// This offset is added to create absolute positions in the host app's grid.
  ///
  /// Example: If host app's tab bar is at row 0, set rowOffset to 1
  /// so Ensemble content starts at row 1.
  ///
  /// Default: 0 (no offset)
  double get rowOffset => 0;

  /// Optional: Order (horizontal) offset for Ensemble content.
  ///
  /// Ensemble's YAML-defined `tvOrder` values are relative (0, 1, 2...).
  /// This offset is added to create absolute positions in the host app's grid.
  ///
  /// Example: If Sports tab is at order 5, set orderOffset to 5
  /// so navigating UP from Ensemble naturally lands on the Sports tab.
  ///
  /// Default: 0 (no offset)
  double get orderOffset => 0;

  // ─────────────────────────────────────────────────────────────────────────
  // TV Focus Styling (optional overrides from host app)
  // Priority: Ensemble Theme > Provider > Default fallback
  // ─────────────────────────────────────────────────────────────────────────

  /// Optional: Focus indicator border color.
  ///
  /// When provided, overrides Ensemble's default focus color.
  /// Theme configuration takes priority over this value.
  ///
  /// Default: null (use theme or fallback to Color(0xFF00E676))
  Color? get focusColor => null;

  /// Optional: Focus indicator border width.
  ///
  /// When provided, overrides Ensemble's default border width.
  /// Theme configuration takes priority over this value.
  ///
  /// Default: null (use theme or fallback to 3.0)
  double? get focusBorderWidth => null;

  /// Optional: Focus indicator border radius.
  ///
  /// When provided, overrides Ensemble's default border radius.
  /// Theme configuration takes priority over this value.
  ///
  /// Default: null (use theme or fallback to 8.0)
  double? get focusBorderRadius => null;

  /// Optional: Focus animation duration in milliseconds.
  ///
  /// When provided, overrides Ensemble's default animation duration.
  /// Theme configuration takes priority over this value.
  ///
  /// Default: null (use theme or fallback to 150ms)
  int? get focusAnimationDurationMs => null;

  /// Whether the host app handles horizontal scrolling for focused items.
  ///
  /// When true, Ensemble will skip its horizontal scroll logic and let
  /// the host app manage scrolling. This prevents double-scrolling when
  /// both systems try to scroll the same content.
  ///
  /// Default: false (Ensemble handles horizontal scrolling)
  bool get handlesHorizontalScroll => false;

  /// Disposes any resources held by this provider.
  void dispose() {}
}

/// InheritedWidget that provides [TVFocusProvider] to the widget tree.
///
/// Ensemble widgets look up this provider to determine how to handle TV focus.
/// If not found, they use Ensemble's built-in [TVFocusWidget].
class TVFocusProviderScope extends InheritedWidget {
  const TVFocusProviderScope({
    super.key,
    required this.provider,
    required super.child,
  });

  final TVFocusProvider provider;

  /// Get the provider from the widget tree, or null if not provided.
  static TVFocusProvider? of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<TVFocusProviderScope>();
    return scope?.provider;
  }

  /// Get provider without registering dependency (for one-time lookups).
  static TVFocusProvider? maybeOf(BuildContext context) {
    final scope =
        context.getInheritedWidgetOfExactType<TVFocusProviderScope>();
    return scope?.provider;
  }

  @override
  bool updateShouldNotify(TVFocusProviderScope oldWidget) {
    return provider != oldWidget.provider;
  }
}
