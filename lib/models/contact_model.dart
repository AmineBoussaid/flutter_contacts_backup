import 'dart:convert';

import 'package:flutter_contacts/flutter_contacts.dart';

class ContactModel {
  final String id;
  final String firstName;
  final String lastName;
  final String? photo; // base64
  final List<String> phones;
  final List<String> emails;
  final DateTime createdAt;

  ContactModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.photo,
    required this.phones,
    required this.emails,
    required this.createdAt,
  });

  factory ContactModel.fromEntity(Contact c) {
    return ContactModel(
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
  };
}
