# Remote execution (Firebase Test Lab)

Host-owned remote runs for Ensemble YAML **integration** suites. The on-device engine remains `LocalTestExecutionSession` + `YamlStepDispatcher`; the CLI builds packages, submits to Firebase Test Lab (FTL), collects artifacts, and reconciles results.

## One-command GCP onboarding

Setup configures **Google Cloud only** (local `gcloud`). It never creates service-account JSON keys and never calls the GitHub API. At the end it prints CI env values for you to paste into GitHub Actions, GitLab, or any other platform.

```bash
gcloud auth login
gcloud config set project my-gcp-project

dart run ensemble_test_runner:ensemble_test remote setup \
  --gcp-project=my-gcp-project \
  --repo=Owner/repo

# Inspect without changes:
dart run ensemble_test_runner:ensemble_test remote setup \
  --gcp-project=my-gcp-project --repo=Owner/repo --dry-run

# Health check:
dart run ensemble_test_runner:ensemble_test remote doctor \
  --gcp-project=my-gcp-project --repo=Owner/repo

# Fix drifted WIF condition / missing pieces (never deletes buckets):
dart run ensemble_test_runner:ensemble_test remote setup \
  --gcp-project=my-gcp-project --repo=Owner/repo --repair --yes
```

`--repo=Owner/name` only restricts the GitHub OIDC Workload Identity Federation provider condition on GCP (`assertion.repository == "Owner/name"`).

### What setup creates or reuses

| Resource | Name |
|----------|------|
| Service account | `ensemble-test-ftl-ci@{project}.iam.gserviceaccount.com` (no keys) |
| WIF pool | `ensemble-test-ftl` |
| WIF provider | `github` (repo-restricted) |
| Results bucket | `{project}-ensemble-ftl-results` (14-day object retention) |
| Durable store bucket | `{project}-ensemble-remote-runs` (14-day object retention) |

IAM is additive only (`add-iam-policy-binding`): project
`roles/cloudtestservice.testAdmin` + `roles/firebase.analyticsViewer` for the CI SA
(Firebase Test Lab’s documented pair), `roles/iam.workloadIdentityUser` for the
repo principal set on the SA, and `roles/storage.objectAdmin` on the two buckets.
Setup never replaces project-wide IAM policies and never deletes buckets.

### Caller permissions required

Your gcloud user needs enough rights on the project to enable APIs, create service accounts, manage WIF pools/providers, create buckets, and add IAM bindings (typically Project IAM Admin + Service Usage Admin, or Owner on a dedicated test project).

### Printed CI configuration

After setup (or a healthy doctor), copy values like:

```text
ENSEMBLE_TEST_FTL_PROJECT_ID=...
ENSEMBLE_TEST_FTL_RESULTS_BUCKET=...
ENSEMBLE_TEST_REMOTE_STORE_GCS_BUCKET=...
ENSEMBLE_TEST_GCP_WIF_PROVIDER=projects/.../providers/github
ENSEMBLE_TEST_GCP_SERVICE_ACCOUNT=ensemble-test-ftl-ci@....iam.gserviceaccount.com
```

For GitHub Actions, add them as **repository variables** (not JSON key secrets). The sample workflow [`.github/workflows/ensemble-test-runner-remote.yml`](../../../.github/workflows/ensemble-test-runner-remote.yml) reads `${{ vars.* }}`, requires `id-token: write`, installs the Cloud SDK, and fails if vars are missing.

### Billing

FTL device minutes and GCS storage/egress are billed to the GCP project. Setup refuses to continue when Cloud Billing is disabled. Prefer a dedicated project and device budgets.

### Cleanup (manual)

1. Remove CI variables from your platform.
2. Optionally delete the WIF provider/pool and CI service account.
3. Empty and delete buckets only if you no longer need artifacts — **setup never auto-deletes buckets**.

## Configuration

```yaml
# yaml-language-server: $schema=https://cdn.ensembleui.com/schemas/ensemble_test_config_schema.json
mode: integration
target: remote
remote:
  provider: firebaseTestLab
  # projectId from env ENSEMBLE_TEST_FTL_PROJECT_ID when omitted
  devices:
    - model: Pixel2
      version: "30"
      locale: en
      orientation: portrait
  endpoints:
    - name: fixture
      url: https://fixtures.example.com
```

**Precedence:** CLI `--target` / `--remote-platform` > `config.yaml` > defaults.

`devices:` at the config root remains the widget/local viewport matrix. FTL catalog devices live only under `remote.devices`.

`target: remote` with `mode: widget` is a validation error.

## CLI

```bash
dart run ensemble_test_runner:ensemble_test --target=remote --remote-platform=android
```

Environment:

| Variable | Purpose |
|----------|---------|
| `ENSEMBLE_TEST_FTL_PROJECT_ID` | GCP project when `remote.projectId` omitted |
| `ENSEMBLE_TEST_FTL_RESULTS_BUCKET` | GCS results/uploads bucket |
| `ENSEMBLE_TEST_REMOTE_STORE_GCS_BUCKET` | Durable CI `RemoteRunStore` (CAS). **Not** GHA artifacts. |
| `ENSEMBLE_TEST_GCP_WIF_PROVIDER` | Full WIF provider resource name (CI auth) |
| `ENSEMBLE_TEST_GCP_SERVICE_ACCOUNT` | CI service account email (CI auth) |
| `ENSEMBLE_TEST_REMOTE_STORE_PREFIX` | Object prefix (default `ensemble-test-remote-runs`) |
| `ENSEMBLE_TEST_FTL_ACCESS_TOKEN` | Optional local bearer token (else `gcloud auth print-access-token`) |
| `ENSEMBLE_TEST_FTL_ANDROID_VERIFIED` | Set to `1` only after Android cloud+artifact proof to allow multi-device matrices |

## Build identity vs execution identity

- **`buildId` / `planHash`:** platform, variant, toolchain, test selection, non-secret dart-defines, package checksums. Reusable across compatible devices/runs.
- **`runId` / `deviceExecutionId`:** assigned at submit time; not baked into reusable APKs/IPAs when the provider accepts execution metadata.

Remote packages use the deterministic test-only encryption key `EnsembleTestKey00000000000000000` (same fallback as unit tests). Do **not** bake ephemeral CLI keys or provider credentials into binaries.

## Fail-fast fixtures

Remote validation **errors** when `services:` would launch host processes, use `adb reverse`, or hit loopback/private LAN URLs. Allowed: explicit `remote.endpoints` with publicly reachable HTTPS (or documented tunnels) and in-app mocks.

## Success definition

A device execution is **successful** only if all of:

1. Native framework outcome is available (Instrumentation / XCTest).
2. `RemoteRunEnvelope` is present with `complete: true` (emitted **after** suite storage restore).
3. Required artifacts verify (checksum + path safety).

Missing/incomplete envelopes never pass (`incomplete`). Bad checksums are `artifactFailure`. Install/infra issues are `infrastructureFailure`. Assertion failures remain `testFailure` (exit 1).

## Cancellation

States: `cancellationRequested` → `cancelled` (provider confirmed) or `cancellationUncertain`. Never mark cancelled solely because a cancel request was sent.

## Durable store

- `FileRemoteRunStore` — local/dev atomic JSON + version CAS.
- `GcsRemoteRunStore` — CI durable store with GCS generation preconditions.

GitHub Actions artifacts are for **checkpoint exports and reports only**, not transactional CAS state.

## Artifact export (hypotheses until FTL-verified)

Android and iOS export paths are **hypotheses** until proven on real devices. Candidate mechanisms (Instrumentation attachments, XCTest attachments, FTL `directoriesToPull`, secondary logcat `ENSEMBLE_TEST_REMOTE_ENVELOPE_V1`) may be tried; only a verified path counts toward acceptance.

See [`ACCEPTANCE.md`](ACCEPTANCE.md).

## Limitations

- No second cloud provider in this milestone.
- No interactive remote control / host RPC session for CI suites.
- Multi-device orchestration is gated on verified Android cloud+artifact proof.
- Production-ready requires **verified** Android **and** iOS real FTL execution + artifact E2E (pass and fail). Fake-provider tests are at most **implemented**.
