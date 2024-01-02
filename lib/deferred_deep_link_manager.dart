import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';

typedef DeferredDeepLink = Function(Map<dynamic, dynamic>);

enum DeepLinkProvider { branch, appsflyer, adjust }

class DeferredLinkResponse {
  bool success = true;
  dynamic result;
  String errorCode = '';
  String errorMessage = '';

  DeferredLinkResponse.success({required this.result}) {
    success = true;
  }
  DeferredLinkResponse.error(
      {required this.errorCode, required this.errorMessage}) {
    success = false;
  }

  @override
  String toString() {
    return ('success: $success, errorCode: $errorCode, errorMessage: $errorMessage}');
  }
}

class DeferredDeepLinkManager {
  static final DeferredDeepLinkManager _instance =
      DeferredDeepLinkManager._internal();

  DeferredDeepLinkManager._internal();

  factory DeferredDeepLinkManager() {
    return _instance;
  }

  Future<void> init({
    required DeepLinkProvider provider,
    Map<String, dynamic>? options,
    DeferredDeepLink? onLinkReceived,
  }) async {
    switch (provider) {
      case DeepLinkProvider.branch:
        final bool useTestKey =
            Utils.getBool(options?['useTestKey'], fallback: false);
        final bool enableLog =
            Utils.getBool(options?['enableLog'], fallback: false);
        final bool disableTrack =
            Utils.getBool(options?['disableTrack'], fallback: false);

        BranchLinkManager().init(
          useTestKey: useTestKey,
          enableLog: enableLog,
          disableTrack: disableTrack,
          onLinkReceived: onLinkReceived,
        );

      case DeepLinkProvider.appsflyer:
        throw LanguageError('Appsflyer Deeplink Provider is in development');
      case DeepLinkProvider.adjust:
        throw LanguageError('Adjust Deeplink Provider is in development');
    }
  }

  Future<DeferredLinkResponse?> createDeepLink(
      {required DeepLinkProvider provider,
      Map<String, dynamic>? universalProps,
      Map<String, dynamic>? linkProps}) async {
    switch (provider) {
      case DeepLinkProvider.branch:
        try {
          if (universalProps == null && linkProps == null) {
            return DeferredLinkResponse.error(
              errorCode: 'propsMissing',
              errorMessage: 'Universal and Link props are mandatory',
            );
          }
          final BranchResponse<dynamic> branchLinkResponse =
              await BranchLinkManager()
                  .createDeepLink(universalProps!, linkProps!);
          if (branchLinkResponse.success) {
            return DeferredLinkResponse.success(
                result: branchLinkResponse.result);
          }
          return DeferredLinkResponse.error(
            errorCode: branchLinkResponse.errorCode,
            errorMessage: branchLinkResponse.errorMessage,
          );
        } catch (_) {
          rethrow;
        }

      case DeepLinkProvider.appsflyer:
        throw LanguageError('Appsflyer Deeplink Provider is in development');
      case DeepLinkProvider.adjust:
        throw LanguageError('Adjust Deeplink Provider is in development');
    }
  }
}

class BranchLinkManager {
  static final BranchLinkManager _instance = BranchLinkManager._internal();

  BranchLinkManager._internal();

  factory BranchLinkManager() {
    return _instance;
  }

  Future<void> init({
    bool useTestKey = false,
    bool enableLog = false,
    bool disableTrack = false,
    DeferredDeepLink? onLinkReceived,
  }) async {
    FlutterBranchSdk.init(
        useTestKey: useTestKey,
        enableLogging: enableLog,
        disableTracking: disableTrack);
    FlutterBranchSdk.disableTracking(false);

    FlutterBranchSdk.listSession().listen((data) {
      onLinkReceived?.call(data);
    });
  }

  void validate() {
    FlutterBranchSdk.validateSDKIntegration();
  }

  Future<BranchResponse<dynamic>> createDeepLink(
      Map<String, dynamic> universalProps,
      Map<String, dynamic> linkProps) async {
    final buo = _getUniversalObject(universalProps);
    final blp = _getLinkProperties(linkProps);

    BranchResponse response =
        await FlutterBranchSdk.getShortUrl(buo: buo, linkProperties: blp);
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
