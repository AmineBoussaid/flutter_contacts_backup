import 'package:flutter/material.dart';
import 'package:contacts_app/controllers/contact_controller.dart';
import 'package:contacts_app/models/contact_model.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final ContactController _controller = ContactController();
  List<ContactModel> _contacts = [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final list = await _controller.getDeviceContacts();
    setState(() => _contacts = list);
  }

  void _onBackup() async {
    final selectedContacts =
        _contacts.where((c) => _selected.contains(c.id)).toList();
    await _controller.backupSelected(selectedContacts);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backed up ${selectedContacts.length} contacts')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selective Backup')),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _onBackup,
        child: Icon(Icons.cloud_upload),
      ),
    );
  }
}
