/// Deferred deep-link manager implementation for Ensemble apps.
library deferred_link_manager;

import 'package:ensemble/deep_link_manager.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/stub/deferred_link_manager.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';

/// Routes Ensemble deferred-link calls to the configured provider.
class DeferredLinkManagerImpl extends DeferredLinkManager {
  static final DeferredLinkManagerImpl _instance =
      DeferredLinkManagerImpl._internal();

  DeferredLinkManagerImpl._internal();

  /// Returns the singleton deferred-link manager.
  factory DeferredLinkManagerImpl() {
    return _instance;
  }

  /// Initializes the selected deferred deep-link provider.
  @override
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

  /// Creates a deferred deep link for the selected provider.
  @override
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

  /// Handles an incoming deferred-link URL.
  @override
  void handleDeferredLink(String url, DeferredDeepLink onLinkReceived) {
    BranchLinkManager().handleDeferredLink(url, onLinkReceived);
  }
}

/// Branch SDK adapter used by [DeferredLinkManagerImpl].
class BranchLinkManager {
  static final BranchLinkManager _instance = BranchLinkManager._internal();

  BranchLinkManager._internal();

  /// Returns the singleton Branch link manager.
  factory BranchLinkManager() {
    return _instance;
  }

  /// Initializes Branch link handling.
  Future<void> init({
    bool useTestKey = false,
    bool enableLog = false,
    bool disableTrack = false,
    DeferredDeepLink? onLinkReceived,
  }) async {
    await FlutterBranchSdk.init(
        useTestKey: useTestKey,
        enableLogging: enableLog,
        disableTracking: disableTrack);

    FlutterBranchSdk.listSession().listen((data) {
      try {
        DeepLinkNavigator().navigateToScreen(data);
      } on Exception catch (_) {}

      try {
        if (data.isNotEmpty) {
          onLinkReceived?.call(data);
        }
      } on Exception catch (_) {}
    });
  }

  /// Validates the Branch SDK integration.
  void validate() {
    FlutterBranchSdk.validateSDKIntegration();
  }

  /// Handles a Branch deferred-link URL.
  void handleDeferredLink(String url, DeferredDeepLink onLinkReceived) {
    FlutterBranchSdk.listSession().listen((data) {
      if (data.isNotEmpty) {
        onLinkReceived.call(data);
      }
    });
    FlutterBranchSdk.handleDeepLink(url);
  }

  /// Creates a short Branch deep link.
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
