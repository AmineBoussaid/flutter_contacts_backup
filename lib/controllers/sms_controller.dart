import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sms_model.dart';

class SmsController {
  final Telephony _telephony = Telephony.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  String _sanitizeEmail(String email) => email.replaceAll('.', ',');

  DatabaseReference _userRef(String email) =>
      _dbRef.child('users').child(_sanitizeEmail(email));

  /// Check and request SMS permissions
  Future<bool> _ensureSmsPermissions() async {
    try {
      var status = await Permission.sms.status;
      if (status.isGranted) return true;

      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }

      status = await Permission.sms.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Permission error: $e');
      return false;
    }
  }

  /// Fetch all SMS messages from device
  Future<List<SmsModel>> getDeviceSms() async {
    try {
      final hasPermission = await _ensureSmsPermissions();
      if (!hasPermission) throw Exception('SMS permissions not granted');

      final inbox = await _telephony.getInboxSms(
        columns: [
          SmsColumn.ID,
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
          SmsColumn.TYPE,
        ],
        // Optional: Add sorting if needed
        // sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)]
      );

      final sent = await _telephony.getSentSms(
        columns: [
          SmsColumn.ID,
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
          SmsColumn.TYPE,
        ],
        // Optional: Add sorting if needed
        // sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)]
      );

      final allMessages = [
        ...inbox.map((m) => SmsModel.fromMessage(m)),
        ...sent.map((m) => SmsModel.fromMessage(m)),
      ];

      // Use a Map to ensure uniqueness based on a composite key (e.g., address+date+body) if ID is not reliable across devices/backups
      // Or simply rely on the ID if it's consistent from backup
      final uniqueMessages = <String, SmsModel>{};
      for (var message in allMessages) {
        // Assuming message.id is a reliable unique identifier from the device
        uniqueMessages[message.id] = message;
      }

      return uniqueMessages.values.toList();
    } catch (e) {
      debugPrint('Error getting device SMS: $e');
      rethrow;
    }
  }

  /// Backup selected messages to Firebase
  /// TODO: Implement differential backup logic here
  Future<void> backupSelected(String userEmail, List<SmsModel> messages) async {
    try {
      if (messages.isEmpty) return;

      // For simplicity, current implementation overwrites/updates based on ID.
      // A true differential backup would compare timestamps or content.
      final backupData = <String, dynamic>{};
      for (var message in messages) {
        // Use message ID as the key in Firebase for easy update/lookup
        backupData[message.id] = message.toMap();
      }

      // Use update instead of set to merge data and not delete other potential user data
      await _userRef(userEmail).child('sms').update(backupData);
      debugPrint('Backed up ${messages.length} SMS to Firebase.');
    } catch (e) {
      debugPrint('Error backing up SMS: $e');
      rethrow;
    }
  }

  /// Retrieve backed up SMS messages from Firebase for a given user
  /// Handles both List<Object?> and Map<dynamic, dynamic> structures.
  Future<List<SmsModel>> getBackupSms(String userEmail) async {
    final snap = await _userRef(userEmail).child('sms').get();
    if (!snap.exists || snap.value == null) return [];

    debugPrint(
      '🔍 RAW SMS DATA FROM FIREBASE (${snap.value.runtimeType}): ${snap.value}',
    );

    final List<SmsModel> result = [];
    final dynamic rawData = snap.value;

    if (rawData is Map) {
      // Handle Map structure (likely keys are message IDs)
      final Map<dynamic, dynamic> map = rawData;
      map.forEach((key, val) {
        if (val is Map) {
          try {
            final smsMap = (val).cast<String, dynamic>();
            // Ensure the ID from the map value is used, or fallback to the key if ID is missing in the map
            if (!smsMap.containsKey('id') && key is String) {
              smsMap['id'] = key;
            }
            result.add(SmsModel.fromMap(smsMap));
          } catch (err) {
            debugPrint(
              '⚠️ Skipping invalid Map entry under key=$key: $err\nValue: $val',
            );
          }
        } else {
          debugPrint('⚠️ Skipping non-Map value under key=$key: $val');
        }
      });
    } else if (rawData is List) {
      // Handle List structure (potentially sparse with nulls)
      final List<Object?> list = rawData as List<Object?>;
      for (int i = 0; i < list.length; i++) {
        final val = list[i];
        if (val is Map) {
          try {
            final smsMap = (val).cast<String, dynamic>();
            // Ensure ID exists, potentially using index 'i' as a fallback if no 'id' field
            if (!smsMap.containsKey('id')) {
              // Using index might not be ideal if list isn't guaranteed stable
              // Consider logging a warning or requiring 'id' in the data
              debugPrint('⚠️ SMS entry at index $i missing \'id\'.');
              // smsMap['id'] = i.toString(); // Assign index as ID if absolutely necessary
            }
            result.add(SmsModel.fromMap(smsMap));
          } catch (err) {
            debugPrint(
              '⚠️ Skipping invalid Map entry at index $i: $err\nValue: $val',
            );
          }
        } else if (val != null) {
          // Log unexpected non-Map, non-null entries
          debugPrint('⚠️ Skipping non-Map, non-null entry at index $i: $val');
        }
        // Null entries are implicitly skipped
      }
    } else {
      // Handle unexpected data type
      debugPrint(
        '❌ Unexpected data type received for SMS backup: ${rawData.runtimeType}',
      );
      throw Exception('Unexpected data format received from Firebase for SMS.');
    }

    debugPrint('Parsed ${result.length} SMS messages from backup.');
    return result;
  }

  /// Attempts to "restore" selected SMS messages by re-sending them.
  /// NOTE: Due to Android platform limitations and the capabilities of the 'telephony' package,
  /// this function does NOT insert messages directly into the phone's SMS database.
  /// It triggers the sending of each selected message via the default SMS app mechanism.
  /// This is a workaround and not a true restoration.
  /// TODO: Implement differential restore logic here
  Future<void> restoreSelected(List<SmsModel> messages) async {
    debugPrint('Attempting to re-send ${messages.length} messages...');
    try {
      final hasPermission = await _ensureSmsPermissions();
      if (!hasPermission) {
        throw Exception('SMS permissions not granted for sending');
      }

      final validMessages =
          messages
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
          debugPrint(
            'Re-sending SMS to: ${message.address}, Body: ${message.body.substring(0, (message.body.length > 20 ? 20 : message.body.length))}...',
          );
          // Use the sendSms method from the telephony package
          await _telephony.sendSms(to: message.address, message: message.body);
          successCount++;
          // Add a small delay between sends to avoid potential rate limiting or issues
          await Future.delayed(const Duration(milliseconds: 750));
        } catch (e) {
          failCount++;
          debugPrint('Error re-sending SMS to ${message.address}: $e');
          // Decide if you want to stop on first error or continue
          continue; // Continue with the next message even if one fails
        }
      }
      debugPrint(
        'Re-send attempt finished. Success: $successCount, Failed: $failCount',
      );
      if (failCount > 0) {
        // Optionally throw an error if any message failed to send
        // throw Exception('$failCount messages failed to re-send.');
      }
    } catch (e) {
      debugPrint('SMS re-send process failed: $e');
      rethrow; // Re-throw the exception to be caught by the UI
    }
  }

  /// Alternative method using intents (Opens the default SMS app pre-filled)
  /// This is less automatic but more transparent to the user.
  Future<void> restoreViaIntent(List<SmsModel> messages) async {
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
            // Wait a bit longer as the user needs to interact with the SMS app
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
