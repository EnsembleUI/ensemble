import 'package:flutter_test/flutter_test.dart';
import 'package:ensemble_test_runner/runner/event_driven_settler.dart';

/// Settles a test fixture without relying on Flutter's unbounded animation
/// scan. Two quiet turns ensure state updates scheduled by the first frame are
/// visible before the helper returns.
Future<void> pumpUntilIdle(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  await EventDrivenSettler(tester: tester).settle(timeout: timeout);
}
