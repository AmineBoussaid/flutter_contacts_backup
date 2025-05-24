import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controllers/sms_controller.dart';
import '../models/sms_model.dart';

class SmsBackupPage extends StatefulWidget {
  const SmsBackupPage({super.key});
  @override
  _SmsBackupPageState createState() => _SmsBackupPageState();
}

class _SmsBackupPageState extends State<SmsBackupPage> {
  final SmsController _smsCtrl = SmsController();
  final user = FirebaseAuth.instance.currentUser!;
  List<SmsModel> _smsList = [];
  final _selected = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSms();
  }

  Future<void> _loadSms() async {
    final list = await _smsCtrl.getDeviceSms();
    setState(() {
      _smsList = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup SMS')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: _smsList.map((m) {
              final isSel = _selected.contains(m.id);
              return CheckboxListTile(
                title: Text(m.address),
                subtitle: Text(
                  '${DateTime.fromMillisecondsSinceEpoch(m.date)}\n${m.body}',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                value: isSel,
                onChanged: (_) => setState(() {
                  isSel ? _selected.remove(m.id) : _selected.add(m.id);
                }),
              );
            }).toList(),
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final toPush = _smsList.where((m) => _selected.contains(m.id)).toList();
          await _smsCtrl.backupSelected(user.email!, toPush);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Backed up ${toPush.length} SMS'))
            );
            Navigator.pop(context);
          }
        },
        label: const Text('Backup Selected'),
        icon: const Icon(Icons.cloud_upload),
      ),
    );
  }
}
