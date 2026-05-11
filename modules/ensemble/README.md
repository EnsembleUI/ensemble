## Getting Started

### For detailed instructions on how to run locally or deploy to iOS AppStore or Google Play, see this - https://github.com/EnsembleUI/ensemble_starter

This is Ensemble Runtime that is essentially an interpreter for the Ensemble Declarative Language (EDL) written in Flutter. 

Signup for Ensemble studio here - https://studio.ensembleui.com to see how the EDL is used to build front-ends. 

To run Ensemble locally using Android Studio or VCS, you will need to download the Ensemble Starter repo here - https://github.com/EnsembleUI/ensemble_starter

and edit the following files as follows - 

1. change the ensemble/appId to your app's Id. If you are just starting off, you can use the Kitchen Sink app's id as an example. It is e24402cb-75e2-404c-866c-29e6c3dd7992
2. You can always find your app's id in the studio.ensembleui.com from the right side 3 dot menu. 

and following the instructions in the readme of https://github.com/EnsembleUI/ensemble_starter to run locally.

# How to contribute a new widget or enhance an existing widget in Ensemble

1. All the ensemble widgets are here - https://github.com/EnsembleUI/ensemble/tree/main/lib/widget 
2. run the Kitchen Sink app - https://studio.ensembleui.com/app/e24402cb-75e2-404c-866c-29e6c3dd7992/screens when running locally use the appId as described above. 
3. See how each widget works and how the yaml is mapped to the Flutter widget
4. In the studio, create your own app and screens with your widget (or enhanced widget). Make sure you can test locally and it works fine
5. When ready, create a pull request and we will review and provide feedback. 

## Runtime layout widget notes

This module maps Ensemble Declarative Language (EDL) YAML to Flutter widgets.
The notes below cover public layout interfaces that are implemented in
`lib/layout` and are useful when building or debugging screens.

### TabBar and TabBarOnly

`TabBar` renders both tab navigation and the selected tab body. `TabBarOnly`
renders only the tab navigation. Both are backed by `BaseTabBar`,
`TabBarState`, and `TabBarController`.

Common properties and methods:

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

Example:

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

Constraints to keep in mind:

- Classic rendering rebuilds the selected body as tabs change. Use
  `useIndexedTab: true` when expensive tab bodies or tab-local widget state
  should survive later tab switches.
- With `useIndexedTab`, non-expanded tab groups use `Offstage` widgets for
  hidden tab bodies; expanded tab groups use an `IndexedStack`.
- `persistentTabBar` makes the tab body scroll independently of the tab header.
  If the body already contains nested scrollables, verify the resulting scroll
  behavior on the target platform.

### ListView scroll controls

`ListView` is backed by `ListViewController` and `ListViewCore`. It can render
static children, an `item-template`, or both, and exposes scroll helpers through
the widget id.

Common scroll fields and methods:

| EDL field or method | Behavior |
| --- | --- |
| `initialScrollOffset` | Pixel offset used when the internal `ScrollController` is created. |
| `initialScrollIndex` | After the first frame, estimates an offset for the requested templated item index. |
| `scrollToOffset(offset)` | Animates to a pixel offset over 300 ms. |
| `scrollToTop()` / `scrollToBottom()` | Convenience methods for the start and current maximum scroll extent. |
| `scrollToIndex(index)` | Estimates the offset from the templated data length and clamps the index into range. |
| `onScroll` | Receives the current pixel offset in `event.data.pixel`. |

Example:

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

Constraints to keep in mind:

- Scroll methods are no-ops until the underlying `ScrollController` has clients,
  so call them after the widget is rendered or in response to user actions.
- `scrollToIndex` and `initialScrollIndex` use the `item-template` data length
  to estimate item height. They return without scrolling when there is no
  templated data.
- `scrollToBottom` uses the current `maxScrollExtent`; if more data is loaded
  later, call it again after the list updates.


# How to run test
- Run unit test with `flutter test`.
- For integration test:
  - first open `.ios > Podfile` and add this entry `ENV['SWIFT_VERSION'] = '5'`.
  - Run `flutter test integration_test`.