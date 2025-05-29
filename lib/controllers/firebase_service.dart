// lib/services/firebase_service.dart

import 'package:contacts_app/models/contact_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  String _sanitizeEmail(String email) => email.replaceAll('.', ',');

  DatabaseReference _userRef() {
    final user = FirebaseAuth.instance.currentUser!;
    final sanitized = _sanitizeEmail(user.email!);
    return _db.child('users').child(sanitized);
  }

  /// Save or update selected contacts in Firebase Realtime Database with metadata
  Future<void> saveContacts(List<ContactModel> contacts) async {
    try {
      final Map<String, dynamic> updates = {};
      for (final contact in contacts) {
        updates['contacts/${contact.id}'] = contact.toMap();
      }
      // Update last backup timestamp
      updates['metadata/lastBackup'] = ServerValue.timestamp;
      await _userRef().update(updates);
    } catch (e) {
      throw Exception('Failed to save contacts: ${e.toString()}');
    }
  }

  /// Fetch all contacts from Firebase Realtime Database
  Future<List<ContactModel>> getContacts() async {
    try {
      final snapshot = await _userRef().child('contacts').get();
      if (!snapshot.exists || snapshot.value == null) return [];

      final value = snapshot.value;
      if (value is List) {
        // Database contains a list
        return value
            .where((e) => e != null)
            .map(
              (e) => ContactModel.fromMap(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      } else if (value is Map) {
        // Database contains a map (key -> contact)
        final contactsMap = Map<String, dynamic>.from(value);
        return contactsMap.values
            .map(
              (contactData) => ContactModel.fromMap(
                Map<String, dynamic>.from(contactData as Map),
              ),
            )
            .toList();
      } else {
        throw Exception('Unexpected data format: ${value.runtimeType}');
      }
    } catch (e) {
      throw Exception('Failed to fetch contacts: ${e.toString()}');
    }
  }

  // ==================== UTILITIES ====================
  Future<void> clearUserData() async {
    try {
      await _userRef().remove();
    } catch (e) {
      throw Exception('Failed to clear user data: ${e.toString()}');
    }
  }

  Future<int> getContactCount() async {
    try {
      final snapshot = await _userRef().child('contacts').get();
      if (!snapshot.exists) return 0;
      return (snapshot.value as Map).length;
    } catch (e) {
      throw Exception('Failed to get contact count: ${e.toString()}');
    }
  }
}
