import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/util/utils.dart';
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
    final buo = _getUniversalObject(universalProps);
    final blp = _getLinkProperties(linkProps);

    try {
      BranchResponse response =
          await FlutterBranchSdk.getShortUrl(buo: buo, linkProperties: blp);
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<BranchResponse> createDeeplinkWithShareSheet({
    required String messageText,
    required Map<String, dynamic> universalProps,
    required Map<String, dynamic> linkProps,
    String messageTitle = '',
    String sharingTitle = '',
  }) async {
    final buo = _getUniversalObject(universalProps);
    final blp = _getLinkProperties(linkProps);

    BranchResponse response = await FlutterBranchSdk.showShareSheet(
      buo: buo,
      linkProperties: blp,
      messageText: messageText,
      androidMessageTitle: messageTitle,
      androidSharingTitle: sharingTitle,
    );

    return response;
  }

  BranchUniversalObject _getUniversalObject(
      Map<String, dynamic> universalProps) {
    final contentMetadata = BranchContentMetaData();
    // contentMetadata.contentSchema = BranchContentSchema.values.from(universalProps['contentSchema']);
    contentMetadata.contentSchema =
        BranchContentSchema.values.from('COMMERCE_PRODUCT');

    return BranchUniversalObject(
      canonicalIdentifier: universalProps['id'],
      title: universalProps['title'],
      imageUrl: universalProps['imageUrl'],
      contentDescription: universalProps['title'],
      // contentMetadata: contentMetadata,
    );
  }

  BranchLinkProperties _getLinkProperties(Map<String, dynamic> linkProps) {
    final blp = BranchLinkProperties(
      channel: linkProps['channel'],
      feature: linkProps['feature'],
      campaign: linkProps['campaign'],
      stage: linkProps['stage'],
      tags: Utils.getListOfStrings(linkProps['tags']) ?? [],
    );

    final controlParams = Utils.getMap(linkProps['controlParams']);
    if (controlParams != null) {
      controlParams.forEach((key, value) {
        blp.addControlParam(key, value);
      });
    }

    return blp;
  }
}
