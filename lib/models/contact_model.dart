import 'dart:convert';

import 'package:flutter_contacts/flutter_contacts.dart';

enum BackupStatus { nouveau, modifie, synchronise, inconnu }

enum RestoreStatus { manquant, present, inconnu }

class ContactModel {
  final String id;
  final String firstName;
  final String lastName;
  final String? photo;
  final List<String> phones;
  final List<String> emails;
  final DateTime createdAt;

  BackupStatus backupStatus;
  RestoreStatus restoreStatus;
  String? hashCodeForSync;

  ContactModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.photo,
    required this.phones,
    required this.emails,
    required this.createdAt,
    this.backupStatus = BackupStatus.inconnu,
    this.restoreStatus = RestoreStatus.inconnu,
    this.hashCodeForSync,
  });

  String calculateSyncHash() {
    final mapForHash = {
      'firstName': firstName,
      'lastName': lastName,
      'phones': phones..sort(),
      'emails': emails..sort(),
    };

    return jsonEncode(mapForHash);
  }

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

      createdAt: DateTime.now(),
    );

    model.hashCodeForSync = model.calculateSyncHash();
    return model;
  }

  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id'],
      firstName: map['firstName'],
      lastName: map['lastName'],
      photo: map['photo'],
      phones: List<String>.from(map['phones'] ?? []),
      emails: List<String>.from(map['emails'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      hashCodeForSync: map['hashCodeForSync'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'photo': photo,
    'phones': phones,
    'emails': emails,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'hashCodeForSync': hashCodeForSync ?? calculateSyncHash(),
  };
}
