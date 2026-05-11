# Ensemble Table Calendar example

Demonstrates how to use the local `ensemble_table_calendar` package. Displays the calendar widget with a `ListView` underneath it.

| ![Image](https://raw.githubusercontent.com/aleksanderwozniak/table_calendar/assets/table_calendar_styles.gif) | ![Image](https://raw.githubusercontent.com/aleksanderwozniak/table_calendar/assets/table_calendar_builders.gif) |
| :------------: | :------------: |
| **Table Calendar** with custom styles | **Table Calendar** with Builders |

**Table Calendar** offers a lot of customization:
* by using custom Styles
* by using custom Builders (accompanied by custom Styles)

Using just Styles is a great way to get nice results with little effort.
That being said, using Builders will give you full control over Calendar's UI.

This example project will show you both of aforementioned methods.

## Installation / Setup

From the repository root:

```bash
melos bootstrap
```

## Usage

Run the example from this directory:

```bash
flutter run
```

For the package API, see `../lib/ensemble_table_calendar.dart`.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android  | Yes | `android/` example runner is present. |
| iOS      | Yes | `ios/` example runner is present. |
| Web      | Unknown | No `web/` runner was found in this example. |
| macOS    | Unknown | Not verified from source. |
| Windows  | Unknown | Not verified from source. |
| Linux    | Unknown | Not verified from source. |

## Permissions

No runtime permissions were found in this example.

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_table_calendar_example" -- flutter analyze
melos exec --scope="ensemble_table_calendar_example" -- flutter test
```

## Testing

No package-specific tests were found.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
