import 'package:flutter_test/flutter_test.dart';
import 'package:js_widget/src/mobile/webview_debug_policy.dart';

void main() {
  group('androidWebViewDebuggingEnabledForBuild', () {
    test('disables debugging for release/profile builds', () {
      expect(androidWebViewDebuggingEnabledForBuild(isDebugBuild: false),
          isFalse);
    });

    test('allows debugging only for debug builds', () {
      expect(
          androidWebViewDebuggingEnabledForBuild(isDebugBuild: true), isTrue);
    });
  });
}
