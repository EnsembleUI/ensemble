# Adobe Analytics Module for Ensemble

[![Flutter](https://img.shields.io/badge/Flutter-3.0.0+-blue.svg)](https://flutter.dev)
[![Adobe Experience Platform](https://img.shields.io/badge/Adobe%20Experience%20Platform-5.0.0+-orange.svg)](https://developer.adobe.com/client-sdks/documentation/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A comprehensive Adobe Analytics integration module for Ensemble applications, providing seamless integration with Adobe Experience Platform SDK. This module enables tracking, identity management, consent handling, and user profile management in your Ensemble applications.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage Guide](#usage-guide)
  - [Core Operations](#1-core-operations)
  - [Edge Operations](#2-edge-operations)
  - [Identity Management](#3-identity-management)
  - [Consent Management](#4-consent-management)
  - [User Profile Management](#5-user-profile-management)
  - [Assurance](#6-assurance)
- [API Reference](#api-reference)
- [License](#license)

## Features

- 🔄 Real-time analytics tracking
- 👤 User identity management
- 🔒 Consent management
- 👥 User profile management
- 🛠️ Adobe Assurance integration
- ⚡ Edge network support
- 🔍 Comprehensive logging
- ⏱️ Timeout handling
- 🛡️ Error handling

## Installation

1. Add the following dependencies to your app's `pubspec.yaml`:

```yaml
dependencies:
  ensemble_adobe_analytics:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: main
      path: modules/adobe_analytics
```

2. Run the following command to install dependencies:

```bash
flutter pub get
```

## Configuration

Initialize Adobe Analytics in your app's `ensemble_modules.dart` file:

```dart
import 'package:ensemble_adobe_analytics/adobe_analytics.dart';

// Initialize Adobe Analytics
GetIt.I.registerSingleton<AdobeAnalyticsModule>(
  AdobeAnalyticsImpl(appId: "YOUR_APP_ID")
);
```

## Usage Guide

### 1. Core Operations

#### Track Action (User Interactions)
```yaml
logEvent:
  name: trackButtonClick
  provider: adobe
  operation: trackAction
  parameters:
    eventName: 'button_click'
    eventType: 'button_click'
    eventSource: 'mobile_app'
    eventCategory: 'button_click'
    eventAction: 'button_click'
    eventLabel: 'button_click'
```

#### Track State (Page Views)
```yaml
logEvent:
  name: trackScreenView
  provider: adobe
  operation: trackState
  parameters:
    eventName: 'screen_view'
    eventType: 'screen_view'
    eventSource: 'mobile_app'
```

### 2. Edge Operations

#### Send XDM Event
```yaml
logEvent:
  name: trackXdmEvent
  provider: adobe
  operation: sendEvent
  parameters:
    xdmData:
      eventType: 'commerce.productViews'
      commerce:
        productViews:
          value: 1
    data:
      customField: 'customValue'
      userSegment:
        - 'segment1'
        - 'segment2'
    datastreamIdOverride: <your_datastream_id>
```

### 3. Identity Management

#### Get Experience Cloud ID
```yaml
logEvent:
  name: getExperienceCloudId
  provider: adobe
  operation: getExperienceCloudId
```

#### Get All Identities
```yaml
logEvent:
  name: getIdentities
  provider: adobe
  operation: getIdentities
```

#### Get URL Variables
```yaml
logEvent:
  name: getUrlVariables
  provider: adobe
  operation: getUrlVariables
```

#### Remove Identity
```yaml
logEvent:
  name: removeIdentity
  provider: adobe
  operation: removeIdentity
  parameters:
    item:
      id: 'test-custom-id'
      authenticatedState: 'ambiguous'  # Options: 'authenticated', 'ambiguous', 'loggedOut'
      primary: false
    namespace: 'CustomNamespace'
```

#### Reset All Identities
```yaml
logEvent:
  name: resetIdentities
  provider: adobe
  operation: resetIdentities
```

#### Set Advertising Identifier
```yaml
logEvent:
  name: setAdvertisingIdentifier
  provider: adobe
  operation: setAdvertisingIdentifier
  parameters:
    advertisingIdentifier: '01558097716640647486978259215290248539'
```

#### Update Identities
```yaml
logEvent:
  name: updateIdentities
  provider: adobe
  operation: updateIdentities
  parameters:
    identities:
      CustomNamespace:
        - id: 'test-custom-id'
          authenticatedState: 'authenticated'
          primary: true
      CustomNamespace2:
        - id: 'test-custom-id-2'
          authenticatedState: 'authenticated'
          primary: false
```

### 4. Consent Management

#### Get Current Consents
```yaml
logEvent:
  name: getConsents
  provider: adobe
  operation: getConsents
```

#### Update Consent
```yaml
logEvent:
  name: updateConsent
  provider: adobe
  operation: updateConsent
  parameters:
    allowed: true  # or false
```

#### Set Default Consent
```yaml
logEvent:
  name: setDefaultConsent
  provider: adobe
  operation: setDefaultConsent
  parameters:
    allowed: true  # or false
```

### 5. User Profile Management

#### Get User Attributes
```yaml
logEvent:
  name: getUserAttributes
  provider: adobe
  operation: getUserAttributes
  parameters:
    attributes:
      - 'firstName'
      - 'lastName'
      - 'email'
```

#### Remove User Attributes
```yaml
logEvent:
  name: removeUserAttributes
  provider: adobe
  operation: removeUserAttributes
  parameters:
    attributes:
      - 'firstName'
      - 'lastName'
```

#### Update User Attributes
```yaml
logEvent:
  name: updateUserAttributes
  provider: adobe
  operation: updateUserAttributes
  parameters:
    attributeMap:
      firstName: 'John'
      lastName: 'Doe'
      email: 'john.doe@example.com'
```

### 6. Assurance

#### Setup Assurance Session
```yaml
logEvent:
  name: setupAssurance
  provider: adobe
  operation: setupAssurance
  parameters:
    url: <your_assurance_url>
```

## API Reference

### Core Methods

- `trackAction(String name, Map<String, String>? parameters)`
- `trackState(String name, Map<String, String>? parameters)`
- `sendEvent(String name, Map<String, dynamic>? parameters)`

### Identity Methods

- `getExperienceCloudId()`
- `getIdentities()`
- `getUrlVariables()`
- `removeIdentity(Map<String, dynamic> parameters)`
- `resetIdentities()`
- `setAdvertisingIdentifier(String advertisingIdentifier)`
- `updateIdentities(Map<String, dynamic> parameters)`

### Consent Methods

- `getConsents()`
- `updateConsent(bool allowed)`
- `setDefaultConsent(bool allowed)`

### User Profile Methods

- `getUserAttributes(Map<String, dynamic> parameters)`
- `removeUserAttributes(Map<String, dynamic> parameters)`
- `updateUserAttributes(Map<String, dynamic> parameters)`

## Requirements

- Flutter 3.0.0 or higher
- Adobe Experience Platform SDK
- Valid Adobe Analytics configuration
- Proper Adobe Experience Platform setup

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

