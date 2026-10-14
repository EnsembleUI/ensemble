# ensemble_chat

`ensemble_chat` provides the Ensemble `Chat` widget implementation used by the core runtime when chat support is registered.

## Overview

This is an optional Ensemble module. `lib/ensemble_chat.dart` implements `EnsembleChatImpl` and `EnsembleChatController`; helper files provide message models, bubble UI, typing indicators, and an OpenAI client helper.

## Features

- Implements the Ensemble widget type `Chat`.
- Supports local chat state through `EnsembleChatController` and `ChatPage`.
- Includes helper models for messages and users.
- Includes an OpenAI helper client and WebSocket-related dependencies used by the implementation.

## Installation / Setup

Use this package from inside the Melos workspace:

```bash
melos bootstrap
```

## Usage

The widget is exposed to Ensemble as `Chat` through `EnsembleChatImpl.type`.

Local chat can expose semantic app tools to the model. The model chooses a
tool and its inputs, while the Ensemble action performs the operation and must
finish it with `respondToTool`:

```yaml
Chat:
  config:
    apiKey: ${secrets.openAiApiKey}
    model: gpt-4o-mini
    systemPrompt: You are a helpful assistant.
    maxToolSteps: 8
  tools:
    - name: get_parental_control_devices
      description: Get parental-control devices from the local gateway.
      inputs:
        includeOffline:
          type: boolean
          required: false
          default: false
      options:
        access: read
        timeout: 15
      action:
        invokeAPI:
          name: getDevices
          inputs:
            includeOffline: ${tool.inputs.includeOffline}
          onResponse:
            respondToTool:
              status: success
              data:
                devices: ${sanitizeDevices(response.body)}
          onError:
            respondToTool:
              status: error
              error:
                code: gateway_unavailable
                message: Unable to retrieve devices.
                retryable: true
```

Top-level `tools` is a pass-through property: expressions inside tool actions
are evaluated only when that action runs. `config.tools` remains supported for
backward compatibility, but should only be used when its definitions contain no
action-scoped expressions such as `tool`, `response`, or `event`.

`tool.inputs` is isolated to the active call. The supported terminal statuses
are `success`, `error`, and `cancelled`. `approved` is reserved for confirmation
widgets. Tool inputs are validated recursively before execution, including
nested object requirements, array bounds, enums, string lengths, and numeric
bounds. The composer remains disabled while a tool call is pending so chat
turns cannot overlap.

For write operations, set `options.access` to `write` or `destructive`.
Ensemble displays a built-in confirmation dialog by default. To use an inline
confirmation widget instead:

```yaml
options:
  access: write
  confirmation:
    widget: ConfirmGatewayChange
```

The widget receives the active call as `tool`. If it only confirms execution of
the tool's configured `action`, return `approved`:

```yaml
Button:
  label: Continue
  onTap:
    respondToTool:
      status: approved
```

If the confirmation widget owns a multi-screen flow, it may navigate directly
without responding. The widget remains pending while the user moves between
screens. The screen that actually finishes the operation returns the terminal
result using the original call ID; no separate tool `action` is required:

```yaml
options:
  access: write
  timeout: 3600
  confirmation:
    widget: ConfirmGatewayChange

# On the destination screen, after the operation actually completes:
respondToTool:
  callId: ${originatingToolCallId}
  status: success
  data:
    applied: true
```

## Configuration

`inlineWidgets` and `actions` remain supported for existing applications.
Use `tools` for operations whose result must be returned to the model before it
continues the conversation.

Feedback controls are enabled for completed assistant messages by default.
Feedback is stored on the message and can be forwarded to any backend with an
Ensemble action:

```yaml
Chat:
  feedback:
    enabled: true
    onSubmit:
      invokeAPI:
        name: submitChatFeedback
        inputs:
          messageId: ${event.data.messageId}
          rating: ${event.data.rating}
```

`rating` is `positive`, `negative`, or `null` when the user clears a previous
selection. The widget intentionally exposes only like and dislike controls.
Feedback is attached to the complete assistant message, so a
message containing text and an inline widget still has only one feedback row.
Static `initialMessages` do not show feedback unless a message explicitly sets
`feedbackEligible: true`. Interactive assistant widgets, including proposal and
confirmation cards, remain feedback eligible.

For Chat Completions requests containing tools, the client explicitly sends
`reasoning_effort: none`. This is required by models such as Luna, whose default
reasoning effort is not compatible with function tools on that endpoint.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android | Unknown | No Android project is included in this package; host app setup is required. |
| iOS | Unknown | No iOS project is included in this package; host app setup is required. |
| Web | Unknown | No web implementation was found in this package. |
| macOS | Unknown | No macOS project is included in this package. |
| Windows | Unknown | No Windows project is included in this package. |
| Linux | Unknown | No Linux project is included in this package. |

## Permissions

No runtime permissions were found in this package.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `EnsembleChatImpl` | Widget | Ensemble widget implementation for the `Chat` type. |
| `EnsembleChatController` | Controller | Holds chat widget state and configurable properties. |
| `ChatPage` | Widget | Flutter UI used by the chat implementation. |
| `OpenAIClient` | Class | Helper client used by the package's OpenAI integration code. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_chat" -- flutter analyze
melos exec --scope="ensemble_chat" -- flutter test
```

## Testing

The package includes focused tests for tool schemas, validation, and OpenAI tool
call decoding.

## Related Packages / Modules

- `ensemble`: the core runtime resolves `EnsembleChat` from its widget registry.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
