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

The widget is exposed to Ensemble as `Chat` through `EnsembleChatImpl.type`. A complete YAML example was not found in this package, so no YAML syntax is documented here. Usage examples are not currently available in this package. See the source files under `lib/` for implementation details.

## Configuration

No package-level configuration files were found. Any API keys or backend endpoints used by chat flows should be verified from the host app or Ensemble app definition before documenting them here.

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

No package-specific tests were found.

## Related Packages / Modules

- `ensemble`: the core runtime resolves `EnsembleChat` from its widget registry.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
