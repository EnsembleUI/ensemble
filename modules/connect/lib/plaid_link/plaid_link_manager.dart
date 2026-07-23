/// Plaid Link manager and response models for Ensemble apps.
library plaid_link_manager;

import 'package:ensemble/framework/stub/plaid_link_manager.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

/// Opens Plaid Link and forwards success, event, and exit callbacks.
class PlaidLinkManagerImpl extends PlaidLinkManager {
  @override
  void openPlaidLink(String plaidLink, PlaidLinkSuccessCallback onSuccess,
      PlaidLinkEventCallback onEvent, PlaidLinkErrorCallback onExit) {
    // Subscribe to all events

    PlaidLink.onSuccess.listen((successData) {
      onSuccess(PlaidLinkSuccess.fromLinkSuccess(successData).toJson());
    });
    PlaidLink.onEvent.listen((eventData) {
      onEvent(eventData.toJson());
    });
    PlaidLink.onExit.listen((exitData) {
      onExit(exitData.toJson());
    });

    PlaidLink.open(configuration: LinkTokenConfiguration(token: plaidLink));
  }
}

/// Successful Plaid Link result exposed to Ensemble.
class PlaidLinkSuccess {
  /// Public token returned by Plaid Link.
  final String publicToken;

  /// Metadata returned with the successful Plaid Link result.
  final PlaidLinkSuccessMetadata metadata;

  /// Creates a successful Plaid Link result.
  PlaidLinkSuccess({
    required this.publicToken,
    required this.metadata,
  });

  /// Converts a `plaid_flutter` success payload into an Ensemble model.
  factory PlaidLinkSuccess.fromLinkSuccess(LinkSuccess data) {
    return PlaidLinkSuccess(
      publicToken: data.publicToken,
      metadata: PlaidLinkSuccessMetadata(
        linkSessionId: data.metadata.linkSessionId,
        institution: PlaidLinkInstitution(
          id: data.metadata.institution?.id ?? '',
          name: data.metadata.institution?.name ?? '',
        ),
        accounts: data.metadata.accounts
            .map(
              (e) => PlaidLinkAccount(
                  id: e.id,
                  mask: e.mask,
                  name: e.name,
                  type: e.type,
                  subtype: e.subtype,
                  verificationStatus: e.verificationStatus),
            )
            .toList(),
      ),
    );
  }

  /// Converts this result to JSON-like map data.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'publicToken': publicToken,
      'metadata': metadata.toJson(),
    };
  }
}

/// Metadata returned by a successful Plaid Link session.
class PlaidLinkSuccessMetadata {
  /// Plaid Link session identifier.
  final String linkSessionId;

  /// Institution selected by the user.
  final PlaidLinkInstitution? institution;

  /// Accounts selected by the user.
  final List<PlaidLinkAccount> accounts;

  /// Creates Plaid Link success metadata.
  PlaidLinkSuccessMetadata({
    required this.linkSessionId,
    required this.institution,
    required this.accounts,
  });

  /// Creates metadata from JSON-like map data.
  factory PlaidLinkSuccessMetadata.fromJson(dynamic json) {
    return PlaidLinkSuccessMetadata(
      linkSessionId: json['linkSessionId'],
      institution: json['institution'] != null
          ? PlaidLinkInstitution.fromJson(json['institution'])
          : null,
      accounts: (json['accounts'] as List)
          .map((info) => PlaidLinkAccount.fromJson(info))
          .toList(),
    );
  }

  /// Converts this metadata to JSON-like map data.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'linkSessionId': linkSessionId,
      'institution': institution?.toJson(),
      'accounts': accounts.map((e) => e.toJson()).toList(),
    };
  }

  /// Returns a readable description of the metadata.
  String description() {
    String description =
        "linkSessionId: $linkSessionId, institution.id: ${institution?.id}, institution.name: ${institution?.name}, accounts: ";

    for (PlaidLinkAccount a in accounts) {
      description += a.description();
    }

    return description;
  }
}

/// Institution metadata returned by Plaid Link.
class PlaidLinkInstitution {
  /// Plaid institution identifier.
  final String id;

  /// Plaid institution display name.
  final String name;

  /// Creates Plaid institution metadata.
  PlaidLinkInstitution({
    required this.id,
    required this.name,
  });

  /// Creates institution metadata from JSON-like map data.
  factory PlaidLinkInstitution.fromJson(dynamic json) {
    return PlaidLinkInstitution(
      id: json['id'],
      name: json['name'],
    );
  }

  /// Converts this institution to JSON-like map data.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
    };
  }

  /// Returns a readable description of the institution.
  String description() {
    return "id: $id, name: $name";
  }
}

/// Account metadata returned by Plaid Link.
class PlaidLinkAccount {
  /// Plaid account identifier.
  final String id;

  /// Masked account number, when available.
  final String? mask;

  /// Account display name.
  final String name;

  /// Plaid account type.
  final String type;

  /// Plaid account subtype.
  final String subtype;

  /// Verification status, when available.
  final String? verificationStatus;

  /// Creates Plaid account metadata.
  PlaidLinkAccount({
    required this.id,
    required this.mask,
    required this.name,
    required this.type,
    required this.subtype,
    required this.verificationStatus,
  });

  /// Creates account metadata from JSON-like map data.
  factory PlaidLinkAccount.fromJson(dynamic json) {
    return PlaidLinkAccount(
      id: json['id'],
      name: json['name'],
      mask: json['mask'],
      type: json['type'],
      subtype: json['subtype'],
      verificationStatus: json['verificationStatus'],
    );
  }

  /// Converts this account to JSON-like map data.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'mask': mask,
      'type': type,
      'subtype': subtype,
      'verificationStatus': verificationStatus,
    };
  }

  /// Returns a readable description of the account.
  String description() {
    return "[id: $id, mask: $mask, name: $name, type: $type, subtype: $subtype, verification_status: $verificationStatus]";
  }
}
