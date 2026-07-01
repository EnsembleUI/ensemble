# Runtime security and data bindings

This document describes **verified** runtime behavior for definition loading,
file writes, multipart uploads, public app storage clears, WebView hardening,
global JavaScript handlers, and device metric bindings. Implementation lives
under `modules/ensemble` unless noted.

## Screen names for local and remote definitions

`LocalDefinitionProvider` and `RemoteDefinitionProvider` both resolve a screen
YAML file as a single segment under a fixed base path or URL prefix. The
selector is validated by `isSafeRemoteScreenSelector` in
`lib/framework/definition_providers/screen_selector_security.dart`.

### Allowed

- Non-empty string, length at most **256** characters.
- Typical screen ids such as `Home`, `screen_1`, or `a-b`.

### Rejected

- Empty strings, `..`, forward or backslash path separators, the `%`
  character (including percent-encoded separators), and ASCII control
  characters (`0x00`-`0x1f`, `0x7f`).

### Runtime effect when invalid

`getDefinition` returns `ScreenDefinition(YamlMap())` (an empty definition), so
navigation with an unsafe id does not read files or HTTP paths outside the
intended `screens/<name>.yaml` layout.

### Tests

`test/remote_definition_security_test.dart` exercises `isSafeRemoteScreenSelector`.

## `saveFile` and mobile save paths

`lib/action/saveFile/save_mobile.dart` defines `sanitizedSaveFileName`, used
when saving images or documents on mobile (and for web download filenames).

### Rules

- Only the **basename** is kept; any directory prefix is stripped.
- The basename must not be empty, `.`, `..`, or contain `..`.
- Path separators in the input are not allowed in the final name (after taking
  the basename, embedded `..` still fails).

Invalid names throw `FormatException` with a message indicating that only a
base name is allowed.

### Tests

`test/save_file_name_test.dart` covers `sanitizedSaveFileName`.

## Multipart upload paths

`lib/util/upload_utils.dart` rejects local file paths that contain a `..` path
segment (after normalising backslashes to forward slashes) before calling
`http.MultipartFile.fromPath`. The intent is to block partially trusted paths
(for example from API JSON bound into file upload actions) from traversing
outside an intended directory when bytes are read from disk.

### Runtime effect

`UploadUtils.uploadFiles` throws `FormatException` with a message that includes
the offending path when any upload item has a non-null `path` that fails this
check.

### Tests

`test/upload_path_security_test.dart` covers `uploadPathContainsParentSegment`.

## `ensemble.storage.clear()` and UI bindings

`EnsembleStorage` (`lib/framework/data_context.dart`) exposes invokable methods
including `get`, `set`, `delete`, and **`clear`**, backed by **public**
`GetStorage` through `StorageManager` (`lib/framework/storage_manager.dart`).
System storage and secure storage are separate; `clear` only affects public
app-developer storage.

### What `clear` removes

`clearPublicStorage` removes every key in the default `GetStorage` box **except**
keys whose names start with the literal prefix **`enc_`**. Those entries are
treated as a reserved namespace and are left in place. Only the `enc_` prefix
is special; for example a key named `enc2` is **not** treated as encrypted and
**is** removed.

### Binding refresh

Before removal, the runtime collects dispatch keys with
`ensembleStorageClearDispatchKeys` (same `enc_` filter). It then invokes
`clearPublicStorage` and, **without awaiting** that `Future`, immediately calls
`ScreenController.dispatchStorageChanges` once per collected key with a `null`
value so `StorageBindingSource` listeners (for example
`${ensemble.storage.someKey}` on the current page) refresh. Do not assume a
fixed ordering between persistence finishing and UI updates across platforms.

### Tests

- `test/ensemble_storage_clear_test.dart` — dispatch key selection for `clear`.
- `test/storage_manager_test.dart` — parity logic for which keys survive a clear.

## Native `WebView` (InAppWebView) TLS and reputation

`lib/widget/webview/native/webviewstate.dart` configures `InAppWebViewSettings`.

- **Android:** `safeBrowsingEnabled` is **true** so Safe Browsing is not
  disabled for the embedded WebView.
- **iOS:** `isFraudulentWebsiteWarningEnabled` is **true**.
- The WebView **does not** register `onReceivedServerTrustAuthRequest` to
  unconditionally proceed on certificate challenges; host apps rely on normal
  platform TLS validation.

`mixedContentMode` remains `MIXED_CONTENT_ALWAYS_ALLOW` on Android; that is a
separate knob from certificate validation and Safe Browsing.

## Global script handlers and string arguments

`ScreenController.runGlobalScriptHandler` (`lib/screen_controller.dart`) looks up
an `appConfig.envVariables` entry whose value must be `library.function` (two
non-empty dot-separated parts). It then evaluates a generated snippet of the
form `functionName(<argument>)` in the global JS interpreter.

Because the argument is interpolated into JS source, **callers must pass a
single safely quoted payload**. Untrusted binary or string data must not be
passed raw.

### BLE characteristic stream

In `modules/ensemble_bluetooth/lib/ensemble_bluetooth.dart`, when a
characteristic notifies in foreground mode, the handler keyed
`ensemble_bluetooth_handler` receives **`jsonEncode(data)`** (UTF-8 decoded
string from the peripheral), so the argument is a JSON string literal safe for
the generated call.

### Deep links

`DeepLinkNavigator` (`lib/deep_link_manager.dart`) invokes
`ensemble_deeplink_handler` with **`jsonEncode(event)`** where `event` wraps the
link payload under `data.link`.

## Device metric bindings after rotation

`EnsemblePage` (`lib/framework/view/page.dart`) overrides `didChangeMetrics`.
After layout, it dispatches `ModelChangeEvent` updates for **`width`**,
**`height`**, and **`orientation`** on the page scope (and on the page-group
scope when present) using `DeviceBindingSource`.

`Device` (`lib/framework/device.dart`) exposes:

- `orientation` via `MediaQuery.orientation.name` (Flutter enum name, e.g.
  `portraitUp`, `landscapeLeft`).
- `width` / `height` as integer pixel dimensions from the current
  `MediaQuery` attached to `Utils.globalAppKey`.

Expressions such as `${device.width}` that depend on these getters are
refreshed when metrics change (for example after device rotation).
