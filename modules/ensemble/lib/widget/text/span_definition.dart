import 'package:ensemble/util/utils.dart';

/// Represents a single span entry from the YAML spans list.
/// Each span is either a text span or a widget span, never both.
class SpanDefinition {
  /// For text spans
  final String? text;
  final Map<String, dynamic>? textStyle;
  final dynamic onTap;

  /// For widget spans
  final dynamic widgetDefinition;

  SpanDefinition._({
    this.text,
    this.textStyle,
    this.onTap,
    this.widgetDefinition,
  });

  bool get isTextSpan => text != null;
  bool get isWidgetSpan => widgetDefinition != null;

  /// Parse a single span entry from the YAML list.
  /// Expected formats:
  ///   - { text: "Hello", textStyle: {...}, onTap: {...} }
  ///   - { widget: { Icon: { name: info, ... } } }
  static SpanDefinition? from(dynamic entry) {
    if (entry is! Map) return null;

    if (entry.containsKey('text')) {
      return SpanDefinition._(
        text: Utils.optionalString(entry['text']),
        textStyle: entry['textStyle'] is Map
            ? Map<String, dynamic>.from(entry['textStyle'])
            : null,
        onTap: entry['onTap'],
      );
    } else if (entry.containsKey('widget')) {
      return SpanDefinition._(
        widgetDefinition: entry['widget'],
      );
    }
    return null;
  }

  /// Parse the entire spans list from raw YAML value
  static List<SpanDefinition> parseAll(dynamic rawSpans) {
    if (rawSpans is! List) return [];
    final List<SpanDefinition> result = [];
    for (final entry in rawSpans) {
      final span = SpanDefinition.from(entry);
      if (span != null) {
        result.add(span);
      }
    }
    return result;
  }
}
