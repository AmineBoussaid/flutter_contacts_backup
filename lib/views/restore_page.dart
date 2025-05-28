import 'package:flutter/material.dart';
import 'package:contacts_app/controllers/contact_controller.dart';
import 'package:contacts_app/models/contact_model.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class RestorePage extends StatefulWidget {
  const RestorePage({super.key});

  @override
  State<RestorePage> createState() => _RestorePageState();
}

class _RestorePageState extends State<RestorePage> {
  final ContactController _controller = ContactController();
  List<ContactModel> _contactsToDisplay = []; // Holds the differential list
  final Set<String> _selected = {};
  bool _isAllSelected = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDifferentialBackup();
  }

  Future<void> _loadDifferentialBackup() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
        _selected.clear();
        _isAllSelected = false;
      });

      // 1. Fetch backup contacts from Firebase
      // Assuming getBackupContacts handles List/Map correctly now
      final backupContacts = await _controller.getBackupContacts();
      if (!mounted) return;
      debugPrint(
        "Fetched ${backupContacts.length} contacts from Firebase backup.",
      );

      // 2. Fetch device contacts
      // Assuming getDeviceContacts exists and works
      List<ContactModel> deviceContacts = [];
      try {
        deviceContacts = await _controller.getDeviceContacts();
        if (!mounted) return;
        debugPrint("Fetched ${deviceContacts.length} contacts from device.");
      } catch (e) {
        debugPrint("Error fetching device contacts for diff: $e");
        setState(() {
          _loading = false;
          _error =
              'Failed to load device contacts for comparison: ${e.toString()}';
          _contactsToDisplay = [];
        });
        return;
      }

      // 3. Perform differential logic: Find backup contacts not present on device
      // Using contact ID as the unique identifier.
      final deviceContactIds = deviceContacts.map((c) => c.id).toSet();
      final diffContacts =
          backupContacts
              .where((c) => !deviceContactIds.contains(c.id))
              .toList();

      debugPrint(
        "Differential contacts to restore (not on device): ${diffContacts.length}",
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
        _error = 'Failed to load and compare contact backups: ${e.toString()}';
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

  void _onRestore() async {
    final toInsert =
        _contactsToDisplay.where((c) => _selected.contains(c.id)).toList();

    if (toInsert.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select contacts to restore')),
      );
      return;
    }

    // Show progress/confirmation dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Restoring Contacts'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Restoring ${toInsert.length} contacts...'),
              ],
            ),
          ),
    );

    try {
      // Assuming restoreSelected adds contacts to the device
      await _controller.restoreSelected(toInsert);
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully restored ${toInsert.length} contacts'),
          ),
        );
        // Reload the differential list after restore
        _loadDifferentialBackup();
        // setState(() => _selected.clear()); // Already cleared in _loadDifferentialBackup
        // _isAllSelected = false;
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore Contacts'),
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
            onPressed: _loadDifferentialBackup,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selected.isEmpty ? null : _onRestore,
        label: const Text('Restore Selected'),
        icon: const Icon(Icons.restore),
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
                onPressed: _loadDifferentialBackup,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_contactsToDisplay.isEmpty) {
      return const Center(
        child: Text('No new contacts found in backup to restore'),
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
