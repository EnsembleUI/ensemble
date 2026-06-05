# Ensemble TV Complete Guide

Comprehensive documentation for TV/D-pad navigation in the Ensemble framework, including YAML patterns, framework architecture, and flutter_pca integration.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [tvOptions Property Reference](#3-tvoptions-property-reference)
4. [YAML Patterns & Examples](#4-yaml-patterns--examples)
5. [Carousel TV Implementation](#5-carousel-tv-implementation)
6. [ListView Scrollbar](#6-listview-scrollbar)
7. [Host App Integration (flutter_pca)](#7-host-app-integration-flutter_pca)
8. [Focus Styling](#8-focus-styling)
9. [Common UI Patterns](#9-common-ui-patterns)
10. [Pitfalls to Avoid](#10-pitfalls-to-avoid)
11. [Testing Checklist](#11-testing-checklist)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Overview

The Ensemble framework provides comprehensive TV support through:

- **2D Grid Navigation** - Row/order based focus traversal for D-pad
- **Pluggable Provider Pattern** - Host apps inject their own focus system
- **Netflix-Style Scrolling** - Fixed focus position with auto-scroll
- **Flexible Styling** - Multiple override levels for focus indicators
- **Carousel Support** - Horizontal slide navigation with autoplay control

### Key Concepts

| Concept                 | Description                                            |
| ----------------------- | ------------------------------------------------------ |
| **Row**                 | Vertical position in focus grid (0, 1, 2, ...)         |
| **Order**               | Horizontal position within a row (0, 1, 2, ...)        |
| **Entry Point**         | Preferred focus target when entering a row             |
| **Fixed Focus Scroll**  | Netflix-style scrolling where focused item stays fixed |
| **Delegate Navigation** | Passing key events to parent (for carousels)           |

---

## 2. Architecture

### Core TV Framework Files

| File                       | Purpose                                          |
| -------------------------- | ------------------------------------------------ |
| `tv_focus_provider.dart`   | Abstract interface for host app integration      |
| `tv_focus_widget.dart`     | Built-in D-pad navigation handler with edge handlers |
| `tv_focus_order.dart`      | Focus coordinates (row/order) and TVFocusScope   |
| `tv_focus_theme.dart`      | Styling configuration                            |
| `tv_scrollbar_widget.dart` | Focusable scrollbar for ListView on TV           |

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Host App (flutter_pca)                    │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    TV Top Navigation Bar                   │  │
│  │  [Home] [Live] [Movies] [Series] [Sports] [Apps]          │  │
│  │                                    ↑ Order 5               │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                     Sports Tab Content                     │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │              TVFocusProviderScope                    │  │  │
│  │  │  ┌───────────────────────────────────────────────┐  │  │  │
│  │  │  │         PageFocusProvider                     │  │  │  │
│  │  │  │  - rowOffset: 1.0 (below tab bar)            │  │  │  │
│  │  │  │  - orderOffset: 5.0 (Sports tab align)       │  │  │  │
│  │  │  └───────────────────────────────────────────────┘  │  │  │
│  │  │                      │                               │  │  │
│  │  │                      ▼                               │  │  │
│  │  │  ┌───────────────────────────────────────────────┐  │  │  │
│  │  │  │         EnsembleScreenRenderer                │  │  │  │
│  │  │  │  - Renders Ensemble YAML UI definitions       │  │  │  │
│  │  │  │  - Widgets wrapped with TVFocusWidget         │  │  │  │
│  │  │  └───────────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Focus Grid Alignment

```
flutter_pca Tab Bar (Row 0):
  [Home:0] [Live:1] [Movies:2] [Series:3] [Watchlist:4] [Sports:5] [Apps:6]

Ensemble Content (Row 1+, aligned with Sports at order 5):
  [Match1:5] [Match2:6] [Match3:7] [Match4:8]

↑ UP from Ensemble → Sports tab
↓ DOWN from Sports tab → Ensemble content
```

---

## 3. tvOptions Property Reference

### Complete tvOptions Structure

```yaml
tvOptions:
    # Navigation Properties (Required for TV focus)
    row: 0 # Vertical position in focus grid
    order: 0 # Horizontal position within row
    isRowEntryPoint: true # Preferred entry point when navigating into row

    # Focus Indicator Styling (Optional)
    focusBorderRadius: 16 # Border radius for focus indicator (pixels)
    focusColor: 0xFF00AAFF # Focus indicator border color
    focusBorderWidth: 2 # Focus indicator border width (pixels)

    # Focused State Styling (Optional - widget appearance when focused)
    backgroundColor: 0xFF1A1A1A # Background color when focused
    backgroundGradient: # Background gradient when focused
        colors: [0xFF1A1A1A, 0xFF2A2A2A]
    borderColor: 0xFFFFFFFF # Border color when focused
    borderWidth: 2 # Border width when focused
    borderRadius: 8 # Border radius when focused
    boxShadow: # Box shadow when focused
        color: 0x40000000
        offset: [0, 4]
        blur: 8
    opacity: 1.0 # Opacity when focused (0.0 to 1.0)
    elevation: 4 # Elevation when focused (0 to 24)
    scale: 1.05 # Scale factor when focused (e.g., 1.05 = 5% larger)
    padding: 12 # Padding when focused
    margin: 8 # Margin when focused

    # Scroll Behavior (Optional - for horizontal lists)
    fixedFocusScroll: true # Enable Netflix-style scrolling
    fixedFocusOffset: 48 # Offset from left edge (pixels)
    verticalScrollPadding: 100 # Extra padding when scrolling vertically
    scrollAnimationDuration: 200 # Scroll animation duration (ms)
    scrollAnimationCurve: easeOut # Animation curve
    horizontalScrollPadding: 16 # Horizontal padding for visibility checks

    # Horizontal Navigation Control (for carousels)
    delegateHorizontalNavigation: true # Delegate LEFT/RIGHT to parent FocusScope
    lockHorizontalNavigation: true # Block LEFT/RIGHT at row boundaries

    # Carousel-Specific (on Carousel widget)
    interceptHorizontalNav: true # Smart edge detection for LEFT/RIGHT
    pauseAutoplayOnFocus: true # Pause autoplay when focused
    restoreFocusOnPageChange: true # Restore focus after slide change

    # ListView Scrollbar (on ListView widget)
    scrollbarOptions:
        position: right # 'left' or 'right'
        color: 0xFF666666 # Color when not focused
        focusedColor: 0xFFFFFFFF # Color when focused
        width: 3 # Width when not focused (pixels)
        focusedWidth: 6 # Width when focused (pixels)
        radius: 4 # Border radius of scrollbar
        thumbHeight: 40 # Fixed thumb height (pixels)
```

### Property Details

#### Navigation Properties

| Property                         | Type     | Default       | Description                                                                                                                      |
| -------------------------------- | -------- | ------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| **row**                          | `double` | `null`        | **Required**. Vertical position in the focus grid (0, 1, 2, ...). Items with the same row navigate horizontally with LEFT/RIGHT. |
| **order**                        | `double` | `0`           | Horizontal position within the row (0, 1, 2, ...). Lower values = more left. Must be unique within a row.                        |
| **isRowEntryPoint**              | `bool`   | `false`       | Marks this item as the preferred entry point when navigating INTO this row from another row.                                     |
| **delegateHorizontalNavigation** | `bool`   | `false`       | When `true`, LEFT/RIGHT events are delegated to parent FocusScope. Use for items inside carousels.                               |
| **lockHorizontalNavigation**     | `bool`   | `false`       | When `true`, prevents horizontal navigation from escaping row at boundaries.                                                     |

#### Focus Indicator Styling

These properties control the **focus indicator border** that appears around focused widgets.

| Property                         | Type     | Default       | Description                                                                                                                      |
| -------------------------------- | -------- | ------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| **focusColor**                   | `Color`  | theme default | Custom color for focus indicator border. Accepts hex (0xFF00AAFF).                                                               |
| **focusBorderWidth**             | `double` | `3.0`         | Custom border width for focus indicator (pixels).                                                                                |
| **focusBorderRadius**            | `double` | theme default | Custom border radius for focus indicator. Use `22` for 44px circular buttons, `100` for pills.                                   |

#### Focused State Styling

These properties change the **widget's appearance** when focused (not the focus indicator, but the widget itself). When unfocused, the widget uses its normal styles.

| Property                         | Type              | Default       | Description                                                                                                                      |
| -------------------------------- | ----------------- | ------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| **backgroundColor**              | `Color`           | `null`        | Background color when focused. Overrides widget's normal backgroundColor.                                                         |
| **backgroundGradient**           | `Gradient`        | `null`        | Background gradient when focused. Overrides widget's normal backgroundGradient.                                                   |
| **borderColor**                  | `Color`           | `null`        | Border color when focused (widget's own border, not the focus indicator).                                                         |
| **borderWidth**                  | `int`             | `null`        | Border width when focused (widget's own border).                                                                                  |
| **borderRadius**                 | `BorderRadius`    | `null`        | Border radius when focused.                                                                                                       |
| **boxShadow**                    | `BoxShadow`       | `null`        | Box shadow when focused. Accepts shadow composite (color, offset, blur, spread).                                                 |
| **opacity**                      | `double`          | `null`        | Opacity when focused (0.0 to 1.0). Use to fade/brighten widgets.                                                                 |
| **elevation**                    | `int`             | `null`        | Material elevation when focused (0 to 24). Creates shadow depth.                                                                  |
| **scale**                        | `double`          | `null`        | Scale factor when focused (e.g., 1.05 = 5% larger, 0.95 = 5% smaller).                                                           |
| **padding**                      | `EdgeInsets`      | `null`        | Padding when focused. Overrides widget's normal padding.                                                                          |
| **margin**                       | `EdgeInsets`      | `null`        | Margin when focused. Overrides widget's normal margin.                                                                            |

#### Scroll Behavior

| Property                         | Type     | Default       | Description                                                                                                                      |
| -------------------------------- | -------- | ------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| **fixedFocusScroll**             | `bool`   | `false`       | Netflix-style scrolling where focused item stays at fixed position while content scrolls.                                        |
| **fixedFocusOffset**             | `double` | `48.0`        | Offset from left edge where focused item stays during fixed focus scrolling.                                                     |
| **verticalScrollPadding**        | `double` | `0.0`         | Extra padding when auto-scrolling vertically to keep focused item visible.                                                       |
| **horizontalScrollPadding**      | `double` | `16.0`        | Horizontal padding for visibility checks during scrolling.                                                                        |
| **scrollAnimationDuration**      | `int`    | `200`         | Duration of scroll animations in milliseconds.                                                                                    |
| **scrollAnimationCurve**         | `String` | `easeOut`     | Animation curve: easeIn, easeOut, easeInOut, linear, decelerate, ease.                                                           |

#### Carousel-Specific Properties

| Property                         | Type     | Default       | Description                                                                                                                      |
| -------------------------------- | -------- | ------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| **interceptHorizontalNav**       | `bool`   | `false`       | Smart edge detection for LEFT/RIGHT navigation in carousels.                                                                     |
| **pauseAutoplayOnFocus**         | `bool`   | `false`       | Pause carousel autoplay when any element within has focus.                                                                       |
| **restoreFocusOnPageChange**     | `bool`   | `false`       | Restore focus after carousel slide change.                                                                                        |

#### ListView Scrollbar Properties

These properties are set under `tvOptions.scrollbarOptions` on ListView widgets.

| Property           | Type     | Default       | Description                                                                                      |
| ------------------ | -------- | ------------- | ------------------------------------------------------------------------------------------------ |
| **position**       | `String` | `'right'`     | Scrollbar position: `'left'` or `'right'`.                                                       |
| **color**          | `Color`  | `0xFF666666`  | Scrollbar color when not focused.                                                                 |
| **focusedColor**   | `Color`  | `0xFFFFFFFF`  | Scrollbar color when focused.                                                                     |
| **width**          | `int`    | `3`           | Scrollbar width in pixels when not focused.                                                       |
| **focusedWidth**   | `int`    | `6`           | Scrollbar width in pixels when focused (wider for visibility).                                    |
| **radius**         | `int`    | `4`           | Border radius of scrollbar corners.                                                               |
| **thumbHeight**    | `int`    | `40`          | Fixed height of scrollbar thumb in pixels.                                                        |

### Where to Apply tvOptions

Apply `tvOptions` in the `styles` section of focusable widgets:

```yaml
Column:
    styles:
        tvOptions:
            row: 0
            order: 0
    onTap:
        navigateBack:
```

**Important**: Only widgets with `onTap` handlers OR form widgets (Switch, TextInput, etc.) can receive focus.

---

## 4. YAML Patterns & Examples

### Pattern 1: Simple List (One Focusable per Item)

```yaml
item-template:
    data: ${items}
    name: item
    indexId: itemIndex
    template:
        Column:
            styles:
                tvOptions:
                    row: 1
                    order: ${itemIndex}
                    isRowEntryPoint: ${itemIndex == 0}
            onTap: ...
```

### Pattern 2: Multiple Focusables per Item (CRITICAL)

When each list item has MULTIPLE focusable elements, multiply the index:

```yaml
# CORRECT - No conflicts
Switch:
    styles:
        tvOptions:
            row: ${tvRow}
            order: ${tvOrder * 2} # Item 0: order 0, Item 1: order 2
Delete:
    styles:
        tvOptions:
            row: ${tvRow}
            order: ${tvOrder * 2 + 1} # Item 0: order 1, Item 1: order 3
```

**Formula**: For N focusable elements per item:

- Element 0: `order: ${index * N}`
- Element 1: `order: ${index * N + 1}`
- Element 2: `order: ${index * N + 2}`

### Pattern 3: Netflix-Style Horizontal List

```yaml
Row:
    styles:
        scrollable: true
        gap: 8
    item-template:
        data: ${mediaItems}
        name: item
        indexId: mediaIndex
        template:
            MediaCard:
                inputs:
                    tvOptions:
                        row: 5
                        order: ${mediaIndex}
                        isRowEntryPoint: ${mediaIndex == 0}
                        fixedFocusScroll: true
                        fixedFocusOffset: 48
                        lockHorizontalNavigation: true
```

### Pattern 4: Grid Layout

```yaml
item-template:
    data: ${items}
    indexId: itemIndex
    template:
        Card:
            styles:
                tvOptions:
                    row: ${1 + Math.floor(itemIndex / 4)} # Row changes every 4 items
                    order: ${itemIndex % 4} # 0, 1, 2, 3, 0, 1, 2, 3...
```

### Pattern 5: Passing tvOptions to Custom Widgets

**Widget Definition:**

```yaml
Widget:
    inputs:
        - item
        - tvOptions
    body:
        Column:
            styles:
                tvOptions: ${tvOptions}
            onTap: ...
```

**Widget Usage:**

```yaml
item-template:
    data: ${items}
    indexId: idx
    template:
        MyWidget:
            inputs:
                item: ${item}
                tvOptions:
                    row: ${1 + idx}
                    order: 0
```

---

## 5. Carousel TV Implementation

### Carousel-Level tvOptions

```yaml
Carousel:
    layout: single
    autoplay: true
    autoplayInterval: 5000
    styles:
        tvOptions:
            row: 1
            interceptHorizontalNav: true # Smart edge detection
            pauseAutoplayOnFocus: true # Pause when user navigates
            restoreFocusOnPageChange: true # Restore focus after slide change
```

### Item-Level: delegateHorizontalNavigation

For focusable elements inside carousel slides:

```yaml
# Inside carousel slide
Button:
    label: "Watch Now"
    styles:
        tvOptions:
            row: 1
            order: 0
            delegateHorizontalNavigation: true # LEFT/RIGHT switch slides
```

### How Carousel Navigation Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Carousel (interceptHorizontalNav: true)        │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │  Slide 1                                                         │   │
│   │  ┌──────────────────────┐                                        │   │
│   │  │ [Button]             │ ← delegateHorizontalNavigation: true   │   │
│   │  │ LEFT/RIGHT delegated │                                        │   │
│   │  └──────────────────────┘                                        │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│   When user presses LEFT/RIGHT:                                         │
│   1. Button delegates to parent FocusScope                              │
│   2. Carousel intercepts the event                                      │
│   3. Carousel switches to previous/next slide                           │
│   4. Focus is restored to new slide's button                            │
└─────────────────────────────────────────────────────────────────────────┘
```

### Complete Hero Carousel Example

```yaml
HeroCarousel:
    body:
        Carousel:
            layout: single
            height: 400
            autoplay: true
            autoplayInterval: 5
            enableLoop: true
            indicatorType: circle
            styles:
                tvOptions:
                    pauseAutoplayOnFocus: true
                    interceptHorizontalNav: true
                    restoreFocusOnPageChange: true
            item-template:
                data: ${competitions}
                name: competition
                indexId: slideIndex
                template:
                    HeroSlide:
                        inputs:
                            competition: ${competition}
                            slideIndex: ${slideIndex}

HeroSlide:
    inputs:
        - competition
        - slideIndex
    body:
        Stack:
            styles:
                width: ${device.width - 96}
                height: 400
                margin: 0 48
                borderRadius: 12
                clipContent: true
            children:
                - Image:
                      source: ${competition.heroImage}
                      styles:
                          width: ${device.width - 96}
                          height: 400
                          fit: cover

                - Column:
                      styles:
                          width: ${device.width - 96}
                          height: 400
                          mainAxis: end
                          crossAxis: start
                          padding: 48 48 80 48
                          gap: 12
                          backgroundGradient:
                              colors:
                                  - 0x00000000
                                  - 0x60000000
                                  - 0xcc000000
                                  - 0xff000000
                              stops:
                                  - 0.0
                                  - 0.40
                                  - 0.65
                                  - 0.85
                              start: topCenter
                              end: bottomCenter
                      children:
                          - Text:
                                text: ${competition.title}
                                styles:
                                    textStyle:
                                        fontSize: 36
                                        fontWeight: bold

                          - Text:
                                text: ${competition.description}

                          - Button:
                                label: "View Competition"
                                styles:
                                    margin: 8 0 0 0
                                    tvOptions:
                                        row: 0
                                        order: ${slideIndex}
                                        verticalScrollPadding: 400
                                        delegateHorizontalNavigation: true
                                onTap:
                                    navigateScreen:
                                        name: CompetitionDetails
```

### Key Difference: delegateHorizontalNavigation vs lockHorizontalNavigation

| Property                       | Behavior                                         | Use Case                    |
| ------------------------------ | ------------------------------------------------ | --------------------------- |
| `delegateHorizontalNavigation` | Event bubbles up to parent (carousel handles it) | Items inside carousels      |
| `lockHorizontalNavigation`     | Event is blocked/consumed (nothing happens)      | Standalone horizontal lanes |

---

## 6. ListView Scrollbar

### Overview

ListView on TV supports a focusable scrollbar that allows users to scroll content using D-pad navigation. The scrollbar:

- Appears on the left or right edge of the ListView
- Becomes focusable via D-pad navigation (RIGHT to right-side scrollbar, LEFT to left-side scrollbar)
- Changes visual state when focused (color, width)
- Scrolls content with UP/DOWN keys when focused
- Works correctly with multi-column content layouts

### Architecture: Edge Handlers

The scrollbar uses **edge handlers** integrated into the TVFocusWidget grid system:

```
┌────────────────────────────────────────────────────────────────┐
│                         ListView                                │
│  ┌──────────────────────────────────────────────────┐  ┌────┐ │
│  │               TVFocusScope                        │  │    │ │
│  │  ┌────────────────────────────────────────────┐  │  │ S  │ │
│  │  │ Item (row=1, order=0)  ─RIGHT→  Item (order=1) │→│ C  │ │
│  │  │ Item (row=2, order=0)  ─RIGHT→  Item (order=1) │→│ R  │ │
│  │  │ Item (row=3, order=0)  ─RIGHT→  Item (order=1) │→│ O  │ │
│  │  └────────────────────────────────────────────┘  │  │ L  │ │
│  │               ↑                                   │  │ L  │ │
│  │     onRightEdge: scrollbar.requestFocus()        │  │    │ │
│  └──────────────────────────────────────────────────┘  └────┘ │
└────────────────────────────────────────────────────────────────┘
```

**How it works:**
1. User navigates through grid items using D-pad
2. When at the rightmost item (e.g., order=1), pressing RIGHT triggers `onRightEdge`
3. `onRightEdge` callback requests focus on the scrollbar
4. Scrollbar receives focus and handles UP/DOWN for scrolling
5. LEFT returns focus back to content

### Basic Usage

```yaml
ListView:
    styles:
        expanded: true
        tvOptions:
            scrollbarOptions:
                position: right           # 'left' or 'right'
                color: 0xFF666666         # Grey when not focused
                focusedColor: 0xFFFFFFFF  # White when focused
                width: 3                  # Thin when not focused
                focusedWidth: 6           # Wider when focused
                radius: 4                 # Corner radius
                thumbHeight: 40           # Thumb size
    item-template:
        data: ${items}
        name: item
        indexId: idx
        template:
            Column:
                styles:
                    tvOptions:
                        row: ${1 + idx}
                        order: 0
                        isRowEntryPoint: ${idx == 0}
                onTap:
                    showToast:
                        message: Tapped ${item.title}
```

### Multi-Column Content

The scrollbar correctly handles multi-column layouts. Users must navigate through all columns before reaching the scrollbar:

```yaml
ListView:
    styles:
        tvOptions:
            scrollbarOptions:
                position: right
    item-template:
        data: ${items}
        indexId: idx
        template:
            Row:
                children:
                    # Left column (order 0)
                    - Column:
                        styles:
                            tvOptions:
                                row: ${1 + idx}
                                order: 0
                        onTap: ...

                    # Right column (order 1)
                    - Column:
                        styles:
                            tvOptions:
                                row: ${1 + idx}
                                order: 1
                        onTap: ...
```

**Navigation flow:**
```
Item (order 0) ─RIGHT→ Item (order 1) ─RIGHT→ Scrollbar
                                              │
Item (order 0) ←LEFT─  Item (order 1) ←LEFT─ ─┘
```

### Left-Positioned Scrollbar

For left-side scrollbar, use `position: left`:

```yaml
ListView:
    styles:
        tvOptions:
            scrollbarOptions:
                position: left
                color: 0xFF666666
                focusedColor: 0xFFFFFFFF
    item-template:
        data: ${items}
        indexId: idx
        template:
            Column:
                styles:
                    tvOptions:
                        row: ${1 + idx}
                        order: 0
                onTap: ...
```

**Navigation flow (left position):**
```
Scrollbar ←LEFT─ Item (order 0)
    │
    └─RIGHT→  Item (order 0)
```

### Scrollbar Styling Options

| Property         | Default       | Description                              |
| ---------------- | ------------- | ---------------------------------------- |
| `position`       | `'right'`     | `'left'` or `'right'` side of ListView   |
| `color`          | `0xFF666666`  | Track and thumb color when not focused   |
| `focusedColor`   | `0xFFFFFFFF`  | Track and thumb color when focused       |
| `width`          | `3`           | Width in pixels when not focused         |
| `focusedWidth`   | `6`           | Width in pixels when focused (wider)     |
| `radius`         | `4`           | Corner radius of scrollbar               |
| `thumbHeight`    | `40`          | Fixed height of scrollbar thumb          |

### Complete Example: Settings List with Scrollbar

```yaml
View:
    title: Settings

    onLoad:
        executeCode:
            body: |
                ensemble.storage.settings = [
                    {name: 'Notifications', enabled: true},
                    {name: 'Dark Mode', enabled: false},
                    {name: 'Auto-play', enabled: true},
                    # ... more settings
                ];

    body:
        Column:
            children:
                # Header
                - Row:
                    styles:
                        tvOptions:
                            row: 0
                            order: 0
                    onTap:
                        navigateBack:
                    children:
                        - Icon:
                            name: arrow_back
                        - Text:
                            text: Settings

                # Settings list with scrollbar
                - ListView:
                    styles:
                        expanded: true
                        tvOptions:
                            scrollbarOptions:
                                position: right
                                color: 0xFF444444
                                focusedColor: 0xFF00AAFF
                                width: 4
                                focusedWidth: 8
                    item-template:
                        data: ${ensemble.storage.settings}
                        name: setting
                        indexId: idx
                        template:
                            Row:
                                styles:
                                    padding: 16
                                    mainAxis: spaceBetween
                                children:
                                    - Text:
                                        text: ${setting.name}
                                    - Switch:
                                        value: ${setting.enabled}
                                        styles:
                                            tvOptions:
                                                row: ${1 + idx}
                                                order: 0
                                                isRowEntryPoint: ${idx == 0}
                                        onChange: |
                                            ensemble.storage.settings[${idx}].enabled = event.value;
```

### Key Points

1. **Only on TV**: Scrollbar only renders on TV devices (not mobile/web)
2. **ScrollController Required**: ListView must have a scroll controller (automatic for most cases)
3. **Grid Navigation**: Works with TVFocusWidget's 2D grid system via edge handlers
4. **Multi-Column Safe**: Correctly navigates through all columns before scrollbar
5. **Bidirectional**: LEFT from right scrollbar (or RIGHT from left scrollbar) returns to content
6. **Visual Feedback**: Scrollbar changes color/width when focused

---

## 7. Host App Integration (flutter_pca)

### TVFocusProvider Interface

```dart
abstract class TVFocusProvider {
    double get rowOffset;      // Ensemble content starts at this row
    double get orderOffset;    // Ensemble content starts at this order

    Color? get focusColor;
    double? get focusBorderWidth;
    double? get focusBorderRadius;

    Widget wrapFocusable({
        required double row,
        required double order,
        required Widget child,
        bool isRowEntryPoint = false,
        bool lockHorizontalNavigation = false,
        bool delegateHorizontalNavigation = false,
        KeyEventResult Function(FocusNode node)? onBackPressed,
        bool disableHostScroll = true,
    });

    void dispose();
}
```

### flutter_pca Implementation

```dart
class PageFocusProvider implements TVFocusProvider {
    @override
    double get rowOffset => 1.0;   // Below tab bar

    @override
    double get orderOffset => 5.0; // Aligned with Sports tab

    @override
    Color? get focusColor => AppThemeManager.currentTheme.snowGrey;

    @override
    double? get focusBorderWidth => 1.5;

    @override
    Widget wrapFocusable({
        required double row,
        required double order,
        required Widget child,
        bool isRowEntryPoint = false,
        bool lockHorizontalNavigation = false,
        bool delegateHorizontalNavigation = false,
        KeyEventResult Function(FocusNode node)? onBackPressed,
        bool disableHostScroll = true,
    }) {
        return PageFocusWidget(
            focusOrder: PageFocusOrder.withOptions(
                row,
                order: order,
                isRowEntryPoint: isRowEntryPoint,
                lockHorizontalNavigation: lockHorizontalNavigation,
                delegateHorizontalNavigation: delegateHorizontalNavigation,
                disableHostScroll: disableHostScroll,
            ),
            goBackButtonHandled: onBackPressed,
            disableHostScroll: disableHostScroll,
            child: child,
        );
    }
}
```

### Integration with EnsembleApp

```dart
// In Sports tab
EnsembleWrapper(
    tvFocusProvider: PageFocusProvider(),
    child: EnsembleScreen(payload: payload),
)

// Internally wraps with scope:
if (widget.tvFocusProvider != null) {
    app = TVFocusProviderScope(
        provider: widget.tvFocusProvider!,
        child: app,
    );
}
```

### Files Changed for flutter_pca Integration

| File                                                       | Description                                       |
| ---------------------------------------------------------- | ------------------------------------------------- |
| `lib/screens/widgets/custom/page_focus_provider.dart`      | Bridge between Ensemble and flutter_pca           |
| `lib/screens/widgets/custom/pca_button.dart`               | PageFocusWidget with delegateHorizontalNavigation |
| `lib/screens/ensemble/ensemble_wrapper.dart`               | TVFocusProvider integration                       |
| `lib/screens/ensemble/platform.tv/ensemble.tv.screen.dart` | TV screen with focus scope                        |

---

## 8. Focus Styling

### Focus Indicator Styling Priority Chain

The focus indicator border color, width, and radius follow this priority order:

```
1. Per-Widget Override (styles.tvOptions.focusColor/focusBorderWidth/focusBorderRadius)
       ↓ (if not set)
2. Theme Configuration (theme.yaml - Common.Tokens.TV.*)
       ↓ (if not set)
3. TVFocusProvider (host app integration, e.g., flutter_pca)
       ↓ (if not set)
4. Widget's Normal Styles (styles.borderColor/borderWidth/borderRadius)
       ↓ (if not set)
5. Ensemble Defaults:
   - Focus Color: App's primary color (Theme.of(context).colorScheme.primary)
   - Border Width: 3.0px
   - Border Radius: 8.0px
   - Animation Duration: 150ms
```

**Source:** [box_wrapper.dart:799-850](../modules/ensemble/lib/widget/helpers/box_wrapper.dart)

### Focused State Styling Priority

Focused state properties (backgroundColor, scale, elevation, etc.) have a simpler chain:

```
1. Per-Widget Override (styles.tvOptions.backgroundColor/scale/elevation/...)
       ↓ (if not set)
2. Widget's Normal Styles (styles.backgroundColor/padding/margin/...)
       ↓ (unfocused state)
```

**Note:** When focused, tvOptions properties override the widget's normal styles. When unfocused, the widget uses its normal styles from the `styles` section.

### Theme Configuration (theme.yaml)

```yaml
Common:
    Tokens:
        TV:
            focusColor: 0xFF00AAFF
            focusBorderWidth: 3
            focusBorderRadius: 8
            focusAnimationDuration: 150
```

### Per-Widget Override (Focus Indicator)

```yaml
Button:
    label: "Special Button"
    styles:
        tvOptions:
            row: 1
            order: 0
            focusColor: 0xFFFF0000 # Red focus border
            focusBorderWidth: 4
            focusBorderRadius: 24
```

### Focused State Styling Examples

#### Example 1: Scale and Brighten on Focus

```yaml
MediaCard:
    styles:
        backgroundColor: 0xFF1A1A1A
        tvOptions:
            row: 2
            order: ${index}
            # Normal widget styles above
            # Focused state styles below
            scale: 1.05              # Grow 5% when focused
            backgroundColor: 0xFF2A2A2A  # Lighter background
    onTap:
        navigateScreen:
            name: MediaDetails
```

#### Example 2: Add Shadow and Border on Focus

```yaml
Button:
    label: "Play"
    styles:
        backgroundColor: 0xFF2196F3
        borderRadius: 8
        tvOptions:
            row: 1
            order: 0
            # Focused state
            elevation: 8             # Add shadow depth
            borderColor: 0xFFFFFFFF  # White border
            borderWidth: 2
            scale: 1.02              # Slight zoom
```

#### Example 3: Change Background Gradient on Focus

```yaml
Column:
    styles:
        backgroundGradient:
            colors: [0xFF1A1A1A, 0xFF0A0A0A]
        tvOptions:
            row: 3
            order: ${idx}
            # Different gradient when focused
            backgroundGradient:
                colors: [0xFF2196F3, 0xFF1976D2]
                start: topLeft
                end: bottomRight
    onTap: ...
```

#### Example 4: Padding/Margin Animation on Focus

```yaml
Card:
    styles:
        padding: 12
        margin: 8
        tvOptions:
            row: 4
            order: ${idx}
            # Adjust spacing when focused
            padding: 16    # More padding
            margin: 4      # Less margin (appears to grow)
    onTap: ...
```

#### Example 5: Opacity Fade on Focus

```yaml
TabButton:
    styles:
        opacity: 0.5  # Dim when not focused
        tvOptions:
            row: 0
            order: ${idx}
            opacity: 1.0  # Full brightness when focused
    onTap:
        executeCode:
            body: |
                switchTab(${idx});
```

#### Example 6: Complete Media Card with All Effects

```yaml
MediaCard:
    styles:
        width: 200
        height: 300
        borderRadius: 12
        backgroundColor: 0xFF1A1A1A
        tvOptions:
            row: ${rowIndex}
            order: ${itemIndex}
            isRowEntryPoint: ${itemIndex == 0}
            # Focus indicator
            focusColor: 0xFFFFFFFF
            focusBorderWidth: 3
            focusBorderRadius: 12
            # Focused state (widget transformation)
            scale: 1.08
            backgroundColor: 0xFF2A2A2A
            elevation: 12
            boxShadow:
                color: 0x60000000
                offset: [0, 8]
                blur: 16
                spread: 2
    onTap:
        navigateScreen:
            name: MediaDetails
    children:
        - Image:
              source: ${media.poster}
              styles:
                  width: 200
                  height: 300
                  fit: cover
```

### Focus Indicator vs Focused State

**Focus Indicator** (focusColor, focusBorderWidth, focusBorderRadius):
- The **border** that appears around the focused widget
- Controlled by Ensemble's TV focus system
- Always a simple border overlay

**Focused State** (backgroundColor, scale, elevation, etc.):
- Changes to the **widget itself** when focused
- Animated transitions (150ms default)
- Stacks with focus indicator for rich effects

**Combined Example:**
```yaml
Button:
    label: "Watch Now"
    styles:
        backgroundColor: 0xFF2196F3
        borderRadius: 8
        tvOptions:
            row: 1
            order: 0
            # Focus indicator (white border around button)
            focusColor: 0xFFFFFFFF
            focusBorderWidth: 3
            focusBorderRadius: 10
            # Focused state (button itself changes)
            scale: 1.05
            backgroundColor: 0xFF1E88E5
            elevation: 8
```

Result when focused:
1. Button grows 5% larger (scale: 1.05)
2. Button background changes to darker blue
3. Button gets 8px elevation shadow
4. **Then** white 3px focus border appears around it

---

## 9. Common UI Patterns

### Back Button (44x44 Circular)

```yaml
- Column:
      styles:
          width: 44
          height: 44
          mainAxis: center
          crossAxis: center
          tvOptions:
              row: 0
              order: 0
              focusBorderRadius: 22
      onTap:
          navigateBack:
      children:
          - Image:
                source: ${env.assets}${env.back_icon_png}
                styles:
                    width: 44
                    height: 44
                    placeholderColor: transparent
```

### "View All" Link with Arrow

```yaml
Row:
    styles:
        mainAxis: spaceBetween
    children:
        - Text:
              text: Section Title
        - Row:
              styles:
                  gap: 8
                  crossAxis: center
                  padding: 4 8
                  tvOptions:
                      row: 10
                      order: 0
                      focusBorderRadius: 16
              onTap:
                  navigateScreen:
                      name: TargetScreen
              children:
                  - Text:
                        text: View all
                        className: linkTextSmall
                  - Icon:
                        name: arrow_forward
                        color: 0xff00aaff
                        size: 16
```

### Switch in List

```yaml
- Switch:
      styles:
          flexMode: none
          maxWidth: 60
          width: 60
          tvOptions:
              row: ${tvRow}
              order: ${tvOrder * 2}
      value: ${item.notifications}
      onChange: ...
```

### Dialog Focus Order

```yaml
DialogWidget:
    body:
        Column:
            children:
                # Close button (row 0)
                - FlexRow:
                      children:
                          - Text:
                                text: Title
                                styles:
                                    flexMode: expanded
                          - Column:
                                styles:
                                    flexMode: none
                                    tvOptions:
                                        row: 0
                                        order: 0
                                onTap:
                                    closeAllDialogs:
                                children:
                                    - Icon:
                                          name: close

                # Content items (row 1+)
                - Column:
                      item-template:
                          data: ${items}
                          indexId: idx
                          template:
                              ItemWidget:
                                  inputs:
                                      tvOptions:
                                          row: ${1 + idx}
                                          order: 0

                # Save button (high row number)
                - Button:
                      label: Save
                      styles:
                          tvOptions:
                              row: 50
                              order: 0
```

---

## 10. Pitfalls to Avoid

### Order Conflicts in Lists

```yaml
# WRONG - Creates conflicts!
Switch:  order: ${index}      # 0, 1, 2
Delete:  order: ${index + 1}  # 1, 2, 3  <- Item 1 Switch (1) = Item 0 Delete (1)

# CORRECT - No conflicts
Switch:  order: ${index * 2}      # 0, 2, 4
Delete:  order: ${index * 2 + 1}  # 1, 3, 5
```

### tvOptions on Wrong Element

```yaml
# WRONG - Switch won't be focusable!
Column:
    styles:
        tvOptions:
            row: 0
    children:
        - Switch:
            value: true

# CORRECT - tvOptions on the Switch itself
Column:
    children:
        - Switch:
            styles:
                tvOptions:
                    row: 0
            value: true
```

### Missing flexMode in FlexRow

```yaml
# WRONG - Column may expand unexpectedly
FlexRow:
    children:
        - Text:
            styles:
                flexMode: expanded
        - Column:
            styles:
                width: 40
            onTap: ...

# CORRECT - Explicitly set flexMode: none
FlexRow:
    children:
        - Text:
            styles:
                flexMode: expanded
        - Column:
            styles:
                flexMode: none
                width: 40
            onTap: ...
```

### Size Mismatch (Gap Between Border and Content)

```yaml
# WRONG - 4px gap on each side!
Column:
    styles:
        width: 48
        height: 48
        tvOptions:
            focusBorderRadius: 24
    children:
        - Image:
            styles:
                width: 40
                height: 40

# CORRECT - Same size, no gap
Column:
    styles:
        width: 44
        height: 44
        tvOptions:
            focusBorderRadius: 22
    children:
        - Image:
            styles:
                width: 44
                height: 44
```

---

## 11. Testing Checklist

### Navigation

- [ ] All focusable elements have unique (row, order) pairs
- [ ] D-pad UP/DOWN moves between rows correctly
- [ ] D-pad LEFT/RIGHT moves within rows correctly
- [ ] First item in each row has `isRowEntryPoint: true`
- [ ] Back button is always row 0, order 0
- [ ] Dialog focus is trapped within dialog

### Focus Visual

- [ ] Focus border has appropriate radius matching widget shape
- [ ] No visual gap between focus border and widget content
- [ ] Focus color is visible against background

### Scrolling (fixedFocusScroll)

- [ ] Content scrolls smoothly while focus stays fixed
- [ ] Focus moves correctly at list boundaries
- [ ] `fixedFocusOffset` positions the focused item appropriately
- [ ] Scroll position resets when re-entering the row

### Carousel Navigation

- [ ] LEFT/RIGHT on carousel items switches slides
- [ ] Focus is restored to new slide's button after slide change
- [ ] Autoplay pauses when carousel item is focused
- [ ] Autoplay resumes when focus leaves carousel
- [ ] UP/DOWN exits carousel to adjacent rows correctly
- [ ] `lockHorizontalNavigation` blocks escape at lane boundaries

### ListView Scrollbar

- [ ] Scrollbar appears on correct side (left/right based on position)
- [ ] Scrollbar only shows on TV (not mobile/web)
- [ ] RIGHT from rightmost item goes to scrollbar (right position)
- [ ] LEFT from leftmost item goes to scrollbar (left position)
- [ ] Multi-column navigation works before reaching scrollbar
- [ ] Scrollbar visual changes when focused (color, width)
- [ ] UP/DOWN on scrollbar scrolls content smoothly
- [ ] LEFT from right scrollbar returns to content
- [ ] RIGHT from left scrollbar returns to content
- [ ] Scrollbar thumb position syncs with scroll position

---

## 12. Troubleshooting

### Focus not working on Ensemble widgets

1. Verify `row` is set in `tvOptions`
2. Check if `TVFocusProviderScope` is wrapping content
3. Ensure widget has `onTap` handler or is a form widget
4. Verify `rowOffset` and `orderOffset` values in provider

### Navigation skipping items

1. Check for duplicate row/order values
2. Verify items are within same `FocusTraversalGroup`
3. Check `lockHorizontalNavigation` settings

### Scroll not following focus

1. Enable `fixedFocusScroll: true`
2. Set appropriate `fixedFocusOffset`
3. Check if host's `handlesHorizontalScroll` is interfering

### Carousel slides not switching

1. Verify `delegateHorizontalNavigation: true` on carousel items
2. Check `interceptHorizontalNav: true` on carousel
3. Ensure carousel's FocusScope is receiving bubbled events

### Navigation conflicts with native content

1. Ensure `EnsembleWrapper` is scoped correctly (inside tab, not top-level)
2. Check row/order alignment with host app's focus grid
3. Verify cross-boundary navigation is enabled

### Scrollbar not receiving focus

1. Verify `scrollbarOptions` is set under `tvOptions` (not directly in `styles`)
2. Check position value is `'left'` or `'right'` (string, not unquoted)
3. For multi-column: ensure you're at the rightmost/leftmost item before pressing the edge key
4. Check logs for `[TVFocusWidget] At right edge - calling onRightEdge handler`
5. Verify ListView has a scroll controller (automatic for most cases)

### Scrollbar not scrolling content

1. Verify ListView content exceeds viewport (scrollbar needs scrollable content)
2. Check if `scrollController.hasClients` is true
3. Look for errors in logs related to scroll position

### Scrollbar appearing on wrong side

1. Verify `position` property value: `'left'` or `'right'`
2. Check for typos in position value
3. Ensure quotes around position value in YAML

---

## Row Number Guidelines

| Screen Section                  | Recommended Row Range |
| ------------------------------- | --------------------- |
| Header (back button, actions)   | 0                     |
| Hero Carousel                   | 0 (carousel items)    |
| Info/help buttons               | 1                     |
| Favorites row                   | 1                     |
| Main content lists              | 2-4                   |
| Section headers with "View all" | 5, 7                  |
| Section content rows            | 6, 8                  |
| Footer buttons                  | 50+                   |

**Note**: Leave gaps between sections to allow for future additions.

---

## Related Documentation

- [TV_FOCUS_NAVIGATION_RULES.md](TV_FOCUS_NAVIGATION_RULES.md) - Quick reference patterns and rules for TV navigation YAML
- [TV_IMPLEMENTATION_HISTORY.md](TV_IMPLEMENTATION_HISTORY.md) - Technical implementation details and commit history
- [ENSEMBLE_FRAMEWORK_REFERENCE.md](ENSEMBLE_FRAMEWORK_REFERENCE.md) - General Ensemble framework reference

---

## Appendix: Quick Reference Card

### Minimum TV-Enabled Widget

```yaml
Button:
    label: "Click"
    styles:
        tvOptions:
            row: 1
            order: 0
    onTap: ...
```

### Horizontal List Item

```yaml
tvOptions:
    row: 2
    order: ${index}
    isRowEntryPoint: ${index == 0}
    lockHorizontalNavigation: true
    fixedFocusScroll: true
    fixedFocusOffset: 48
```

### Carousel Item Button

```yaml
tvOptions:
    row: 0
    order: ${slideIndex}
    delegateHorizontalNavigation: true
    verticalScrollPadding: 400
```

### Carousel Container

```yaml
tvOptions:
    pauseAutoplayOnFocus: true
    interceptHorizontalNav: true
    restoreFocusOnPageChange: true
```
