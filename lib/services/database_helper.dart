// Work on database schema!!! how is everything related??
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:thru_hike_tracker/models/data_entry.dart';

class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  // Factory constructor to return the singleton instance
  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  // Database instance
  static Database? _database;

  static const int _version = 1;
  static const String _dbName = "data_entry.db";

  static Future<Database> _getDB() async {
    if (_database != null) return _database!;
    _database = await openDatabase(
      join(await getDatabasesPath(), _dbName),
      onCreate: (db, version) async {

        // Full data entry table
        await db.execute(
            "CREATE TABLE FullDataEntry(id INTEGER PRIMARY KEY, current_date TEXT, start REAL, end REAL, trailName TEXT)"
        );
        // Create TrailJournal table
        await db.execute(
            "CREATE TABLE TrailJournal(id INTEGER PRIMARY KEY, trailName TEXT, startDate TEXT, direction TEXT, trailType TEXT, length REAL)"
        );
      },
      version: _version,
    );
    return _database!;
  }

  static Future<int> addDataEntry(FullDataEntry entry) async {
    final db = await _getDB();
    return await db.insert("FullDataEntry", entry.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<int> updateDataEntry(FullDataEntry entry) async {
    final db = await _getDB();
    return await db.update("FullDataEntry", entry.toJson(),
        where: "id = ?",
        whereArgs: [entry.id],
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<int> deleteDataEntry(FullDataEntry entry) async {
    final db = await _getDB();
    return await db.delete("FullDataEntry",
        where: "id = ?",
        whereArgs: [entry.id],
    );
  }
  
  static Future<List<FullDataEntry>?> getAllDataEntries() async {
    final db = await _getDB();
    final List<Map<String, dynamic>> maps = await db.query("FullDataEntry");
    if(maps.isEmpty) { // ChatGPT says I can return an empty list instead of null
      return null;
    }
    return List.generate(maps.length, (index) => FullDataEntry.fromJson(maps[index]));
  }

  Future<void> close() async {
    final db = await _getDB();
    db.close();
  }
}
