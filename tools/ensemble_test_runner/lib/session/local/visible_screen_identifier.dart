import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble_test_runner/session/local/modal_route_lookup.dart';
import 'package:ensemble_test_runner/session/local/element_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

/// Identifies the screen that owns the visible widget tree.
///
/// Navigation services can briefly lag while a route is restored, so observer
/// snapshots should prefer the currently visible Screen widget or route
/// metadata over a cached navigation-service identifier.
String? visibleScreenIdentifier(WidgetTester tester) {
  String? visibleScreen;
  var visibleScreenDepth = -1;
  for (final element in tester.allElements) {
    if (!isUnderCurrentModalRoute(element) ||
        isUnderOffstageAncestor(element)) {
      continue;
    }
    final widget = element.widget;
    if (widget is! Screen) continue;
    final payload = widget.screenPayload;
    final name = payload?.screenName?.trim();
    final id = payload?.screenId?.trim();
    final identifier = name != null && name.isNotEmpty
        ? name
        : id != null && id.isNotEmpty
            ? id
            : null;
    if (identifier == null) continue;

    var depth = 0;
    element.visitAncestorElements((_) {
      depth++;
      return true;
    });
    // A nested screen is the most specific identifier for the visible
    // content (for example, a page inside a navigator hosted by a parent).
    if (depth > visibleScreenDepth) {
      visibleScreen = identifier;
      visibleScreenDepth = depth;
    }
  }
  if (visibleScreen != null) return visibleScreen;

  for (final element in tester.allElements) {
    if (!isUnderCurrentModalRoute(element)) continue;
    final route = modalRouteForElement(element);
    if (route == null || !route.isCurrent) continue;
    final arguments = route.settings.arguments;
    if (arguments is ScreenPayload) {
      final name = arguments.screenName?.trim();
      if (name != null && name.isNotEmpty) return name;
      final id = arguments.screenId?.trim();
      if (id != null && id.isNotEmpty) return id;
    }
    final name = route.settings.name?.trim();
    if (name != null && name.isNotEmpty && name != '/') return name;
  }
  return null;
}
