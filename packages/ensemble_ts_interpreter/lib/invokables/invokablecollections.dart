import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class JSMapConstructor extends Object with Invokable {
  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> methods() => {
        'init': ([List? entries]) {
          final map = JSMap({});
          if (entries != null) {
            for (final entry in entries) {
              if (entry is List && entry.length >= 2) {
                map._data[entry[0]] = entry[1];
              } else if (entry is Map) {
                final key = entry.containsKey('key') ? entry['key'] : entry[0];
                final value =
                    entry.containsKey('value') ? entry['value'] : entry[1];
                map._data[key] = value;
              }
            }
          }
          return map;
        },
      };

  @override
  Map<String, Function> setters() => {};
}

class JSMap extends Object with Invokable {
  JSMap(this._data);
  final Map<dynamic, dynamic> _data;

  @override
  Map<String, Function> getters() => {'size': () => _data.length};

  @override
  Map<String, Function> methods() => {
        'get': (dynamic key) => _data[key],
        'set': (dynamic key, dynamic value) {
          _data[key] = value;
          return this;
        },
        'has': (dynamic key) => _data.containsKey(key),
        'delete': (dynamic key) => _data.remove(key) != null,
        'clear': () => _data.clear(),
        'keys': () => _data.keys.toList(),
        'values': () => _data.values.toList(),
        'entries': () =>
            _data.entries.map((e) => {'key': e.key, 'value': e.value}).toList(),
        'forEach': (Function f) => _data.forEach((k, v) => f([v, k, this])),
      };

  @override
  Map<String, Function> setters() => {};

  String toConsoleString() {
    final entries = _data.entries
        .map((entry) =>
            '${_formatCollectionValue(entry.key)} => ${_formatCollectionValue(entry.value)}')
        .join(', ');
    return 'Map(${_data.length}) {$entries}';
  }

  @override
  String toString() => toConsoleString();
}

class JSSetConstructor extends Object with Invokable {
  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> methods() => {
        'init': ([List? values]) {
          return JSSet(values ?? []);
        },
      };

  @override
  Map<String, Function> setters() => {};
}

class JSSet extends Object with Invokable {
  JSSet(List initial) : _data = Set<dynamic>.from(initial);
  final Set<dynamic> _data;

  @override
  Map<String, Function> getters() => {'size': () => _data.length};

  @override
  Map<String, Function> methods() => {
        'add': (dynamic value) {
          _data.add(value);
          return this;
        },
        'has': (dynamic value) => _data.contains(value),
        'delete': (dynamic value) => _data.remove(value),
        'clear': () => _data.clear(),
        'keys': () => _data.toList(),
        'values': () => _data.toList(),
        'entries': () => _data.map((e) => [e, e]).toList(),
        'forEach': (Function f) => _data.forEach((e) => f([e, e, this])),
      };

  @override
  Map<String, Function> setters() => {};

  String toConsoleString() {
    final values = _data.map(_formatCollectionValue).join(', ');
    return 'Set(${_data.length}) {$values}';
  }

  @override
  String toString() => toConsoleString();
}

String _formatCollectionValue(dynamic value) {
  if (value == null) return 'null';
  if (value is String) return '"$value"';
  if (value is JSMap) return value.toConsoleString();
  if (value is JSSet) return value.toConsoleString();
  return value.toString();
}
