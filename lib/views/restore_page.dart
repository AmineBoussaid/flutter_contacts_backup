import 'package:flutter/material.dart';
import 'package:contacts_app/controllers/contact_controller.dart';
import 'package:contacts_app/models/contact_model.dart';

class RestorePage extends StatefulWidget {
  const RestorePage({Key? key}) : super(key: key);

  @override
  State<RestorePage> createState() => _RestorePageState();
}

class _RestorePageState extends State<RestorePage> {
  final ContactController _controller = ContactController();
  List<ContactModel> _contacts = [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadBackup();
  }

  Future<void> _loadBackup() async {
    final list = await _controller.getBackupContacts();
    setState(() => _contacts = list);
  }

  void _onRestore() async {
    final toInsert = _contacts
        .where((c) => _selected.contains(c.id))
        .toList();
    await _controller.restoreSelected(toInsert);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Restored ${toInsert.length} contacts')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selective Restore')),
      body: ListView.builder(
        itemCount: _contacts.length,
        itemBuilder: (_, i) {
          final c = _contacts[i];
          return CheckboxListTile(
            title: Text('${c.firstName} ${c.lastName}'),
            subtitle: Text(c.phones.join(', ')),
            value: _selected.contains(c.id),
            onChanged: (v) {
              setState(() {
                if (v == true) _selected.add(c.id);
                else _selected.remove(c.id);
              });
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onRestore,
        child: Icon(Icons.restore),
      ),
    );
  }
}