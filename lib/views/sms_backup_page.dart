import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controllers/sms_controller.dart';
import '../models/sms_model.dart';
import 'package:collection/collection.dart'; 
import 'package:flutter/foundation.dart'; // For debugPrint

class SmsBackupPage extends StatefulWidget {
  const SmsBackupPage({super.key});
  @override
  _SmsBackupPageState createState() => _SmsBackupPageState();
}

class _SmsBackupPageState extends State<SmsBackupPage> {
  final SmsController _smsCtrl = SmsController();
  final user = FirebaseAuth.instance.currentUser!;

  List<SmsModel> _allDeviceSms = []; // Holds all SMS from device with status
  Map<String, List<SmsModel>> _groupedSmsToDisplay =
      {}; // Holds grouped SMS for display after filtering
  final Map<String, SmsModel> _backupSmsMap =
      {}; // Holds backup SMS for quick lookup

  final _selected = <String>{}; // Set of selected message IDs (only 'Nouveau')
  bool _isAllSelectableSelected =
      false; // State for Select All (only 'Nouveau')
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _currentSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAndCompareSms();
    _searchController.addListener(() {
      if (_currentSearchQuery != _searchController.text) {
        _currentSearchQuery = _searchController.text;
        _filterAndGroupSms();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAndCompareSms() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
        _selected.clear();
        _isAllSelectableSelected = false;
      });

      // 1. Fetch device SMS
      final deviceSms = await _smsCtrl.getDeviceSms();
      if (!mounted) return;
      debugPrint("Fetched ${deviceSms.length} SMS from device.");

      // 2. Fetch backup SMS from Firebase
      final backupSms = await _smsCtrl.getBackupSms(user.email!);
      if (!mounted) return;
      debugPrint("Fetched ${backupSms.length} SMS from Firebase backup.");

      // Create map for quick lookup
      _backupSmsMap.clear();
      for (var sms in backupSms) {
        _backupSmsMap[sms.id] = sms;
      }

      // 3. Compare and determine status for each device SMS
      for (var deviceSmsItem in deviceSms) {
        if (_backupSmsMap.containsKey(deviceSmsItem.id)) {
          deviceSmsItem.backupStatus = BackupStatus.synchronise;
        } else {
          deviceSmsItem.backupStatus = BackupStatus.nouveau;
        }
      }

      // 4. Resolve contact names (can take time, consider doing it lazily or showing progress)
      final resolvedDeviceSms = await _smsCtrl.resolveContactNames(deviceSms);
      if (!mounted) return;

      // Store all resolved device SMS
      _allDeviceSms = resolvedDeviceSms;

      // Initial filter and group
      _filterAndGroupSms();

      setState(() {
        _loading = false;
        _error = null;
        _updateSelectAllState();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load and compare SMS: ${e.toString()}';
        _allDeviceSms = [];
        _groupedSmsToDisplay = {};
      });
      debugPrint("Error in _loadAndCompareSms: $e");
    }
  }

  void _filterAndGroupSms() {
    final query = _searchController.text.toLowerCase();
    List<SmsModel> filteredSms;

    if (query.isEmpty) {
      filteredSms = _allDeviceSms;
    } else {
      filteredSms =
          _allDeviceSms.where((sms) {
            final contactIdentifier =
                (sms.contactName ?? sms.address).toLowerCase();
            final body = sms.body.toLowerCase();
            return contactIdentifier.contains(query) || body.contains(query);
          }).toList();
    }

    // Group the filtered list by contact name or address
    final grouped = groupBy(
      filteredSms,
      (SmsModel sms) => sms.contactName ?? sms.address,
    );

    // Sort messages within each group by date (descending for recent first)
    grouped.forEach((key, value) {
      value.sort((a, b) => b.date.compareTo(a.date));
    });

    // Sort contacts (groups) alphabetically
    final sortedGrouped = Map.fromEntries(
      grouped.entries.toList()..sort(
        (e1, e2) => e1.key.toLowerCase().compareTo(e2.key.toLowerCase()),
      ),
    );

    setState(() {
      _groupedSmsToDisplay = sortedGrouped;
      _updateSelectAllState();
    });
  }

  void _updateSelectAllState() {
    // Consider only the currently displayed (filtered) SMS
    final selectableSms =
        _groupedSmsToDisplay.values
            .expand((list) => list)
            .where((sms) => sms.backupStatus == BackupStatus.nouveau)
            .toList();

    if (selectableSms.isEmpty) {
      _isAllSelectableSelected = false;
    } else {
      _isAllSelectableSelected = selectableSms.every(
        (sms) => _selected.contains(sms.id),
      );
    }
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _isAllSelectableSelected = value ?? false;
      // Select/deselect only the *visible* and *selectable* items
      final selectableVisibleSms = _groupedSmsToDisplay.values
          .expand((list) => list)
          .where((sms) => sms.backupStatus == BackupStatus.nouveau);

      if (_isAllSelectableSelected) {
        for (var sms in selectableVisibleSms) {
          _selected.add(sms.id);
        }
      } else {
        for (var sms in selectableVisibleSms) {
          _selected.remove(sms.id);
        }
      }
    });
  }

  void _onBackup() async {
    // Get IDs from the selection set
    final selectedIds = _selected.toList();

    // Find the corresponding SmsModel objects from the full list
    final smsToBackup =
        _allDeviceSms
            .where(
              (sms) =>
                  selectedIds.contains(sms.id) &&
                  sms.backupStatus == BackupStatus.nouveau,
            )
            .toList();

    if (smsToBackup.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select new messages to backup')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Backing Up SMS'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Backing up ${smsToBackup.length} SMS messages...'),
              ],
            ),
          ),
    );

    try {
      await _smsCtrl.backupSelected(user.email!, smsToBackup);
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully backed up ${smsToBackup.length} SMS'),
          ),
        );
        // Reload list to update status
        _loadAndCompareSms();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: ${e.toString()}')),
        );
      }
      debugPrint("Error during _onBackup (SMS): $e");
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
    return Tooltip(message: text, child: Icon(icon, color: color, size: 18));
  }

  @override
  Widget build(BuildContext context) {
    final bool canSelectAny = _groupedSmsToDisplay.values
        .expand((list) => list)
        .any((sms) => sms.backupStatus == BackupStatus.nouveau);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup SMS'),
        actions: [
          if (!_loading && _allDeviceSms.isNotEmpty && canSelectAny)
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
            tooltip: 'Refresh SMS List',
            onPressed: _loadAndCompareSms,
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
                labelText: 'Search SMS',
                hintText: 'Search by contact or content...',
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
                onPressed: _loadAndCompareSms,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_allDeviceSms.isEmpty) {
      return const Center(child: Text('No SMS found on device.'));
    }

    if (_groupedSmsToDisplay.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Text('No SMS found matching "${_searchController.text}"'),
      );
    }

    if (_groupedSmsToDisplay.isEmpty) {
      return const Center(
        child: Text('All device SMS are already backed up.'),
        // Or show all SMS but greyed out? Based on requirements.
      );
    }

    // Display grouped SMS
    final contacts = _groupedSmsToDisplay.keys.toList();
    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (_, contactIndex) {
        final contactIdentifier = contacts[contactIndex];
        final messagesForContact = _groupedSmsToDisplay[contactIdentifier]!;
        final firstMessage = messagesForContact.first;
        final titleText =
            firstMessage.contactName != null
                ? '${firstMessage.contactName} (${firstMessage.address})'
                : firstMessage.address;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExpansionTile(
            key: PageStorageKey(contactIdentifier), // Preserve state
            title: Text('$titleText (${messagesForContact.length} SMS)'),
            subtitle: Text(
              firstMessage.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            childrenPadding: const EdgeInsets.only(
              left: 0,
              right: 8.0,
              bottom: 8.0,
            ),
            children:
                messagesForContact.map((message) {
                  final isSelectable =
                      message.backupStatus == BackupStatus.nouveau;
                  return CheckboxListTile(
                    secondary: _buildStatusIndicator(message.backupStatus),
                    title: Text(
                      message.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      DateTime.fromMillisecondsSinceEpoch(
                        message.date,
                      ).toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    value: _selected.contains(message.id),
                    onChanged:
                        isSelectable
                            ? (value) {
                              setState(() {
                                if (value == true) {
                                  _selected.add(message.id);
                                } else {
                                  _selected.remove(message.id);
                                }
                                _updateSelectAllState();
                              });
                            }
                            : null,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Theme.of(context).primaryColor,
                    tileColor:
                        isSelectable ? null : Colors.grey.withOpacity(0.1),
                  );
                }).toList(),
          ),
        );
      },
    );
  }
}
