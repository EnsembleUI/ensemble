import 'dart:convert';

/// Shrinks the HTML report document before gzip:
/// - strips nested step payload copies
/// - interns repeated large values into a root `blobs` table
/// - omits empty collections / default fields
class ReportJsonOptimizer {
  /// Marker key for a blob reference: `{ "$b": "0" }`.
  static const blobRefKey = r'$b';

  /// Values shorter than this (JSON-encoded) stay inline.
  static const internMinBytes = 48;

  /// Returns an optimized copy of [document].
  static Map<String, dynamic> optimize(Map<String, dynamic> document) {
    final blobs = <String, dynamic>{};
    final indexByEncoded = <String, String>{};
    var nextId = 0;

    String intern(dynamic value) {
      final encoded = json.encode(value);
      final existing = indexByEncoded[encoded];
      if (existing != null) return existing;
      final id = nextId.toRadixString(36);
      nextId++;
      indexByEncoded[encoded] = id;
      blobs[id] = value;
      return id;
    }

    dynamic maybeIntern(dynamic value) {
      if (value == null) return null;
      final encoded = json.encode(value);
      if (encoded.length < internMinBytes) return value;
      return {blobRefKey: intern(value)};
    }

    dynamic alwaysIntern(dynamic value) {
      if (value == null) return null;
      return {blobRefKey: intern(value)};
    }

    Map<String, dynamic>? optimizeApiCall(Map<String, dynamic> ev) {
      final out = <String, dynamic>{};
      for (final key in const [
        'name',
        'timestamp',
        'stepIndex',
        'index',
        'mocked',
        'statusCode',
        'type',
        'error',
      ]) {
        if (ev.containsKey(key) && ev[key] != null) {
          out[key] = ev[key];
        }
      }
      final request = ev['request'];
      if (request is Map) {
        final req = <String, dynamic>{};
        if (request['url'] != null) req['url'] = request['url'];
        if (request['method'] != null) req['method'] = request['method'];
        if (request['headers'] != null) {
          req['headers'] = alwaysIntern(request['headers']);
        }
        if (request['body'] != null) {
          req['body'] = alwaysIntern(request['body']);
        }
        if (request['parameters'] != null) {
          req['parameters'] = maybeIntern(request['parameters']);
        }
        if (req.isNotEmpty) out['request'] = req;
      }
      if (ev.containsKey('responseBody') && ev['responseBody'] != null) {
        out['responseBody'] = alwaysIntern(ev['responseBody']);
      }
      return out.isEmpty ? null : out;
    }

    Map<String, dynamic>? optimizeStorageChange(Map<String, dynamic> change) {
      final out = <String, dynamic>{};
      if (change['key'] != null) out['key'] = change['key'];
      if (change['change'] != null) out['change'] = change['change'];
      if (change.containsKey('before')) {
        out['before'] = maybeIntern(change['before']);
      }
      if (change.containsKey('after')) {
        out['after'] = maybeIntern(change['after']);
      }
      return out.isEmpty ? null : out;
    }

    Map<String, dynamic> optimizeStep(Map<String, dynamic> step) {
      final text = step['stepText']?.toString() ?? '';
      final nested = text.startsWith('  ');
      final out = <String, dynamic>{'stepText': text};
      if (nested) {
        // Payloads live only on the parent non-nested step.
        return out;
      }

      final apiCalls = step['apiCalls'];
      if (apiCalls is List && apiCalls.isNotEmpty) {
        final optimizedCalls = <Map<String, dynamic>>[];
        for (final ev in apiCalls) {
          if (ev is! Map) continue;
          final optimized =
              optimizeApiCall(Map<String, dynamic>.from(ev));
          if (optimized != null) optimizedCalls.add(optimized);
        }
        if (optimizedCalls.isNotEmpty) out['apiCalls'] = optimizedCalls;
      }

      final appLogs = step['appLogs'];
      if (appLogs is List && appLogs.isNotEmpty) {
        out['appLogs'] = [for (final line in appLogs) line.toString()];
      }

      final changes = step['storageChanges'];
      if (changes is List && changes.isNotEmpty) {
        final optimizedChanges = <Map<String, dynamic>>[];
        for (final c in changes) {
          if (c is! Map) continue;
          final optimized =
              optimizeStorageChange(Map<String, dynamic>.from(c));
          if (optimized != null) optimizedChanges.add(optimized);
        }
        if (optimizedChanges.isNotEmpty) {
          out['storageChanges'] = optimizedChanges;
        }
      }

      final shots = step['screenshots'];
      if (shots is List && shots.isNotEmpty) {
        out['screenshots'] = [
          for (final s in shots)
            if (s is Map) Map<String, dynamic>.from(s),
        ];
      }
      final stepPerf = step['performance'];
      if (stepPerf is Map && stepPerf.isNotEmpty) {
        out['performance'] = maybeIntern(Map<String, dynamic>.from(stepPerf));
      }
      return out;
    }

    Map<String, dynamic> optimizeTest(Map<String, dynamic> test) {
      final out = <String, dynamic>{
        'id': test['id'],
        'status': test['status'],
        'durationMs': test['durationMs'],
      };
      final baseId = test['baseId'];
      if (baseId != null && baseId.toString().isNotEmpty) {
        out['baseId'] = baseId;
      }
      final badge = test['deviceBadge'];
      if (badge != null && badge.toString().isNotEmpty) {
        out['deviceBadge'] = badge;
      }
      final filePath = test['filePath'];
      if (filePath != null && filePath.toString().isNotEmpty) {
        out['filePath'] = filePath;
      }
      final attempts = test['attempts'];
      if (attempts is int && attempts != 1) out['attempts'] = attempts;
      final retry = test['retry'];
      if (retry is int && retry != 0) out['retry'] = retry;
      if (test['message'] != null) out['message'] = test['message'];
      if (test['failedStepIndex'] != null) {
        out['failedStepIndex'] = test['failedStepIndex'];
      }
      if (test['report'] is Map) {
        out['report'] = Map<String, dynamic>.from(test['report'] as Map);
      }

      final storage = test['storage'];
      if (storage is Map && storage['keys'] is Map) {
        final keys = storage['keys'] as Map;
        if (keys.isNotEmpty) {
          out['storage'] = {
            'keys': {
              for (final e in keys.entries) e.key.toString(): maybeIntern(e.value),
            },
          };
        }
      }

      if (test['performance'] is Map) {
        out['performance'] =
            alwaysIntern(Map<String, dynamic>.from(test['performance'] as Map));
      }
      if (test['dumpTree'] != null) {
        out['dumpTree'] = alwaysIntern(test['dumpTree']);
      }

      final steps = test['steps'];
      if (steps is List && steps.isNotEmpty) {
        out['steps'] = [
          for (final s in steps)
            if (s is Map) optimizeStep(Map<String, dynamic>.from(s)),
        ];
      }
      return out;
    }

    final out = <String, dynamic>{
      'state': document['state'],
      if (document['generatedAt'] != null) 'generatedAt': document['generatedAt'],
      if (document['summary'] is Map)
        'summary': Map<String, dynamic>.from(document['summary'] as Map),
    };

    final artifacts = document['suiteArtifacts'];
    if (artifacts is List && artifacts.isNotEmpty) {
      final optimizedArtifacts = <Map<String, dynamic>>[];
      for (final artifact in artifacts) {
        if (artifact is! Map) continue;
        final entry = <String, dynamic>{
          'label': artifact['label'],
        };
        if (artifact['path'] != null) entry['path'] = artifact['path'];
        if (artifact['href'] != null) entry['href'] = artifact['href'];
        optimizedArtifacts.add(entry);
      }
      if (optimizedArtifacts.isNotEmpty) {
        out['suiteArtifacts'] = optimizedArtifacts;
      }
    }

    final tests = document['tests'];
    if (tests is List) {
      out['tests'] = [
        for (final t in tests)
          if (t is Map) optimizeTest(Map<String, dynamic>.from(t)),
      ];
    } else {
      out['tests'] = <Map<String, dynamic>>[];
    }

    if (blobs.isNotEmpty) {
      out['blobs'] = blobs;
    }
    return out;
  }

  /// Expands blob refs and restores nested step payloads for viewers/tests.
  static Map<String, dynamic> expand(Map<String, dynamic> document) {
    final blobs = document['blobs'] is Map
        ? Map<String, dynamic>.from(document['blobs'] as Map)
        : <String, dynamic>{};

    dynamic resolve(dynamic value) {
      if (value is Map) {
        if (value.length == 1 && value.containsKey(blobRefKey)) {
          final id = value[blobRefKey]?.toString();
          if (id != null && blobs.containsKey(id)) {
            return resolve(blobs[id]);
          }
        }
        return {
          for (final e in value.entries) e.key.toString(): resolve(e.value),
        };
      }
      if (value is List) {
        return [for (final item in value) resolve(item)];
      }
      return value;
    }

    final resolved = Map<String, dynamic>.from(resolve(document) as Map);
    resolved.remove('blobs');

    final tests = resolved['tests'];
    if (tests is List) {
      for (final test in tests) {
        if (test is! Map) continue;
        final steps = test['steps'];
        if (steps is! List) continue;
        Map<String, dynamic>? parentPayload;
        for (var i = 0; i < steps.length; i++) {
          final step = steps[i];
          if (step is! Map) continue;
          final text = step['stepText']?.toString() ?? '';
          final nested = text.startsWith('  ');
          if (!nested) {
            parentPayload = {
              'apiCalls': step['apiCalls'] ?? const [],
              'appLogs': step['appLogs'] ?? const [],
              'storageChanges': step['storageChanges'] ?? const [],
              'screenshots': step['screenshots'] ?? const [],
              'performance': step['performance'],
            };
            step.putIfAbsent('apiCalls', () => const []);
            step.putIfAbsent('appLogs', () => const []);
            step.putIfAbsent('storageChanges', () => const []);
            step.putIfAbsent('screenshots', () => const []);
          } else if (parentPayload != null) {
            step['apiCalls'] = parentPayload['apiCalls'];
            step['appLogs'] = parentPayload['appLogs'];
            step['storageChanges'] = parentPayload['storageChanges'];
            step['screenshots'] = parentPayload['screenshots'];
            if (parentPayload['performance'] != null) {
              step['performance'] = parentPayload['performance'];
            }
          } else {
            step['apiCalls'] = const [];
            step['appLogs'] = const [];
            step['storageChanges'] = const [];
            step['screenshots'] = const [];
          }
        }
      }
    }
    return resolved;
  }
}
