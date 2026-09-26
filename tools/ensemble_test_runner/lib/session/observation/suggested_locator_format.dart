import 'package:ensemble_test_runner/session/actions/test_action.dart';

/// Compact YAML-mappable form of an [ElementLocator] for inspect-ui text.
///
/// Kept free of Flutter imports so the CLI (`dart run`) can format observe
/// output without loading `dart:ui`.
String formatSuggestedSelector(ElementLocator locator) {
  final parts = <String>[];
  if (locator.id != null && locator.id!.trim().isNotEmpty) {
    parts.add('id=${locator.id!.trim()}');
  }
  final within = locator.within;
  if (within != null && !within.isEmpty) {
    parts.add('within={${formatSuggestedSelector(within)}}');
  }
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
  final occurrence = locator.occurrence;
  if (occurrence != null) {
    parts.add('occurrence=$occurrence');
  }
  if (locator.bounds != null) {
    parts.add('bounds=${locator.bounds!.toJson()}');
  }
  return parts.join(', ');
}
