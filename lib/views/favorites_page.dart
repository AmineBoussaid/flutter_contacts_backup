import 'package:flutter/material.dart';
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
  List<FavoriteModel> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initializeFavorites();
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
    final favs = await _favoriteController.getFavorites();
    setState(() {
      _favorites = favs;
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
              : _favorites.isEmpty
              ? const Center(child: Text('Aucun favori trouvé.'))
              : ListView.builder(
                itemCount: _favorites.length,
                itemBuilder: (context, index) {
                  final fav = _favorites[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ListTile(
                      title: Text('Contact: ${fav.contactId}'),
                      subtitle: Text(
                        'Appels: ${fav.callCount}, SMS: ${fav.smsCount}',
                      ),
                      trailing: Text(
                        '${fav.lastUpdated.toLocal()}'.split(' ')[0],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
