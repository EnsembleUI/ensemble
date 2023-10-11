import 'package:ensemble/framework/stub/contacts_manager.dart';
import 'package:ensemble/framework/stub/contacts_manager.dart' as manager;
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactManagerImpl extends ContactManager {
  @override
  void getPhoneContacts(
      ContactSuccessCallback onSuccess, ContactErrorCallback onError) async {
    if (await FlutterContacts.requestPermission(readonly: true)) {
      FlutterContacts.getContacts(
              withProperties: true,
              withPhoto: true,
              withThumbnail: true,
              withAccounts: true,
              withGroups: true)
          .then((contacts) {
        final mappedContacts = contacts
            .map((contact) => manager.Contact.fromJson(contact.toJson()))
            .toList();
        onSuccess(mappedContacts);
      }).catchError((error) {
        onError('Failed to fetch contacts: $error');
      });
    } else {
      onError('Failed to fetch contacts');
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final status = await FlutterContacts.requestPermission();
      return status;
    } catch (_) {
      return false;
    }
  }
}
