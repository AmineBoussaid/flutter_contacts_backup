import 'package:flutter/material.dart';
import 'package:contacts_app/controllers/contact_controller.dart';
import 'package:contacts_app/models/contact_model.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final ContactController _controller = ContactController();
  List<ContactModel> _contactsToDisplay =
      []; // Holds the differential list for backup
  final Set<String> _selected = {};
  bool _isAllSelected = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDifferentialContactsForBackup();
  }

  Future<void> _loadDifferentialContactsForBackup() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
        _selected.clear();
        _isAllSelected = false;
      });

      // 1. Fetch device contacts
      final deviceContacts = await _controller.getDeviceContacts();
      if (!mounted) return;
      debugPrint("Fetched ${deviceContacts.length} contacts from device.");

      // 2. Fetch backup contacts from Firebase
      List<ContactModel> backupContacts = [];
      try {
        // Assuming getBackupContacts handles List/Map correctly
        backupContacts = await _controller.getBackupContacts();
        if (!mounted) return;
        debugPrint(
          "Fetched ${backupContacts.length} contacts from Firebase backup.",
        );
      } catch (e) {
        debugPrint("Error fetching backup contacts for diff: $e");
        // Decide how to handle - here we proceed showing all device contacts if backup fails
        // setState(() {
        //   _loading = false;
        //   _error = 'Failed to load backup contacts for comparison: ${e.toString()}';
        //   _contactsToDisplay = [];
        // });
        // return;
      }

      // 3. Perform differential logic: Find device contacts not present in backup
      // Using contact ID as the unique identifier.
      // TODO: Add logic to also include contacts updated since last backup if needed

      final backupContactIds = backupContacts.map((c) => c.id).toSet();
      final diffContacts =
          deviceContacts
              .where((c) => !backupContactIds.contains(c.id))
              .toList();

      debugPrint(
        "Differential contacts to backup (not in backup): ${diffContacts.length}",
      );

      // Sort the differential list alphabetically by name for consistent order
      diffContacts.sort((a, b) {
        final nameA = '${a.firstName} ${a.lastName}'.trim();
        final nameB = '${b.firstName} ${b.lastName}'.trim();
        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      });

      setState(() {
        _contactsToDisplay = diffContacts; // Store differential list
        _loading = false;
        _error = null;
        _isAllSelected =
            _contactsToDisplay.isNotEmpty &&
            _selected.length == _contactsToDisplay.length;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load and compare contacts: ${e.toString()}';
        _contactsToDisplay = [];
      });
    }
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _isAllSelected = value ?? false;
      _selected.clear();
      if (_isAllSelected) {
        for (var contact in _contactsToDisplay) {
          _selected.add(contact.id);
        }
      }
    });
  }

  void _onBackup() async {
    final selectedContacts =
        _contactsToDisplay.where((c) => _selected.contains(c.id)).toList();

    if (selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select contacts to backup')),
      );
      return;
    }

    // Show progress/confirmation dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Backing Up Contacts'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Backing up ${selectedContacts.length} contacts...'),
              ],
            ),
          ),
    );

    try {
      await _controller.backupSelected(selectedContacts);
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully backed up ${selectedContacts.length} contacts',
            ),
          ),
        );
        // Reload the differential list after backup
        _loadDifferentialContactsForBackup();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Contacts'),
        actions: [
          if (!_loading && _contactsToDisplay.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("All", style: Theme.of(context).textTheme.bodyMedium),
                  Checkbox(
                    value: _isAllSelected,
                    onChanged: _toggleSelectAll,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDifferentialContactsForBackup,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selected.isEmpty ? null : _onBackup,
        label: const Text('Backup Selected'),
        icon: const Icon(Icons.cloud_upload),
        backgroundColor:
            _selected.isEmpty
                ? Colors.grey
                : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDifferentialContactsForBackup,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_contactsToDisplay.isEmpty) {
      return const Center(
        child: Text('No new contacts found on device to backup'),
      );
    }

    return ListView.builder(
      itemCount: _contactsToDisplay.length,
      itemBuilder: (_, i) {
        final c = _contactsToDisplay[i];
        final displayName =
            ('${c.firstName} ${c.lastName}'.trim().isEmpty)
                ? '(No Name)'
                : '${c.firstName} ${c.lastName}'.trim();
        final displayPhones =
            c.phones.isNotEmpty ? c.phones.join(', ') : '(No Phones)';
        return CheckboxListTile(
          title: Text(displayName),
          subtitle: Text(displayPhones),
          value: _selected.contains(c.id),
          onChanged: (v) {
            setState(() {
              if (v == true) {
                _selected.add(c.id);
              } else {
                _selected.remove(c.id);
              }
              _isAllSelected =
                  _contactsToDisplay.isNotEmpty &&
                  _selected.length == _contactsToDisplay.length;
            });
          },
        );
      },
    );
  }
}
