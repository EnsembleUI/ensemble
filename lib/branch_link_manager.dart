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

  Future<BranchResponse<dynamic>?> createDeepLink(
      Map<String, dynamic> universalProps,
      Map<String, dynamic> linkProps) async {
    final contentMetadata = BranchContentMetaData();
    contentMetadata.contentSchema = universalProps['contentSchema'];

    final buo = BranchUniversalObject(
      canonicalIdentifier: universalProps['id'],
      title: universalProps['title'],
      imageUrl: universalProps['imageUrl'],
      contentDescription: universalProps['title'],
      contentMetadata: contentMetadata,
    );

    final blp = BranchLinkProperties(
      channel: linkProps['channel'],
      feature: linkProps['feature'],
      campaign: linkProps['campaign'],
      stage: linkProps['stage'],
      tags: linkProps['tags'],
    );

    final controlParams = linkProps['controlParams'] as Map<String, dynamic>?;
    if (controlParams != null) {
      controlParams.forEach((key, value) {
        blp.addControlParam(key, value);
      });
    }

    try {
      BranchResponse response =
          await FlutterBranchSdk.getShortUrl(buo: buo, linkProperties: blp);
      return response;
    } catch (e) {
      return null;
    }
  }
}
