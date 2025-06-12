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

Track event actions that occur in your application.

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

Track states that represent screens or views in your application.

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

Sends an Experience event to Adobe Experience Platform Edge Network.

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

This API retrieves the Experience Cloud ID (ECID) that was generated when the app was initially launched. This ID is preserved between app upgrades, is saved and restored during the standard application backup process, and is removed at uninstall.

```yaml
logEvent:
  name: getExperienceCloudId
  provider: adobe
  operation: getExperienceCloudId
```

#### Get All Identities

Get all identities in the Identity for Edge Network extension, including customer identifiers which were previously added.

```yaml
logEvent:
  name: getIdentities
  provider: adobe
  operation: getIdentities
```

#### Get URL Variables

Returns the identifiers in a URL's query parameters for consumption in hybrid mobile applications. The response will not return any leading & or ?, since the caller is responsible for placing the variables in the resulting URL in the correct locations. If an error occurs while retrieving the URL variables, the callback handler will return a null value. Otherwise, the encoded string is returned. An example of an encoded string is as follows: 'adobe_mc=TS%3DTIMESTAMP_VALUE%7CMCMID%3DYOUR_ECID%7CMCORGID%3D9YOUR_EXPERIENCE_CLOUD_ID'

- MCID: This is also known as the Experience Cloud ID (ECID).
- MCORGID: This is also known as the Experience Cloud Organization ID.
- TS: The timestamp that is taken when the request was made.

```yaml
logEvent:
  name: getUrlVariables
  provider: adobe
  operation: getUrlVariables
```

#### Remove Identity

Remove the identity from the stored client-side IdentityMap. The Identity extension will stop sending the identifier to the Edge Network. Using this API does not remove the identifier from the server-side User Profile Graph or Identity Graph.

Identities with an empty id or namespace are not allowed and are ignored.

Removing identities using a reserved namespace is not allowed using this API. The reserved namespaces are:

- ECID
- IDFA
- GAID

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

Clears all identities stored in the Identity extension and generates a new Experience Cloud ID (ECID) . Using this API does not remove the identifiers from the server-side User Profile Graph or Identity Graph.

This is a destructive action, since once an ECID is removed it cannot be reused. The new ECID generated by this API can increase metrics like unique visitors when a new user profile is created.

Some example use cases for this API are:

- During debugging, to see how new ECIDs (and other identifiers paired with it) behave with existing rules and metrics.
- A last-resort reset for when an ECID should no longer be used.

This API is not recommended for:

- Resetting a user's consent and privacy settings.
- Removing existing custom identifiers; use the `removeIdentity` API instead.
- Removing a previously synced advertising identifier after the advertising tracking settings were changed by the user; use the `setAdvertisingIdentifier` API instead.

ℹ️ The Identity for Edge Network extension does not read the Mobile SDK's privacy status and therefor setting the SDK's privacy status to opt-out will not clear the identities from the Identity for Edge Network extension.

```yaml
logEvent:
  name: resetIdentities
  provider: adobe
  operation: resetIdentities
```

#### Set Advertising Identifier

When this API is called with a valid advertising identifier, the Identity for Edge Network extension includes the advertising identifier in the XDM Identity Map using the namespace GAID (Google Advertising ID) in Android and IDFA (Identifier for Advertisers) in iOS. If the API is called with the empty string (''), null/nil, or the all-zeros UUID string values, the advertising identifier is removed from the XDM Identity Map (if previously set). The advertising identifier is preserved between app upgrades, is saved and restored during the standard application backup process, and is removed at uninstall.

```yaml
logEvent:
  name: setAdvertisingIdentifier
  provider: adobe
  operation: setAdvertisingIdentifier
  parameters:
    advertisingIdentifier: <your_advertising_identifier>
```

#### Update Identities

Update the currently known identities within the SDK. The Identity extension will merge the received identifiers with the previously saved ones in an additive manner, no identities are removed from this API.

Identities with an empty id or namespace are not allowed and are ignored.

Updating identities using a reserved namespace is not allowed using this API. The reserved namespaces are:

- ECID
- IDFA
- GAID

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

Retrieves the current consent preferences stored in the Consent extension.

```yaml
logEvent:
  name: getConsents
  provider: adobe
  operation: getConsents
```

#### Update Consent

Merges the existing consents with the given consents. Duplicate keys will take the value of those passed in the API.

```yaml
logEvent:
  name: updateConsent
  provider: adobe
  operation: updateConsent
  parameters:
    allowed: true  # or false
```

#### Set Default Consent

Sets the default consent preferences for the Consent extension.

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

Get user profile attributes which match the provided keys.

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

Remove provided user profile attributes if they exist.

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

Set multiple user profile attributes.

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

