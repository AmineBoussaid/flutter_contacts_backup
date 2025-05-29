import 'package:contacts_app/controllers/favorite_controller.dart';
import 'package:contacts_app/models/favorite_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/contact_model.dart';
import 'firebase_service.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull

class ContactController {
  final FirebaseService _firebaseService = FirebaseService();
  final FavoriteController _favoriteController = FavoriteController();

  // Cache for device contacts to avoid multiple fetches
  List<ContactModel>? _deviceContactsCache;

  /// Fetch all device contacts, using cache if available
  Future<List<ContactModel>> getDeviceContacts({bool forceRefresh = false}) async {
    if (!forceRefresh && _deviceContactsCache != null) {
      debugPrint("Returning cached device contacts.");
      return _deviceContactsCache!;
    }

    debugPrint("Requesting contacts permission...");
    if (!await FlutterContacts.requestPermission()) {
      debugPrint("Contacts permission denied by user.");
      throw Exception('Contacts permission denied');
    }
    debugPrint("Contacts permission granted. Fetching contacts...");
    try {
      // Fetch contacts with properties
      final raw = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false, // Fetch photo only if needed later
      );
      debugPrint("Fetched ${raw.length} raw contacts from device.");

      final List<ContactModel> models = [];
      for (final c in raw) {
        try {
          // Convert to ContactModel (includes hash calculation)
          models.add(ContactModel.fromEntity(c));
        } catch (e) {
          debugPrint("Error converting contact ${c.id} (${c.displayName}): $e");
        }
      }
      debugPrint(
        "Successfully converted ${models.length} contacts to ContactModel.",
      );
      _deviceContactsCache = models; // Update cache
      return models;
    } catch (e) {
      debugPrint("Error fetching device contacts: $e");
      throw Exception('Failed to fetch device contacts: ${e.toString()}');
    }
  }

  /// Fetch all contacts from Firebase backup
  Future<List<ContactModel>> getBackupContacts() async {
    debugPrint("Fetching contacts from Firebase backup...");
    try {
      final contacts = await _firebaseService.getContacts();
      debugPrint(
        "Successfully fetched ${contacts.length} contacts from backup.",
      );
      // Ensure hash is calculated if missing from older backups (optional)
      // for (var contact in contacts) {
      //   contact.hashCodeForSync ??= contact.calculateSyncHash();
      // }
      return contacts;
    } catch (e) {
      debugPrint("Error fetching backup contacts: $e");
      rethrow; // Rethrow to be caught by UI
    }
  }

  /// Backup (save or update) selected contacts to Firebase
  /// The UI layer should provide the list of contacts marked as Nouveau or Modifie
  Future<void> backupSelected(List<ContactModel> contactsToBackup) async {
    if (contactsToBackup.isEmpty) {
      debugPrint("No contacts selected for backup.");
      return;
    }
    debugPrint("Attempting to backup ${contactsToBackup.length} selected contacts...");
    try {
      // The Firebase service should handle add/update based on ID
      await _firebaseService.saveContacts(contactsToBackup);
      debugPrint("Successfully backed up ${contactsToBackup.length} contacts.");
      // Invalidate cache after backup
      _deviceContactsCache = null;
    } catch (e) {
      debugPrint("Error during backupSelected: $e");
      rethrow; // Rethrow to be caught by UI
    }
  }

  /// Restore selected contacts (those marked as Manquant) to the device
  Future<void> restoreSelected(List<ContactModel> contactsToRestore) async {
    if (contactsToRestore.isEmpty) {
      debugPrint("No contacts selected for restore.");
      return;
    }
    debugPrint("Requesting contacts permission for restore...");
    if (!await FlutterContacts.requestPermission()) {
      debugPrint("Contacts permission denied for restore.");
      throw Exception('Contacts permission denied');
    }
    debugPrint(
      "Contacts permission granted. Attempting to restore ${contactsToRestore.length} selected contacts...",
    );

    int successCount = 0;
    int failCount = 0;

    for (final c in contactsToRestore) {
      try {
        final newContact = Contact();
        newContact.name.first = c.firstName;
        newContact.name.last = c.lastName;
        newContact.phones = (c.phones).map((p) => Phone(p)).toList();
        newContact.emails = (c.emails).map((e) => Email(e)).toList();

        // Photo handling (optional, consider performance and errors)
        // if (c.photo != null) {
        //   try {
        //     newContact.photo = base64Decode(c.photo!);
        //   } catch (e) { debugPrint("Error decoding photo for contact ${c.id}: $e"); }
        // }

        await newContact.insert();
        successCount++;
        debugPrint(
          "Successfully inserted contact: ${c.firstName} ${c.lastName}",
        );
      } catch (e) {
        failCount++;
        debugPrint(
          "Error inserting contact ${c.id} (${c.firstName} ${c.lastName}): $e",
        );
        continue; // Continue with the next contact
      }
    }
    debugPrint(
      "Restore attempt finished. Success: $successCount, Failed: $failCount",
    );
    // Invalidate cache after restore
    _deviceContactsCache = null;
    if (failCount > 0) {
      // Optionally throw an error to indicate partial success
      // throw Exception('$failCount contacts failed to restore.');
    }
  }

  /// Get contact display name from phone number
  /// Uses the cached device contacts for efficiency
  Future<String?> getContactNameFromNumber(String number) async {
    // Ensure cache is populated
    final contacts = await getDeviceContacts();
    if (contacts.isEmpty) return null;

    // Normalize the number for comparison (basic example)
    final normalizedNumber = number.replaceAll(RegExp(r'\s+|-|\(|\)'), '');

    final matchingContact = contacts.firstWhereOrNull((contact) {
      return contact.phones.any((phone) {
        final normalizedPhone = phone.replaceAll(RegExp(r'\s+|-|\(|\)'), '');
        // Simple suffix check, might need more robust comparison
        return normalizedPhone.endsWith(normalizedNumber) || normalizedNumber.endsWith(normalizedPhone);
      });
    });

    if (matchingContact != null) {
      final name = '${matchingContact.firstName} ${matchingContact.lastName}'.trim();
      return name.isNotEmpty ? name : null; // Return null if name is empty
    }

    return null; // No matching contact found
  }


  // --- Favorite methods remain unchanged for now ---
  Future<void> addOrUpdateFavorite(FavoriteModel fav) async {
    final existing =
        (await _favoriteController.getFavorites(
          manuelle: true,
        )).where((f) => f.contactId == fav.contactId).toList();

    if (existing.isNotEmpty) {
      await _favoriteController.removeFavorite(fav.contactId);
    }

    final enrichedFav = await _favoriteController.enrichManualFavorite(fav);
    await _favoriteController.addOrUpdateFavorite(enrichedFav);
  }

  Future<List<FavoriteModel>> getManualFavorites() async {
    return await _favoriteController.getFavorites(manuelle: true);
  }
}

