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
- **Packaging builds (ios):** `IosFtlPackager` uses `--no-tree-shake-icons`, pins `TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault`, `RunnerTests.swift`, debug `--config-only` then release, absolute `-derivedDataPath`. Submits **one** XCTest zip (Release-iphoneos + `.xctestrun` inside) like `gcloud --test` — a separate bare `.xctestrun` GCS object caused 0 XCTest cases. Auto-detects local Xcode and passes `xcodeVersion` on submit. CI pins Xcode **26.2**. Stub packages refused before submit; cloud unverified.
- **Console URLs:** Prefer Testing API `resultStorage.resultsUrl` (numeric matrix id). Never invent `/matrices/{matrix-*}` Firebase URLs. Do **not** print the project histories browse URL when `resultsUrl` is still pending.
- **Artifact export E2E:** Remote Android writes screenshots + `remote/envelope.json` under `/data/local/tmp/ensemble_test_remote` (and mirrors under `/sdcard/Download/ensemble_test_remote` when allowed). FTL `directoriesToPull` requests both. Logcat base64 screenshot dumps are **disabled** on remote (they overflow the circular buffer and drop envelope lines). Host still reassembles chunked `ENSEMBLE_TEST_REMOTE_ENVELOPE_V1` from logcat as backup. Missing envelope still fails closed (`incomplete`). Cloud row still needs a verified green collect.
- **Real FTL execution + collect:** Requires `ENSEMBLE_TEST_FTL_PROJECT_ID` + ADC. Missing creds ⇒ **unverified**, not passed. Blocks multi-device orchestration until Android is verified.
- **Envelope complete after cleanup:** Entry emits `RemoteRunEnvelope` only after `restorePreSuiteStorageAtSuiteEnd`; `cleanupErrors` included.
- **Durable resume:** `RemoteOrchestrator` + `FileRemoteRunStore` + `GcsRemoteRunStore` CAS. GHA artifacts are checkpoints only.
- **Reports:** `RemoteReportReconciler` taxonomy: pass / testFailure / incomplete / infrastructureFailure / artifactFailure.

Regenerate from code:

```bash
cd tools/ensemble_test_runner
dart -e "import 'package:ensemble_test_runner/execution/remote/acceptance_ledger.dart'; void main() { print(RemoteAcceptanceLedger.renderMarkdown()); }"
```
