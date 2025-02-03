// Work on database schema!!! how is everything related??
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:thru_hike_tracker/models/data_entry.dart';
//import 'package:thru_hike_tracker/models/trail_journal.dart';
//import 'package:thru_hike_tracker/models/trail_metadata.dart';

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
        await db.execute('''
          CREATE TABLE FullDataEntry(
            id INTEGER PRIMARY KEY, 
            trail_journal_id INTEGER,  -- Foreign key linking to TrailJournal
            current_date TEXT, 
            start REAL, 
            startLocation TEXT, -- Optional, can be null
            end REAL, 
            endLocation TEXT, -- Optional, can be null
            trailDistance REAL,
            distanceAdded REAL, -- Optional, can be null
            distanceSkipped REAL, -- Optional, can be null
            netDistance REAL,
            trailName TEXT),
            campType TEXT, -- Optional, can be null
            elevationGain REAL, -- Optional, can be null
            elevationLoss REAL, -- Optional, can be null
            netElevation REAL, -- Optional, can be null
            shoes TEXT, -- Optional, can be null
            wildlife TEXT, -- Optional, Separate column for wildlife tracking as JSON
            customFields TEXT,  -- Optional, Stores user-defined fields as JSON
            FOREIGN KEY (trail_journal_id) REFERENCES TrailJournal(id) ON DELETE CASCADE
          )
        ''');

        // Alternate Route table - can have one or more per data entry. A single alternate route can span multiple data entries
        await db.execute('''
          CREATE TABLE AlternateRoutes ( -- One data entry = one row
            id INTEGER PRIMARY KEY,
            full_data_entry_id INTEGER,  -- Foreign key linking to FullDataEntry
            routeName TEXT,  -- Name of the alternate route (e.g., Kearsarge Pass)
            distanceAdded REAL,  -- Length of the route
            distanceSkipped REAL,  -- Length of trail skipped
            start_date TEXT,  -- When the alternate route started (if it spans multiple days)
            end_date TEXT,    -- When the alternate route ended (if it spans multiple days)
            FOREIGN KEY (full_data_entry_id) REFERENCES FullDataEntry(id) ON DELETE CASCADE
          )
        ''');
        // Shoes table
        await db.execute('''
          CREATE TABLE Shoes (
            id INTEGER PRIMARY KEY,
            name TEXT,
            totalMiles REAL  -- Miles covered in these shoes
          )
        ''');
        // Create TrailJournal table
        await db.execute('''
          CREATE TABLE TrailJournal(
            id INTEGER PRIMARY KEY, 
            trailName TEXT, 
            startDate TEXT, 
            direction TEXT, 
            trailType TEXT, 
            initialLength REAL, -- Refers to length of trail without alternate routes
            totalLength REAL,   -- Total length of the trail including alternate routes
            totalMilesHiked REAL,   -- Total miles hiked (calculated from FullDataEntry sum)
            trailMilesHiked REAL,   -- Total miles hiked on the trail excluding alternates, based on last recorded trail mile marker
            percentTrailComplete REAL,   -- Percentage of the trail completed (calculated from trailMilesHiked / initialLength)
            percentTotalComplete REAL,   -- Percentage of the total trail completed (calculated from totalMilesHiked / totalLength)
            neroThreshold REAL DEFAULT 10.0,   -- Threshold for a Near-Zero day (in miles)
            neroNumber INTEGER,   -- Number of Near-Zero days
            zeroNumber INTEGER,   -- Number of Zero days
            totalElevationGain REAL,   -- Total elevation gain (ft) on the trail
            trailId TEXT,           -- Optional: references TrailMetadata (if applicable)
            FOREIGN KEY (trailId) REFERENCES TrailMetadata(trailId) ON DELETE SET NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE TrailJournalShoes (
            id INTEGER PRIMARY KEY,
            trail_journal_id INTEGER,  -- Foreign key to TrailJournal
            shoe_id INTEGER,           -- Foreign key to Shoes
            milesOnShoes REAL,         -- Miles hiked with this pair of shoes on this trail journal
            FOREIGN KEY (trail_journal_id) REFERENCES TrailJournal(id) ON DELETE CASCADE,
            FOREIGN KEY (shoe_id) REFERENCES Shoes(id) ON DELETE CASCADE
          )
        ''');

        // TrailMetadata table
        await db.execute('''
          CREATE TABLE TrailMetadata(
            trailId TEXT PRIMARY KEY, 
            trailName TEXT, 
            trailType TEXT, 
            trailLength REAL, 
            trailStructure TEXT, 
            trailDirection TEXT, 
            trailStart TEXT, 
            trailEnd TEXT, 
            trailDescription TEXT, 
            trailUrl TEXT
          )
        ''');

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

// Public method to access the database (for use in other classes like FormulaService)
  static Future<Database> getDatabase() async {
    return await _getDB();  // Simply returns the result of _getDB()
  }

}
