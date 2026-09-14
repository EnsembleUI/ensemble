# ensemble_agent

Provider-independent Flutter runtime for **on-device AI agents**.

This package owns local-model integrations, sessions, tool calling, streaming,
capability detection, lifecycle/cancellation, and standardized errors. It does
**not** know about Ensemble YAML, Chat widgets, or actions such as `invokeAPI`.

## Install

```yaml
dependencies:
  ensemble_agent: ^0.1.0
```

From the Ensemble Melos workspace:

```bash
melos bootstrap
```

## Quick start

```dart
import 'package:ensemble_agent/ensemble_agent.dart';

final provider = await LocalModelProvider.system();

final agent = EnsembleAgent(
  provider: provider,
  instructions: 'You are a network diagnostics assistant.',
  tools: [
    AgentTool(
      name: 'getDevices',
      description: 'List parental-control devices.',
      inputSchema: {
        'includeOffline': {'type': 'boolean'},
      },
    ),
  ],
  onToolCall: (call) async {
    // Consumer executes the tool (e.g. ensemble_chat runs an Ensemble action).
    return ToolResult.success(data: {'devices': []});
  },
);

final session = agent.createSession();
await for (final event in session.sendStream(AgentInput.text('Why is Wi-Fi slow?'))) {
  switch (event) {
    case AgentTextDelta(:final delta):
      print(delta);
    case AgentCompleted(:final result):
      print(result.text);
    case AgentFailed(:final error):
      print(error);
    default:
      break;
  }
}
```

## Capabilities

```dart
final caps = await EnsembleAgentCapabilities.current();
if (!caps.available) {
  // Show fallback UI using caps.unavailableReason
}
```

| Field | Meaning |
|-------|---------|
| `toolCalling` | Effective: runtime can run tools (Path A and/or Path B) |
| `nativeToolCalling` | Provider has a native function-calling API |

## Platform tool matrix

| Platform | Model | `nativeToolCalling` | How tools run |
|----------|-------|---------------------|---------------|
| iOS | Apple Foundation Models | `true` when available | Path A (native tools; generate still gated until wired) |
| Android | Gemini Nano (ML Kit GenAI Prompt API) | `false` | **Path B** — Ensemble JSON tool protocol in Dart |
| Other | — | `false` | Unavailable |

Android does **not** use `flutter_local_ai` or downloaded Gemma weights. The
Kotlin plugin talks to `com.google.mlkit:genai-prompt` for text generate/stream
only; the Dart agent loop owns tool orchestration via Path B:

```json
{"type":"tool_call","id":"call_1","name":"getDevices","arguments":{...}}
```

or

```json
{"type":"final","text":"..."}
```

## Boundary with ensemble_chat

| Package | Owns |
|---------|------|
| `ensemble_agent` | Local models, agent loop, sessions, tool protocol, streaming, errors |
| `ensemble_chat` | EDL Chat UI, mapping tool calls → Ensemble actions, message rendering |

`ensemble_agent` never imports `ensemble_chat`. Chat (or another host) maps YAML
tool definitions to `AgentTool` and supplies `onToolCall`.

## Providers

- `LocalModelProvider.system()` — Apple Foundation Models on iOS, Gemini Nano on Android
- `FakeLocalModelProvider` — deterministic provider for unit tests
- `PlatformLocalModelProvider` — method-channel bridge to native plugins

Native adapters degrade cleanly when the OS/model is unavailable, returning
standardized `unavailableReason` values.

## License

MIT
