# Remote execution acceptance ledger

Statuses: `implemented` | `verified` | `blocked` | `unverified`.

**Production-ready:** NO (requires verified Android and iOS cloud E2E + artifact rows).

| Criterion | Android | iOS | Shared |
|-----------|---------|-----|--------|
| Packaging builds | implemented | implemented | |
| Artifact export E2E (pass) | unverified | unverified | |
| Artifact export E2E (fail) | unverified | unverified | |
| Real FTL execution + collect | unverified | unverified | |
| Envelope complete after cleanup | | | implemented |
| Multi-device orchestrate + durable resume | | | implemented |
| Unified reports + correct exit codes | | | implemented |
| Widget/local integration backward compatible | | | implemented |

## Notes

- **Packaging builds (android):** `AndroidFtlPackager` follows Flutter FTL flow (`flutter build apk --target` → `assembleAndroidTest` → `assembleDebug -Ptarget`). `-Pdart-defines` must use per-define base64 (`encodeDartDefinesForGradle`), matching `flutter_tools`; a single base64 of the joined string drops defines so screenshots write to relative `build/` and crash on device (read-only FS). Requires `MainActivityTest` + `androidx.test` 1.2+ ranges. Validation checks dex + kernel (integration entry + remote encryption-key define).
- **Packaging builds (ios):** `IosFtlPackager` uses `--no-tree-shake-icons`, pins `TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault` for Xcode 26 Metal toolchain Swift-compat linking, and `RunnerTests.swift` so the ObjC test target links Swift pods. Runs `flutter build ios --config-only --debug` before release (Flutter #170119). `-derivedDataPath` is always absolute. CI pins Xcode **26.2** (FTL’s current latest) so the XCTest zip matches Test Lab’s default runtime — newer host SDKs (26.5/27) yield 0 XCTest cases. Stub packages refused before submit; cloud unverified.
- **Console URLs:** Prefer Testing API `resultStorage.resultsUrl` (numeric matrix id). Never invent `/matrices/{matrix-*}` Firebase URLs.
- **Artifact export E2E:** Android writes under `/data/local/tmp/ensemble_test_remote` and FTL `directoriesToPull` requests that same path (Google allowlist: `/sdcard`, `/storage`, `/data/local/tmp`). Host also parses `ENSEMBLE_TEST_REMOTE_ENVELOPE_V1` from downloaded logcat, materializes screenshot chunks, and writes HTML + `ensemble_test_history.db` from `envelope.results`. Missing envelope still fails closed (`incomplete`). Cloud row still needs a verified green collect.
- **Real FTL execution + collect:** Requires `ENSEMBLE_TEST_FTL_PROJECT_ID` + ADC. Missing creds ⇒ **unverified**, not passed. Blocks multi-device orchestration until Android is verified.
- **Envelope complete after cleanup:** Entry emits `RemoteRunEnvelope` only after `restorePreSuiteStorageAtSuiteEnd`; `cleanupErrors` included.
- **Durable resume:** `RemoteOrchestrator` + `FileRemoteRunStore` + `GcsRemoteRunStore` CAS. GHA artifacts are checkpoints only.
- **Reports:** `RemoteReportReconciler` taxonomy: pass / testFailure / incomplete / infrastructureFailure / artifactFailure.

Regenerate from code:

```bash
cd tools/ensemble_test_runner
dart -e "import 'package:ensemble_test_runner/execution/remote/acceptance_ledger.dart'; void main() { print(RemoteAcceptanceLedger.renderMarkdown()); }"
```
