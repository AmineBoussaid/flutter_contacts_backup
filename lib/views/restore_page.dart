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
  List<ContactModel> _allBackupContacts =
      []; // Holds all contacts from backup with status
  List<ContactModel> _filteredContacts =
      []; // Holds contacts displayed after search
  final Map<String, ContactModel> _deviceContactsMap =
      {}; // Holds device contacts for quick lookup
  final Set<String> _selected =
      {}; // Holds IDs of selected contacts (only 'Manquant')
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

      // 1. Fetch backup contacts from Firebase
      final backupContacts = await _controller.getBackupContacts();
      if (!mounted) return;
      debugPrint(
        "Fetched ${backupContacts.length} contacts from Firebase backup.",
      );

      // 2. Fetch device contacts (use cache if possible)
      final deviceContacts = await _controller.getDeviceContacts();
      if (!mounted) return;
      debugPrint("Fetched ${deviceContacts.length} contacts from device.");

      // Create a map for quick lookup of device contacts by ID
      _deviceContactsMap.clear();
      for (var contact in deviceContacts) {
        _deviceContactsMap[contact.id] = contact;
      }

      // 3. Compare and determine status for each backup contact
      for (var backupContact in backupContacts) {
        if (_deviceContactsMap.containsKey(backupContact.id)) {
          backupContact.restoreStatus = RestoreStatus.present;
        } else {
          backupContact.restoreStatus = RestoreStatus.manquant;
        }
      }

      // Sort contacts alphabetically by name
      backupContacts.sort((a, b) {
        final nameA = '${a.firstName} ${a.lastName}'.trim().toLowerCase();
        final nameB = '${b.firstName} ${b.lastName}'.trim().toLowerCase();
        return nameA.compareTo(nameB);
      });

      setState(() {
        _allBackupContacts = backupContacts;
        _filteredContacts = backupContacts; // Initially show all
        _loading = false;
        _error = null;
        _updateSelectAllState();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load and compare contacts: ${e.toString()}';
        _allBackupContacts = [];
        _filteredContacts = [];
      });
      debugPrint("Error in _loadAndCompareContacts (Restore): $e");
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _allBackupContacts;
      } else {
        _filteredContacts =
            _allBackupContacts.where((contact) {
              final name =
                  '${contact.firstName} ${contact.lastName}'.toLowerCase();
              final phones = contact.phones.join(' ').toLowerCase();
              final emails = contact.emails.join(' ').toLowerCase();
              return name.contains(query) ||
                  phones.contains(query) ||
                  emails.contains(query);
            }).toList();
      }
      _updateSelectAllState();
    });
  }

  void _updateSelectAllState() {
    final selectableContacts =
        _filteredContacts
            .where((c) => c.restoreStatus == RestoreStatus.manquant)
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
        (c) => c.restoreStatus == RestoreStatus.manquant,
      );

      if (_isAllSelectableSelected) {
        for (var contact in selectableContacts) {
          _selected.add(contact.id);
        }
      } else {
        for (var contact in selectableContacts) {
          _selected.remove(contact.id);
        }
      }
    });
  }

  void _onRestore() async {
    final selectedContacts =
        _allBackupContacts // Use full list to find by ID
            .where((c) => _selected.contains(c.id))
            .toList();

    // Filter again to ensure only 'Manquant' are restored
    final contactsToRestore =
        selectedContacts
            .where((c) => c.restoreStatus == RestoreStatus.manquant)
            .toList();

    if (contactsToRestore.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select contacts missing from device to restore',
          ),
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
            title: const Text('Restoring Contacts'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Restoring ${contactsToRestore.length} contacts...'),
              ],
            ),
          ),
    );

    try {
      await _controller.restoreSelected(contactsToRestore);
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully restored ${contactsToRestore.length} contacts',
            ),
          ),
        );
        // Reload contacts after restore to update status
        _loadAndCompareContacts();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: ${e.toString()}')),
        );
      }
      debugPrint("Error during _onRestore: $e");
    }
  }

  Widget _buildStatusIndicator(RestoreStatus status) {
    IconData icon;
    Color color;
    String text;
    switch (status) {
      case RestoreStatus.manquant:
        icon = Icons.file_download_outlined;
        color = Colors.blue;
        text = 'Missing'; // Missing on device
        break;
      case RestoreStatus.present:
        icon = Icons.check_circle_outline;
        color = Colors.green;
        text = 'On Device';
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        text = 'Unknown';
    }
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
      (c) => c.restoreStatus == RestoreStatus.manquant,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore Contacts'),
        actions: [
          if (!_loading && _allBackupContacts.isNotEmpty && canSelectAny)
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
                labelText: 'Search Backup Contacts',
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
        onPressed: _selected.isEmpty ? null : _onRestore,
        label: Text('Restore (${_selected.length})'),
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

    if (_allBackupContacts.isEmpty) {
      return const Center(child: Text('No contacts found in backup.'));
    }

    if (_filteredContacts.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Text(
          'No backup contacts found matching "${_searchController.text}"',
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredContacts.length,
      itemBuilder: (_, i) {
        final c = _filteredContacts[i];
        final isSelectable = c.restoreStatus == RestoreStatus.manquant;
        final displayName =
            ('${c.firstName} ${c.lastName}'.trim().isEmpty)
                ? '(No Name)'
                : '${c.firstName} ${c.lastName}'.trim();
        final displayPhones =
            c.phones.isNotEmpty ? c.phones.join(', ') : '(No Phones)';

        return CheckboxListTile(
          secondary: _buildStatusIndicator(c.restoreStatus),
          title: Text(displayName),
          subtitle: Text(
            displayPhones,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          value: _selected.contains(c.id),
          onChanged:
              isSelectable
                  ? (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(c.id);
                      } else {
                        _selected.remove(c.id);
                      }
                      _updateSelectAllState();
                    });
                  }
                  : null, // Disable checkbox if contact is present on device
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Theme.of(context).primaryColor,
          tileColor: isSelectable ? null : Colors.grey.withOpacity(0.1),
        );
      },
    );
  }
}
