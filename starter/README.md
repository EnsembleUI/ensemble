## Overview
This starter project enables running and deploying Ensemble-powered Apps across iOS, Android, and Web (other platforms are not yet fully supported). It also includes examples on how to integrate Ensemble pages into your existing Flutter App.

## Setup
### Prerequisite
- Install [Flutter](https://docs.flutter.dev/get-started/install) on your machine. 
- Web is supported out-of-the-box. 
- To run on iOS emulator, install Xcode and Simulator. Run `open -a Simulator`. Create a new Simulator as needed (File -> Open Simulator -> ..).
- Please follow Flutter instructions on other platforms.

### Initial Setup
- Review `/ensemble/ensemble.properties`. Update the appId as needed - this is your app's bundle ID in the format of <reversed-domain>.<project name> e.g. `com.ensembleui.myfirstapp` (all lowercase, no special characters). 
- Run `flutter create --org com.ensembleui --project-name starter --platform=ios,android,web .` (note the period at the end). If you modified the appId, make sure the org and project name match the bundle ID.
- Run `flutter pub upgrade`. Run this occasionally when the Ensemble framework has been updated.
- Run the App with `flutter run`. If you currently have a running iOS or Android emulator, the command will prompt for a selection, otherwise the App will be opened in the web browser.
- This will run the `Ensemble Kitchen Sink` app. This app is available as a demo app in Ensemble Studio.
- Optionally, you can package your app locally, or hosted them on your own server or on Ensemble-hosted server. 

### Modules
By default, Starter does not include all the modules or capabilities (e.g. camera, location). Excluding these capabilities by default reduces the App's size and not trigger any red flags during your App Store Review (e.g. camera code is present when your app doesn't use camera). Please follow the below steps carefully if your app requires these capabilities:
- In `pubspec.yaml`, uncomment the libraries that correspond to the capabilities you need, e.g. `ensemble_camera`
- Run `flutter pub upgrade`
- In `lib/generated/EnsembleModules.dart`, enable your services and uncomment the lines that correspond with your capabilities. For example, if you are importing `ensemble_camera`, uncomment the import and lines relating to `CameraServiceImpl`
  - TODO: these files will eventually be automatically generated during a build step
- Run `flutter run` to verify the additional capabilities
- Follow the [docs](https://docs.ensembleui.com/#/deploy/1-prepare-app) on deploying your app 

### Getting Started with Ensemble Studio
Ensemble Studio enables you to make changes to your pages and immediately broadcast the changes to your App (both native and web). Here's how to get started:
- Login or sign up at studio.ensembleui.com.
- Find your App ID. This is under the App's Settings screen, or on the App's URL `https://studio.ensembleui.com/app/<appId>/...`.
- Open up `/ensemble/ensemble-config.yaml`. 
  - Update `definitions -> from` to `ensemble` (previously `local`)
  - Update `definitions -> ensemble -> appId` with your App ID.
- Run the App with `flutter run`. Your App now fetches its pages and resources from Ensemble server.
- Go back to your App on Ensemble Studio and make any changes. Re-running the App with `flutter run` should have the latest content.

### Concepts
- Each YAML definition under your app folder represents a screen.
- `theme.ensemble` allows you to make styling changes that are applicable to the entire app
- `resources.ensemble` is where you can define you own custom widgets, visible across the entire app.

## Editing definitions
Ensemble Studio includes an Online Editor for making changes with type-ahead support and enables Live Preview. However if you decide to host your own definitions, we include a JSON Schema to help with type-ahead for popular Editors.
### Android Studio
- Open Preferences and go to `Languages & Frameworks > Schemas and DTDs > JSON Schema Mappings`
- Add a new schema
- Under Schema URL, enter `https://raw.githubusercontent.com/EnsembleUI/ensemble/main/assets/schema/ensemble_schema.json`
- Select Schema version 7
- Add a Directory mapping right below, pointing to `<your_folder>/starter/ensemble/apps`.
- Editing any definition files will show the appropriate type-ahead.

### Visual Studio Code
- With [VS Code](https://code.visualstudio.com/download), open folder `/ensemble/apps`. 
- Type-ahead should just work with the the default config (in .vscode/settings.json).

## Generate release code for deployment 
- Run `flutter build web --release`. The output will be under `/build/web`
- Follow [iOS](https://docs.flutter.dev/deployment/ios), [Android](https://docs.flutter.dev/deployment/android), [MacOS](https://docs.flutter.dev/deployment/macos), [Windows](https://docs.flutter.dev/deployment/windows) release documentation.

## Misc
### Run with remote definition
To take advantage of Server-driven UI (change your UI at anytime from the server), you can host these definitions on your file server.
When hosting on your server, follow the following steps. 

- in ensemble/ensemble-config.yaml - specify `from: remote` under `definitions`
- then change the `remote:` settings to match your server's configuration
- make sure that your server is configured to serve files with extension `.ensemble` with `text/yaml` mime-type.
- lastly if you are running `flutter run` with web configuration locally, make sure your webserver is properly configured to avoid CORS issues. See `custom_http_server.py` for an example

- You can also use the sample python server script to test it out locally, see `custom_http_server.py` and run it as `python3 custom_http_server.py` from command prompt.
- Alternatively, you can build starter for web as `flutter build web --no-tree-shake-icons --base-href "/web/"`. Then copy/paste the starter/build/web folder under the root directory on your localhost and access it as - `<domain>:<port>/web/index.html` This should avoid the CORS issue. 

### For Flutter developers
Use [Android Studio](https://developer.android.com/studio) to open this project and run `main.dart`.
To incorporate Ensemble pages to your existing Flutter App, see `example_existing_app_*.dart`.

## Build Tips
### Windows
- If any issue is faced on `flutter pub get`, clean Pub cache either by running `flutter pub cache clean` command or emptying the contents of 'C:\Users\username\AppData\Local\Pub\Cache' directory.
