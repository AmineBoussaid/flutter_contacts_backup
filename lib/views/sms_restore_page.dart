import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart'; // Import for groupBy
import '../controllers/sms_controller.dart';
import '../models/sms_model.dart';
// For debugPrint

class SmsRestorePage extends StatefulWidget {
  const SmsRestorePage({super.key});

  @override
  _SmsRestorePageState createState() => _SmsRestorePageState();
}

class _SmsRestorePageState extends State<SmsRestorePage> {
  // Use the corrected controller (assuming it's renamed or replaced)
  // Ensure the controller used here is the one handling List/Map correctly
  final SmsController _smsCtrl = SmsController();
  final user = FirebaseAuth.instance.currentUser!;
  List<SmsModel> _smsList = []; // Holds the *differential* list to display
  Map<String, List<SmsModel>> _groupedSms =
      {}; // Map for grouped differential messages
  final _selected = <String>{}; // Set of selected message IDs
  bool _isAllSelected = false; // State for Select All checkbox
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDifferentialBackup();
  }

  // Renamed function to reflect differential logic
  Future<void> _loadDifferentialBackup() async {
    try {
      setState(() {
        _loading = true;
        _error = null; // Clear previous errors
        _selected.clear(); // Clear selection on reload
        _isAllSelected = false;
      });

      // 1. Fetch backup SMS from Firebase
      final backupSms = await _smsCtrl.getBackupSms(user.email!);
      if (!mounted) return; // Check if widget is still mounted
      debugPrint("Fetched ${backupSms.length} SMS from Firebase backup.");

      // 2. Fetch device SMS
      List<SmsModel> deviceSms = [];
      try {
        deviceSms = await _smsCtrl.getDeviceSms();
        if (!mounted) return;
        debugPrint("Fetched ${deviceSms.length} SMS from device.");
      } catch (e) {
        debugPrint("Error fetching device SMS for diff: $e");
        // Option 1: Show error and stop
        setState(() {
          _loading = false;
          _error = 'Failed to load device SMS for comparison: ${e.toString()}';
          _groupedSms = {};
        });
        return;
        // Option 2: Proceed without differential (show all backup SMS)
        // diffSms = backupSms;
      }

      // 3. Perform differential logic: Find backup SMS not present on device
      // Using message ID as the unique identifier. Ensure IDs are consistent!
      final deviceSmsIds = deviceSms.map((sms) => sms.id).toSet();
      final diffSms =
          backupSms.where((sms) => !deviceSmsIds.contains(sms.id)).toList();

      debugPrint(
        "Differential SMS to restore (not on device): ${diffSms.length}",
      );

      // 4. Group the differential list by address
      final grouped = groupBy(diffSms, (SmsModel sms) => sms.address);

      // Sort messages within each group by date (ascending)
      grouped.forEach((key, value) {
        value.sort((a, b) => a.date.compareTo(b.date));
      });

      // Sort contacts (addresses) alphabetically for consistent order
      final sortedGrouped = Map.fromEntries(
        grouped.entries.toList()..sort((e1, e2) => e1.key.compareTo(e2.key)),
      );

      setState(() {
        _smsList = diffSms; // Store differential list
        _groupedSms = sortedGrouped; // Store grouped and sorted map
        _loading = false;
        _error = null;
        // Initial check for 'Select All' state (might be empty list)
        _isAllSelected =
            _smsList.isNotEmpty && _selected.length == _smsList.length;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load and compare backups: ${e.toString()}';
        _groupedSms = {}; // Clear groups on error
      });
    }
  }

  // Toggle selection for all items currently displayed in the differential list
  void _toggleSelectAll(bool? value) {
    setState(() {
      _isAllSelected = value ?? false;
      _selected.clear();
      if (_isAllSelected) {
        // Add all displayed message IDs to selected set
        for (var sms in _smsList) {
          _selected.add(sms.id);
        }
      }
    });
  }

  // Restore function remains largely the same, but operates on the selected IDs
  // which now come from the differential list.
  Future<void> _restoreMessages() async {
    // Filter the original differential list based on selected IDs
    final toRestore = _smsList.where((m) => _selected.contains(m.id)).toList();

    if (toRestore.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select messages to restore')),
      );
      return;
    }

    // Show confirmation dialog explaining the re-send limitation
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Restore Messages (Re-send)'), // Clarify action
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Note: This will attempt to re-send selected messages via your SMS app. It does not directly insert them into your phone\\s history due to platform limitations.', // Explain limitation
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Attempting to re-send ${toRestore.length} messages...',
                ), // Clarify action
              ],
            ),
          ),
    );

    try {
      // Call the controller method (which should also be clarified)
      await _smsCtrl.restoreSelected(toRestore);
      if (mounted) {
        Navigator.pop(context); // Close the progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully initiated re-send for ${toRestore.length} messages',
            ), // Clarify result
          ),
        );
        // Optionally reload the list after restore attempt to reflect changes
        // _loadDifferentialBackup();
        setState(() => _selected.clear()); // Clear selection after attempt
        _isAllSelected = false; // Reset select all
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close the progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Re-send failed: ${e.toString()}'),
          ), // Clarify error
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore SMS'), // Update title
        actions: [
          // Select All Checkbox
          if (!_loading && _smsList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 0,
              ), // Reduced padding
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("All", style: Theme.of(context).textTheme.bodyMedium),
                  Checkbox(
                    value: _isAllSelected,
                    onChanged: _toggleSelectAll,
                    visualDensity:
                        VisualDensity.compact, // Make checkbox smaller
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap, // Reduce tap area
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
        onPressed:
            _selected.isEmpty
                ? null
                : _restoreMessages, // Disable if nothing selected
        label: const Text('Restore Selected'),
        icon: const Icon(Icons.cloud_download),
        backgroundColor:
            _selected.isEmpty
                ? Colors.grey
                : Theme.of(
                  context,
                ).colorScheme.primary, // Visual cue for disabled state
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

    if (_groupedSms.isEmpty) {
      return const Center(
        child: Text('No new messages found in backup to restore'),
      );
    }

    // Get the list of contacts (addresses) from the grouped map keys
    final contacts = _groupedSms.keys.toList();

    // Build the list view with ExpansionTiles for each contact
    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (_, contactIndex) {
        final contactAddress = contacts[contactIndex];
        final messagesForContact = _groupedSms[contactAddress]!;
        // Use ExpansionTile for grouping
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExpansionTile(
            key: PageStorageKey(contactAddress), // Preserve expansion state
            title: Text('$contactAddress (${messagesForContact.length} SMS)'),
            subtitle: Text(
              messagesForContact
                  .first
                  .body, // Show first message body as preview
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            childrenPadding: const EdgeInsets.only(
              left: 16.0,
              right: 8.0,
            ), // Indent messages
            children:
                messagesForContact.map((message) {
                  // Use CheckboxListTile for each message
                  return CheckboxListTile(
                    title: Text(
                      message.body,
                      maxLines: 3, // Allow slightly more lines for body
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      DateTime.fromMillisecondsSinceEpoch(
                        message.date,
                      ).toString(),
                      style:
                          Theme.of(
                            context,
                          ).textTheme.bodySmall, // Use theme style
                    ),
                    value: _selected.contains(message.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selected.add(message.id);
                        } else {
                          _selected.remove(message.id);
                        }
                        // Update _isAllSelected status after individual change
                        _isAllSelected =
                            _smsList.isNotEmpty &&
                            _selected.length == _smsList.length;
                      });
                    },
                    controlAffinity:
                        ListTileControlAffinity.leading, // Checkbox first
                  );
                }).toList(),
          ),
        );
      },
    );
  }
}
