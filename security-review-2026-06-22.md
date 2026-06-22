# Application Security Review — 2026-06-22

## Summary

4 validated medium+ vulnerabilities with end-to-end attack paths. Fixes implemented on separate branches; automated PR creation blocked (GitHub integration lacks `createPullRequest` permission).

## Findings

### 1. Native WebView JavaScript channel origin bypass — HIGH

- **Severity:** High
- **Location:** `modules/ensemble/lib/widget/webview/native/webviewstate.dart`
- **Attacker:** External site loaded in WebView after redirect/navigation
- **Controlled input:** Bridge/postMessage payloads from attacker's origin
- **Attack path:** WebView navigates to evil.com → page calls `flutter_inappwebview.callHandler` → YAML `javascriptChannels.onMessageReceived` actions run without origin check (web iframe path already validated origin)
- **Impact:** Spoofed messages trigger app actions (API calls, navigation, sensitive handlers)
- **Remediation:** `webview_javascript_bridge_security.dart`; reject callbacks unless `getUrl().origin` matches configured WebView URL
- **Tests:** `modules/ensemble/test/webview_javascript_bridge_security_test.dart`
- **Branch:** `security/fix-webview-js-channel-origin` (commit a1ffd61e)
- **PR status:** No PR created: automated PR creation blocked (branch pushed)

### 2. TabaPay postMessage origin spoofing — HIGH

- **Severity:** High
- **Location:** `modules/ensemble/lib/widget/fintech/tabapayconnect.dart`
- **Attacker:** Cross-origin frame or page in TabaPay WebView
- **Controlled input:** Arbitrary `postMessage` data forwarded to `messageHandler`
- **Attack path:** Unrestricted `window.addEventListener("message", …)` forwards all messages → `_handleTabaPayMessage` treats spoofed `token|…` payload as payment success → `onSuccess` YAML actions run with attacker-controlled token fields
- **Impact:** Fraudulent payment-success callbacks; downstream actions may trust spoofed card/token data
- **Remediation:** `tabapay_post_message.dart`; only forward messages where `event.origin` matches iframe URL origin; fail closed for invalid URLs
- **Tests:** `modules/ensemble/test/tabapay_post_message_test.dart`
- **Branch:** `security/fix-tabapay-postmessage-origin` (commit ea2e8897)
- **PR status:** No PR created: automated PR creation blocked (branch pushed)

### 3. Lottie web postMessage origin spoofing — MEDIUM

- **Severity:** Medium
- **Location:** `modules/ensemble/lib/widget/lottie/web/lottiestate.dart`
- **Attacker:** Cross-origin page with reference to Ensemble app window (or opener)
- **Controlled input:** Forged `{"data":"onComplete","id":N,"tag":"…"}` postMessage payloads
- **Attack path:** Wildcard `postMessage(..., "*")` + no `event.origin` check on host listener → spoofed animation callbacks execute YAML `onComplete`/`onForward`/etc.
- **Impact:** Unauthorized triggering of YAML actions wired to Lottie lifecycle callbacks
- **Remediation:** `lottie_post_message.dart`; restrict postMessage targets to app origin; validate inbound origin; structured payload parsing
- **Tests:** `modules/ensemble/test/lottie_post_message_test.dart`
- **Branch:** `security/fix-lottie-postmessage-origin` (commit aa162188)
- **PR status:** No PR created: automated PR creation blocked (branch pushed)

### 4. Lottie HTML renderer JS injection — HIGH (web HTML renderer)

- **Severity:** High
- **Location:** `modules/ensemble/lib/widget/lottie/web/lottiestate.dart` (generated iframe `srcdoc`)
- **Attacker:** Party controlling Lottie `source` or widget `id` (e.g. via API-bound YAML field)
- **Controlled input:** `source` URL or `id` containing `"` and `);` breakout sequences
- **Attack path:** Values embedded raw in `player_$divId.load("$source")` → breakout executes arbitrary JS in iframe sandbox
- **Impact:** iframe XSS; potential parent communication abuse depending on browser isolation
- **Remediation:** `lottie_html_renderer_security.dart`; JSON-encode source literal; sanitize widget ids
- **Tests:** `modules/ensemble/test/lottie_html_renderer_security_test.dart`
- **Branch:** `security/fix-lottie-html-injection` (commit 07ee5e74)
- **PR status:** No PR created: automated PR creation blocked (branch pushed)

## Reviewed but not fixed (no PR)

| Topic | Reason |
|-------|--------|
| YAML/JS runtime (`evalCode`, `fetch`, `invokeAPI`) | By design; definition author is trusted boundary |
| Global script handler raw-string injection | All current callers pass `jsonEncode(...)`; defense-in-depth fix exists on unmerged branch but no active raw-string caller found |
| `javascript:` / `file:` in `launchUrl` (html/markdown/openUrl) | Valid concern for API-rendered user content; needs product decision on allowed URL schemes |
| OAuth web client secret in secure storage | Architectural; requires owner input on web OAuth model |

## Create PRs manually

- https://github.com/EnsembleUI/ensemble/compare/main...security/fix-webview-js-channel-origin
- https://github.com/EnsembleUI/ensemble/compare/main...security/fix-tabapay-postmessage-origin
- https://github.com/EnsembleUI/ensemble/compare/main...security/fix-lottie-postmessage-origin
- https://github.com/EnsembleUI/ensemble/compare/main...security/fix-lottie-html-injection
