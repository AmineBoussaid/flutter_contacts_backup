import 'package:contacts_app/database/DatabaseHelper.dart';
import 'package:flutter/foundation.dart';
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
  Future<List<FavoriteModel>> getFavorites() async {
    try {
      return await _dbHelper.getAllFavorites();
    } catch (e) {
      debugPrint('Error fetching favorites: $e');
      return [];
    }
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
  Future<Map<String, int>> _getSmsCountByContact() async {
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
  Future<Map<String, int>> _getCallCountByContact() async {
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
  Future<void> generateFavoritesAuto() async {
    final smsCounts = await _getSmsCountByContact();
    final callCounts = await _getCallCountByContact();

    // Fusionner contacts et créer des favoris avec un seuil (ex: > 3 échanges)
    final allContacts = <String>{};
    allContacts.addAll(smsCounts.keys);
    allContacts.addAll(callCounts.keys);

    for (var contactId in allContacts) {
      final smsCount = smsCounts[contactId] ?? 0;
      final callCount = callCounts[contactId] ?? 0;

      // Exemple seuil : 3 échanges minimum entre sms et appels
      if (smsCount + callCount >= 3) {
        final fav = FavoriteModel(
          contactId: contactId,
          smsCount: smsCount,
          callCount: callCount,
          lastUpdated: DateTime.now(),
        );
        await addOrUpdateFavorite(fav);
      }
    }
  }
}
