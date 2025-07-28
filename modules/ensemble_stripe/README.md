# Ensemble Stripe Module

A Stripe payment integration module for the Ensemble framework, providing easy-to-use actions for handling payments with Stripe's Payment Sheet.

## Features

- **Payment Processing**: Initialize Stripe and show payment sheets
- **Payment Sheet**: Display the native Stripe payment sheet for secure payments
- **Error Handling**: Comprehensive error handling with onError callbacks
- **Modular Design**: Easy to extend with new payment features

## Installation

The Stripe actions are now part of the Ensemble runtime and are available by default. To use the Stripe module implementation, add it to your Ensemble project:

```yaml
dependencies:
  ensemble_stripe:
    path: modules/ensemble_stripe
```

## Configuration

Stripe is automatically initialized when the module is enabled. Add your Stripe configuration to `ensemble-config.yaml`:

```yaml
# Stripe payment configuration
stripe:
  enabled: true
  publishableKey: "pk_test_your_publishable_key_here"
  stripeAccountId: "acct_optional_account_id"  # Optional
  merchantIdentifier: "merchant.com.yourapp"   # Optional, for Apple Pay
```

The configuration is automatically read from `ensemble-config.yaml` when the first payment sheet is shown.

## Actions

### showPaymentSheet

Display the native Stripe payment sheet.

```yaml
showPaymentSheet:
  clientSecret: "pi_client_secret_here"
  configuration:
    merchantDisplayName: "Your Company"
    primaryButtonLabel: "Pay Now"
    style: "system"  # "light", "dark", or "system"
    billingDetails:
      name: "John Doe"
      email: "john@example.com"
      phone: "+1234567890"
      address:
        line1: "123 Main St"
        city: "New York"
        state: "NY"
        postalCode: "10001"
        country: "US"
  onSuccess:
    showToast:
      message: "Payment completed successfully"
  onError:
    showToast:
      message: "Payment failed"
```

## Complete Example

Here's a complete example of a payment flow:

```yaml
View:
  body:
    Column:
      children:
        - Text:
            text: "Complete Payment"
            styles:
              fontSize: 24
              fontWeight: bold
              marginBottom: 20
        
        - Button:
            text: "Pay $20.00"
            styles:
              backgroundColor: "#007AFF"
              color: white
              padding: 15
              borderRadius: 8
            onTap:
              showPaymentSheet:
                clientSecret: "pi_test_client_secret_here"
                configuration:
                  merchantDisplayName: "Your Company"
                  primaryButtonLabel: "Pay Now"
                  style: "system"
                onSuccess:
                  showToast:
                    message: "Payment successful!"
                onError:
                  showToast:
                    message: ${event.error}
```

## Configuration

### iOS Configuration

Add the following to your `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Scan your card to add it automatically</string>
```

### Android Configuration

Ensure your Android app uses:
- Android 5.0 (API level 21) and above
- Kotlin version 1.8.0 and above
- Android Gradle plugin 8 and higher
- `FlutterFragmentActivity` instead of `FlutterActivity`

## Error Handling

All actions support error handling through the `onError` callback. The error information is available in the event data:

```yaml
onError:
  showToast:
    message: "Error: {{event.error}}"
```

## Dependencies

- `flutter_stripe: ^11.5.0`
- `ensemble: path: ../ensemble`
- `get_it: ^8.0.3`

## License

This module follows the same license as the Ensemble framework. 