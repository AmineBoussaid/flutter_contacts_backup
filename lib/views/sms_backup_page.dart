import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controllers/sms_controller.dart';
import '../models/sms_model.dart';
// For debugPrint
import 'package:collection/collection.dart'; // For groupBy

class SmsBackupPage extends StatefulWidget {
  const SmsBackupPage({super.key});
  @override
  _SmsBackupPageState createState() => _SmsBackupPageState();
}

class _SmsBackupPageState extends State<SmsBackupPage> {
  // Ensure the controller used here is the one handling List/Map correctly
  final SmsController _smsCtrl = SmsController();
  final user = FirebaseAuth.instance.currentUser!;
  List<SmsModel> _smsListToDisplay =
      []; // Holds the differential list for backup
  Map<String, List<SmsModel>> _groupedSms =
      {}; // Optional: Grouping for display
  final _selected = <String>{}; // Set of selected message IDs
  bool _isAllSelected = false; // State for Select All checkbox
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDifferentialSmsForBackup();
  }

  Future<void> _loadDifferentialSmsForBackup() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
        _selected.clear();
        _isAllSelected = false;
      });

      // 1. Fetch device SMS
      final deviceSms = await _smsCtrl.getDeviceSms();
      if (!mounted) return;
      debugPrint("Fetched ${deviceSms.length} SMS from device.");

      // 2. Fetch backup SMS from Firebase
      List<SmsModel> backupSms = [];
      try {
        backupSms = await _smsCtrl.getBackupSms(user.email!);
        if (!mounted) return;
        debugPrint("Fetched ${backupSms.length} SMS from Firebase backup.");
      } catch (e) {
        debugPrint("Error fetching backup SMS for diff: $e");
        // Decide how to handle - here we proceed showing all device SMS if backup fails
      }

      // 3. Perform differential logic: Find device SMS not present in backup
      // Using message ID as the unique identifier.
      final backupSmsIds = backupSms.map((sms) => sms.id).toSet();
      final diffSms =
          deviceSms.where((sms) => !backupSmsIds.contains(sms.id)).toList();

      debugPrint(
        "Differential SMS to backup (not in backup): ${diffSms.length}",
      );

      // 4. Optional: Group the differential list for display (like restore page)
      final grouped = groupBy(diffSms, (SmsModel sms) => sms.address);
      grouped.forEach((key, value) {
        value.sort(
          (a, b) => a.date.compareTo(b.date),
        ); // Sort by date within group
      });
      final sortedGrouped = Map.fromEntries(
        grouped.entries.toList()
          ..sort((e1, e2) => e1.key.compareTo(e2.key)), // Sort contacts
      );

      setState(() {
        _smsListToDisplay = diffSms; // Store differential list
        _groupedSms = sortedGrouped; // Store grouped map for display
        _loading = false;
        _error = null;
        _isAllSelected =
            _smsListToDisplay.isNotEmpty &&
            _selected.length == _smsListToDisplay.length;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load and compare SMS: ${e.toString()}';
        _smsListToDisplay = [];
        _groupedSms = {};
      });
    }
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _isAllSelected = value ?? false;
      _selected.clear();
      if (_isAllSelected) {
        for (var sms in _smsListToDisplay) {
          _selected.add(sms.id);
        }
      }
    });
  }

  void _onBackup() async {
    final toPush =
        _smsListToDisplay.where((m) => _selected.contains(m.id)).toList();

    if (toPush.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select messages to backup')),
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
                Text('Backing up ${toPush.length} SMS messages...'),
              ],
            ),
          ),
    );

    try {
      await _smsCtrl.backupSelected(user.email!, toPush);
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully backed up ${toPush.length} SMS'),
          ),
        );
        // Reload the differential list after backup
        _loadDifferentialSmsForBackup();
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
        title: const Text('Backup SMS'),
        actions: [
          if (!_loading && _smsListToDisplay.isNotEmpty)
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
            onPressed: _loadDifferentialSmsForBackup,
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
                onPressed: _loadDifferentialSmsForBackup,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_groupedSms.isEmpty) {
      return const Center(child: Text('No new SMS found on device to backup'));
    }

    // Display grouped SMS similar to the restore page
    final contacts = _groupedSms.keys.toList();
    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (_, contactIndex) {
        final contactAddress = contacts[contactIndex];
        final messagesForContact = _groupedSms[contactAddress]!;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExpansionTile(
            key: PageStorageKey(contactAddress), // Preserve state
            title: Text('$contactAddress (${messagesForContact.length} SMS)'),
            subtitle: Text(
              messagesForContact.first.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            childrenPadding: const EdgeInsets.only(left: 16.0, right: 8.0),
            children:
                messagesForContact.map((message) {
                  return CheckboxListTile(
                    title: Text(
                      message.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      DateTime.fromMillisecondsSinceEpoch(
                        message.date,
                      ).toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    value: _selected.contains(message.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selected.add(message.id);
                        } else {
                          _selected.remove(message.id);
                        }
                        _isAllSelected =
                            _smsListToDisplay.isNotEmpty &&
                            _selected.length == _smsListToDisplay.length;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }).toList(),
          ),
        );
      },
    );
  }
}
