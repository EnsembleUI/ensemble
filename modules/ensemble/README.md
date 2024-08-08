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


# How to run test
- Run unit test with `flutter test`.
- For integration test:
  - first open `.ios > Podfile` and add this entry `ENV['SWIFT_VERSION'] = '5'`.
  - Run `flutter test integration_test`.