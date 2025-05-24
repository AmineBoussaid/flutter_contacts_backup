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
      );

      final sent = await _telephony.getSentSms(
        columns: [
          SmsColumn.ID,
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
          SmsColumn.TYPE,
        ],
      );

      final allMessages = [
        ...inbox.map((m) => SmsModel.fromMessage(m)),
        ...sent.map((m) => SmsModel.fromMessage(m)),
      ];

      final uniqueMessages = <String, SmsModel>{};
      for (var message in allMessages) {
        uniqueMessages[message.id] = message;
      }

      return uniqueMessages.values.toList();
    } catch (e) {
      debugPrint('Error getting device SMS: $e');
      rethrow;
    }
  }

  /// Backup selected messages to Firebase
  Future<void> backupSelected(String userEmail, List<SmsModel> messages) async {
    try {
      if (messages.isEmpty) return;

      final backupData = <String, dynamic>{};
      for (var message in messages) {
        backupData[message.id] = message.toMap();
      }

      await _userRef(userEmail).child('sms').update(backupData);
    } catch (e) {
      debugPrint('Error backing up SMS: $e');
      rethrow;
    }
  }

  Future<List<SmsModel>> getBackupSms(String userEmail) async {
    final snap = await _userRef(userEmail).child('sms').get();
    if (!snap.exists || snap.value == null) return [];

    // 1) Log it so we know exactly what we have:
    print('🔍 RAW SMS DATA (${snap.value.runtimeType}): ${snap.value}');

    // 2) Tell Dart “treat this as a map of dynamic→dynamic”
    final Map<dynamic, dynamic> map = snap.value as Map<dynamic, dynamic>;
    final List<SmsModel> result = [];

    // 3) For each entry, cast *that* to a Map<String, dynamic> and build your model
    map.forEach((key, val) {
      try {
        // This cast uses the built-in .cast<>() which doesn’t blow up
        final smsMap = (val as Map).cast<String, dynamic>();
        result.add(SmsModel.fromMap(smsMap));
      } catch (err) {
        print('⚠️ Skipping invalid entry under key=$key: $err');
      }
    });

    return result;
  }

  /// Restore (re-send) selected SMS messages
  Future<void> restoreSelected(List<SmsModel> messages) async {
    try {
      final hasPermission = await _ensureSmsPermissions();
      if (!hasPermission) throw Exception('SMS permissions not granted');

      final validMessages =
          messages
              .where((m) => m.address.isNotEmpty && m.body.isNotEmpty)
              .toList();

      if (validMessages.isEmpty)
        throw Exception('No valid messages to restore');

      for (var message in validMessages) {
        try {
          // Updated sendSms call without status check
          await _telephony.sendSms(to: message.address, message: message.body);

          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint('Error sending to ${message.address}: $e');
          continue;
        }
      }
    } catch (e) {
      debugPrint('SMS restore failed: $e');
      rethrow;
    }
  }

  /// Alternative method using intents
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
            await Future.delayed(const Duration(seconds: 1));
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
