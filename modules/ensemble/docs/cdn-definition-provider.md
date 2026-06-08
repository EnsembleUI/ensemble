# CDN definition provider

This document describes how Ensemble loads app definitions from Ensemble's CDN
when `definitions.from` is set to `cdn` in `ensemble-config.yaml`. Implementation
lives in `lib/framework/definition_providers/cdn_provider.dart`.

## Configuration

In the starter app (`starter/ensemble/ensemble-config.yaml`):

```yaml
definitions:
  from: cdn
  cdn:
    appId: <your-ensemble-app-id>
    # forcedLocale: en   # optional; same shape as other providers
```

`DefinitionProvider.from` (`lib/framework/definition_providers/provider.dart`)
requires `definitions.cdn.appId`. The provider fetches a single atomic manifest
from:

`https://cdn.ensembleui.com/manifests/apps/<appId>/`

## Manifest fetch and caching

### Freshness check

Before downloading the manifest, the provider calls
`<baseUrl>/<appId>/lastUpdateTime.json` and compares `lastUpdatedAt` with the
locally cached value. A full manifest fetch runs only when the remote timestamp
is newer.

### Transport

- Plain manifest: `manifest.json`
- Encrypted manifest (when `ENSEMBLE_ENCRYPTION_KEY` is present in
  `.env.secrets`, `ensemble/.env.secrets`, or dotenv): `encrypted-manifest.json`
  with optional `x-manifest-key` header from `ENSEMBLE_MANIFEST_KEY`
- Responses may be Brotli-compressed (`Content-Encoding: br`)
- Conditional requests use `If-None-Match` with the cached ETag; HTTP 304 skips
  a body download

### Persistent cache

Manifest JSON, ETag, and `lastUpdatedAt` are stored in `SharedPreferences`
under `cdn_provider_state_<appId>`. On cold start, cached artifacts are loaded
first so the app can render offline; a background refresh runs when the cache
is non-empty.

Invalid cached JSON clears the cache and triggers a fresh fetch.

## Runtime artifact refresh

CDN publishes the entire app manifest at once. The provider cannot tell which
individual screens changed, so updates trigger a **global** refresh across all
mounted screens.

### `ENABLE_ARTIFACT_REFRESH`

Runtime refresh is **disabled by default**. Set the app config environment
variable `ENABLE_ARTIFACT_REFRESH` to `true` (in Studio or in the synced
manifest `artifacts.config.envVariables`) to allow live UI updates without
restarting the app.

When disabled, background fetches still update the on-disk cache, but the UI
does not rebuild until the next cold start.

### Lifecycle and pending updates

| App state | Behavior |
| --- | --- |
| **Paused / inactive** | `_refreshIfStale` may fetch a newer manifest and update the in-memory cache. UI refresh events are **not** fired while backgrounded. |
| **Resumed** | If `ENABLE_ARTIFACT_REFRESH` is `true` and `_hasPendingUpdate` is set, `_handlePendingUpdate` runs. |

`_handlePendingUpdate` applies updates in a fixed order to avoid a race where
screens rebuild before new resources are available:

1. `Ensemble().notifyAppBundleChanges()` — sync scripts, widgets, theme, and
   other bundle entries from `_artifactCache`
2. `_refreshTranslationsAtRuntime()` — refresh `FlutterI18n` decoded maps
3. `_fireManifestRefreshEvent()` — clear parsed script caches and fire
   `ResourceRefreshEvent` on `AppEventBus`

If a background refresh completes while the app is already initialized and
artifact refresh is enabled, `_handlePendingUpdate` runs immediately instead of
deferring to resume.

### Tests

`test/cdn_provider_test.dart` covers translation refresh, pending-update
ordering, and cache invalidation.

## Secrets and encryption

When `ENSEMBLE_ENCRYPTION_KEY` is configured, the provider prefers
`encrypted-manifest.json`. Missing keys throw `ConfigError` at decrypt time.
Runtime secrets from the manifest are merged into the provider's secret map and
used for manifest-key headers and other CDN artifacts.

## Comparison with `ensemble` provider

| | `ensemble` (Firestore) | `cdn` |
| --- | --- | --- |
| Hosting | Ensemble cloud (Firestore) | CDN manifest bundle |
| Recommended use | Development, Studio preview | Production (per starter config comments) |
| Refresh model | Per-artifact events where possible | Global manifest refresh |
| Offline | Depends on Firestore cache | SharedPreferences manifest cache |

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `Failed to fetch manifest from CDN` | Wrong `appId`, app not synced to CDN, or network error |
| UI does not update after Studio publish | `ENABLE_ARTIFACT_REFRESH` is not `true`, or app has not resumed from background |
| Stale translations after CDN update | Background refresh may have skipped translation reload when context was null; resume triggers `_refreshTranslationsAtRuntime` |
| Encrypted manifest errors | `ENSEMBLE_ENCRYPTION_KEY` missing or incorrect |
