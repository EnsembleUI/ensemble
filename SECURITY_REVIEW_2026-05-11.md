# Scheduled application security review - 2026-05-11

Scope reviewed: Flutter/Ensemble runtime entry points, definition loading, auth/API helpers, WebView and JavaScript bridges, native/plugin modules, Bluetooth, deep links, file/network access, logging, and GitHub automation.

## Validated findings

### 1. High - Native WebView disables TLS certificate validation

- **Location:** `modules/ensemble/lib/widget/webview/native/webviewstate.dart:317`
- **Attacker:** An active network attacker on the victim's network path, such as a hostile Wi-Fi access point, proxy, or compromised DNS/router.
- **Attacker-controlled input:** The TLS certificate and HTTPS response body for any URL loaded by the Ensemble native `WebView` widget.
- **Reachability:** App definitions set `WebView.url` / `WebView.uri` through `modules/ensemble/lib/widget/webview/webview.dart:42` and `:59`. The native renderer then builds an `InAppWebView` and unconditionally answers every server-trust challenge with `ServerTrustAuthResponseAction.PROCEED` in `modules/ensemble/lib/widget/webview/native/webviewstate.dart:317-319`.
- **Impact:** The attacker can impersonate the HTTPS site loaded in the WebView, read or modify sensitive pages, steal cookies or custom headers configured on the WebView, and run JavaScript inside the page. If the app configured `javascriptChannels`, the forged page can call those bridge handlers and trigger the configured Ensemble actions via `ScreenController().executeAction(...)` at `modules/ensemble/lib/widget/webview/native/webviewstate.dart:205-218`.
- **Highest-leverage remediation:** Remove the unconditional trust override and let the platform reject invalid certificates by default. If a development or pinning bypass is still needed, gate it behind a non-production build flag plus a per-host allowlist, and make bridge handlers unavailable until certificate validation succeeds.

### 2. High - Bluetooth GATT notifications are evaluated as code

- **Location:** `modules/ensemble_bluetooth/lib/ensemble_bluetooth.dart:194`
- **Attacker:** A malicious or spoofed BLE peripheral that the victim app connects to and subscribes to.
- **Attacker-controlled input:** Raw GATT notification bytes from the subscribed characteristic.
- **Reachability:** `BluetoothManagerImpl.subscribe()` decodes notification bytes as UTF-8 and passes the resulting string directly to `ScreenController().runGlobalScriptHandler('ensemble_bluetooth_handler', data)` at `modules/ensemble_bluetooth/lib/ensemble_bluetooth.dart:194-199`. `runGlobalScriptHandler()` embeds that string into interpreter source as `"$function($inputs)"` without JSON encoding or quoting at `modules/ensemble/lib/screen_controller.dart:99-117`, then evaluates it in `executeGlobalFunction()` at `modules/ensemble/lib/screen_controller.dart:124-137`.
- **Impact:** A peripheral can break out of the intended handler argument and execute arbitrary Ensemble interpreter statements in the app context. That context includes `secrets`, `auth` when registered, and the `ensemble` helper object (`modules/ensemble/lib/framework/data_context.dart:80-90`), whose methods expose navigation, API invocation, secure/keychain operations, native method calls, socket messaging, and other actions (`modules/ensemble/lib/framework/data_context.dart:501-580`). This enables data exfiltration, authenticated API calls, forged navigation/actions, or native method abuse depending on the app's configured globals.
- **Highest-leverage remediation:** Treat BLE notifications as data, not source code. Pass a structured event object such as `jsonEncode({'data': data})` into the global handler, or replace `runGlobalScriptHandler()` with an action callback API that supplies the notification as an `EnsembleEvent`. In `runGlobalScriptHandler()`, never concatenate untrusted strings into interpreter source; build a safe argument literal or call a pre-resolved function with data through interpreter APIs.

### 3. Medium - Release workflow dispatch input is interpolated into a privileged shell command

- **Location:** `.github/workflows/release-melos-version.yml:50`
- **Attacker:** A repository user or automation token that can manually dispatch the `Release Ensemble Version` workflow but should not be able to run arbitrary shell commands with the release job's repository credentials.
- **Attacker-controlled input:** The `workflow_dispatch` `version` string.
- **Reachability:** The workflow inserts `${{ inputs.version }}` directly into a double-quoted shell command: `melos version ensemble "${{ inputs.version }}" --yes`. GitHub expression interpolation happens before the shell starts, and POSIX shells still perform command substitution inside double quotes. A value containing `$(...)` or backticks is therefore executed by the `Version packages` step. The job checks out `main` with `secrets.RELEASE_TOKEN`, leaves checkout credentials available by default, and has `contents: write`, so injected commands execute in a release context.
- **Impact:** The attacker can execute arbitrary commands on the GitHub-hosted runner and can use the persisted release checkout credentials to modify repository contents or tags, bypassing the intended "version string only" workflow interface.
- **Highest-leverage remediation:** Validate the dispatch input before any shell use with a strict semver allowlist and fail closed. Pass the validated value through an environment variable or a small script using argv, not expression interpolation in `run:`. Also set `persist-credentials: false` on checkout unless a later step explicitly needs release credentials, and provide credentials only to the push step.

## Reviewed candidates not reported as validated medium+

- Generic remote definition/YAML execution, SSL-bypass flags, permissive chart/fintech widget trust models, deep-link navigation, and local starter CLI command construction were reviewed. They either require a malicious trusted definition publisher/operator, a shipped insecure configuration, a privileged local user, or an app-specific sensitive screen/action that is not present in this repository snapshot.
- No validated unauthenticated SQL injection, server-side request forgery, raw shell execution from remote app input, or secret leakage through a remotely reachable application endpoint was found in this pass.
