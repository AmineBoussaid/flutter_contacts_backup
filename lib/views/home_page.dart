import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controllers/contact_controller.dart';

class HomePage extends StatelessWidget {
  final ContactController _contactController = ContactController();
  final user = FirebaseAuth.instance.currentUser!;
  String _sanitizeEmail(String email) => email.replaceAll('.', ',');

  HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts Backup')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Logged in as: ${user.email}', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _backupContacts(context),
              child: const Text('Backup Contacts'),
            ),
            ElevatedButton(
              onPressed: () => _restoreContacts(context),
              child: const Text('Restore Contacts'),
            ),
            ElevatedButton(
            onPressed: () async {
              final snapshot = await FirebaseDatabase.instance
                  .ref('users/${_sanitizeEmail(user.email!)}/contacts')
                  .get();
              debugPrint(snapshot.value.toString());
            },
            child: Text('Debug: Print Firebase Data'),
          ),
            // Add similar buttons for SMS and Favorites
          ],
        ),
      ),
    );
  }

  Future<void> _backupContacts(BuildContext context) async {
    try {
      await _contactController.backupContacts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts backed up successfully!'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'))
      );
    }
  }
  Future<void> _restoreContacts(BuildContext context) async {
  try {
    final contacts = await _contactController.restoreContacts();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Restored ${contacts.length} contacts'))
    );
    // Optionally navigate to contacts view
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Restore failed: ${e.toString()}'))
    );
  }
}
}