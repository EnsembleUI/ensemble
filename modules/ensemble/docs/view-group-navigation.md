# ViewGroup navigation

This document describes runtime behavior for **ViewGroup** screens (tabbed or
drawer page groups) in `modules/ensemble`. ViewGroups are defined with a
top-level `ViewGroup` key in screen YAML and rendered by `PageGroup` /
`BottomNavPageGroup` under `lib/framework/view/`.

## Tab index and visible menu items

Each ViewGroup maintains a selected tab index in the global
`viewGroupNotifier` (`lib/framework/view/page_group.dart`). The index selects
which child screen payload is active in an `IndexedStack` (drawer groups) or
bottom navigation bar.

Visible tabs come from menu items whose `visible` expression evaluates to
`true`. When only one item is visible, the runtime renders that page directly
without showing the navigation chrome.

## Index clamping (`safeViewGroupPayloadIndex`)

The global `viewGroupNotifier.viewIndex` can become **stale** relative to the
current list of page payloads—for example after:

- Restoring a persisted index from system storage when the menu definition now
  has fewer tabs.
- Changing `visible` expressions so fewer items render.
- Hot reload or definition updates that shrink the menu.

All indexing into `pagePayloads` and `IndexedStack` children goes through
`safeViewGroupPayloadIndex(index, payloadLength)`:

| Input | Result |
| --- | --- |
| `payloadLength <= 0` | `0` |
| `index < 0` | `0` |
| `index >= payloadLength` | `payloadLength - 1` |
| otherwise | `index` |

When the raw index is out of range, `_ensureViewGroupIndexSyncedWithPayloads`
schedules a post-frame correction via `viewGroupNotifier.updatePage` so
persistence and navigation stay aligned.

### Example scenario

An app persisted tab index `3` while offline. A new app definition ships with
only two tabs. On launch, index `3` is clamped to `1` instead of throwing or
showing an empty slot.

## Persisted tab index

`ViewGroupNotifier.storeCurrentIndex()` and `PageGroupState._storeViewGroupIndex`
write the current index to **system storage** under the key
`viewgroup_current_index`.

On cold start, `PageGroupState._getStoredViewGroupIndex` reads that value when
it is within the current menu item count; otherwise the group starts at the
default index.

## Child screen callbacks

Individual pages inside a ViewGroup can define:

| EDL field | When it runs |
| --- | --- |
| `onViewGroupUpdate` (on the child `View`) | Whenever `viewGroupNotifier` changes (tab switch or payload update). |
| `onViewGroupResume` (on the `ViewGroup`) | ViewGroup-level resume hook parsed into `PageGroupModel.onViewGroupResume`. |

`EnsemblePage` registers a listener on `viewGroupNotifier` in `initState` and
removes it in `dispose`.

## TabBar vs ViewGroup

`TabBar` layout widgets (`lib/layout/tab_bar.dart`) maintain their own
`selectedIndex` and clamp out-of-range values to `0` when tabs rebuild. That
logic is independent of ViewGroup navigation; see
[layout-widgets.md](layout-widgets.md).

## Tests

`test/safe_view_group_payload_index_test.dart` exercises
`safeViewGroupPayloadIndex` boundary cases.
