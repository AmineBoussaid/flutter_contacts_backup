import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controllers/sms_controller.dart';
import '../models/sms_model.dart';

class SmsRestorePage extends StatefulWidget {
  const SmsRestorePage({super.key});

  @override
  _SmsRestorePageState createState() => _SmsRestorePageState();
}

class _SmsRestorePageState extends State<SmsRestorePage> {
  final SmsController _smsCtrl = SmsController();
  final user = FirebaseAuth.instance.currentUser!;
  List<SmsModel> _smsList = [];
  final _selected = <String>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBackup();
  }

  Future<void> _loadBackup() async {
    try {
      setState(() => _loading = true);
      final list = await _smsCtrl.getBackupSms(user.email!);
      setState(() {
        _smsList = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load backup: ${e.toString()}';
      });
    }
  }

  Future<void> _restoreMessages() async {
    final toRestore = _smsList.where((m) => _selected.contains(m.id)).toList();

    if (toRestore.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select messages to restore')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Restoring Messages'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Restoring ${toRestore.length} messages...'),
              ],
            ),
          ),
    );

    try {
      await _smsCtrl.restoreSelected(toRestore);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully restored ${toRestore.length} messages'),
          ),
        );
        setState(() => _selected.clear());
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
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
        title: const Text('Restore SMS'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBackup),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _restoreMessages,
        label: const Text('Restore Selected'),
        icon: const Icon(Icons.cloud_download),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadBackup, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_smsList.isEmpty) {
      return const Center(child: Text('No backup messages found'));
    }

    return ListView.builder(
      itemCount: _smsList.length,
      itemBuilder: (_, index) {
        final message = _smsList[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: CheckboxListTile(
            title: Text(message.address),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  DateTime.fromMillisecondsSinceEpoch(message.date).toString(),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            value: _selected.contains(message.id),
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selected.add(message.id);
                } else {
                  _selected.remove(message.id);
                }
              });
            },
          ),
        );
      },
    );
  }
}
