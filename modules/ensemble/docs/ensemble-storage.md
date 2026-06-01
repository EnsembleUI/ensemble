# Ensemble storage (`ensemble.storage`)

This document describes the **public** storage API exposed to Ensemble
Declarative Language (EDL) scripts and expressions. Implementation lives in
`lib/framework/data_context.dart` (`EnsembleStorage`) and
`lib/framework/storage_manager.dart` (`StorageManager`).

## Storage tiers

`StorageManager` combines three backends:

| Tier | Access from EDL | Backend | Typical use |
| --- | --- | --- | --- |
| **Public** | `ensemble.storage.*` | `GetStorage` (default box) | App-defined key/value data, session state, UI preferences |
| **System** | `ensemble.user.*` (via `SystemStorageBindingSource`) | `GetStorage('system')` | Framework-managed data such as authenticated user info |
| **Secure** | Not directly synchronous from JS | `FlutterSecureStorage` | Native secure keychain/keystore (framework internal) |

`ensemble.storage` reads and writes **public** storage only. Encrypted values
written through secure-storage actions are stored in public storage under keys
prefixed with `enc_` (see [Encrypted keys and `clear()`](#encrypted-keys-and-clear)).

## Public API

`EnsembleStorage` is a singleton invokable bound as `ensemble.storage` in the
data context.

### Property access

```yaml
Text:
  text: Hello ${ensemble.storage.profile.name}
```

Assigning through a property path writes and dispatches binding updates:

```javascript
ensemble.storage.profile = { name: 'Ada' };
```

Setting a property to `null` removes the key.

### Methods

| Method | Behavior |
| --- | --- |
| `get(key)` | Returns the stored value, or `null` if missing. |
| `set(key, value)` | Same as property assignment; dispatches binding updates. |
| `delete(key)` | Removes one key and dispatches a binding update with `null`. |
| `clear()` | Removes **all public keys except those starting with `enc_`**, then dispatches binding updates for each removed key. |

### Example: sign-out reset

```yaml
Button:
  label: Sign out
  onTap: |-
    // Wipes non-encrypted public storage; enc_* entries remain.
    ensemble.storage.clear();
    navigateScreen('Login');
```

## Binding refresh

Writes through `ensemble.storage` call
`ScreenController.dispatchStorageChanges`, which emits `ModelChangeEvent`
updates for `StorageBindingSource` on:

1. The current page `ScopeManager`, and
2. The parent `PageGroup` scope when it differs from the page scope.

Expressions such as `${ensemble.storage.cart}` re-evaluate when the matching
storage key changes. `clear()` dispatches an update for **each removed key** so
bound widgets refresh after a bulk wipe.

Binding resolution for storage keys is implemented in
`lib/framework/bindings.dart` (top-level keys only, e.g.
`ensemble.storage.theme`, not nested paths in the binding source id).

## Encrypted keys and `clear()`

`EncryptedStorageManager` (`lib/framework/encrypted_storage_manager.dart`)
persists ciphertext in public storage using the `enc_` prefix. `clear()` and
`StorageManager.clearPublicStorage()` skip any key that starts with `enc_`.

Keys like `enc2` or `encrypted_token` are **not** treated as encrypted
namespace keys—only the literal `enc_` prefix is reserved.

Secure-storage actions (`setSecureStorage`, `getSecureStorage`,
`clearSecureStorage`) manage individual encrypted entries; they are not removed
by `ensemble.storage.clear()`.

## Page header integration

`EnsemblePage` (`lib/framework/view/page.dart`) can react to storage-driven
header styles:

- **`listenTitleBarHeightStorage: true`** — attaches a storage listener (plus a
  periodic fallback poll) so `${ensemble.storage.*}` expressions in
  `titleBarHeight` update the AppBar after storage changes.
- **`collapsibleHeader.enabled: true`** with a `visible` expression referencing
  `ensemble.storage.*` — listens for storage changes to toggle header
  visibility.

These listeners are opt-in to avoid unnecessary subscriptions on pages with
static headers.

## Constraints

- Public storage is **not** encrypted. Use secure-storage actions for sensitive
  values that must survive app restarts.
- `clear()` does not touch system storage (`ensemble.user.*`) or native secure
  storage.
- Storage operations from EDL are synchronous; the underlying `GetStorage`
  writes are async but fire-and-forget from the script layer.
- Nested binding sources resolve only the first path segment (e.g.
  `ensemble.storage.cart` binds to key `cart`, not `cart.items`).

## Tests

- `test/storage_manager_test.dart` — `enc_` filtering logic for bulk clear.
- `test/ensemble_storage_clear_test.dart` — dispatch key selection for
  `ensemble.storage.clear()`.
- `test/invokable_test.dart` — `ensemble.storage.get()` expression evaluation.
