// lib/views/contacts_page.dart

import 'package:flutter/material.dart';
import 'package:contacts_app/controllers/contact_controller.dart';
import 'package:contacts_app/models/contact_model.dart';
import 'package:contacts_app/models/favorite_model.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});
  
  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final ContactController _controller = ContactController();
  List<ContactModel> _contacts = [];
  final Set<String> _selected = {};
  Set<String> _alreadyFavorites = {};

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final list = await _controller.getDeviceContacts();
    final favs = await _controller.getManualFavorites();
    setState(() {
      _contacts = list;
      _alreadyFavorites = favs.map((f) => f.contactId).toSet();
    });
  }

  void _onAddToFavorites() async {
    final selectedContacts =
        _contacts.where((c) => _selected.contains(c.id)).toList();

    List<String> already = [];
    for (final contact in selectedContacts) {
      if (_alreadyFavorites.contains(contact.id)) {
        already.add('${contact.firstName} ${contact.lastName}');
        continue;
      }

      final fav = FavoriteModel(
        contactId: contact.id,
        name: '${contact.firstName} ${contact.lastName}',
        number: contact.phones.isNotEmpty ? contact.phones.first : '',
        callCount: 0,
        smsCount: 0,
        lastUpdated: DateTime.now(),
        manuelle: true,
      );

      await _controller.addOrUpdateFavorite(fav);
    }

    setState(() => _selected.clear());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          already.isEmpty
              ? 'Favoris ajoutés avec succès.'
              : 'Déjà favoris :\n${already.join(', ')}',
        ),
      ),
    );

    // Reload
    final favs = await _controller.getManualFavorites();
    setState(() {
      _alreadyFavorites = favs.map((f) => f.contactId).toSet();
    });
  }

  void _onMenuOption(String value) {
    switch (value) {
      case 'backup':
        Navigator.pushNamed(context, '/backup');
        break;
      case 'restore':
        Navigator.pushNamed(context, '/restore');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _onMenuOption,
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'backup',
                    child: Text('Selective Backup'),
                  ),
                  const PopupMenuItem(
                    value: 'restore',
                    child: Text('Selective Restore'),
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _contacts.length,
              itemBuilder: (_, i) {
                final c = _contacts[i];
                return CheckboxListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text('${c.firstName} ${c.lastName}')),
                      if (_alreadyFavorites.contains(c.id))
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                    ],
                  ),
                  subtitle: Text(c.phones.join(', ')),
                  value: _selected.contains(c.id),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(c.id);
                      } else {
                        _selected.remove(c.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: _onAddToFavorites,
              icon: const Icon(Icons.star),
              label: const Text("Ajouter aux Favoris"),
            ),
          ),
        ],
      ),
    );
  }
}
