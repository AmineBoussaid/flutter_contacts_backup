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
            smsCount INTEGER,
            callCount INTEGER,
            lastUpdated TEXT
          )
        ''');
      },
    );
  }

  // Exemple d'insertion ou mise à jour
  Future<void> insertOrUpdateFavorite(FavoriteModel fav) async {
    final db = await database;
    await db.insert(
      'favorites',
      fav.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
}
