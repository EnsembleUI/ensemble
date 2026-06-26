# Reusable Actions

This document describes **reusable Actions** in Ensemble: named, parameterized
workflows you can call from any screen with `executeAction`. Implementation
lives in `lib/action/execute_action.dart`, `lib/action/action_scope_util.dart`,
and `lib/page_model.dart`.

Reusable Actions are similar to custom widgets: they support scoped
`Import`, `Global`, and `API` blocks, plus **events** for communicating
results back to the caller.

## Overview

| Concept | Description |
| --- | --- |
| **App-level Action** | YAML file under `actions/` in a local app, or an entry in the Studio `resources` artifact `Actions` map |
| **Page-level Action** | `Action:` block defined inline on a screen YAML |
| **Invocation** | `executeAction` with a `name`, optional `inputs`, and optional `events` |
| **Scope** | Each run creates a child scope with its own inputs, imports, APIs, and global code |

Page-level Actions override app-level Actions when both share the same name.

## Minimal example

**`actions/showMessage.yaml`**

```yaml
Action:
  inputs:
    - message
  body:
    showToast:
      message: ${message}
```

**Screen**

```yaml
Button:
  label: Greet
  onTap:
    executeAction:
      name: showMessage
      inputs:
        message: Hello ${ensemble.storage.helloApp.name.first}
```

## Action definition structure

A reusable Action requires a `body` — a single Ensemble action (or action
group). Optional fields:

| Field | Description |
| --- | --- |
| `inputs` | List of parameter names passed in at call time |
| `events` | Declares events the action can dispatch (documentation + Studio hints) |
| `body` | The action tree to execute (required) |

### App-level file layout

For local apps, each Action is a separate file. The file can use a top-level
`Action:` wrapper with sibling resource blocks:

```yaml
Import:
  - common

Global: |-
  function formatUserName(user) {
    return user.firstName + ' ' + user.lastName;
  }

API:
  getUser:
    url: ${env.apiURL}/users/${userId}
    method: GET

Action:
  inputs:
    - userId
  events:
    onSuccess:
      data:
        user: object
  body:
    invokeAPI:
      name: getUser
```

`Import`, `Global`, and `API` at the file root are merged into the Action
definition at load time (same pattern as custom widgets).

### Page-level layout

Define Actions directly on a screen:

```yaml
View:
  body:
    Button:
      label: Fetch
      onTap:
        executeAction:
          name: callAPI
          inputs:
            call: true

Action:
  callAPI:
    inputs:
      - call
    body:
      executeConditionalAction:
        conditions:
          - if: ${call == true}
            action:
              invokeAPI:
                name: mockAPI

API:
  mockAPI:
    url: ${env.apiURL}/users/1
    method: GET
```

## Calling a reusable Action

Use the `executeAction` action:

```yaml
executeAction:
  name: fetchUser          # required — action name
  inputs:                  # optional — maps to declared input parameters
    userId: 1
  events:                  # optional — handlers for events dispatched by the action
    onSuccess:
      showToast:
        message: Loaded ${event.data.user.firstName}
    onError:
      showToast:
        message: ${event.data.message}
```

| Field | Required | Description |
| --- | --- | --- |
| `name` | Yes | Name of the reusable Action |
| `inputs` | No | Key/value map of input parameters |
| `events` | No | Event handlers (see below) |

Input values support data bindings (`${...}`) and are evaluated in the
caller's scope before being passed into the action.

## Events

Events let a reusable Action communicate results to its caller without
writing to `ensemble.storage`. The pattern matches custom widget events.

### 1. Declare events on the Action

```yaml
Action:
  events:
    onSuccess:
      data:
        user: object
    onError:
      data:
        message: string
```

Event declarations describe the payload shape. They are optional but
recommended for documentation and tooling.

### 2. Dispatch events from the action body

Use `dispatchEvent` inside the action `body`:

```yaml
body:
  invokeAPI:
    name: getUser
    onResponse:
      dispatchEvent:
        onSuccess:
          data:
            user: ${getUser.body}
    onError:
      dispatchEvent:
        onError:
          data:
            message: Failed to fetch user
```

### 3. Handle events at the call site

Wire handlers in `executeAction`:

```yaml
executeAction:
  name: fetchUser
  inputs:
    userId: 1
  events:
    onSuccess:
      navigateScreen:
        name: Profile
    onError:
      showToast:
        message: ${event.data.message}
```

Event handlers run in the **caller's scope**. The dispatched payload is
available as `event.data` (and `event.error` when applicable).

### Multiple steps in the body

When the body needs more than one action (for example, run code then call an
API), use `executeActionGroup`:

```yaml
body:
  executeActionGroup:
    executeInOrder: true
    actions:
      - executeCode:
          body: |-
            console.log('starting fetch');
      - invokeAPI:
          name: getUser
          onResponse:
            dispatchEvent:
              onSuccess:
                data:
                  user: ${getUser.body}
```

## Scoped resources

### Import

Pull in app scripts from the `scripts/` directory (local) or the `Scripts`
resources map (Ensemble/CDN):

```yaml
Import:
  - common
  - utils
```

Imported functions are available inside the action scope for `Global` code and
API `onResponse` blocks.

### Global

JavaScript functions and variables scoped to the action run:

```yaml
Global: |-
  function formatUserName(user) {
    return user.firstName + ' ' + user.lastName;
  }
```

Global code runs after inputs are set and before the `body` executes.

### API

APIs defined on a reusable Action are scoped to the action's child scope.
Use `invokeAPI` by name inside the `body`:

```yaml
API:
  getUser:
    url: https://api.example.com/users/${userId}
    method: GET

Action:
  inputs:
    - userId
  body:
    invokeAPI:
      name: getUser
```

Action-scoped APIs are merged into the page `apiMap` while the action runs,
so bindings like `${getUser.body}` work inside the action. Prefer
`dispatchEvent` to pass API results to the caller rather than relying on
screen-level bindings.

## Local app setup

### Directory structure

```
ensemble/apps/yourAppName/
├── actions/
│   ├── showMessage.yaml
│   └── fetchUser.yaml
├── .manifest.json
├── screens/
├── widgets/
└── scripts/
```

### Manifest

Register each action in `.manifest.json`:

```json
{
  "actions": [
    { "name": "showMessage" },
    { "name": "fetchUser" }
  ]
}
```

### pubspec assets

Include the actions directory in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - ensemble/apps/yourAppName/actions/
```

The starter app's `helloApp` includes working examples:
`actions/showMessage.yaml`, `actions/fetchUser.yaml`, and usage on
`screens/Hello Home.yaml`.

## Ensemble and CDN providers

For Studio / Firestore apps, Actions are stored in the `resources` artifact
under the `Actions` key (see `ResourceArtifactEntry.Actions` in
`lib/framework/definition_providers/provider.dart`).

Each entry is a map of action name to YAML content. The same file-level layout
applies:

```yaml
Import:
  - apiUtils
API:
  myApi:
    url: https://example.com/data
    method: GET
Action:
  inputs: []
  body:
    invokeAPI:
      name: myApi
```

For CDN-hosted apps, actions are parsed from the manifest `actions` array with
`name` and `content` fields. File-level `Import`, `Global`, and `API` blocks
are merged automatically.

Remote definitions (`resources.ensemble`) use the same `Actions` map structure.

## Scope and isolation

| Data | Visibility |
| --- | --- |
| `inputs` | Action scope only; set per call |
| `Import` / `Global` | Action scope only |
| `API` bindings | Available inside the action while it runs |
| `dispatchEvent` payload | Passed explicitly to caller via `event.data` |
| `ensemble.storage` | App-global; only used if the action explicitly writes to it |

Keep side effects explicit: use **events** for outputs, **inputs** for
parameters, and avoid `ensemble.storage` unless the data should be shared
across the whole app.

## When to use reusable Actions

| Use reusable Actions when… | Use inline actions when… |
| --- | --- |
| The same workflow appears on multiple screens | The logic is used once on a single screen |
| You want a named, testable unit (login, checkout, fetch profile) | The action is a simple one-liner (`navigateScreen`, `showToast`) |
| The workflow needs its own APIs, scripts, or global helpers | No extra scope or resources are needed |

## Implementation references

| File | Role |
| --- | --- |
| `lib/action/execute_action.dart` | Parses and runs `executeAction` |
| `lib/action/action_scope_util.dart` | Merges resources, prepares child scope, registers event handlers |
| `lib/page_model.dart` | Merges global and page-level `Action:` blocks into `actionsMap` |
| `lib/framework/definition_providers/local_provider.dart` | Loads `actions/*.yaml` for local apps |
| `lib/framework/definition_providers/cdn_provider.dart` | Parses CDN manifest actions |
| `lib/framework/definition_providers/ensemble_provider.dart` | Loads `Actions` from Firestore resources |
