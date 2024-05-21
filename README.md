# Ensemble

Welcome to the Ensemble! This repository houses the Flutter runtime, various modules, and an example app called the Starter App that utilizes different packages. Ensemble allows you to build, publish, and iterate native and web apps seamlessly within your browser.

## What is Ensemble?

Ensemble is a revolutionary platform that enables app development through a declarative language. Rather than traditional coding, you configure your app using this language, allowing for rapid development and deployment. Key features of Ensemble include:

- **Native Experience:** Ensemble apps are native to each platform - iOS, Android, and web.
- **Instant Updates:** App definitions are pushed to clients, enabling instant updates without waiting for app store approvals.
- **Cutting-Edge Technologies:** Ensemble apps leverage the latest front-end technologies, such as Flutter for iOS and Android, and React for web, ensuring you're always at the forefront without worrying about technical debt.

## Modules

This monorepo contains the following modules:

- **Auth Module:** Handles authentication functionalities.
- **Bracket Module:** Manages brackets for various purposes.
- **Camera Module:** Provides camera-related features.
- **Connect Module:** Facilitates connectivity features.
- **Contacts Module:** Manages contact information.
- **Deeplink Module:** Handles deep linking functionalities.
- **File Manager Module:** Manages files within the app.
- **Firebase Analytics Module:** Integrates Firebase analytics into Ensemble apps.

## Getting Started
- Ensemble comes bundled with the Starter (located in /starter) to run any Ensemble-powered apps.
- First initialize the modules with `melos bootstrap`, then follow the instructions at [Starter README](/starter/README.md).

## Links

- [Ensemble Website](https://ensembleui.com/)
- [Ensemble Docs](https://docs.ensembleui.com/#/)
- [Ensemble Studio](https://studio.ensembleui.com/)
- [Ensemble Go (App Store)](https://testflight.apple.com/join/yFKnLQ1S)
- [Ensemble Preview (Play Store)](https://play.google.com/store/apps/details?id=com.ensembleui.preview)

## Melos Integration

This monorepo is managed using [Melos](https://melos.invertase.dev/), a tool for managing Dart and Flutter monorepos. Below are some useful commands:

- **Initialize Melos:** `melos bootstrap` - Initializes the monorepo and installs dependencies.
- **Add Dependency:** `melos add` - Add a dependency to one or more packages.
- **Run Scripts:** `melos exec` - Run a script in each package.
- **Publish Packages:** `melos release` - Publishes changed packages.

## How to Contribute

To contribute a new widget or enhance an existing one in Ensemble, follow these steps:

1. All Ensemble widgets can be found [here](https://github.com/EnsembleUI/ensemble/tree/main/lib/widget).
2. Run the Kitchen Sink app locally by visiting [this link](https://studio.ensembleui.com/app/e24402cb-75e2-404c-866c-29e6c3dd7992/screens) and use the appId as described above.
3. Explore how each widget works and how the YAML is mapped to the Flutter widget.
4. Create your own app and screens with your widget (or enhanced widget) in the studio. Ensure it works flawlessly.
5. When ready, create a pull request, and our team will review and provide feedback.

Thank you for contributing to Ensemble! 🚀
