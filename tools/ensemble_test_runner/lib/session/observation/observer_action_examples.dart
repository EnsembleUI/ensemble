import 'dart:convert';

/// Builds ready-to-run YAML snippets for actions the Observer verified for an
/// element. The action name appears only in the YAML key.
List<String> observerActionExamples({
  required List<String> actions,
  required String? title,
  required String? id,
  required Map<String, dynamic>? locator,
  required Map<String, dynamic>? bounds,
  required String? warning,
  String? value,
  bool? secure,
  bool? checked,
  List<String> options = const [],
}) {
  final target = _targetLocator(
    locator: locator,
    bounds: bounds,
    warning: warning,
    id: id,
    title: title,
  );
  return [
    for (final action in actions)
      if (target != null ||
          const {
            'waitForText',
            'expectText',
            'expectNoText',
            'expectTextContains',
          }.contains(action))
        _formatExample(
          action,
          target: target,
          title: title,
          id: id,
          value: value,
          secure: secure,
          checked: checked,
          options: options,
        ),
  ];
}

String? observerElementTitleForFields({
  required String? type,
  required String? label,
  required String? text,
  required String? testId,
}) {
  final t = (type ?? '').toLowerCase();
  final values = switch (t) {
    'text' || 'icon' => [text, label],
    'image' || 'svg' || 'gif' || 'lottie' => [text, label, testId],
    'dropdown' ||
    'switch' ||
    'toggle' ||
    'checkbox' ||
    'textinput' ||
    'textfield' =>
      [label, testId],
    'button' => [text, label, testId],
    'toast' || 'card' => <String?>[],
    _ => [label, text, testId],
  };
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

Map<String, dynamic>? _targetLocator({
  required Map<String, dynamic>? locator,
  required Map<String, dynamic>? bounds,
  required String? warning,
  required String? id,
  required String? title,
}) {
  if (warning != null) {
    return bounds == null ? null : {'bounds': bounds};
  }
  if (locator != null && locator.isNotEmpty) return locator;
  if (id != null && id.trim().isNotEmpty) return {'id': id.trim()};
  if (bounds != null) return {'bounds': bounds};
  if (title != null && title.trim().isNotEmpty) return {'text': title.trim()};
  return null;
}

String _formatExample(
  String action, {
  required Map<String, dynamic>? target,
  required String? title,
  required String? id,
  required String? value,
  required bool? secure,
  required bool? checked,
  required List<String> options,
}) {
  final text = title?.trim().isNotEmpty == true ? title!.trim() : (id ?? '...');
  final extra = <String, Object?>{};
  switch (action) {
    case 'enterText':
    case 'replaceText':
      // Never copy a captured field value into an action suggestion.
      extra['value'] = '...';
      break;
    case 'select':
      extra['value'] = options.isNotEmpty ? options.first : '...';
      break;
    case 'selectIndex':
      extra['index'] = 0;
      break;
    case 'setSlider':
      extra['value'] = 0.5;
      break;
    case 'expectValue':
      extra['equals'] = secure == true ? '...' : (value ?? '...');
      break;
    case 'expectChecked':
      if (checked != null) extra['equals'] = checked;
      break;
    case 'waitForText':
    case 'expectText':
    case 'expectNoText':
    case 'expectTextContains':
      extra['text'] = text;
      break;
  }

  final lines = ['$action:'];
  final isTextAction = const {
    'waitForText',
    'expectText',
    'expectNoText',
    'expectTextContains',
  }.contains(action);

  if (isTextAction) {
    extra.forEach((key, value) => lines.add('  $key: ${_yamlScalar(value)}'));
    final sameTextTarget = action == 'waitForText' &&
        target != null &&
        target.length == 1 &&
        target['text'] == extra['text'];
    if (action == 'waitForText' && target != null && !sameTextTarget) {
      lines.add('  target:');
      lines.addAll(_yamlObjectLines(target, 2));
    }
    return lines.join('\n');
  }

  if (_isIdOnly(target!)) {
    lines.add('  id: ${_yamlScalar(target['id'])}');
  } else {
    lines.add('  target:');
    lines.addAll(_yamlObjectLines(target, 2));
  }
  extra.forEach((key, value) => lines.add('  $key: ${_yamlScalar(value)}'));
  return lines.join('\n');
}

bool _isIdOnly(Map<String, dynamic> locator) =>
    locator.length == 1 && locator['id'] != null;

List<String> _yamlObjectLines(Map<String, dynamic> object, int indent) {
  final pad = '  ' * indent;
  final lines = <String>[];
  for (final entry in object.entries) {
    final value = entry.value;
    if (value == null) continue;
    if (value is Map) {
      lines.add('$pad${entry.key}:');
      lines.addAll(
        _yamlObjectLines(Map<String, dynamic>.from(value), indent + 1),
      );
    } else {
      lines.add('$pad${entry.key}: ${_yamlScalar(value)}');
    }
  }
  return lines;
}

String _yamlScalar(Object? value) => jsonEncode(value ?? '');
