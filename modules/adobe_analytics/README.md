# Adobe Analytics Module for Ensemble

This module provides Adobe Analytics integration for Ensemble applications using Adobe Experience Platform SDK.

## Setup

1. Add the following dependencies to your app's `pubspec.yaml`:

```yaml
dependencies:
  ensemble_adobe_analytics:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: main
      path: modules/adobe_analytics
```

2. Initialize Adobe Analytics in your app's main.dart:

```dart
import 'package:ensemble_adobe_analytics/adobe_analytics.dart';

GetIt.I.registerSingleton<AdobeAnalyticsModule>(
    AdobeAnalyticsImpl(appId: ''));
```

## Usage

The module provides a singleton instance of Adobe Analytics that can be accessed throughout your application. The module supports five types of operations:

1. trackAction - For user interactions (button clicks, form submissions, etc.)
2. trackState - For page/screen views and navigation tracking
3. sendEvent - For Experience Platform events with XDM schema format
4. trackPurchase - For tracking product purchases
5. trackProductView - For tracking product views

### Examples

1. Track Action (User Interactions):
```yaml
logEvent:
  name: trackButtonClick
  provider: adobe
  parameters:
    eventName: "button_click"
    eventType: "button_click"
    eventSource: "mobile_app"
    eventCategory: "button_click"
    eventAction: "button_click"
    eventLabel: "button_click"
```

2. Track State (Page Views):
```yaml
logEvent:
  name: trackScreenView
  provider: adobe
  parameters:
    eventName: "screen_view"
    eventType: "screen_view"
    eventSource: "mobile_app"
```

3. XDM Event (Experience Platform):
```yaml
logEvent:
  name: trackXdmEvent
  provider: adobe
  parameters:
    eventName: "xdm_event"
    eventType: "xdm_event"
    eventSource: "mobile_app"
```

4. Track Purchase:
```yaml
logEvent:
  name: trackPurchase
  provider: adobe
  parameters:
    eventName: "purchase"
    eventType: "purchase"
    eventSource: "mobile_app"
    products: ";Running Shoes;1;69.95;event1|event2=55.99;eVar1=12345"
    events: "event5,purchase"
    additionalData:
      myapp.promotion: "a0138"
```

5. Track Product View:
```yaml
logEvent:
  name: trackProductView
  provider: adobe
  parameters:
    eventName: "product_view"
    eventType: "product_view"
    eventSource: "mobile_app"
    products: ";Running Shoes;1;69.95;prodView|event2=55.99;eVar1=12345"
    events: "event5,purchase"
    additionalData:
      myapp.promotion: "a0138"
      products: ";Running Shoes;1;69.95;prodView|event2=55.99;eVar1=12345"
```

## Requirements

- Flutter 3.0.0 or higher
- Adobe Experience Platform SDK
- Valid Adobe Analytics configuration

## Notes

- The module uses Adobe's Mobile Core SDK for basic tracking (trackAction and trackState)
- For Experience Platform events, it uses Adobe Edge SDK with XDM schema format
- Make sure to configure your Adobe Analytics settings in the Adobe Experience Platform
- Product tracking follows Adobe's product string format for compatibility with Adobe Analytics

## Implementation Details

The module uses a singleton pattern to ensure only one instance of Adobe Analytics is initialized and used throughout the application. Key features:

1. **Singleton Instance**: The `AdobeAnalyticsImpl` class is implemented as a singleton to maintain a single instance across the app
2. **Initialization Check**: All tracking methods check if Adobe Analytics is initialized before proceeding
3. **Error Handling**: Proper error handling for uninitialized state and tracking failures
4. **Type Safety**: Strong typing for parameters and return values
