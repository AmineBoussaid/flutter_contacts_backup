import 'dart:convert';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/contact_model.dart';
import 'firebase_service.dart';

class ContactController {
  final FirebaseService _firebaseService = FirebaseService();

  /// Fetch all device contacts
  Future<List<ContactModel>> getDeviceContacts() async {
    if (!await FlutterContacts.requestPermission()) {
      throw Exception('Contacts permission denied');
    }
    final raw = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: true,
    );
    return raw.map((c) => ContactModel.fromEntity(c)).toList();
  }

  /// Backup (save or update) selected contacts to Firebase
  Future<void> backupSelected(List<ContactModel> contacts) async {
    if (contacts.isEmpty) return;
    await _firebaseService.saveContacts(contacts);
  }

  /// Convenience: Backup *all* device contacts
  Future<void> backupContacts() async {
    final all = await getDeviceContacts();
    await backupSelected(all);
  }

  /// Fetch contacts from Firebase
  Future<List<ContactModel>> getBackupContacts() async {
    return await _firebaseService.getContacts();
  }

  /// Convenience: Fetch & restore all backed-up contacts into device
  Future<List<ContactModel>> restoreContacts() async {
    final backups = await getBackupContacts();
    for (final c in backups) {
      final newContact =
          Contact()
            ..name.first = c.firstName
            ..name.last = c.lastName
            ..phones = c.phones.map((p) => Phone(p)).toList()
            ..emails = c.emails.map((e) => Email(e)).toList();
      if (c.photo != null) {
        newContact.photo = base64Decode(c.photo!);
      }
      await newContact.insert();
    }
    return backups;
  }

  /// Restore only selected contacts (used by the selective UI)
  Future<void> restoreSelected(List<ContactModel> contacts) async {
    if (!await FlutterContacts.requestPermission()) {
      throw Exception('Contacts permission denied');
    }
    for (final c in contacts) {
      final newContact =
          Contact()
            ..name.first = c.firstName
            ..name.last = c.lastName
            ..phones = c.phones.map((p) => Phone(p)).toList()
            ..emails = c.emails.map((e) => Email(e)).toList();
      if (c.photo != null) {
        newContact.photo = base64Decode(c.photo!);
      }
      await newContact.insert();
    }
  }
}
