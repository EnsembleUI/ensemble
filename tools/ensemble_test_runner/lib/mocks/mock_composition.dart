import 'dart:convert';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

/// Resolves mock JSON documents that use `$extends` and `$merge`.
///
/// File shape:
/// ```json
/// {
///   "$extends": "mocks/base.mock.json",
///   "getDevices": {
///     "$merge": {
///       "body.status[0].Active": false
///     }
///   }
/// }
/// ```
///
/// `$extends` may be a string or a list of mock file paths (merged in order).
/// `$merge` applies path updates onto the extended/current response for that API.
/// Without `$merge`, an API entry fully replaces the previous response.
class MockComposition {
  MockComposition._();

  static const extendsKey = r'$extends';
  static const mergeKey = r'$merge';

  /// Loads and fully resolves a mock file into API response maps
  /// (`statusCode` / `body` / `headers` / `delayMs` / `responses`).
  ///
  /// [testAssetPath] is the owning `*.test.yaml` (or equivalent) used to resolve
  /// `$extends` paths the same way as test-level `mocks:` file entries.
  static Future<Map<String, Map<String, dynamic>>> resolveFile({
    required String testAssetPath,
    required String mockFilePath,
    required Future<String> Function(String assetPath) assetLoader,
    required String Function(String fromAssetPath, String relativePath)
        resolveAssetPath,
    Set<String>? resolving,
  }) async {
    final assetPath = resolveAssetPath(testAssetPath, mockFilePath);
    final stack = resolving ?? <String>{};
    if (!stack.add(assetPath)) {
      throw EnsembleTestFailure(
        'Mock file "$assetPath" has a cyclic ${extendsKey} chain: '
        '${[...stack, assetPath].join(' -> ')}',
      );
    }

    try {
      if (!assetPath.endsWith('.mock.json')) {
        throw EnsembleTestFailure(
          'Mock file "$mockFilePath" must be a .mock.json file.',
        );
      }

      final content = await assetLoader(assetPath);
      final dynamic doc = _parseJson(content, assetPath);
      if (doc == null) return {};
      if (doc is! Map) {
        throw EnsembleTestFailure('Mock file "$assetPath" root must be a map');
      }

      return resolveDocument(
        Map<dynamic, dynamic>.from(doc),
        sourceLabel: assetPath,
        testAssetPath: testAssetPath,
        assetLoader: assetLoader,
        resolveAssetPath: resolveAssetPath,
        resolving: stack,
      );
    } finally {
      stack.remove(assetPath);
    }
  }

  /// Resolves a mock document map (file root or inline layer) into API maps.
  static Future<Map<String, Map<String, dynamic>>> resolveDocument(
    Map<dynamic, dynamic> doc, {
    required String sourceLabel,
    required String testAssetPath,
    required Future<String> Function(String assetPath) assetLoader,
    required String Function(String fromAssetPath, String relativePath)
        resolveAssetPath,
    Set<String>? resolving,
  }) async {
    final raw = <String, Map<String, dynamic>>{};
    final extendsRaw = doc[extendsKey];
    if (extendsRaw != null) {
      final parents = _extendsList(extendsRaw, sourceLabel);
      for (final parent in parents) {
        final parentApis = await resolveFile(
          testAssetPath: testAssetPath,
          mockFilePath: parent,
          assetLoader: assetLoader,
          resolveAssetPath: resolveAssetPath,
          resolving: resolving,
        );
        mergeApiMaps(
          raw,
          parentApis,
          sourceLabel: sourceLabel,
        );
      }
    }

    for (final entry in doc.entries) {
      final apiName = entry.key.toString();
      if (apiName == extendsKey) continue;
      if (entry.value is! Map) {
        throw EnsembleTestFailure(
          'Mock for API "$apiName" in "$sourceLabel" must be a map',
        );
      }
      mergeApiMaps(
        raw,
        {
          apiName: _stringifyKeys(Map<dynamic, dynamic>.from(entry.value as Map)),
        },
        sourceLabel: sourceLabel,
      );
    }
    return raw;
  }

  /// Merges [incoming] into [target]. Entries with `$merge` patch the existing
  /// API response; all other entries replace it.
  static void mergeApiMaps(
    Map<String, Map<String, dynamic>> target,
    Map<String, Map<String, dynamic>> incoming, {
    required String sourceLabel,
  }) {
    for (final entry in incoming.entries) {
      final apiName = entry.key;
      final value = Map<String, dynamic>.from(entry.value);
      final merge = value.remove(mergeKey);
      if (merge == null) {
        target[apiName] = value;
        continue;
      }
      if (merge is! Map) {
        throw EnsembleTestFailure(
          'API mock "$apiName" in "$sourceLabel" $mergeKey must be a map of '
          'path → value.',
        );
      }
      final base = target[apiName];
      if (base == null) {
        throw EnsembleTestFailure(
          'API mock "$apiName" in "$sourceLabel" uses $mergeKey but there is '
          'no existing mock to patch. Add $extendsKey or a prior mock for this API.',
        );
      }
      final merged = deepCopy(base) as Map<String, dynamic>;
      // Non-merge keys on the same object replace those top-level fields first.
      for (final field in value.entries) {
        merged[field.key] = deepCopy(field.value);
      }
      applyMergePaths(
        merged,
        Map<String, dynamic>.from(merge),
        sourceLabel: sourceLabel,
        apiName: apiName,
      );
      target[apiName] = merged;
    }
  }

  static void applyMergePaths(
    Map<String, dynamic> target,
    Map<String, dynamic> paths, {
    required String sourceLabel,
    required String apiName,
  }) {
    for (final entry in paths.entries) {
      try {
        setPath(target, entry.key, deepCopy(entry.value));
      } on FormatException catch (error) {
        throw EnsembleTestFailure(
          'API mock "$apiName" in "$sourceLabel" has invalid $mergeKey path '
          '"${entry.key}": ${error.message}',
        );
      }
    }
  }

  /// Sets [value] at a dotted/bracket path or JSON Pointer.
  ///
  /// Examples:
  /// - `body.status[0].Active`
  /// - `/body/status/0/Active`
  static void setPath(Map<String, dynamic> root, String path, dynamic value) {
    final segments = parsePath(path);
    if (segments.isEmpty) {
      throw const FormatException('path is empty');
    }

    dynamic cursor = root;
    for (var i = 0; i < segments.length - 1; i++) {
      final segment = segments[i];
      final next = segments[i + 1];
      if (segment is String) {
        if (cursor is! Map) {
          throw FormatException('expected object before "$segment"');
        }
        final map = cursor;
        if (!map.containsKey(segment) || map[segment] == null) {
          map[segment] = next is int ? <dynamic>[] : <String, dynamic>{};
        }
        cursor = map[segment];
        if (next is int && cursor is! List) {
          throw FormatException('expected array at "$segment"');
        }
        if (next is String && cursor is! Map) {
          throw FormatException('expected object at "$segment"');
        }
      } else if (segment is int) {
        if (cursor is! List) {
          throw FormatException('expected array before index $segment');
        }
        while (cursor.length <= segment) {
          cursor.add(next is int ? <dynamic>[] : <String, dynamic>{});
        }
        cursor[segment] ??= next is int ? <dynamic>[] : <String, dynamic>{};
        cursor = cursor[segment];
        if (next is int && cursor is! List) {
          throw FormatException('expected array at index $segment');
        }
        if (next is String && cursor is! Map) {
          throw FormatException('expected object at index $segment');
        }
      }
    }

    final last = segments.last;
    if (last is String) {
      if (cursor is! Map) {
        throw FormatException('expected object before "$last"');
      }
      cursor[last] = value;
    } else if (last is int) {
      if (cursor is! List) {
        throw FormatException('expected array before index $last');
      }
      while (cursor.length <= last) {
        cursor.add(null);
      }
      cursor[last] = value;
    }
  }

  static List<Object> parsePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.startsWith('/')) {
      return [
        for (final part in trimmed.substring(1).split('/'))
          if (part.isNotEmpty)
            int.tryParse(part) ?? Uri.decodeComponent(part.replaceAll('~1', '/').replaceAll('~0', '~')),
      ];
    }

    final segments = <Object>[];
    final pattern = RegExp(r'([^.\[\]]+)|\[(\d+)\]');
    var index = 0;
    for (final match in pattern.allMatches(trimmed)) {
      if (match.start != index) {
        throw FormatException('unexpected character at index $index');
      }
      final key = match.group(1);
      final listIndex = match.group(2);
      if (key != null) {
        segments.add(key);
      } else if (listIndex != null) {
        segments.add(int.parse(listIndex));
      }
      index = match.end;
      if (index < trimmed.length && trimmed[index] == '.') {
        index++;
      }
    }
    if (index != trimmed.length) {
      throw FormatException('unexpected trailing character at index $index');
    }
    return segments;
  }

  static Map<String, MockAPIResponse> toMockApis(
    Map<String, Map<String, dynamic>> raw, {
    required String sourceLabel,
  }) {
    return {
      for (final entry in raw.entries)
        entry.key: parseApiResponse(
          entry.value,
          sourceLabel: sourceLabel,
          apiName: entry.key,
        ),
    };
  }

  static MockAPIResponse parseApiResponse(
    Map<String, dynamic> map, {
    required String sourceLabel,
    required String apiName,
  }) {
    if (map.isEmpty) {
      throw EnsembleTestFailure(
        'API mock "$apiName" in "$sourceLabel" must include a response',
      );
    }
    if (map.containsKey(mergeKey) || map.containsKey(extendsKey)) {
      throw EnsembleTestFailure(
        'API mock "$apiName" in "$sourceLabel" still contains unresolved '
        '$extendsKey/$mergeKey keys.',
      );
    }
    final unknownKeys = map.keys
        .where(
          (key) => !const {
            'statusCode',
            'body',
            'headers',
            'delayMs',
            'responses',
          }.contains(key),
        )
        .toList();
    if (unknownKeys.isNotEmpty) {
      throw EnsembleTestFailure(
        'API mock "$apiName" in "$sourceLabel" has unsupported keys: '
        '${unknownKeys.join(", ")}. Use direct JSON shape or $mergeKey paths.',
      );
    }

    final responses = map['responses'];
    if (responses != null) {
      if (responses is! List || responses.isEmpty) {
        throw EnsembleTestFailure(
          'API mock "$apiName" in "$sourceLabel" responses must be a non-empty list',
        );
      }
      return MockAPIResponse(
        responses: [
          for (final entry in responses)
            if (entry is Map)
              parseApiResponse(
                _stringifyKeys(Map<dynamic, dynamic>.from(entry)),
                sourceLabel: sourceLabel,
                apiName: apiName,
              )
            else
              throw EnsembleTestFailure(
                'API mock "$apiName" in "$sourceLabel" responses entries must be objects',
              ),
        ],
      );
    }

    return MockAPIResponse(
      statusCode: map['statusCode'] as int? ?? 200,
      body: map.containsKey('body') ? deepCopy(map['body']) : null,
      headers: map['headers'] is Map
          ? Map<String, dynamic>.from(deepCopy(map['headers']) as Map)
          : null,
      delayMs: map['delayMs'] as int?,
    );
  }

  static dynamic deepCopy(dynamic value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): deepCopy(entry.value),
      };
    }
    if (value is List) {
      return [for (final item in value) deepCopy(item)];
    }
    return value;
  }

  static List<String> _extendsList(dynamic value, String sourceLabel) {
    if (value is String) {
      final path = value.trim();
      if (path.isEmpty) {
        throw EnsembleTestFailure(
          'Mock "$sourceLabel" $extendsKey must be a non-empty path.',
        );
      }
      return [path];
    }
    if (value is List) {
      final paths = <String>[
        for (final item in value)
          if (item != null && item.toString().trim().isNotEmpty)
            item.toString().trim(),
      ];
      if (paths.isEmpty) {
        throw EnsembleTestFailure(
          'Mock "$sourceLabel" $extendsKey list must contain at least one path.',
        );
      }
      return paths;
    }
    throw EnsembleTestFailure(
      'Mock "$sourceLabel" $extendsKey must be a string or list of strings.',
    );
  }

  static Map<String, dynamic> _stringifyKeys(Map<dynamic, dynamic> map) {
    return {
      for (final entry in map.entries)
        entry.key.toString(): entry.value is Map
            ? _stringifyKeys(Map<dynamic, dynamic>.from(entry.value as Map))
            : entry.value is List
                ? [
                    for (final item in entry.value as List)
                      item is Map
                          ? _stringifyKeys(Map<dynamic, dynamic>.from(item))
                          : item,
                  ]
                : entry.value,
    };
  }

  static dynamic _parseJson(String content, String assetPath) {
    try {
      return jsonDecode(content);
    } on FormatException catch (error) {
      throw EnsembleTestFailure(
        'Mock file "$assetPath" is not valid JSON: ${error.message}',
      );
    }
  }
}
