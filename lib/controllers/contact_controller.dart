import 'package:contacts_app/controllers/favorite_controller.dart';
import 'package:contacts_app/models/favorite_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/contact_model.dart';
import 'firebase_service.dart';

class ContactController {
  final FirebaseService _firebaseService = FirebaseService();
  final FavoriteController _favoriteController = FavoriteController();

  /// Fetch all device contacts
  Future<List<ContactModel>> getDeviceContacts() async {
    debugPrint("Requesting contacts permission...");
    if (!await FlutterContacts.requestPermission()) {
      debugPrint("Contacts permission denied by user.");
      throw Exception('Contacts permission denied');
    }
    debugPrint("Contacts permission granted. Fetching contacts...");
    try {
      // Fetch contacts with properties but without photo initially for performance
      final raw = await FlutterContacts.getContacts(
        withProperties: true,
        // withPhoto: false, // Fetch photo only if needed later or handle potential errors
        // withThumbnail: true, // Fetch thumbnail instead of full photo?
      );
      debugPrint("Fetched ${raw.length} raw contacts from device.");
      // Convert to ContactModel, handling potential errors during conversion
      final List<ContactModel> models = [];
      for (final c in raw) {
        try {
          models.add(ContactModel.fromEntity(c));
        } catch (e) {
          debugPrint("Error converting contact ${c.id} (${c.displayName}): $e");
          // Optionally skip this contact or handle the error
        }
      }
      debugPrint(
        "Successfully converted ${models.length} contacts to ContactModel.",
      );
      return models;
    } catch (e) {
      debugPrint("Error fetching device contacts: $e");
      throw Exception('Failed to fetch device contacts: ${e.toString()}');
    }
  }

  /// Backup (save or update) selected contacts to Firebase
  /// Assumes the input list `contacts` is already the *differential* list (e.g., new/updated)
  Future<void> backupSelected(List<ContactModel> contacts) async {
    if (contacts.isEmpty) {
      debugPrint("No contacts selected for backup.");
      return;
    }
    debugPrint("Attempting to backup ${contacts.length} selected contacts...");
    try {
      await _firebaseService.saveContacts(contacts);
      debugPrint("Successfully backed up ${contacts.length} contacts.");
    } catch (e) {
      debugPrint("Error during backupSelected: $e");
      rethrow; // Rethrow to be caught by UI
    }
  }

  /// Fetch contacts from Firebase backup
  Future<List<ContactModel>> getBackupContacts() async {
    debugPrint("Fetching contacts from Firebase backup...");
    try {
      final contacts = await _firebaseService.getContacts();
      debugPrint(
        "Successfully fetched ${contacts.length} contacts from backup.",
      );
      return contacts;
    } catch (e) {
      debugPrint("Error fetching backup contacts: $e");
      rethrow; // Rethrow to be caught by UI
    }
  }

  /// Restore only selected contacts (used by the selective UI)
  /// Assumes the input list `contacts` is already the *differential* list (e.g., not on device)
  Future<void> restoreSelected(List<ContactModel> contacts) async {
    if (contacts.isEmpty) {
      debugPrint("No contacts selected for restore.");
      return;
    }
    debugPrint("Requesting contacts permission for restore...");
    if (!await FlutterContacts.requestPermission()) {
      debugPrint("Contacts permission denied for restore.");
      throw Exception('Contacts permission denied');
    }
    debugPrint(
      "Contacts permission granted. Attempting to restore ${contacts.length} selected contacts...",
    );

    int successCount = 0;
    int failCount = 0;

    for (final c in contacts) {
      try {
        final newContact = Contact();
        newContact.name.first = c.firstName;
        newContact.name.last = c.lastName;
        // Ensure phones and emails are not null before mapping
        newContact.phones = (c.phones ?? []).map((p) => Phone(p)).toList();
        newContact.emails = (c.emails ?? []).map((e) => Email(e)).toList();

        // Handle photo - requires careful error handling and base64 decoding
        // if (c.photo != null) {
        //   try {
        //     newContact.photo = base64Decode(c.photo!);
        //   } catch (e) {
        //     debugPrint("Error decoding photo for contact ${c.id}: $e");
        //     // Decide how to handle: skip photo, log, etc.
        //   }
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
        // Decide if you want to stop on first error or continue
        continue; // Continue with the next contact
      }
    }
    debugPrint(
      "Restore attempt finished. Success: $successCount, Failed: $failCount",
    );
    if (failCount > 0) {
      // Optionally throw an error to indicate partial success
      // throw Exception('$failCount contacts failed to restore.');
    }
  }

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
