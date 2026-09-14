## 0.1.0

* Initial release of the on-device agent runtime.
* Provider-agnostic `EnsembleAgent` API with sessions, tool calling, streaming,
  capability detection, and standardized errors.
* Custom native plugins: Apple Foundation Models (iOS) and Gemini Nano via ML Kit
  GenAI Prompt API (Android).
* Android tools via **Path B** (Ensemble JSON tool protocol); `nativeToolCalling`
  is false on Nano because the Prompt API has no function calling.
* Fake provider for unit tests.
