# ensemble_chat

`ensemble_chat` provides an Ensemble chat widget with local message handling and optional OpenAI-backed completion support.

## Overview

This is an optional Ensemble widget module. `EnsembleChatImpl` extends `EnsembleWidget` and renders `ChatPage`, while `EnsembleChatController` exposes setters, methods, callbacks, and OpenAI configuration used by Ensemble screens.

## Features

- Maintains chat messages through `initialMessages`, `addMessage`, `sendMessage`, and `getMessages`.
- Supports `local` and `server` chat modes.
- Dispatches `onMessageSend` and `onMessageReceived` Ensemble actions.
- Supports assistant inline widgets and action tools from the verified `config.inlineWidgets` and `config.actions` fields.
- Provides bubble, text field, loading, and background style setters.

## Installation / Setup

From the repository root:

```bash
melos bootstrap
```

## Usage

The verified controller methods are `addMessage`, `sendMessage`, and `getMessages`. A complete, checked Ensemble YAML example was not found in this package.

Usage examples are not currently available in this package. See the source files under `lib/` for implementation details.

## Configuration

The `config` setter creates an OpenAI client when provided. Verified keys in `ensemble_chat.dart` are:

- `apiKey` (required when `config` is used)
- `model` (defaults to `gpt-3.5-turbo`)
- `temperature` (defaults to `1.0`)
- `systemPrompt` (defaults to `You are a helpful assistant`)
- `inlineWidgets`
- `actions`

Keep API keys out of client-side definitions unless the host app has an approved secret-handling strategy.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android  | Unknown | Flutter widget package; no platform folder or plugin declaration was found. |
| iOS      | Unknown | Flutter widget package; no platform folder or plugin declaration was found. |
| Web      | Unknown | Not verified from source. |
| macOS    | Unknown | Not verified from source. |
| Windows  | Unknown | Not verified from source. |
| Linux    | Unknown | Not verified from source. |

## Permissions

No runtime permissions were found in this package. The package performs network calls through `http` and the OpenAI helper when configured.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `EnsembleChatImpl` | Widget | Ensemble chat widget implementation. |
| `EnsembleChatController` | Controller | Stores messages, configuration, callbacks, styling, and invokable methods. |
| `ChatPage` | Widget | Flutter chat UI used by the Ensemble widget. |
| `InternalMessage` | Model | Internal message model with role, content, inline widget, and visibility metadata. |
| `ChatType` | Enum | Supports `local` and `server` modes. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_chat" -- flutter analyze
melos exec --scope="ensemble_chat" -- flutter test
```

## Testing

No package-specific tests were found.

## Related Packages / Modules

- `ensemble` provides widget, action, event, and screen-controller APIs.
- `ensemble_ts_interpreter` is listed as a dependency.
- `http` and `dart_openai` support remote completion behavior.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
