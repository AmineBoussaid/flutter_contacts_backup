// lib/controllers/contact_controller.dart

import 'dart:convert';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:contacts_app/models/contact_model.dart';
import 'package:contacts_app/controllers/firebase_service.dart';

class ContactController {
  final FirebaseService _firebaseService = FirebaseService();

  Future<List<ContactModel>> getDeviceContacts() async {
    // Demande de permission
    if (!await FlutterContacts.requestPermission()) {
      throw Exception('Contacts permission denied');
    }

    // Récupère tous les contacts avec propriétés et photos
    final List<Contact> rawContacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: true,
    );

    return rawContacts.map((c) {
      return ContactModel(
        id: c.id,
        name: c.displayName,
        photo:
            (c.photo != null && c.photo!.isNotEmpty)
                ? base64Encode(c.photo!)
                : null,
        phones:
            c.phones.map((p) => p.number).where((s) => s.isNotEmpty).toList() ??
            [],
        emails:
            c.emails
                .map((e) => e.address)
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        createdAt: DateTime.now(),
      );
    }).toList();
  }

  Future<void> backupContacts() async {
    final contacts = await getDeviceContacts();
    await _firebaseService.saveContacts(contacts);
  }

  Future<List<ContactModel>> restoreContacts() async {
    final contacts = await _firebaseService.getContacts();
    if (contacts.isEmpty) {
      throw Exception('No contacts found in backup');
    }
    return contacts;
  }
}
