import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
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

  // Nested steps inherit the evidence attached to their parent. Keeping the
  // field list in one place prevents the compact and expanded report paths
  // from drifting when a new evidence channel is added.
  static const _stepPayloadFields = [
    'apiCalls',
    'appLogs',
    'storageChanges',
    'secureStorageChanges',
    'keychainChanges',
    'screenshots',
    'observer',
  ];

  static dynamic _emptyStepPayload(String field) =>
      field == 'observer' ? null : const [];

  static Map<String, dynamic> _stepPayload(Map step) => {
        for (final field in _stepPayloadFields)
          field: step[field] ?? _emptyStepPayload(field),
      };

  static void _applyStepPayload(Map target, Map<String, dynamic> payload) {
    for (final field in _stepPayloadFields) {
      target[field] = payload[field];
    }
  }

  /// Returns an optimized copy of [document].
  static Map<String, dynamic> optimize(Map<String, dynamic> document) {
    return RunnerBenchmark.sync('report', 'optimize', () {
      final blobs = <String, dynamic>{};
      final indexByEncoded = <String, String>{};
      var nextId = 0;

      String intern(dynamic value, {String? encoded}) {
        // Callers that already encoded a value pass it through so large
        // payloads are serialized only once while deciding whether to intern
        // them. This is especially relevant for API bodies and debug trees.
        final stableEncoding = encoded ?? json.encode(value);
        final existing = indexByEncoded[stableEncoding];
        if (existing != null) return existing;
        final id = nextId.toRadixString(36);
        nextId++;
        indexByEncoded[stableEncoding] = id;
        blobs[id] = value;
        return id;
      }

      dynamic maybeIntern(dynamic value) {
        if (value == null) return null;
        final encoded = json.encode(value);
        if (encoded.length < internMinBytes) return value;
        return {blobRefKey: intern(value, encoded: encoded)};
      }

      dynamic alwaysIntern(dynamic value) {
        if (value == null) return null;
        final encoded = json.encode(value);
        return {blobRefKey: intern(value, encoded: encoded)};
      }

      Map<String, dynamic>? optimizeApiCall(Map ev) {
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

      Map<String, dynamic>? optimizeStorageChange(Map change) {
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

      Map<String, dynamic> optimizeReport(Map report) {
        final out = Map<String, dynamic>.from(report);
        final screens = report['screens'];
        if (screens is! Map || screens.isEmpty) return out;
        final optimizedScreens = <String, dynamic>{};
        screens.forEach((key, value) {
          if (value is! Map) {
            optimizedScreens[key.toString()] = value;
            return;
          }
          final screen = Map<String, dynamic>.from(value);
          if (screen['debugTree'] != null) {
            screen['debugTree'] = alwaysIntern(screen['debugTree']);
          }
          if (screen['performance'] is Map) {
            screen['performance'] = alwaysIntern(
              Map<String, dynamic>.from(screen['performance'] as Map),
            );
          }
          optimizedScreens[key.toString()] = screen;
        });
        out['screens'] = optimizedScreens;
        return out;
      }

      Map<String, dynamic> optimizeStep(Map step) {
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
            final optimized = optimizeApiCall(ev);
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
            final optimized = optimizeStorageChange(c);
            if (optimized != null) optimizedChanges.add(optimized);
          }
          if (optimizedChanges.isNotEmpty) {
            out['storageChanges'] = optimizedChanges;
          }
        }
        for (final field in const ['secureStorageChanges', 'keychainChanges']) {
          final secureChanges = step[field];
          if (secureChanges is List && secureChanges.isNotEmpty) {
            final optimizedChanges = <Map<String, dynamic>>[];
            for (final c in secureChanges) {
              if (c is! Map) continue;
              final optimized = optimizeStorageChange(c);
              if (optimized != null) optimizedChanges.add(optimized);
            }
            if (optimizedChanges.isNotEmpty) out[field] = optimizedChanges;
          }
        }

        final shots = step['screenshots'];
        if (shots is List && shots.isNotEmpty) {
          out['screenshots'] = [
            for (final s in shots)
              if (s is Map) Map<String, dynamic>.from(s),
          ];
        }
        final observer = step['observer'];
        if (observer is Map && observer.isNotEmpty) {
          out['observer'] = Map<String, dynamic>.from(observer);
        }
        return out;
      }

      Map<String, dynamic> optimizeTest(Map test) {
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
        final device = test['device'];
        if (device is Map && device.isNotEmpty) {
          out['device'] = Map<String, dynamic>.from(device);
        }
        final filePath = test['filePath'];
        if (filePath != null && filePath.toString().isNotEmpty) {
          out['filePath'] = filePath;
        }
        final metadata = test['metadata'];
        if (metadata is Map && metadata.isNotEmpty) {
          out['metadata'] = Map<String, dynamic>.from(metadata);
        }
        final feature = test['feature'];
        if (feature != null && feature.toString().isNotEmpty) {
          out['feature'] = feature;
        }
        final profile = test['profile'];
        if (profile != null && profile.toString().isNotEmpty) {
          out['profile'] = profile;
        }
        final scenarioId = test['scenarioId'];
        if (scenarioId != null && scenarioId.toString().isNotEmpty) {
          out['scenarioId'] = scenarioId;
        }
        final scenarioDescription = test['scenarioDescription'];
        if (scenarioDescription != null &&
            scenarioDescription.toString().isNotEmpty) {
          out['scenarioDescription'] = scenarioDescription;
        }
        final description = test['description'];
        if (description != null && description.toString().isNotEmpty) {
          out['description'] = description;
        }
        // Keep the diagnostic fields emitted by TestReportDocument's
        // canonical result projection.  These fields used to survive in the
        // in-memory document but were silently discarded by the compressed
        // report path, making persisted JSON disagree with HTML, console,
        // JUnit, and history projections.
        for (final field in const [
          'failure',
          'secondaryFailures',
          'stackTrace',
          'failedStep',
          'failureOperation',
          'failureSource',
          'capabilities',
        ]) {
          if (test[field] != null) out[field] = test[field];
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
          out['report'] = optimizeReport(test['report'] as Map);
        }

        final storage = test['storage'];
        if (storage is Map) {
          final storageOut = <String, dynamic>{};
          for (final entry in const [
            ('keys', 'keys'),
            ('secureStorageKeys', 'secureStorageKeys'),
            ('keychainKeys', 'keychainKeys'),
          ]) {
            final keys = storage[entry.$1];
            if (keys is Map && keys.isNotEmpty) {
              storageOut[entry.$2] = {
                for (final e in keys.entries)
                  e.key.toString(): maybeIntern(e.value),
              };
            }
          }
          if (storageOut.isNotEmpty) out['storage'] = storageOut;
        }

        final steps = test['steps'];
        if (steps is List && steps.isNotEmpty) {
          out['steps'] = [
            for (final s in steps)
              if (s is Map) optimizeStep(s),
          ];
        }
        return out;
      }

      final out = <String, dynamic>{
        'state': document['state'],
        if (document['generatedAt'] != null)
          'generatedAt': document['generatedAt'],
        if (document['summary'] is Map)
          'summary': Map<String, dynamic>.from(document['summary'] as Map),
        if (document['metadata'] is Map)
          'metadata': Map<String, dynamic>.from(document['metadata'] as Map),
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
            if (t is Map) optimizeTest(t),
        ];
      } else {
        out['tests'] = <Map<String, dynamic>>[];
      }

      if (blobs.isNotEmpty) {
        out['blobs'] = blobs;
      }
      return out;
    });
  }

  /// Expands blob refs and restores nested step payloads for viewers/tests.
  static Map<String, dynamic> expand(Map<String, dynamic> document) {
    return RunnerBenchmark.sync('report', 'expand', () {
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
              parentPayload = _stepPayload(step);
              for (final field in _stepPayloadFields) {
                step.putIfAbsent(field, () => parentPayload![field]);
              }
            } else if (parentPayload != null) {
              _applyStepPayload(step, parentPayload);
            } else {
              _applyStepPayload(
                step,
                {
                  for (final field in _stepPayloadFields)
                    field: _emptyStepPayload(field),
                },
              );
            }
          }
        }
      }
      return resolved;
    });
  }
}
