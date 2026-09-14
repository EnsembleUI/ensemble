import 'package:ensemble_chat/helpers/chat_tools.dart';
import 'package:ensemble_chat/helpers/openai.dart';
import 'package:ensemble_chat/ensemble_chat.dart';
import 'package:ensemble/framework/tool_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('allows a confirmation widget to own the complete tool flow', () {
    final controller = EnsembleChatController();

    controller.setters()['config']!({
      'apiKey': 'test-key',
      'tools': [
        {
          'name': 'review_change',
          'description': 'Review and apply a change.',
          'inputs': <String, dynamic>{},
          'options': {
            'confirmation': {'widget': 'ReviewChange'}
          },
        }
      ],
    });

    expect(controller.toolDefinitions['review_change']?.action, isNull);
  });

  test('parses deferred top-level app tools', () {
    final controller = EnsembleChatController();

    controller.setters()['config']!({'apiKey': 'test-key'});
    controller.setters()['tools']!([
      {
        'name': 'get_devices',
        'description': 'Get devices.',
        'inputs': <String, dynamic>{},
        'action': {
          'invokeAPI': {
            'name': 'getDevices',
            'onResponse': {
              'respondToTool': {
                'status': 'success',
                'data': r'${sanitizeDevices(response.body)}',
              },
            },
          },
        },
      }
    ]);

    expect(controller.toolDefinitions, contains('get_devices'));
    expect(controller.toolDefinitions['get_devices']?.action, isNotNull);
  });

  test('keeps top-level tools out of eager scope evaluation', () {
    final controller = EnsembleChatController();

    expect(controller.passthroughSetters(), contains('tools'));
    expect(controller.passthroughSetters(), isNot(contains('config')));
  });

  test('keeps pending tool responses on the controller until completion',
      () async {
    final controller = EnsembleChatController();
    final responseFuture = controller.waitForToolResponse('call-pending');

    expect(controller.hasPendingToolResponse('call-pending'), isTrue);

    final delivered = await EnsembleToolResponseDispatcher.instance.tryRespond(
      const EnsembleToolResponse(
        callId: 'call-pending',
        status: 'approved',
      ),
    );
    final response = await responseFuture;

    expect(delivered, isTrue);
    expect(response.status, 'approved');
    expect(controller.hasPendingToolResponse('call-pending'), isTrue);

    controller.removePendingToolResponse('call-pending');
    expect(controller.hasPendingToolResponse('call-pending'), isFalse);
  });

  test('builds an OpenAI schema with explicit required inputs', () {
    final definition = ChatToolDefinition(
      name: 'get_devices',
      description: 'Get devices.',
      kind: ChatToolKind.appTool,
      inputs: {
        'includeOffline': {
          'type': 'boolean',
          'required': false,
          'default': false,
        },
        'customerId': {
          'type': 'string',
          'required': true,
        },
      },
    );

    final function = definition.toOpenAITool()['function'] as Map;
    final parameters = function['parameters'] as Map;
    expect(parameters['required'], ['customerId']);
    expect(parameters['additionalProperties'], false);
    expect((parameters['properties'] as Map)['includeOffline'], {
      'type': 'boolean',
    });
  });

  test('keeps array item schemas valid while lifting required metadata', () {
    final definition = ChatToolDefinition(
      name: 'choose_devices',
      description: 'Choose matching devices.',
      kind: ChatToolKind.appTool,
      inputs: {
        'devices': {
          'type': 'array',
          'required': true,
          'minItems': 1,
          'items': {
            'type': 'object',
            'properties': {
              'ref': {'type': 'string'},
              'name': {'type': 'string'},
            },
            'required': ['ref', 'name'],
          },
        },
      },
    );

    final function = definition.toOpenAITool()['function'] as Map;
    final parameters = function['parameters'] as Map;
    final devices = (parameters['properties'] as Map)['devices'] as Map;

    expect(parameters['required'], ['devices']);
    expect(devices['required'], isNull);
    expect((devices['items'] as Map)['required'], ['ref', 'name']);
  });

  test('applies defaults and rejects unknown inputs', () {
    final definition = ChatToolDefinition(
      name: 'get_devices',
      description: 'Get devices.',
      kind: ChatToolKind.appTool,
      inputs: {
        'includeOffline': {
          'type': 'boolean',
          'default': false,
        },
      },
    );

    expect(definition.prepareInputs({}), {'includeOffline': false});
    expect(
      () => definition.prepareInputs({'unexpected': true}),
      throwsFormatException,
    );
  });

  test('validates nested objects, arrays, enums, and numeric bounds', () {
    final definition = ChatToolDefinition(
      name: 'prepare_limit',
      description: 'Prepare a time limit.',
      kind: ChatToolKind.appTool,
      inputs: {
        'devices': {
          'type': 'array',
          'required': true,
          'minItems': 1,
          'uniqueItems': true,
          'items': {
            'type': 'object',
            'properties': {
              'ref': {'type': 'string', 'minLength': 1},
              'kind': {
                'type': 'string',
                'enum': ['computer', 'phone'],
              },
            },
            'required': ['ref', 'kind'],
            'additionalProperties': false,
          },
        },
        'durationMinutes': {
          'type': 'integer',
          'required': true,
          'minimum': 1,
          'maximum': 1440,
        },
      },
    );

    expect(
      definition.prepareInputs({
        'devices': [
          {'ref': 'device-r1', 'kind': 'computer'}
        ],
        'durationMinutes': 120,
      }),
      {
        'devices': [
          {'ref': 'device-r1', 'kind': 'computer'}
        ],
        'durationMinutes': 120,
      },
    );
    expect(
      () => definition.prepareInputs({
        'devices': [
          {'ref': '', 'kind': 'router'}
        ],
        'durationMinutes': 0,
      }),
      throwsFormatException,
    );
    expect(
      () => definition.prepareInputs({
        'devices': <dynamic>[],
        'durationMinutes': 120,
      }),
      throwsFormatException,
    );
    expect(
      () => definition.prepareInputs({
        'devices': [
          {'ref': 'device-r1', 'kind': 'computer', 'mac': 'secret'}
        ],
        'durationMinutes': 120,
      }),
      throwsFormatException,
    );
  });

  test('parses all model tool calls', () {
    final call = ChatToolCall.fromOpenAI({
      'id': 'call-1',
      'function': {
        'name': 'get_devices',
        'arguments': '{"includeOffline":true}',
      }
    });

    expect(call.id, 'call-1');
    expect(call.name, 'get_devices');
    expect(call.inputs, {'includeOffline': true});
  });

  test('omits null assistant content when replaying tool calls', () {
    final assistantMessage = InternalMessage(
      role: MessageRole.assistant,
      visible: false,
    )..rawResponse = {
        'message': {
          'role': 'assistant',
          'content': null,
          'tool_calls': [
            {
              'id': 'call-1',
              'type': 'function',
              'function': {
                'name': 'get_devices',
                'arguments': '{}',
              },
            }
          ],
        },
      };
    assistantMessage.toolResults.add(ChatToolResult(
      callId: 'call-1',
      name: 'get_devices',
      status: 'success',
      data: const {'devices': <dynamic>[]},
    ));
    final client = OpenAIClient(
      model: 'gpt-5.6-luna',
      temperature: 0.2,
      systemPrompt: 'Test assistant.',
      apiKey: 'test-key',
      getMessages: () => [assistantMessage],
    );

    final messages = client.buildRequestData('')['messages'] as List;
    final replayedAssistant = messages[1] as Map<String, dynamic>;

    expect(replayedAssistant['role'], 'assistant');
    expect(replayedAssistant, contains('tool_calls'));
    expect(replayedAssistant, isNot(contains('content')));
  });

  test('preserves string assistant content when replaying tool calls', () {
    final assistantMessage = InternalMessage(
      role: MessageRole.assistant,
      visible: true,
    )..rawResponse = {
        'message': {
          'role': 'assistant',
          'content': 'I will check that.',
          'tool_calls': [
            {
              'id': 'call-1',
              'type': 'function',
              'function': {
                'name': 'get_devices',
                'arguments': '{}',
              },
            }
          ],
        },
      };
    final client = OpenAIClient(
      model: 'gpt-5.6-luna',
      temperature: 0.2,
      systemPrompt: 'Test assistant.',
      apiKey: 'test-key',
      getMessages: () => [assistantMessage],
    );

    final messages = client.buildRequestData('')['messages'] as List;
    final replayedAssistant = messages[1] as Map<String, dynamic>;

    expect(replayedAssistant['content'], 'I will check that.');
  });

  test('explicitly disables reasoning effort for tool-enabled requests', () {
    final client = OpenAIClient(
      model: 'gpt-5.6-luna',
      temperature: 0.2,
      reasoningEffort: 'high',
      tools: [
        {
          'type': 'function',
          'function': {
            'name': 'get_devices',
            'description': 'Get devices.',
            'parameters': {
              'type': 'object',
              'properties': <String, dynamic>{},
            },
          },
        },
      ],
      systemPrompt: 'Test assistant.',
      apiKey: 'test-key',
      getMessages: () => [],
    );

    final payload = client.buildRequestData('');

    expect(payload['reasoning_effort'], 'none');
  });
}
