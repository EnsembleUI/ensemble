import 'dart:convert';

import 'package:ensemble_test_runner/session/observation/suggested_locator_format.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';

/// Output format for `ensemble test --inspect-ui`.
enum ObserveFormat {
  text,
  json;

  static ObserveFormat parse(String? raw) {
    switch ((raw ?? 'text').trim().toLowerCase()) {
      case 'json':
        return ObserveFormat.json;
      case 'text':
      case '':
        return ObserveFormat.text;
      default:
        throw ArgumentError(
          'Unsupported --format=$raw. Use text or json.',
        );
    }
  }
}

/// Protocol markers so the CLI can extract observe output from `flutter test`
/// stdout without Flutter framework noise.
const ensembleTestObserveBegin = 'ENSEMBLE_TEST_OBSERVE_V1_BEGIN';
const ensembleTestObserveEnd = 'ENSEMBLE_TEST_OBSERVE_V1_END';

/// Formats a live [UiObservation] for developer inspection.
class ObserveFormatter {
  const ObserveFormatter();

  String format(
    UiObservation observation, {
    ObserveFormat format = ObserveFormat.text,
    String? screenshotPath,
    List<String> screenshotPaths = const [],
  }) {
    final paths = [
      ...screenshotPaths,
      if (screenshotPath != null && screenshotPath.trim().isNotEmpty)
        screenshotPath.trim(),
    ];
    switch (format) {
      case ObserveFormat.json:
        final json = Map<String, dynamic>.from(observation.toJson());
        if (paths.isNotEmpty) {
          json['screenshotPaths'] = paths;
          json['screenshotPath'] = paths.first;
        }
        return const JsonEncoder.withIndent('  ').convert(json);
      case ObserveFormat.text:
        return formatText(observation, screenshotPaths: paths);
    }
  }

  /// Prints observation between protocol markers for CLI extraction.
  void emit(
    UiObservation observation, {
    ObserveFormat format = ObserveFormat.text,
    String? screenshotPath,
    List<String> screenshotPaths = const [],
  }) {
    final body = this.format(
      observation,
      format: format,
      screenshotPath: screenshotPath,
      screenshotPaths: screenshotPaths,
    );
    print(ensembleTestObserveBegin);
    for (final line in body.split('\n')) {
      print(line);
    }
    print(ensembleTestObserveEnd);
  }

  String formatText(
    UiObservation observation, {
    String? screenshotPath,
    List<String> screenshotPaths = const [],
  }) {
    final paths = [
      ...screenshotPaths,
      if (screenshotPath != null && screenshotPath.trim().isNotEmpty)
        screenshotPath.trim(),
    ];
    final buffer = StringBuffer()
      ..writeln('Screen: ${_screenLabel(observation)}')
      ..writeln('Observation: ${observation.observationId}');
    if (paths.isNotEmpty) {
      buffer.writeln('Screenshots:');
      for (final path in paths) {
        buffer.writeln('  ${Uri.file(path)}');
      }
    }

    final flat = _flatten(observation.elements);
    final visible = <UiElement>[];
    final hidden = <UiElement>[];
    for (final element in flat) {
      if (element.state.visible == false) {
        hidden.add(element);
      } else {
        visible.add(element);
      }
    }

    buffer.writeln();
    _writeSection(buffer, 'Elements', visible, startIndex: 1);
    if (hidden.isNotEmpty) {
      buffer.writeln();
      _writeSection(
        buffer,
        'Hidden elements',
        hidden,
        startIndex: visible.length + 1,
      );
    }
    return buffer.toString().trimRight();
  }

  void _writeSection(
    StringBuffer buffer,
    String title,
    List<UiElement> elements, {
    required int startIndex,
  }) {
    buffer.writeln('$title (${elements.length}):');
    if (elements.isEmpty) {
      buffer.writeln('  (none)');
      return;
    }
    for (var i = 0; i < elements.length; i++) {
      final element = elements[i];
      final index = startIndex + i;
      final props = _elementProperties(element);
      if (i > 0) {
        buffer.writeln();
      }
      final indexLabel = '[$index] ';
      final lineIndent = '  ';
      final propIndent = '$lineIndent${' ' * indexLabel.length}';
      buffer.writeln('$lineIndent$indexLabel${_elementTitle(element)}');
      for (final prop in props) {
        buffer.writeln('$propIndent$prop');
      }
    }
  }

  List<UiElement> _flatten(List<UiElement> roots) {
    final out = <UiElement>[];
    void walk(UiElement e) {
      out.add(e);
      for (final child in e.children) {
        walk(child);
      }
    }

    for (final root in roots) {
      walk(root);
    }
    return out;
  }

  String _screenLabel(UiObservation observation) {
    final screen = observation.screen;
    if (screen.unknown) return 'Unknown';
    final name = screen.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    final route = screen.routeId?.trim();
    if (route != null && route.isNotEmpty) return route;
    return 'Unknown';
  }

  String _elementType(UiElement element) {
    final type = element.type?.trim();
    if (type != null && type.isNotEmpty) return type;
    final role = element.role?.trim();
    if (role != null && role.isNotEmpty) return role;
    return 'widget';
  }

  String _normalizedType(UiElement element) =>
      _elementType(element).toLowerCase();

  /// One-line title: `text: Hello` / `dropdown: Device Type` / `icon:`.
  String _elementTitle(UiElement element) {
    final type = _elementType(element);
    final title = _titleText(element);
    if (title == null || title.isEmpty) return '$type:';
    return '$type: ${_displayString(title)}';
  }

  String? _titleText(UiElement element) {
    switch (_normalizedType(element)) {
      case 'text':
        return _firstNonEmpty([element.text, element.label]);
      case 'icon':
        // Name is listed as a nested property.
        return null;
      case 'dropdown':
      case 'switch':
      case 'toggle':
      case 'textinput':
      case 'textfield':
        return _firstNonEmpty([element.label, element.testId]);
      case 'button':
        return _firstNonEmpty([element.text, element.label, element.testId]);
      default:
        return _firstNonEmpty([
          element.label,
          element.text,
          element.testId,
        ]);
    }
  }

  List<String> _elementProperties(UiElement element) {
    final type = _normalizedType(element);
    final props = <String>[];

    final testId = element.testId?.trim();
    if (testId != null && testId.isNotEmpty) {
      props.add('id: $testId');
    }

    switch (type) {
      case 'icon':
        final name = _firstNonEmpty([element.text, element.label]);
        if (name != null) props.add('name: ${_displayString(name)}');
        _addEnabled(props, element);
        break;
      case 'dropdown':
        _addValue(props, element, emptyIfMissing: false);
        if (element.options.isNotEmpty) {
          final options = element.options.map(_displayString).join(', ');
          props.add('options: [$options]');
        }
        _addEnabled(props, element);
        break;
      case 'switch':
      case 'toggle':
        final checked = element.state.checked;
        if (checked != null) {
          props.add('checked: $checked');
        }
        _addEnabled(props, element);
        break;
      case 'textinput':
      case 'textfield':
        if (element.state.secure == true) {
          props.add('value: (secure)');
        } else {
          _addValue(props, element, emptyIfMissing: true);
        }
        final hint = element.hint?.trim();
        if (hint != null && hint.isNotEmpty) {
          props.add('hint: ${_displayString(hint)}');
        }
        _addEnabled(props, element);
        break;
      case 'button':
        _addEnabled(props, element);
        break;
      case 'text':
        break;
      default:
        _addValue(props, element, emptyIfMissing: false);
        _addEnabled(props, element);
        break;
    }

    _addSelector(props, element, type: type);
    return props;
  }

  void _addEnabled(List<String> props, UiElement element) {
    final enabled = element.state.enabled;
    if (enabled != null) {
      props.add('enabled: $enabled');
    }
  }

  void _addSelector(
    List<String> props,
    UiElement element, {
    required String type,
  }) {
    final locator = element.suggestedLocator;
    final warning = element.locatorWarning?.trim();
    final wantsSelector = type != 'text' ||
        locator != null ||
        (warning != null && warning.isNotEmpty);

    if (!wantsSelector) return;

    if (locator != null) {
      props.add('selector: ${formatSuggestedSelector(locator)}');
    } else if (type != 'text' || (warning != null && warning.isNotEmpty)) {
      props.add('selector: unavailable');
    }
    if (warning != null && warning.isNotEmpty) {
      props.add('warning: $warning');
    }
  }

  void _addValue(
    List<String> props,
    UiElement element, {
    required bool emptyIfMissing,
  }) {
    if (element.state.secure == true) {
      props.add('value: (secure)');
      return;
    }
    final value = element.text?.trim();
    if (value != null && value.isNotEmpty) {
      props.add('value: ${_displayString(value)}');
    } else if (emptyIfMissing) {
      props.add('value: (empty)');
    }
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  String _displayString(String raw) {
    var value = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    const maxLen = 96;
    if (value.length > maxLen) {
      value = '${value.substring(0, maxLen - 1)}…';
    }
    return value;
  }
}

/// Extracts the observe payload from Flutter test process output.
///
/// Tolerates `flutter:` / logcat prefixes that wrap `print` on device.
String? extractObservePayload(String output) {
  final lines = output.split('\n');
  final start = lines.indexWhere(
    (line) => line.contains(ensembleTestObserveBegin),
  );
  if (start < 0) return null;
  final end = lines.indexWhere(
    (line) => line.contains(ensembleTestObserveEnd),
    start + 1,
  );
  if (end < 0) return null;
  return lines
      .sublist(start + 1, end)
      .map(_stripFlutterLogPrefix)
      .join('\n');
}

String _stripFlutterLogPrefix(String line) {
  const markers = ['flutter: ', 'I/flutter ('];
  for (final marker in markers) {
    final index = line.indexOf(marker);
    if (index < 0) continue;
    if (marker == 'flutter: ') {
      return line.substring(index + marker.length);
    }
    final colon = line.indexOf('): ', index);
    if (colon >= 0) {
      return line.substring(colon + 3);
    }
  }
  return line;
}
