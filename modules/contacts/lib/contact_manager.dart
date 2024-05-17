import 'dart:developer';

import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/stub/contacts_manager.dart';
import 'package:ensemble/framework/stub/contacts_manager.dart' as manager;
import 'package:fast_contacts/fast_contacts.dart' as fc;
import 'package:flutter_contacts/flutter_contacts.dart' as fcontacts;

class ContactManagerImpl extends ContactManager {
  // @override
  // void getPhoneContacts(
  //     ContactSuccessCallback onSuccess, ContactErrorCallback onError) async {
  //   if (await fcontacts.FlutterContacts.requestPermission(readonly: true)) {
  //
  //     final timer = Stopwatch()..start();
  //     fcontacts.FlutterContacts.getContacts(
  //             withProperties: true,
  //             // withPhoto: true,
  //             // withThumbnail: true,
  //             // withAccounts: true,
  //             // withGroups: true
  //         )
  //         .then((contacts) {
  //       timer.stop();
  //       log("Time taken: ${timer.elapsedMilliseconds}ms");
  //       final mappedContacts = contacts
  //           .map((contact) => manager.Contact.fromJson(contact.toJson()))
  //           .toList();
  //       onSuccess(mappedContacts);
  //     }).catchError((error) {
  //       onError('Failed to fetch contacts: $error');
  //     });
  //   } else {
  //     onError('Failed to fetch contacts');
  //   }
  // }

  @override
  Future<void> getPhoneContacts(
      ContactSuccessCallback onSuccess, ContactErrorCallback onError) async {
    if (await requestPermission()) {
      try {
        List<fc.Contact> rawContacts = await fc.FastContacts.getAllContacts();
        onSuccess(_toContacts(rawContacts));
        return;
      } catch (e) {
        onError('Failed to fetch contacts');
      }
    } else {
      onError('Permission denied');
    }
  }

  @override
  Future<void> getContactPhoto(String id, ContactPhotoSuccessCallback onSuccess,
      ContactPhotoErrorCallback onError) async {
    try {
      final image = await fc.FastContacts.getContactImage(id);
      if (image != null) {
        onSuccess(image);
      } else {
        onError('Failed to fetch contact photo - ContactID: $id');
      }
    } catch (e) {
      onError('Failed to fetch contact photo - Reason: $e');
    }
  }

  /// convert to our native Contacts
  List<Contact> _toContacts(List<fc.Contact> contacts) => contacts
      .map((contact) => manager.Contact(
            id: contact.id,
            displayName: _getDisplayName(contact),
            name: manager.Name(
                first: contact.structuredName?.givenName ?? '',
                middle: contact.structuredName?.middleName ?? '',
                last: contact.structuredName?.familyName ?? '',
                prefix: contact.structuredName?.namePrefix ?? '',
                suffix: contact.structuredName?.nameSuffix ?? ''),
            phones: contact.phones
                .map((phone) => manager.Phone(phone.number,
                    label: PhoneLabel.values.from(phone.label) ??
                        PhoneLabel.mobile))
                .toList(),
            emails: contact.emails
                .map((email) => manager.Email(email.address,
                    label:
                        EmailLabel.values.from(email.label) ?? EmailLabel.home))
                .toList(),
            organizations: contact.organization != null
                ? [manager.Organization(company: contact.organization!.company)]
                : null,
          ))
      .toList();

  String _getDisplayName(fc.Contact contact) => contact.displayName.isNotEmpty
      ? contact.displayName
      : (contact.organization?.company ?? '');

  @override
  Future<bool> requestPermission() async {
    try {
      final status =
          await fcontacts.FlutterContacts.requestPermission(readonly: true);
      return status;
    } catch (_) {
      return false;
    }
  }
}
