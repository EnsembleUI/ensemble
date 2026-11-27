import 'package:ensemble/framework/tv/apple_tv.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Lets the Siri Remote Menu button reach `goBack` key handlers on Apple TV.
///
/// On Android TV, Back first arrives as a `goBack` key press (down, then up).
/// If no widget handles the key-up, the system Back follows and pops the
/// route. On tvOS, flutter-tvos sends Menu only as a system Back
/// (`popRoute`), so `goBack` key handlers never run.
///
/// On Menu, this bridge first sends a `goBack` key press through the normal
/// key dispatch (focused widget, then its ancestors). If the key-up is
/// handled, Menu stops there. Otherwise the system Back goes ahead as before.
/// This is the same order as on Android TV.
///
/// Call [install] before `runApp`: Flutter asks Back listeners in the order
/// they were registered, and the app's own Navigator listener is registered
/// when the app is built. Does nothing outside Apple TV.
class AppleTVBackBridge with WidgetsBindingObserver {
  AppleTVBackBridge._();

  static AppleTVBackBridge? _instance;

  // There's no physical Back key on the Siri Remote. Any key works as long as
  // the down and up use the same one, so the pressed-key state stays balanced.
  static const _physicalKey = PhysicalKeyboardKey.browserBack;

  /// Registers the bridge. Safe to call more than once.
  static void install() {
    if (!isAppleTV || _instance != null) return;
    _instance = AppleTVBackBridge._();
    WidgetsBinding.instance.addObserver(_instance!);
  }

  @visibleForTesting
  static void debugUninstall() {
    final instance = _instance;
    if (instance == null) return;
    WidgetsBinding.instance.removeObserver(instance);
    _instance = null;
  }

  @override
  Future<bool> didPopRoute() async => dispatchBackKey();

  /// Sends a `goBack` key press to the focused widget and its ancestors.
  /// Returns true when the key-up was handled, so the system Back is skipped.
  @visibleForTesting
  static bool dispatchBackKey() {
    if (FocusManager.instance.primaryFocus == null) return false;
    final timeStamp = Duration(
      microseconds: DateTime.now().microsecondsSinceEpoch,
    );
    _dispatch(KeyDownEvent(
      physicalKey: _physicalKey,
      logicalKey: LogicalKeyboardKey.goBack,
      timeStamp: timeStamp,
    ));
    return _dispatch(KeyUpEvent(
      physicalKey: _physicalKey,
      logicalKey: LogicalKeyboardKey.goBack,
      timeStamp: timeStamp,
    ));
  }

  /// Dispatches [event] the way the engine's key events are dispatched:
  /// [HardwareKeyboard] handlers first, then the focus tree.
  static bool _dispatch(KeyEvent event) {
    final handledByKeyboard = HardwareKeyboard.instance.handleKeyEvent(event);
    // KeyMessage is how the focus tree receives key events today; there is no
    // other public entry point that runs the full focus dispatch. Revisit when
    // Flutter moves the FocusManager onto HardwareKeyboard.
    // ignore: deprecated_member_use
    final handler = ServicesBinding.instance.keyEventManager.keyMessageHandler;
    // ignore: deprecated_member_use
    final handledByFocus = handler?.call(KeyMessage([event], null)) ?? false;
    return handledByKeyboard || handledByFocus;
  }
}
