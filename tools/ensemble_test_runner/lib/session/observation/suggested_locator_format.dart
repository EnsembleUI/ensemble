import 'package:ensemble_test_runner/session/actions/test_action.dart';

/// Compact YAML-mappable form of an [ElementLocator] for inspect-ui text.
///
/// Kept free of Flutter imports so the CLI (`dart run`) can format observe
/// output without loading `dart:ui`.
String formatSuggestedSelector(ElementLocator locator) {
  if (locator.id != null && locator.id!.trim().isNotEmpty) {
    return 'id=${locator.id!.trim()}';
  }
  final parts = <String>[];
  final label = locator.label?.trim();
  if (label != null && label.isNotEmpty) {
    parts.add('label="${label.replaceAll('"', r'\"')}"');
  }
  final text = locator.text?.trim();
  if (text != null && text.isNotEmpty) {
    parts.add('text="${text.replaceAll('"', r'\"')}"');
  }
  final role = locator.role?.trim();
  if (role != null && role.isNotEmpty) {
    parts.add('role=$role');
  }
  return parts.join(', ');
}
