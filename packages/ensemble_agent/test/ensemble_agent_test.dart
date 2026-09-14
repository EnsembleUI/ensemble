import 'package:ensemble_agent/ensemble_agent.dart';
import 'package:ensemble_agent/src/runtime/tool_call_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ToolCallProtocol', () {
    const tools = {'getWifiInfo', 'getDevices'};

    test('parses tool_call', () {
      final parsed = ToolCallProtocol.parse(
        '{"type":"tool_call","id":"c1","name":"getWifiInfo","arguments":{"band":"5g"}}',
        allowedToolNames: tools,
      );
      expect(parsed, isA<ProtocolToolCall>());
      final call = (parsed as ProtocolToolCall).call;
      expect(call.id, 'c1');
      expect(call.name, 'getWifiInfo');
      expect(call.arguments['band'], '5g');
    });

    test('parses final', () {
      final parsed = ToolCallProtocol.parse(
        '{"type":"final","text":"All good"}',
        allowedToolNames: tools,
      );
      expect(parsed, isA<ProtocolFinal>());
      expect((parsed as ProtocolFinal).text, 'All good');
    });

    test('parses fenced JSON', () {
      final parsed = ToolCallProtocol.parse(
        '```json\n{"type":"final","text":"ok"}\n```',
        allowedToolNames: tools,
      );
      expect((parsed as ProtocolFinal).text, 'ok');
    });

    test('rejects prose', () {
      expect(
        () => ToolCallProtocol.parse(
          'Sure, I will check your Wi-Fi.',
          allowedToolNames: tools,
        ),
        throwsA(isA<ProtocolParseException>()),
      );
    });

    test('rejects unknown tool', () {
      expect(
        () => ToolCallProtocol.parse(
          '{"type":"tool_call","id":"1","name":"hack","arguments":{}}',
          allowedToolNames: tools,
        ),
        throwsA(isA<ProtocolParseException>()),
      );
    });
  });

  group('EnsembleAgent with FakeLocalModelProvider', () {
    test('run returns final text without tools', () async {
      final provider = FakeLocalModelProvider(
        turns: [
          const FakeModelTurn(text: 'Hello from the local model.'),
        ],
      );
      final agent = EnsembleAgent(
        provider: provider,
        instructions: 'You are helpful.',
      );

      final result = await agent.run(AgentInput.text('Hi'));

      expect(result.text, 'Hello from the local model.');
      expect(result.finishReason, AgentFinishReason.completed);
      expect(provider.remainingTurns, 0);
    });

    test('structured toolCalls invoke handler and continue', () async {
      final provider = FakeLocalModelProvider(
        turns: [
          const FakeModelTurn(
            toolCalls: [
              ToolCall(
                id: 'call_1',
                name: 'getDevices',
                arguments: {'includeOffline': true},
              ),
            ],
          ),
          const FakeModelTurn(
            text: '{"type":"final","text":"Found 2 devices."}',
          ),
        ],
      );

      ToolCall? seen;
      final agent = EnsembleAgent(
        provider: provider,
        tools: const [
          AgentTool(
            name: 'getDevices',
            description: 'List devices',
            inputSchema: {
              'includeOffline': {'type': 'boolean'},
            },
          ),
        ],
        onToolCall: (call) async {
          seen = call;
          return ToolResult.success(data: {
            'devices': ['a', 'b'],
          });
        },
      );

      final result = await agent.run(AgentInput.text('List devices'));

      expect(seen?.name, 'getDevices');
      expect(seen?.arguments['includeOffline'], true);
      expect(result.text, 'Found 2 devices.');
    });

    test('Path B JSON tool_call then final', () async {
      final provider = FakeLocalModelProvider(
        turns: [
          const FakeModelTurn(
            text:
                '{"type":"tool_call","id":"c1","name":"getDevices","arguments":{"includeOffline":false}}',
          ),
          const FakeModelTurn(
            text: '{"type":"final","text":"One device online."}',
          ),
        ],
      );

      ToolCall? seen;
      final agent = EnsembleAgent(
        provider: provider,
        tools: const [
          AgentTool(
            name: 'getDevices',
            description: 'List devices',
            inputSchema: {
              'includeOffline': {'type': 'boolean'},
            },
          ),
        ],
        onToolCall: (call) async {
          seen = call;
          return ToolResult.success(data: {
            'devices': ['gw'],
          });
        },
      );

      final result = await agent.run(AgentInput.text('Check devices'));
      expect(seen?.name, 'getDevices');
      expect(seen?.arguments['includeOffline'], false);
      expect(result.text, 'One device online.');
    });

    test('stream emits text deltas and completed', () async {
      final provider = FakeLocalModelProvider(
        turns: [
          const FakeModelTurn(
            text: 'Hello world',
            textDeltas: ['Hello ', 'world'],
          ),
        ],
      );
      final agent = EnsembleAgent(provider: provider);

      final events = await agent.stream(AgentInput.text('Hi')).toList();

      expect(events.whereType<AgentStarted>(), isNotEmpty);
      expect(
        events.whereType<AgentTextDelta>().map((e) => e.delta).toList(),
        ['Hello ', 'world'],
      );
      final completed = events.whereType<AgentCompleted>().single;
      expect(completed.result.text, 'Hello world');
    });

    test('maxToolCalls stops the loop', () async {
      final provider = FakeLocalModelProvider(
        turns: [
          const FakeModelTurn(
            toolCalls: [
              ToolCall(id: '1', name: 'ping', arguments: {}),
            ],
          ),
          const FakeModelTurn(
            toolCalls: [
              ToolCall(id: '2', name: 'ping', arguments: {}),
            ],
          ),
        ],
      );
      final agent = EnsembleAgent(
        provider: provider,
        tools: const [
          AgentTool(name: 'ping', description: 'Ping'),
        ],
        options: const AgentOptions(maxToolCalls: 1, maxIterations: 5),
        onToolCall: (_) async => ToolResult.success(data: {'ok': true}),
      );

      final events = await agent.stream(AgentInput.text('loop')).toList();
      final failed = events.whereType<AgentFailed>().single;
      expect(failed.error, isA<AgentLoopLimitException>());
    });

    test('missing onToolCall fails when model requests a tool', () async {
      final provider = FakeLocalModelProvider(
        turns: [
          const FakeModelTurn(
            toolCalls: [
              ToolCall(id: '1', name: 'ping', arguments: {}),
            ],
          ),
        ],
      );
      final agent = EnsembleAgent(
        provider: provider,
        tools: const [AgentTool(name: 'ping', description: 'Ping')],
      );

      final events = await agent.stream(AgentInput.text('tool')).toList();
      final failed = events.whereType<AgentFailed>().single;
      expect(failed.error, isA<ToolExecutionException>());
    });

    test('session retains conversation history across turns', () async {
      final provider = FakeLocalModelProvider(
        turns: [
          const FakeModelTurn(text: 'First'),
          const FakeModelTurn(text: 'Second'),
        ],
      );
      final agent = EnsembleAgent(provider: provider);
      final session = agent.createSession();

      await session.send(AgentInput.text('one'));
      await session.send(AgentInput.text('two'));

      expect(session.history.length, greaterThanOrEqualTo(4));
      expect(session.history.first.role, ModelMessageRole.user);
    });

    test('reject concurrency throws when session is busy', () async {
      final provider = FakeLocalModelProvider(
        turns: [
          const FakeModelTurn(
            text: 'slow',
            textDeltas: ['a', 'b', 'c'],
          ),
        ],
      );
      final agent = EnsembleAgent(
        provider: provider,
        options: const AgentOptions(
          concurrency: AgentConcurrencyPolicy.reject,
        ),
      );
      final session = agent.createSession();

      final first = session.sendStream(AgentInput.text('1'));
      final sub = first.listen((_) {});
      await Future<void>.delayed(Duration.zero);

      expect(
        () => session.send(AgentInput.text('2')),
        throwsA(isA<AgentBusyException>()),
      );

      await sub.cancel();
    });

    test('unavailable provider surfaces AgentFailed', () async {
      final provider = FakeLocalModelProvider(
        capabilities: const AgentCapabilities(
          available: false,
          unavailableReason: AgentUnavailableReason.unsupportedDevice,
        ),
        turns: [const FakeModelTurn(text: 'unused')],
      );
      final agent = EnsembleAgent(provider: provider);

      final events = await agent.stream(AgentInput.text('Hi')).toList();
      final failed = events.whereType<AgentFailed>().single;
      expect(failed.error, isA<AgentUnavailableException>());
    });

    test('tool error result is passed back as ToolResult.error', () async {
      final provider = FakeLocalModelProvider(
        turns: [
          const FakeModelTurn(
            toolCalls: [
              ToolCall(id: '1', name: 'broken', arguments: {}),
            ],
          ),
          const FakeModelTurn(
            text: '{"type":"final","text":"Handled the error."}',
          ),
        ],
      );
      final agent = EnsembleAgent(
        provider: provider,
        tools: const [AgentTool(name: 'broken', description: 'Broken')],
        onToolCall: (_) async => ToolResult.error(
          code: 'gateway_unavailable',
          message: 'down',
          retryable: true,
        ),
      );

      final result = await agent.run(AgentInput.text('go'));
      expect(result.text, 'Handled the error.');
    });
  });

  group('AgentCapabilities', () {
    test('fromMap parses nativeToolCalling and unavailable reason', () {
      final caps = AgentCapabilities.fromMap({
        'available': true,
        'provider': 'gemini_nano',
        'toolCalling': true,
        'nativeToolCalling': false,
        'unavailableReason': null,
      });
      expect(caps.available, isTrue);
      expect(caps.toolCalling, isTrue);
      expect(caps.nativeToolCalling, isFalse);

      final downloading = AgentCapabilities.fromMap({
        'available': false,
        'unavailableReason': 'modelDownloading',
      });
      expect(
        downloading.unavailableReason,
        AgentUnavailableReason.modelDownloading,
      );
    });
  });

  group('LocalModelProvider.system override', () {
    tearDown(() {
      LocalModelProviderFactory.debugSetSystemProvider(null);
    });

    test('debug override is used by system()', () async {
      final fake = FakeLocalModelProvider();
      LocalModelProviderFactory.debugSetSystemProvider(() async => fake);

      final provider = await LocalModelProvider.system();
      expect(provider.id, 'fake');

      final caps = await EnsembleAgentCapabilities.current();
      expect(caps.provider, 'fake');
      expect(caps.available, isTrue);
    });
  });
}
