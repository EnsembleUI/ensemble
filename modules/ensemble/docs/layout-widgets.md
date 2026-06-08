# Layout widgets

This document covers public Ensemble Declarative Language (EDL) layout
interfaces implemented in `modules/ensemble/lib/layout`.

## TabBar and TabBarOnly

`TabBar` renders both tab navigation and the selected tab body. `TabBarOnly`
renders only the tab navigation. Both are backed by `BaseTabBar`,
`TabBarState`, and `TabBarController`.

### Common fields and methods

| EDL field or method | Behavior |
| --- | --- |
| `items` | List of tab definitions. Each item must provide at least one of `label`, `icon`, or `tabWidget`. |
| `body`, `widget`, `bodyWidget` | Aliases for the body rendered when the tab is selected. |
| `tabWidget`, `tabItem` | Aliases for a custom tab label widget. |
| `selectedIndex` | Initial and current selected tab index. Out-of-range values are reset to `0` when tabs are rebuilt. |
| `visible` | Optional boolean or `${...}` expression string per item. Expression strings are evaluated against the current data scope. |
| `navigateTo(index)` | Programmatically selects a tab. `changeTabItem(index)` is kept as a legacy alias. |
| `useIndexedTab` | Builds each tab body on first visit and caches it for later tab switches. |
| `persistentTabBar` | Wraps tab bodies in a scroll view so the tab bar remains pinned while body content scrolls. |

### Example

```yaml
View:
  body:
    Column:
      children:
        - Button:
            label: Show activity
            onTap: |-
              accountTabs.navigateTo(1);
        - TabBar:
            id: accountTabs
            selectedIndex: 0
            useIndexedTab: true
            persistentTabBar: true
            items:
              - label: Overview
                body:
                  Text:
                    text: Account overview
              - label: Activity
                visible: ${account.showActivity == true}
                body:
                  ListView:
                    item-template:
                      data: ${account.events}
                      name: event
                      template:
                        Text:
                          text: ${event.title}
              - tabWidget:
                  Text:
                    text: Settings
                bodyWidget:
                  Text:
                    text: Account settings
```

### Constraints

- Classic rendering rebuilds the selected body as tabs change. Use
  `useIndexedTab: true` when expensive tab bodies or tab-local widget state
  should survive later tab switches.
- With `useIndexedTab`, non-expanded tab groups use `Offstage` widgets for
  hidden tab bodies; expanded tab groups use an `IndexedStack`.
- `persistentTabBar` makes the tab body scroll independently of the tab header.
  If the body already contains nested scrollables, verify the resulting scroll
  behavior on the target platform.

## ListView scroll controls

`ListView` is backed by `ListViewController` and `ListViewCore`. It can render
static children, an `item-template`, or both, and exposes scroll helpers through
the widget id.

### Common fields and methods

| EDL field or method | Behavior |
| --- | --- |
| `initialScrollOffset` | Pixel offset used when the internal `ScrollController` is created. |
| `initialScrollIndex` | After the first frame, estimates an offset for the requested templated item index. |
| `scrollToOffset(offset)` | Animates to a pixel offset over 300 ms. |
| `scrollToTop()` / `scrollToBottom()` | Convenience methods for the start and current maximum scroll extent. |
| `scrollToIndex(index)` | Estimates the offset from the templated data length and clamps the index into range. |
| `onScroll` | Receives the current pixel offset in `event.data.pixel`. |

### Example

```yaml
View:
  body:
    Column:
      children:
        - Button:
            label: Back to top
            onTap: |-
              resultsList.scrollToTop();
        - ListView:
            id: resultsList
            initialScrollIndex: 10
            onScroll: |-
              console.log(event.data.pixel);
            item-template:
              data: ${searchResults}
              name: result
              template:
                Text:
                  text: ${result.title}
```

### Constraints

- Scroll methods are no-ops until the underlying `ScrollController` has clients,
  so call them after the widget is rendered or in response to user actions.
- `scrollToIndex` and `initialScrollIndex` use the `item-template` data length
  to estimate item height. They return without scrolling when there is no
  templated data.
- `scrollToBottom` uses the current `maxScrollExtent`; if more data is loaded
  later, call it again after the list updates.
- When a parent widget supplies a new `ScrollController` after build,
  `ListViewCore` re-attaches its scroll listener to the new controller so
  `onScroll` and scroll helpers keep working.

## ViewGroup tab index safety

`ViewGroup` screens (bottom navigation, drawer, and similar page groups) track
the selected tab through `ViewGroupNotifier` and `PageGroupState.pagePayloads`.
The runtime clamps tab indices with `safeViewGroupPayloadIndex` in
`lib/framework/view/page_group.dart` whenever the index is used to index tab
payloads or `IndexedStack` children.

### Clamping rules

| Input | `payloadLength` | Result |
| --- | --- | --- |
| negative | any positive | `0` |
| `0` … `length - 1` | positive | unchanged |
| `>= length` | positive | `length - 1` |
| any | `0` | `0` |

This prevents crashes when:

- `navigateViewGroup` targets a `viewIndex` outside the current menu after the
  menu definition shrinks
- A stored tab index is restored from `ensemble.storage` after a CDN or Studio
  update removed tabs

### `navigateViewGroup` action

```yaml
- navigateViewGroup:
    viewIndex: 2
    payload:
      orderId: ${order.id}
```

When only `viewIndex` is provided (no `name`), the action resolves the index
through `safeViewGroupPayloadIndex` against the current `PageGroup` menu length
before calling `PageController.jumpToPage` and `viewGroupNotifier.updatePage`.

When `name` is provided, navigation goes to the named screen and may include
`viewIndex` in the page arguments payload.

### Tests

`test/safe_view_group_payload_index_test.dart` covers `safeViewGroupPayloadIndex`.
