import 'dart:convert';

import 'package:flutter_contacts/flutter_contacts.dart';

// Define enums for synchronization status
enum BackupStatus { nouveau, modifie, synchronise, inconnu }

enum RestoreStatus { manquant, present, inconnu }

class ContactModel {
  final String id;
  final String firstName;
  final String lastName;
  final String? photo; // base64
  final List<String> phones;
  final List<String> emails;
  final DateTime
  createdAt; // Consider using a last modified timestamp if available

  // New fields for status tracking and comparison
  BackupStatus backupStatus;
  RestoreStatus restoreStatus;
  String? hashCodeForSync; // Stores a hash of relevant fields for comparison

  ContactModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.photo,
    required this.phones,
    required this.emails,
    required this.createdAt,
    this.backupStatus = BackupStatus.inconnu, // Default status
    this.restoreStatus = RestoreStatus.inconnu, // Default status
    this.hashCodeForSync,
  });

  // Method to calculate a hash for comparing contact data
  // Uses a simple JSON representation for hashing. Consider crypto for robustness.
  String calculateSyncHash() {
    final mapForHash = {
      'firstName': firstName,
      'lastName': lastName,
      'phones': phones..sort(), // Sort lists for consistent order
      'emails': emails..sort(),
      // Include other fields relevant for detecting modifications
    };
    // Using jsonEncode as a simple way to get a string representation
    // For production, a cryptographic hash (e.g., SHA-256) of this string would be better.
    return jsonEncode(mapForHash);
  }

  // Update factory constructor from FlutterContacts entity
  factory ContactModel.fromEntity(Contact c) {
    final model = ContactModel(
      id: c.id,
      firstName: c.name.first,
      lastName: c.name.last,
      photo:
          (c.photo != null && c.photo!.isNotEmpty)
              ? base64Encode(c.photo!)
              : null,
      phones: c.phones.map((p) => p.number).toList(),
      emails: c.emails.map((e) => e.address).toList(),
      // Use current time as createdAt since Contact does not provide a last modified property
      createdAt: DateTime.now(),
    );
    // Calculate and store the hash upon creation from device entity
    model.hashCodeForSync = model.calculateSyncHash();
    return model;
  }

  // Update factory constructor from a map (e.g., from Firebase)
  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id'],
      firstName: map['firstName'],
      lastName: map['lastName'],
      photo: map['photo'],
      phones: List<String>.from(map['phones'] ?? []),
      emails: List<String>.from(map['emails'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      // Retrieve the hash stored in Firebase if available
      hashCodeForSync: map['hashCodeForSync'],
      // Status fields are typically determined dynamically during comparison,
      // so they are not usually loaded directly from the map.
    );
  }

  // Update method to convert the model to a map (e.g., for Firebase)
  Map<String, dynamic> toMap() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'photo': photo,
    'phones': phones,
    'emails': emails,
    'createdAt': createdAt.millisecondsSinceEpoch,
    // Store the calculated hash in Firebase for comparison purposes
    'hashCodeForSync': hashCodeForSync ?? calculateSyncHash(),
    // Status fields (backupStatus, restoreStatus) are transient and not stored
  };
}
