import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/favorite_controller.dart';
import '../models/favorite_model.dart';
import 'package:permission_handler/permission_handler.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final FavoriteController _favoriteController = FavoriteController();
  bool _loading = true;
  List<FavoriteModel> _autoFavorites = [];
  List<FavoriteModel> _manualFavorites = [];

  @override
  void initState() {
    super.initState();
    _initialize(); // Ne pas mettre de await ici
  }

  void _initialize() async {
    await _favoriteController.generateFavoritesAutoOncePerDay();
    await _initializeFavorites();
  }

  Future<bool> requestPermissions() async {
    final smsStatus = await Permission.sms.request();
    final callLogStatus = await Permission.phone.request();

    return smsStatus.isGranted && callLogStatus.isGranted;
  }

  Future<void> _initializeFavorites() async {
    bool granted = await requestPermissions();
    if (!granted) {
      setState(() {
        _loading = false;
      });
      return;
    }

    await _favoriteController.generateFavoritesAuto();

    final autoFavs = await _favoriteController.getFavorites(manuelle: false);
    final manualFavs = await _favoriteController.getFavorites(manuelle: true);

    setState(() {
      _autoFavorites = autoFavs;
      _manualFavorites = manualFavs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoris'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeFavorites,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Favoris Automatiques',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ..._autoFavorites.map(_buildFavoriteTile),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Favoris Manuels',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ..._manualFavorites.map(_buildFavoriteTile),
                ],
              ),
    );
  }

  Widget _buildFavoriteTile(FavoriteModel fav) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(fav.name.isNotEmpty ? fav.name : fav.contactId),

        subtitle: Text('Appels: ${fav.callCount}, SMS: ${fav.smsCount}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            final number = fav.number;
            if (value == 'call') {
              await launchUrl(Uri.parse("tel:$number"));
            } else if (value == 'sms') {
              await launchUrl(Uri.parse("sms:$number"));
            } else if (value == 'delete') {
              await _favoriteController.removeFavorite(fav.contactId);
              await _initializeFavorites(); // pour rafraîchir la liste
            }
          },
          itemBuilder: (context) {
            final items = [
              const PopupMenuItem(value: 'call', child: Text('Appeler')),
              const PopupMenuItem(value: 'sms', child: Text('Envoyer SMS')),
            ];

            if (fav.manuelle) {
              items.add(
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Supprimer le favori'),
                ),
              );
            }

            return items;
          },
        ),
      ),
    );
  }
}
