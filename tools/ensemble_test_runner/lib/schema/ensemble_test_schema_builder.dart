import 'dart:convert';

import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';

/// Builds JSON Schema for app-local `tests/*.test.yaml` files.
class EnsembleTestSchemaBuilder {
  static const schemaId =
      'https://cdn.ensembleui.com/schemas/ensemble_tests_schema.json';
  static const schemaVersion = 'https://json-schema.org/draft/2020-12/schema';

  static Map<String, dynamic> build() {
    final defs = <String, dynamic>{
      'mockResponse': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'statusCode': {'type': 'integer'},
          'body': true,
          'headers': {
            'type': 'object',
            'additionalProperties': true,
          },
        },
      },
      'mockApiEntry': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'response': {'\$ref': '#/\$defs/mockResponse'},
          'delayMs': {'type': 'integer'},
        },
        'required': ['response'],
      },
      'initialState': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'storage': {'type': 'object', 'additionalProperties': true},
          'keychain': {'type': 'object', 'additionalProperties': true},
          'env': {'type': 'object', 'additionalProperties': true},
        },
      },
      'mocks': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'apis': {
            'type': 'object',
            'additionalProperties': {'\$ref': '#/\$defs/mockApiEntry'},
          },
        },
      },
      'options': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'screenshots': {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'enabled': {'type': 'boolean'},
              'platform': {'type': 'string'},
              'model': {'type': 'string'},
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
        },
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
          'startScreen': {
            'type': 'string',
            'minLength': 1,
            'description': 'Ensemble screen name or id to load first',
          },
          'prerequisite': {
            'type': 'string',
            'minLength': 1,
            'description':
                'ID of another test that must run before this one in the same app session',
          },
          'initialState': {'\$ref': '#/\$defs/initialState'},
          'options': {'\$ref': '#/\$defs/options'},
          'mocks': {'\$ref': '#/\$defs/mocks'},
          'steps': {
            'type': 'array',
            'minItems': 1,
            'items': {'\$ref': '#/\$defs/step'},
          },
        },
        'required': ['id', 'steps'],
        'oneOf': [
          {
            'required': ['startScreen'],
            'not': {
              'required': ['prerequisite'],
            },
          },
          {
            'required': ['prerequisite'],
            'not': {
              'required': ['startScreen'],
            },
          },
        ],
      },
    };

    // Register per-step arg defs and step wrappers.
    final stepOneOf = <Map<String, dynamic>>[];
    final registeredArgDefs = <String>{};

    for (final yamlKey in TestStepVocabulary.yamlStepKeys) {
      final entry = TestStepRegistry.entries[yamlKey]!;
      final description = entry.description;
      final argsSchema = TestStepVocabulary.argJsonSchemaForYamlKey(yamlKey);
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
}
