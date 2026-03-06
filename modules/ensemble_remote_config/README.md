# Ensemble Remote Config

Ensemble module for Firebase Remote Config. Use it for A/B testing, feature flags, and runtime configuration in screens and expressions.

## What it does

- Fetches and activates Remote Config in the background when the module is registered.
- Exposes Remote Config on the ensemble object like storage: `ensemble.remoteConfig.my_key` (or `ensemble.remoteConfig.get('key', 'default')` for a custom default).

## Enabling the module

Remote Config is **off** by default. To turn it on:

1. **Starter `pubspec.yaml`**  
   Uncomment the dependency:

   ```yaml
   ensemble_remote_config:
     git:
       url: https://github.com/EnsembleUI/ensemble.git
       ref: <ensemble-version>
       path: modules/ensemble_remote_config
   ```

2. **Starter `lib/generated/ensemble_modules.dart`**  
   - Set `useRemoteConfig = true`.
   - Uncomment: `import 'package:ensemble_remote_config/remote_config.dart';`
   - Uncomment: `GetIt.I.registerSingleton<RemoteConfig>(RemoteConfigImpl());`

3. **Firebase**  
   Ensure Firebase is set up (e.g. `GoogleService-Info.plist` / `google-services.json`). With `useRemoteConfig = true`, `Firebase.initializeApp()` is already triggered by the starter’s init.

### Optional environment variables

You can tune Remote Config fetch behavior via environment variables:

- `remote_config_fetch_timeout` — fetch timeout in seconds (default `10`).
- `remote_config_minimum_fetch_interval` — minimum fetch interval in seconds (default `3600`, i.e. 1 hour).

Example:

```yaml
environmentVariables:
  remote_config_fetch_timeout: 10
  remote_config_minimum_fetch_interval: 3600
```

Notes:

- These values are applied when Remote Config is initialized **and** before each
  subsequent `fetchAndActivate()` / `ensemble.remoteConfig.refresh()`.
- On the very first app start, Ensemble config may not be loaded yet when RC
  initializes, so the defaults can be used for the first fetch; any later call
  to `ensemble.remoteConfig.refresh()` re-reads and reapplies the env values.
- For local debugging you can temporarily set `remote_config_minimum_fetch_interval: 0` to avoid throttling, but you should use a higher value in production.

## Usage in YAML

In any screen or expression, use the `ensemble` object

- **Property access** — `ensemble.remoteConfig.my_key` returns a minimally typed value
  - `"true"/"false"` → `bool`
  - numeric string → `num`
  - otherwise a `String` (or `null` if the key is missing/empty).
- **Custom default and type** — `ensemble.remoteConfig.get('my_key', false)` uses the
  default's type (here `bool`) and falls back to that default on errors.
- **Typed helpers** — these are just wrappers around `get` with a typed default:
  - `ensemble.remoteConfig.getBool('flag', false)`
  - `ensemble.remoteConfig.getInt('max_items', 10)`
  - `ensemble.remoteConfig.getDouble('ratio', 0.5)`
  - `ensemble.remoteConfig.getString('cta_text', 'Try it now')`

### Defaults

- `ensemble.remoteConfig.setDefaults({ flag: true, max_items: 10 })` registers app‑side
  defaults with Firebase Remote Config.
- **Intended use**: call once during app startup before the screens that depend on these keys are built.
- Changing defaults at runtime does **not automatically update existing widgets**; you may need to rebuild the screen or navigate away/back to see the new default take effect.

### Debug helpers

For debugging and introspection (e.g. a developer screen):

- `ensemble.remoteConfig.all()` → map of all keys to their current values.
- `ensemble.remoteConfig.info()` → metadata such as `initialized`, `lastFetchStatus`,
  `lastFetchTime`, and fetch/interval settings.
- `ensemble.remoteConfig.refresh()` → manually trigger a re‑fetch/activate of
  Remote Config values (using Firebase's built‑in throttling and current env
  settings for timeout/interval).

## Debug logging

In debug builds, the module logs to `debugPrint` when:

- Fetch/activate fails (with exception and stack).
- `getValue` returns the default because the service isn’t initialized, the key is empty, or an error occurred.
