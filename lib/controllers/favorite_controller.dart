import 'package:contacts_app/database/DatabaseHelper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:telephony/telephony.dart';
import '../models/favorite_model.dart';
import 'package:call_log/call_log.dart';

class FavoriteController {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Ajouter ou mettre à jour un favori
  Future<void> addOrUpdateFavorite(FavoriteModel fav) async {
    try {
      await _dbHelper.insertOrUpdateFavorite(fav);
    } catch (e) {
      debugPrint('Error adding favorite: $e');
    }
  }

  /// Récupérer tous les favoris
  Future<List<FavoriteModel>> getFavorites({bool manuelle = false}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'favorites',
      where: 'manuelle = ?',
      whereArgs: [manuelle ? 1 : 0],
    );
    return maps.map((m) => FavoriteModel.fromMap(m)).toList();
  }

  /// Supprimer un favori
  Future<void> removeFavorite(String contactId) async {
    try {
      await _dbHelper.deleteFavorite(contactId);
    } catch (e) {
      debugPrint('Error deleting favorite: $e');
    }
  }

  // ... (autres méthodes et variables)

  final Telephony _telephony = Telephony.instance;

  /// Récupérer SMS par contact (nombre d'échanges)
  Future<Map<String, int>> getSmsCountByContact() async {
    final smsList = await _telephony.getInboxSms(columns: [SmsColumn.ADDRESS]);
    final Map<String, int> smsCountMap = {};

    for (var sms in smsList) {
      final addr = sms.address ?? '';
      if (addr.isEmpty) continue;
      smsCountMap[addr] = (smsCountMap[addr] ?? 0) + 1;
    }
    return smsCountMap;
  }

  /// Récupérer appels par contact (nombre d'appels)
  Future<Map<String, int>> getCallCountByContact() async {
    final Iterable<CallLogEntry> entries = await CallLog.get();
    final Map<String, int> callCountMap = {};

    for (var entry in entries) {
      final number = entry.number ?? '';
      if (number.isEmpty) continue;
      callCountMap[number] = (callCountMap[number] ?? 0) + 1;
    }
    return callCountMap;
  }

  /// Générer et stocker favoris automatiquement
  Future<void> generateFavoritesAutoOncePerDay() async {
    final lastUpdate = await _dbHelper.getLastAutoUpdateTime();
    final now = DateTime.now();

    if (lastUpdate == null || now.difference(lastUpdate).inHours >= 24) {
      await generateFavoritesAuto();
    }
  }

  Future<void> generateFavoritesAuto() async {
    final smsCounts = await getSmsCountByContact();
    final callCounts = await getCallCountByContact();
    final allContacts =
        <String>{}
          ..addAll(smsCounts.keys)
          ..addAll(callCounts.keys);

    // Charger tous les contacts pour trouver les noms
    List<Contact> contacts = await FlutterContacts.getContacts(
      withProperties: true,
    );

    final List<FavoriteModel> tempFavorites = [];

    for (var contactId in allContacts) {
      final smsCount = smsCounts[contactId] ?? 0;
      final callCount = callCounts[contactId] ?? 0;

      if (callCount + smsCount >= 3) {
        // Chercher le nom correspondant
        String name = contactId;
        final matched = contacts.firstWhere(
          (c) => c.phones.any(
            (p) => p.number.replaceAll(RegExp(r'\s+'), '') == contactId,
          ),
          orElse: () => Contact(),
        );
        if (matched.displayName.isNotEmpty) {
          name = matched.displayName;
        }

        final fav = FavoriteModel(
          contactId: contactId,
          name: name,
          number: contactId,
          smsCount: smsCount,
          callCount: callCount,
          lastUpdated: DateTime.now(),
          manuelle: false,
        );
        tempFavorites.add(fav);
      }
    }

    tempFavorites.sort(
      (a, b) =>
          (b.callCount != a.callCount)
              ? b.callCount - a.callCount
              : b.smsCount - a.smsCount,
    );

    final top5 = tempFavorites.take(5).toList();

    for (final fav in top5) {
      await addOrUpdateFavorite(fav);
    }
  }

  Future<FavoriteModel> enrichManualFavorite(FavoriteModel fav) async {
    final smsCounts = await getSmsCountByContact();
    final callCounts = await getCallCountByContact();
    final name = await getContactNameFromNumber(fav.number); // méthode à créer
    return FavoriteModel(
      contactId: fav.contactId,
      name: name ?? fav.name,
      number: fav.number,
      smsCount: smsCounts[fav.number] ?? 0,
      callCount: callCounts[fav.number] ?? 0,
      lastUpdated: DateTime.now(),
      manuelle: true,
    );
  }

  Future<String?> getContactNameFromNumber(String number) async {
    if (!await FlutterContacts.requestPermission()) return null;
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    for (final c in contacts) {
      if (c.phones.any(
        (p) => p.number.replaceAll(' ', '') == number.replaceAll(' ', ''),
      )) {
        return '${c.name.first} ${c.name.last}'.trim();
      }
    }
    return null;
  }
}
