// lib/services/firebase_service.dart

import 'package:contacts_app/models/contact_model.dart';
import 'package:contacts_app/models/favorite_model.dart';
import 'package:contacts_app/models/sms_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String _sanitizeEmail(String email) => email.replaceAll('.', ',');

  DatabaseReference _userRef() {
    final email = FirebaseAuth.instance.currentUser!.email!;
    return _db.child('users/${_sanitizeEmail(email)}');
  }

  // ==================== CONTACTS ====================
  Future<void> saveContacts(List<ContactModel> contacts) async {
    try {
      final Map<String, dynamic> updates = {};
      for (final contact in contacts) {
        updates['contacts/${contact.id}'] = contact.toMap();
      }
      updates['metadata/lastBackup'] = ServerValue.timestamp;
      await _userRef().update(updates);
    } catch (e) {
      throw Exception('Failed to save contacts: ${e.toString()}');
    }
  }

  Future<List<ContactModel>> getContacts() async {
    try {
      final snapshot = await _userRef().child('contacts').get();
      if (!snapshot.exists || snapshot.value == null) return [];

      final contactsMap = Map<String, dynamic>.from(snapshot.value as Map);
      return contactsMap.values.map((contactData) {
        final data = Map<String, dynamic>.from(contactData as Map);
        return ContactModel.fromMap(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch contacts: ${e.toString()}');
    }
  }

  // ==================== SMS ====================
  Future<void> saveSms(List<SmsModel> smsList) async {
    try {
      final Map<String, dynamic> updates = {};
      for (final sms in smsList) {
        updates['sms/${sms.contactId}/${sms.id}'] = {
          'id': sms.id,
          'contactId': sms.contactId,
          'text': sms.text,
          'sender': sms.sender,
          'date': sms.date.millisecondsSinceEpoch,
        };
      }
      await _userRef().update(updates);
    } catch (e) {
      throw Exception('Failed to save SMS: ${e.toString()}');
    }
  }

  Future<List<SmsModel>> getSms() async {
    try {
      final snapshot = await _userRef().child('sms').get();
      if (!snapshot.exists || snapshot.value == null) return [];

      final smsMap = Map<String, dynamic>.from(snapshot.value as Map);
      final smsList = <SmsModel>[];

      smsMap.forEach((contactId, messages) {
        final messagesMap = Map<String, dynamic>.from(messages as Map);
        for (var messageData in messagesMap.values) {
          final data = Map<String, dynamic>.from(messageData as Map);
          smsList.add(
            SmsModel(
              id: data['id']?.toString() ?? 'unknown_sms',
              contactId: contactId,
              text: data['text']?.toString() ?? '',
              sender: data['sender']?.toString() ?? 'unknown',
              date: DateTime.fromMillisecondsSinceEpoch(
                data['date'] is int
                    ? data['date']
                    : DateTime.now().millisecondsSinceEpoch,
              ),
            ),
          );
        }
      });

      return smsList;
    } catch (e) {
      throw Exception('Failed to fetch SMS: ${e.toString()}');
    }
  }

  // ==================== FAVORITES ====================
  Future<void> syncFavorites(List<FavoriteModel> favorites) async {
    try {
      final Map<String, dynamic> updates = {};
      for (final fav in favorites) {
        updates['favorites/${fav.contactId}'] = {
          'contactId': fav.contactId,
          'callCount': fav.callCount,
          'smsCount': fav.smsCount,
          'lastInteraction': fav.lastUpdated.millisecondsSinceEpoch,
        };
      }
      await _userRef().update(updates);
    } catch (e) {
      throw Exception('Failed to sync favorites: ${e.toString()}');
    }
  }

  Future<List<FavoriteModel>> getFavorites() async {
    try {
      final snapshot = await _userRef().child('favorites').get();
      if (!snapshot.exists || snapshot.value == null) return [];

      final favoritesMap = Map<String, dynamic>.from(snapshot.value as Map);
      return favoritesMap.values.map((favData) {
        final data = Map<String, dynamic>.from(favData as Map);
        return FavoriteModel(
          contactId: data['contactId']?.toString() ?? '',
          callCount: (data['callCount'] as num?)?.toInt() ?? 0,
          smsCount: (data['smsCount'] as num?)?.toInt() ?? 0,
          lastUpdated: DateTime.fromMillisecondsSinceEpoch(
            data['lastInteraction'] is int
                ? data['lastInteraction']
                : DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch favorites: ${e.toString()}');
    }
  }

  // ==================== METADATA ====================
  Future<DateTime?> getLastBackupTime() async {
    try {
      final snapshot = await _userRef().child('metadata/lastBackup').get();
      if (snapshot.exists && snapshot.value != null) {
        return DateTime.fromMillisecondsSinceEpoch(snapshot.value as int);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get backup time: ${e.toString()}');
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
