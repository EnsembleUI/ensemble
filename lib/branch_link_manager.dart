import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';

class BranchLinkManager {
  static final BranchLinkManager _instance = BranchLinkManager._internal();

  BranchLinkManager._internal();

  factory BranchLinkManager() {
    return _instance;
  }

  Future<void> init(
      {bool useTestKey = false,
      bool enableLog = false,
      bool disableTrack = false}) async {
    FlutterBranchSdk.init(
        useTestKey: useTestKey,
        enableLogging: enableLog,
        disableTracking: disableTrack);
  }

  void validate() {
    FlutterBranchSdk.validateSDKIntegration();
  }
}
