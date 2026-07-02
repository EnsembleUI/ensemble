import 'dart:typed_data';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/contacts_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:get_it/get_it.dart';

/// Ensemble action that reads contacts from the device address book.
class GetPhoneContactAction extends EnsembleAction {
  /// Creates a [GetPhoneContactAction] action.
  GetPhoneContactAction({
    super.initiator,
    this.id,
    this.onSuccess,
    this.onError,
  });

  /// Identifier used to store results, target an existing resource, or correlate callbacks.
  final String? id;
  /// Action executed when the operation succeeds.
  final EnsembleAction? onSuccess;
  /// Action executed when the operation fails.
  final EnsembleAction? onError;

  /// Returns the success callback configured for this action.
  EnsembleAction? getOnSuccess(DataContext dataContext) =>
      dataContext.eval(onSuccess);

  /// Returns the error callback configured for contact lookup failures.
  EnsembleAction? getOnError(DataContext dataContext) =>
      dataContext.eval(onError);

  /// Creates a [GetPhoneContactAction] from a YAML or map action payload.
  factory GetPhoneContactAction.fromMap(
      {Invokable? initiator, dynamic payload}) {
    if (payload is Map) {
      return GetPhoneContactAction(
        initiator: initiator,
        id: Utils.optionalString(payload['id']),
        onSuccess: EnsembleAction.from(payload['onSuccess']),
        onError: EnsembleAction.from(payload['onError']),
      );
    }
    throw LanguageError(
        "${ActionType.getPhoneContacts.name} action requires payload");
  }

  /// Runs this action and performs the get phone contact operation.
  @override
  Future execute(BuildContext context, ScopeManager scopeManager) {
    GetIt.I<ContactManager>().getPhoneContacts((contacts) {
      if (getOnSuccess(scopeManager.dataContext) != null) {
        final contactsData =
            contacts.map((contact) => contact.toJson()).toList();

        ScreenController().executeActionWithScope(
          context,
          scopeManager,
          getOnSuccess(scopeManager.dataContext)!,
          event: EnsembleEvent(
            initiator,
            data: {'contacts': contactsData},
          ),
        );
      }
    }, (error) {
      if (getOnError(scopeManager.dataContext) != null) {
        ScreenController().executeActionWithScope(
          context,
          scopeManager,
          getOnError(scopeManager.dataContext)!,
          event: EnsembleEvent(initiator!, error: error),
        );
      }
    });
    return Future.value(null);
  }
}

/// Ensemble action that fetches a photo for a device contact.
class GetPhoneContactPhotoAction extends EnsembleAction {
  /// Creates a [GetPhoneContactPhotoAction] action.
  GetPhoneContactPhotoAction({
    super.initiator,
    this.id,
    required this.contactId,
  });

  /// Identifier used to store results, target an existing resource, or correlate callbacks.
  final String? id;
  /// Identifier of the contact whose photo should be fetched.
  final String contactId;

  /// Evaluates the target contact id from the current scope.
  String getContactId(DataContext dataContext) => dataContext.eval(contactId);

  /// Creates a [GetPhoneContactPhotoAction] from a YAML or map action payload.
  factory GetPhoneContactPhotoAction.fromMap(
      {Invokable? initiator, dynamic payload}) {
    if (payload is Map) {
      final contactId = Utils.optionalString(payload['contactId']);
      if (contactId == null) {
        throw LanguageError(
            "${ActionType.getPhoneContactPhoto.name} action requires contactId");
      }

      return GetPhoneContactPhotoAction(
        initiator: initiator,
        id: Utils.optionalString(payload['id']),
        contactId: contactId,
      );
    }

    throw LanguageError(
        "${ActionType.getPhoneContactPhoto.name} action requires payload");
  }

  /// Runs this action and performs the get phone contact photo operation.
  @override
  Future execute(BuildContext context, ScopeManager scopeManager) {
    GetIt.I<ContactManager>()
        .getContactPhoto(getContactId(scopeManager.dataContext), (imageData) {
      if (id != null) {
        scopeManager.dataContext.addDataContextById(
            id!, PhoneContactPhotoResponse(image: imageData));
        updateContactData(scopeManager, context, id!);
      }
    }, (error) {
      if (id != null) {
        // Sending empty list for the Image fallback to be called
        scopeManager.dataContext.addDataContextById(
            id!, PhoneContactPhotoResponse(image: Uint8List.fromList([])));
        updateContactData(scopeManager, context, id!);
      }
      if (kDebugMode) {
        debugPrint('Contact photo missing $error');
      }
    });

    return Future.value(null);
  }

  /// Stores contact data on the event payload for callbacks.
  void updateContactData(
      ScopeManager scopeManager, BuildContext context, String id) {
    final contactData = scopeManager.dataContext.getContextById(id);
    scopeManager
        .dispatch(ModelChangeEvent(SimpleBindingSource(id), contactData));
  }
}

/// Invokable response object containing bytes for a contact photo.
class PhoneContactPhotoResponse with Invokable {
  Uint8List? _image;

  /// Creates a [PhoneContactPhotoResponse] response object.
  PhoneContactPhotoResponse({Uint8List? image}) {
    if (image != null) {
      setImage(image);
    }
  }

  /// Stores image bytes on the contact photo response.
  void setImage(Uint8List image) {
    _image = image;
  }

  /// Returns image bytes from the contact photo response.
  Uint8List? getImage() {
    return _image;
  }

  /// Exposes the contact photo bytes to Ensemble expressions.
  @override
  Map<String, Function> getters() {
    return {
      'image': () => _image,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}
