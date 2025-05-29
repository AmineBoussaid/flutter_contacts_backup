import 'package:flutter/material.dart';
import 'package:contacts_app/controllers/contact_controller.dart';
import 'package:contacts_app/models/contact_model.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:collection/collection.dart'; // For mapEquals

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final ContactController _controller = ContactController();
  List<ContactModel> _allDeviceContacts = []; // Holds all contacts from device
  List<ContactModel> _filteredContacts =
      []; // Holds contacts displayed after search
  final Map<String, ContactModel> _backupContactsMap =
      {}; // Holds backup contacts for quick lookup
  final Set<String> _selected = {}; // Holds IDs of selected contacts
  bool _isAllSelectableSelected = false;
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAndCompareContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterContacts);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAndCompareContacts() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
        _selected.clear();
        _isAllSelectableSelected = false;
      });

      // 1. Fetch device contacts (use cache if possible)
      final deviceContacts = await _controller.getDeviceContacts(
        forceRefresh: true,
      );
      if (!mounted) return;
      debugPrint("Fetched ${deviceContacts.length} contacts from device.");

      // 2. Fetch backup contacts from Firebase
      final backupContacts = await _controller.getBackupContacts();
      if (!mounted) return;
      debugPrint(
        "Fetched ${backupContacts.length} contacts from Firebase backup.",
      );

      // Create a map for quick lookup of backup contacts by ID
      _backupContactsMap.clear();
      for (var contact in backupContacts) {
        _backupContactsMap[contact.id] = contact;
      }

      // 3. Compare and determine status for each device contact
      for (var deviceContact in deviceContacts) {
        final backupContact = _backupContactsMap[deviceContact.id];
        if (backupContact == null) {
          deviceContact.backupStatus = BackupStatus.nouveau;
        } else {
          // Compare using the hash (or timestamp/full comparison)
          if (deviceContact.hashCodeForSync == backupContact.hashCodeForSync) {
            deviceContact.backupStatus = BackupStatus.synchronise;
          } else {
            deviceContact.backupStatus = BackupStatus.modifie;
          }
        }
      }

      // Sort contacts alphabetically by name
      deviceContacts.sort((a, b) {
        final nameA = '${a.firstName} ${a.lastName}'.trim().toLowerCase();
        final nameB = '${b.firstName} ${b.lastName}'.trim().toLowerCase();
        return nameA.compareTo(nameB);
      });

      setState(() {
        _allDeviceContacts = deviceContacts;
        _filteredContacts = deviceContacts; // Initially show all
        _loading = false;
        _error = null;
        _updateSelectAllState(); // Update select all based on current selection
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load and compare contacts: ${e.toString()}';
        _allDeviceContacts = [];
        _filteredContacts = [];
      });
      debugPrint("Error in _loadAndCompareContacts: $e");
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _allDeviceContacts;
      } else {
        _filteredContacts =
            _allDeviceContacts.where((contact) {
              final name =
                  '${contact.firstName} ${contact.lastName}'.toLowerCase();
              final phones = contact.phones.join(' ').toLowerCase();
              final emails = contact.emails.join(' ').toLowerCase();
              return name.contains(query) ||
                  phones.contains(query) ||
                  emails.contains(query);
            }).toList();
      }
      _updateSelectAllState(); // Recalculate select all based on filtered list
    });
  }

  void _updateSelectAllState() {
    final selectableContacts =
        _filteredContacts
            .where(
              (c) =>
                  c.backupStatus == BackupStatus.nouveau ||
                  c.backupStatus == BackupStatus.modifie,
            )
            .toList();
    if (selectableContacts.isEmpty) {
      _isAllSelectableSelected = false;
    } else {
      _isAllSelectableSelected = selectableContacts.every(
        (c) => _selected.contains(c.id),
      );
    }
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _isAllSelectableSelected = value ?? false;
      final selectableContacts = _filteredContacts.where(
        (c) =>
            c.backupStatus == BackupStatus.nouveau ||
            c.backupStatus == BackupStatus.modifie,
      );

      if (_isAllSelectableSelected) {
        for (var contact in selectableContacts) {
          _selected.add(contact.id);
        }
      } else {
        for (var contact in selectableContacts) {
          _selected.remove(contact.id);
        }
        // Ensure only selectable items are affected
        // _selected.removeWhere((id) => selectableContacts.any((c) => c.id == id));
      }
    });
  }

  void _onBackup() async {
    final selectedContacts =
        _allDeviceContacts // Use all contacts to find selected ones by ID
            .where((c) => _selected.contains(c.id))
            .toList();

    // Filter again to ensure only Nouveau or Modifie are backed up
    final contactsToBackup =
        selectedContacts
            .where(
              (c) =>
                  c.backupStatus == BackupStatus.nouveau ||
                  c.backupStatus == BackupStatus.modifie,
            )
            .toList();

    if (contactsToBackup.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select new or modified contacts to backup'),
        ),
      );
      return;
    }

    // Show progress dialog
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
                Text('Backing up ${contactsToBackup.length} contacts...'),
              ],
            ),
          ),
    );

    try {
      await _controller.backupSelected(contactsToBackup);
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully backed up ${contactsToBackup.length} contacts',
            ),
          ),
        );
        // Reload contacts after backup to update status
        _loadAndCompareContacts();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: ${e.toString()}')),
        );
      }
      debugPrint("Error during _onBackup: $e");
    }
  }

  Widget _buildStatusIndicator(BackupStatus status) {
    IconData icon;
    Color color;
    String text;
    switch (status) {
      case BackupStatus.nouveau:
        icon = Icons.add_circle_outline;
        color = Colors.blue;
        text = 'New';
        break;
      case BackupStatus.modifie:
        icon = Icons.sync_problem_outlined;
        color = Colors.orange;
        text = 'Modified';
        break;
      case BackupStatus.synchronise:
        icon = Icons.check_circle_outline;
        color = Colors.green;
        text = 'Synced';
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        text = 'Unknown';
    }
    // Simple icon indicator
    // return Icon(icon, color: color, size: 18);
    // Chip indicator
    return Chip(
      avatar: Icon(icon, color: color, size: 16),
      label: Text(text, style: TextStyle(fontSize: 10)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: color.withOpacity(0.1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canSelectAny = _filteredContacts.any(
      (c) =>
          c.backupStatus == BackupStatus.nouveau ||
          c.backupStatus == BackupStatus.modifie,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Contacts'),
        actions: [
          if (!_loading && _allDeviceContacts.isNotEmpty && canSelectAny)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("All", style: Theme.of(context).textTheme.bodySmall),
                  Checkbox(
                    value: _isAllSelectableSelected,
                    onChanged: _toggleSelectAll,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Contacts',
            onPressed: _loadAndCompareContacts,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Contacts',
                hintText: 'Search by name, phone, email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 10,
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selected.isEmpty ? null : _onBackup,
        label: Text('Backup (${_selected.length})'),
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
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadAndCompareContacts,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_allDeviceContacts.isEmpty) {
      return const Center(child: Text('No contacts found on device.'));
    }

    if (_filteredContacts.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Text('No contacts found matching "${_searchController.text}"'),
      );
    }

    return ListView.builder(
      itemCount: _filteredContacts.length,
      itemBuilder: (_, i) {
        final c = _filteredContacts[i];
        final isSelectable =
            c.backupStatus == BackupStatus.nouveau ||
            c.backupStatus == BackupStatus.modifie;
        final displayName =
            ('${c.firstName} ${c.lastName}'.trim().isEmpty)
                ? '(No Name)'
                : '${c.firstName} ${c.lastName}'.trim();
        final displayPhones =
            c.phones.isNotEmpty ? c.phones.join(', ') : '(No Phones)';

        return CheckboxListTile(
          secondary: _buildStatusIndicator(c.backupStatus),
          title: Text(displayName),
          subtitle: Text(
            displayPhones,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          value: _selected.contains(c.id),
          // Disable checkbox if status is 'synchronise'
          onChanged:
              isSelectable
                  ? (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(c.id);
                      } else {
                        _selected.remove(c.id);
                      }
                      _updateSelectAllState(); // Update select all based on current selection
                    });
                  }
                  : null, // Set onChanged to null to disable
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Theme.of(context).primaryColor,
          // Optionally change visual appearance for non-selectable items
          tileColor: isSelectable ? null : Colors.grey.withOpacity(0.1),
        );
      },
    );
  }
}
