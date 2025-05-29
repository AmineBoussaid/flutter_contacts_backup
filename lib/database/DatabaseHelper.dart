import 'package:contacts_app/models/favorite_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    // Initialiser la DB si elle n'existe pas encore
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'favorites.db');

    // Ouvre ou crée la base de données
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
  CREATE TABLE favorites (
    contactId TEXT PRIMARY KEY,
    name TEXT,
    number TEXT,
    smsCount INTEGER,
    callCount INTEGER,
    lastUpdated INTEGER,
    manuelle INTEGER
  )
''');
      },
    );
  }

  Future<DateTime?> getLastAutoUpdateTime() async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT MAX(lastUpdated) as lastAutoUpdate FROM favorites WHERE manuelle = 0
  ''');
    if (result.isNotEmpty && result.first['lastAutoUpdate'] != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        result.first['lastAutoUpdate'] as int,
      );
    }
    return null;
  }

  // Exemple d'insertion ou mise à jour
  Future<void> insertOrUpdateFavorite(FavoriteModel fav) async {
    final db = await database;

    // Cherche si le favori existe déjà
    final existing = await db.query(
      'favorites',
      where: 'contactId = ?',
      whereArgs: [fav.contactId],
    );

    if (existing.isNotEmpty) {
      final current = FavoriteModel.fromMap(existing.first);

      // Compare l'existant avec le nouveau
      if (!current.isSameAs(fav)) {
        await db.delete(
          'favorites',
          where: 'contactId = ?',
          whereArgs: [fav.contactId],
        );
        await db.insert('favorites', fav.toMap());
      }
      // Sinon, ne rien faire (identique)
    } else {
      // Nouveau favori
      await db.insert('favorites', fav.toMap());
    }
  }

  // Récupérer tous les favoris
  Future<List<FavoriteModel>> getAllFavorites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('favorites');

    return List.generate(maps.length, (i) {
      return FavoriteModel.fromMap(maps[i]);
    });
  }

  // Supprimer un favori
  Future<void> deleteFavorite(String contactId) async {
    final db = await database;
    await db.delete(
      'favorites',
      where: 'contactId = ?',
      whereArgs: [contactId],
    );
  }

  Future<void> debugPrintFavorites() async {
    final db = await database;
    final result = await db.query('favorites');

    print('--- FICHES FAVORIS DANS LA BD ---');
    for (final row in result) {
      print(row);
    }
  }
}
