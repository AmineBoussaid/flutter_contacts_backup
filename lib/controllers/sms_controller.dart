import 'package:contacts_app/controllers/contact_controller.dart'; // Import ContactController
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sms_model.dart';
import 'package:collection/collection.dart'; // For groupBy

class SmsController {
  final Telephony _telephony = Telephony.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  // Instance of ContactController to resolve names
  final ContactController _contactController = ContactController();

  String _sanitizeEmail(String email) => email.replaceAll('.', ',');

  DatabaseReference _userRef(String email) =>
      _dbRef.child('users').child(_sanitizeEmail(email));

  /// Check and request SMS permissions
  Future<bool> _ensureSmsPermissions() async {
    try {
      var status = await Permission.sms.status;
      if (status.isGranted) return true;

      if (status.isPermanentlyDenied) {
        debugPrint("SMS permission permanently denied. Opening settings...");
        await openAppSettings();
        return false;
      }

      debugPrint("Requesting SMS permission...");
      status = await Permission.sms.request();
      debugPrint("SMS permission status: $status");
      return status.isGranted;
    } catch (e) {
      debugPrint('SMS Permission error: $e');
      return false;
    }
  }

  /// Fetch all SMS messages from device
  Future<List<SmsModel>> getDeviceSms() async {
    debugPrint("Attempting to fetch device SMS...");
    try {
      final hasPermission = await _ensureSmsPermissions();
      if (!hasPermission) throw Exception('SMS permissions not granted');
      debugPrint("SMS permissions granted. Fetching inbox and sent SMS...");

      // Fetch both inbox and sent messages
      final inbox = await _telephony.getInboxSms(
        columns: [SmsColumn.ID, SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE, SmsColumn.TYPE],
        // sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)] // Optional sorting
      );
      debugPrint("Fetched ${inbox.length} inbox SMS.");

      final sent = await _telephony.getSentSms(
        columns: [SmsColumn.ID, SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE, SmsColumn.TYPE],
        // sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)] // Optional sorting
      );
      debugPrint("Fetched ${sent.length} sent SMS.");

      // Combine and convert to SmsModel
      final allMessages = [
        ...inbox.map((m) => SmsModel.fromMessage(m)),
        ...sent.map((m) => SmsModel.fromMessage(m)),
      ];
      debugPrint("Total device SMS converted to model: ${allMessages.length}");

      // Ensure uniqueness using ID (assuming it's reliable)
      final uniqueMessages = <String, SmsModel>{};
      for (var message in allMessages) {
        if (message.id.isNotEmpty) { // Only add if ID is valid
           uniqueMessages[message.id] = message;
        }
      }
      debugPrint("Unique device SMS count: ${uniqueMessages.length}");

      // Optionally resolve contact names here or let the UI do it
      // final resolvedMessages = await _resolveContactNames(uniqueMessages.values.toList());
      // return resolvedMessages;

      return uniqueMessages.values.toList();
    } catch (e) {
      debugPrint('Error getting device SMS: $e');
      rethrow; // Rethrow to be handled by the UI
    }
  }

  /// Helper function to resolve contact names for a list of SMS messages
  /// This can be called by the UI layer after fetching device/backup SMS
  Future<List<SmsModel>> resolveContactNames(List<SmsModel> messages) async {
    debugPrint("Resolving contact names for ${messages.length} SMS...");
    int resolvedCount = 0;
    for (var message in messages) {
      if (message.address.isNotEmpty) {
        // Use the ContactController to get the name
        message.contactName = await _contactController.getContactNameFromNumber(message.address);
        if (message.contactName != null) {
          resolvedCount++;
        }
      }
    }
    debugPrint("Resolved names for $resolvedCount SMS.");
    return messages;
  }

  /// Backup selected messages (those marked as Nouveau) to Firebase
  Future<void> backupSelected(String userEmail, List<SmsModel> messagesToBackup) async {
    if (messagesToBackup.isEmpty) {
      debugPrint("No new SMS selected for backup.");
      return;
    }
    debugPrint("Attempting to backup ${messagesToBackup.length} new SMS...");
    try {
      final backupData = <String, dynamic>{};
      for (var message in messagesToBackup) {
        // Use message ID as the key in Firebase
        if (message.id.isNotEmpty) { // Ensure ID is valid before backup
           backupData[message.id] = message.toMap();
        }
      }

      if (backupData.isEmpty) {
         debugPrint("No valid SMS with IDs found to backup.");
         return;
      }

      // Use update to merge data
      await _userRef(userEmail).child('sms').update(backupData);
      debugPrint('Backed up ${backupData.length} SMS to Firebase.');
    } catch (e) {
      debugPrint('Error backing up SMS: $e');
      rethrow;
    }
  }

  /// Retrieve backed up SMS messages from Firebase for a given user
  Future<List<SmsModel>> getBackupSms(String userEmail) async {
    debugPrint("Fetching SMS backup from Firebase for user: $userEmail");
    final snap = await _userRef(userEmail).child('sms').get();
    if (!snap.exists || snap.value == null) {
      debugPrint("No SMS backup found for user.");
      return [];
    }

    debugPrint('Raw SMS data from Firebase (${snap.value.runtimeType})');

    final List<SmsModel> result = [];
    final dynamic rawData = snap.value;

    if (rawData is Map) {
      final Map<dynamic, dynamic> map = rawData;
      map.forEach((key, val) {
        if (val is Map) {
          try {
            final smsMap = Map<String, dynamic>.from(val);
            // Ensure ID exists, using key as fallback
            if (!smsMap.containsKey('id') || smsMap['id'] == null) {
               smsMap['id'] = key.toString();
               debugPrint("SMS from backup using key '$key' as ID.");
            }
            result.add(SmsModel.fromMap(smsMap));
          } catch (err) {
            debugPrint('Skipping invalid Map entry in SMS backup (key=$key): $err');
          }
        } else {
           debugPrint('Skipping non-Map value in SMS backup (key=$key)');
        }
      });
    } else if (rawData is List) {
       debugPrint("Handling List format for SMS backup (potentially older format).");
       final List<Object?> list = rawData as List<Object?>;
       for (int i = 0; i < list.length; i++) {
         final val = list[i];
         if (val is Map) {
           try {
             final smsMap = Map<String, dynamic>.from(val);
             // Ensure ID exists - crucial for list format
             if (!smsMap.containsKey('id') || smsMap['id'] == null) {
                debugPrint('SMS entry at index $i missing ID, skipping.');
                continue; // Skip if no ID
             }
             result.add(SmsModel.fromMap(smsMap));
           } catch (err) {
             debugPrint('Skipping invalid Map entry in SMS backup list (index $i): $err');
           }
         } else if (val != null) {
            debugPrint('Skipping non-Map, non-null entry in SMS backup list (index $i)');
         }
       }
    } else {
      debugPrint('Unexpected data type for SMS backup: ${rawData.runtimeType}');
      throw Exception('Unexpected data format received from Firebase for SMS.');
    }

    debugPrint('Parsed ${result.length} SMS messages from backup.');
    // Optionally resolve contact names here or let the UI do it
    // final resolvedMessages = await _resolveContactNames(result);
    // return resolvedMessages;
    return result;
  }

  /// Attempts to "restore" selected SMS (those marked as Manquant) by re-sending them.
  /// This is a workaround due to platform limitations.
  Future<void> restoreSelected(List<SmsModel> messagesToRestore) async {
    if (messagesToRestore.isEmpty) {
      debugPrint("No missing SMS selected for restore (re-send).");
      return;
    }
    debugPrint('Attempting to re-send ${messagesToRestore.length} messages...');
    try {
      final hasPermission = await _ensureSmsPermissions();
      if (!hasPermission) {
        throw Exception('SMS permissions not granted for sending');
      }

      final validMessages = messagesToRestore
          .where((m) => m.address.isNotEmpty && m.body.isNotEmpty)
          .toList();

      if (validMessages.isEmpty) {
        debugPrint('No valid messages found to re-send.');
        throw Exception('No valid messages to restore (re-send)');
      }

      int successCount = 0;
      int failCount = 0;

      for (var message in validMessages) {
        try {
          debugPrint('Re-sending SMS to: ${message.address}...');
          await _telephony.sendSms(to: message.address, message: message.body);
          successCount++;
          await Future.delayed(const Duration(milliseconds: 750)); // Delay
        } catch (e) {
          failCount++;
          debugPrint('Error re-sending SMS to ${message.address}: $e');
          continue; // Continue with the next message
        }
      }
      debugPrint('Re-send attempt finished. Success: $successCount, Failed: $failCount');
      if (failCount > 0) {
        // Optionally throw
      }
    } catch (e) {
      debugPrint('SMS re-send process failed: $e');
      rethrow;
    }
  }

  // --- Intent-based restore method remains unchanged ---
  Future<void> restoreViaIntent(List<SmsModel> messages) async {
     // ... (keep existing implementation)
    try {
      final validMessages =
          messages
              .where((m) => m.address.isNotEmpty && m.body.isNotEmpty)
              .toList();

      for (var message in validMessages) {
        try {
          final uri = Uri(
            scheme: 'smsto',
            path: message.address,
            queryParameters: {'body': message.body},
          );

          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
            await Future.delayed(const Duration(seconds: 2));
          }
        } catch (e) {
          debugPrint('Error launching intent for ${message.address}: $e');
        }
      }
    } catch (e) {
      debugPrint('Intent-based restore failed: $e');
      rethrow;
    }
  }
}

