import 'dart:convert';

import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';

/// Builds JSON Schema for app-local `tests/*.test.yaml` files.
class EnsembleTestSchemaBuilder {
  static const schemaId =
      'https://cdn.ensembleui.com/schemas/ensemble_tests_schema.json';
  static const configSchemaId =
      'https://cdn.ensembleui.com/schemas/ensemble_test_config_schema.json';
  static const schemaVersion = 'https://json-schema.org/draft/2020-12/schema';

  static Map<String, dynamic> build() {
    final defs = <String, dynamic>{
      'initialState': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'storage': {'type': 'object', 'additionalProperties': true},
          'keychain': {'type': 'object', 'additionalProperties': true},
          'env': {'type': 'object', 'additionalProperties': true},
        },
      },
      'scenario': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'id': {'type': 'string', 'minLength': 1},
          'description': {'type': 'string'},
          'vars': {'type': 'object', 'additionalProperties': true},
        },
        'required': ['id'],
      },
      'mockResponse': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'statusCode': {'type': 'integer'},
          'body': true,
          'headers': {'type': 'object', 'additionalProperties': true},
          'delayMs': {'type': 'integer', 'minimum': 0},
          'responses': {
            'type': 'array',
            'minItems': 1,
            'items': {'\$ref': '#/\$defs/mockResponse'},
          },
          r'$merge': {
            'type': 'object',
            'additionalProperties': true,
            'description':
                'Path → value patches applied onto the extended/current mock '
                'for this API (e.g. body.status[0].Active).',
          },
        },
      },
      'inlineMocks': {
        'type': 'object',
        'properties': {
          r'$extends': {
            'description':
                'Base mock file path (or list of paths) to layer before these APIs.',
            'oneOf': [
              {'type': 'string', 'minLength': 1},
              {
                'type': 'array',
                'minItems': 1,
                'items': {'type': 'string', 'minLength': 1},
              },
            ],
          },
        },
        'additionalProperties': {'\$ref': '#/\$defs/mockResponse'},
      },
      'testCase': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'id': {
            'type': 'string',
            'minLength': 1,
            'description': 'Unique test identifier',
          },
          'type': {'type': 'string'},
          'feature': {
            'type': 'string',
            'minLength': 1,
            'description': 'Feature or flow name, e.g. login or wifi',
          },
          'tags': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Free-form labels for filtering and organization',
          },
          'description': {'type': 'string'},
          'owner': {'type': 'string'},
          'priority': {
            'type': 'string',
            'enum': [
              'p0',
              'p1',
              'p2',
              'p3',
              'critical',
              'high',
              'medium',
              'low'
            ],
          },
          'parallel': {
            'type': 'boolean',
            'description':
                'Set false for tests that mutate shared external state and must not run in a parallel worker shard.',
          },
          'retry': {
            'type': 'integer',
            'minimum': 0,
            'description':
                'Number of additional attempts after the first failure.',
          },
          'startScreen': {
            'type': 'string',
            'minLength': 1,
            'description': 'Ensemble screen name or id to load first',
          },
          'startScreenInputs': {
            'type': 'object',
            'additionalProperties': true,
            'description': 'Inputs passed to startScreen',
          },
          'session': {
            'type': 'string',
            'minLength': 1,
            'description':
                'ID of a successful test whose captured app state is restored before startScreen',
          },
          'initialState': {'\$ref': '#/\$defs/initialState'},
          'setup': {
            'type': 'array',
            'minItems': 1,
            'items': {'\$ref': '#/\$defs/setupStep'},
            'description':
                'Headless httpRequest actions executed before startScreen mounts',
          },
          'mocks': {
            'oneOf': [
              {
                'type': 'array',
                'items': {
                  'oneOf': [
                    {'type': 'string', 'minLength': 1},
                    {'\$ref': '#/\$defs/inlineMocks'},
                  ],
                },
              },
              {'\$ref': '#/\$defs/inlineMocks'},
            ],
          },
          'scenarios': {
            'type': 'array',
            'items': {'\$ref': '#/\$defs/scenario'},
            'minItems': 1,
          },
          'steps': {
            'type': 'array',
            'minItems': 1,
            'items': {'\$ref': '#/\$defs/step'},
          },
        },
        'required': ['id', 'startScreen', 'steps'],
      },
    };

    // Register per-step arg defs and step wrappers.
    final stepOneOf = <Map<String, dynamic>>[];
    final registeredArgDefs = <String>{};
    final mocksSchema = Map<String, dynamic>.from(
        (defs['testCase'] as Map)['properties']['mocks']);

    for (final yamlKey in TestStepVocabulary.yamlStepKeys) {
      final entry = TestStepRegistry.entries[yamlKey]!;
      final description = entry.description;
      final argsSchema = yamlKey == 'mocks'
          ? mocksSchema
          : TestStepVocabulary.argJsonSchemaForYamlKey(yamlKey);
      final argsDefName = 'args_$yamlKey';

      final exampleArgs = Map<String, dynamic>.from(entry.example);
      final exampleStep = {yamlKey: exampleArgs};

      if (registeredArgDefs.add(argsDefName)) {
        defs[argsDefName] = {
          ...argsSchema,
          'title': yamlKey,
          'description': description,
          'examples': [exampleArgs],
        };
      }

      stepOneOf.add({
        'type': 'object',
        'title': yamlKey,
        'description': description,
        'examples': [exampleStep],
        'additionalProperties': false,
        'minProperties': 1,
        'maxProperties': 1,
        'properties': {
          yamlKey: {
            '\$ref': '#/\$defs/$argsDefName',
            'description': description,
            'examples': [exampleArgs],
          },
        },
        'required': [yamlKey],
      });
    }

    defs['step'] = {'oneOf': stepOneOf};
    defs['setupStep'] = {
      'oneOf': stepOneOf
          .where((step) =>
              step['title'] == 'httpRequest' ||
              step['title'] == 'group' ||
              step['title'] == 'optional')
          .toList(),
    };

    final testCase = defs.remove('testCase') as Map<String, dynamic>;

    return {
      '\$schema': schemaVersion,
      '\$id': schemaId,
      'title': 'Ensemble declarative test file',
      'description':
          'Schema for app-local tests/*.test.yaml — one test per file; '
              'see tools/ensemble_test_runner/STEP_VOCABULARY.md',
      ...testCase,
      '\$defs': defs,
    };
  }

  static String buildJson({bool pretty = true}) {
    final encoder =
        pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(build());
  }

  static Map<String, dynamic> buildConfig() {
    return {
      '\$schema': schemaVersion,
      '\$id': configSchemaId,
      'title': 'Ensemble declarative test config',
      'description': 'Suite-wide config for app-local tests/config.yaml',
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'services': {
          'type': 'array',
          'items': {
            'type': 'object',
            'additionalProperties': false,
            'required': ['name', 'command'],
            'properties': {
              'name': {'type': 'string'},
              'command': {'type': 'string'},
              'url': {'type': 'string', 'format': 'uri'},
              'arguments': {
                'type': 'array',
                'items': {'type': 'string'},
              },
              'workingDirectory': {'type': 'string'},
              'environment': {
                'type': 'object',
                'additionalProperties': {'type': 'string'},
              },
              'readyUrl': {'type': 'string'},
              'readyTimeoutMs': {'type': 'integer', 'minimum': 1},
            },
          },
        },
        'mocks': {
          'oneOf': [
            {
              'type': 'array',
              'items': {
                'oneOf': [
                  {'type': 'string', 'minLength': 1},
                  {'\$ref': '#/\$defs/inlineMocks'},
                ],
              },
            },
            {'\$ref': '#/\$defs/inlineMocks'},
          ],
          'description':
              'Suite-wide API mocks applied before each test file mocks',
        },
        'initialState': {
          '\$ref': '#/\$defs/initialState',
          'description':
              'Suite-wide storage/keychain/env applied before each test '
              'initialState. Test values override suite values per key.',
        },
        'devices': {
          'type': 'array',
          'description':
              'Suite device matrix. Each test runs once per entry with that '
              'platform/model viewport, optional locale (APP_LOCALE), and '
              'optional theme (EnsembleThemeManager Light/Dark). '
              'Multiple devices share one contact sheet per logical test id.',
          'items': {'\$ref': '#/\$defs/testDevice'},
        },
        'screenshots': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'enabled': {'type': 'boolean'},
            'includeSteps': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'excludeSteps': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
        },
        'performance': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'enabled': {'type': 'boolean'},
          },
        },
        'timers': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'enabled': {'type': 'boolean'},
            'maxStartAfterSeconds': {'type': 'integer', 'minimum': 0},
            'maxRepeatIntervalSeconds': {'type': 'integer', 'minimum': 0},
          },
        },
        'dumpTree': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'enabled': {'type': 'boolean'},
          },
        },
        'logApiCalls': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'enabled': {'type': 'boolean'},
          },
        },
        'logStorage': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'enabled': {'type': 'boolean'},
            'key': {'type': 'string'},
          },
        },
      },
      '\$defs': {
        'initialState': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'storage': {'type': 'object', 'additionalProperties': true},
            'keychain': {'type': 'object', 'additionalProperties': true},
            'env': {'type': 'object', 'additionalProperties': true},
          },
        },
        'testDevice': {
          'type': 'object',
          'additionalProperties': false,
          'required': ['platform', 'model'],
          'properties': {
            'id': {
              'type': 'string',
              'description':
                  'Stable id used in test ids when multiple devices are '
                  'configured (e.g. home[android_nl]). Defaults to '
                  'platform_locale.',
            },
            'platform': {'type': 'string'},
            'model': {'type': 'string'},
            'locale': {
              'type': 'string',
              'description':
                  'Sets APP_LOCALE / forcedLocale for this device run.',
            },
            'theme': {
              'type': 'string',
              'description':
                  'Ensemble theme for this device run (e.g. light/dark or '
                  'Light/Dark). Applied via EnsembleThemeManager for any '
                  'startScreen.',
            },
          },
        },
        'mockResponse': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'statusCode': {'type': 'integer'},
            'body': true,
            'headers': {'type': 'object', 'additionalProperties': true},
            'delayMs': {'type': 'integer', 'minimum': 0},
            'responses': {
              'type': 'array',
              'minItems': 1,
              'items': {'\$ref': '#/\$defs/mockResponse'},
            },
          },
        },
        'inlineMocks': {
          'type': 'object',
          'additionalProperties': {'\$ref': '#/\$defs/mockResponse'},
        },
      },
    };
  }

  static String buildConfigJson({bool pretty = true}) {
    final encoder =
        pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(buildConfig());
  }
}
