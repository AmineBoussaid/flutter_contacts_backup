// lib/models/sms_model.dart

import 'package:telephony/telephony.dart';

// Define enums for synchronization status (can be moved to a common file)
enum BackupStatus { nouveau, synchronise, inconnu } // SMS are typically not 'modifie'
enum RestoreStatus { manquant, present, inconnu }

class SmsModel {
  final String id;         // Unique ID from the device/telephony plugin
  final String address;      // Phone number
  final String body;
  final int    date;         // Millis since epoch
  final SmsType type;        // Inbox, Sent, Draft etc.

  // New fields for status tracking
  BackupStatus backupStatus;
  RestoreStatus restoreStatus;
  String? contactName; // Added field to store resolved contact name

  SmsModel({
    required this.id,
    required this.address,
    required this.body,
    required this.date,
    required this.type,
    this.backupStatus = BackupStatus.inconnu,
    this.restoreStatus = RestoreStatus.inconnu,
    this.contactName, // Initialize contact name as null
  });

  /// Safely handle a possibly-null msg.type
  factory SmsModel.fromMessage(SmsMessage msg) {
    return SmsModel(
      id:      msg.id?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(), // Ensure ID is never null
      address: msg.address  ?? '',
      body:    msg.body     ?? '',
      date:    msg.date     ?? 0,
      type:    msg.type     ?? SmsType.MESSAGE_TYPE_ALL, // Use a default type
      // Status is determined later during comparison
    );
  }

  factory SmsModel.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'] as int?;
    // Find the enum by index, fallback to a default if not found or null
    final smsType = SmsType.values.firstWhere(
      (e) => e.index == rawType,
      orElse: () => SmsType.MESSAGE_TYPE_ALL,
    );

    return SmsModel(
      id:      map['id']      as String? ?? DateTime.now().millisecondsSinceEpoch.toString(), // Handle potential null ID from older backups
      address: map['address'] as String? ?? '',
      body:    map['body']    as String? ?? '',
      date:    map['date']    as int? ?? 0,
      type:    smsType,
      // Status is determined later during comparison
      // contactName is resolved dynamically, not stored in Firebase
    );
  }

  Map<String, dynamic> toMap() => {
    'id':      id,
    'address': address,
    'body':    body,
    'date':    date,
    'type':    type.index,
    // Status fields (backupStatus, restoreStatus) and contactName are transient and not stored
  };
}

