import 'package:flutter/material.dart';
import 'package:collection/collection.dart'; // pour groupBy
import '../controllers/sms_controller.dart';
import '../models/sms_model.dart';

// Importer tes pages existantes de restore et backup
import 'sms_backup_page.dart';
import 'sms_restore_page.dart';

class SmsPage extends StatefulWidget {
  const SmsPage({super.key});

  @override
  _SmsListPageState createState() => _SmsListPageState();
}

class _SmsListPageState extends State<SmsPage> {
  final SmsController _smsCtrl = SmsController();
  bool _loading = true;
  String? _error;
  Map<String, List<SmsModel>> _groupedSms = {};

  @override
  void initState() {
    super.initState();
    _loadSms();
  }

  Future<void> _loadSms() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final deviceSms = await _smsCtrl.getDeviceSms();
      final grouped = groupBy(deviceSms, (SmsModel sms) => sms.address);
      grouped.forEach((key, value) {
        value.sort((a, b) => b.date.compareTo(a.date)); // SMS récents en haut
      });
      final sortedGrouped = Map.fromEntries(
        grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );

      setState(() {
        _groupedSms = sortedGrouped;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur chargement SMS: ${e.toString()}';
        _loading = false;
      });
    }
  }

  void _onSelectedMenu(String choice) {
    switch (choice) {
      case 'backup':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SmsBackupPage()),
        );
        break;
      case 'restore':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SmsRestorePage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes SMS'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _onSelectedMenu,
            itemBuilder:
                (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'backup',
                    child: Text('Sauvegarder les SMS'),
                  ),
                  const PopupMenuItem(
                    value: 'restore',
                    child: Text('Restaurer les SMS'),
                  ),
                ],
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
              : _groupedSms.isEmpty
              ? const Center(child: Text('Aucun SMS trouvé'))
              : ListView.builder(
                itemCount: _groupedSms.length,
                itemBuilder: (context, index) {
                  final contact = _groupedSms.keys.elementAt(index);
                  final messages = _groupedSms[contact]!;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ExpansionTile(
                      title: Text('$contact (${messages.length} SMS)'),
                      subtitle: Text(
                        messages.first.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      childrenPadding: const EdgeInsets.only(
                        left: 16,
                        right: 8,
                      ),
                      children:
                          messages.map((sms) {
                            return ListTile(
                              title: Text(
                                sms.body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                DateTime.fromMillisecondsSinceEpoch(
                                  sms.date,
                                ).toString(),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            );
                          }).toList(),
                    ),
                  );
                },
              ),
    );
  }
}
