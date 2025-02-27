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
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {

        // Full data entry table - CRUD operations in data_entry_service.dart
        await db.execute('''
          CREATE TABLE full_data_entry(
            id INTEGER PRIMARY KEY AUTOINCREMENT, 
            -- CoreDataEntry fields
            current_date TEXT, -- Date of entry
            start_mile REAL, -- Start mile marker
            end_mile REAL, -- End mile marker
            -- Optional fields, can be null
            start_location TEXT,
            end_location TEXT,
            camp_type TEXT, -- (Tent, cowboy, shelter, etc)
            elevation_gain REAL,
            elevation_loss REAL,
            notes TEXT,
            -- Calculated fields
            trail_distance REAL, -- Difference between end and start (farout distance)
            distance_added REAL, -- Calculate from alternates
            distance_skipped REAL, -- Calculate from alternates
            net_distance REAL,
            net_elevation REAL, -- Optional, can be null
            directon TEXT, -- Reverse initial direction if trail distance is negative
            -- Foreign keys
            trail_journal_id INTEGER,  -- Foreign key linking to TrailJournal
            section_id INTEGER,  -- Foreign key linking to Section
            alternate_route_id INTEGER, -- Link to alternate route
            FOREIGN KEY (section_id) REFERENCES sections(id),
            FOREIGN KEY (trail_journal_id) REFERENCES TrailJournal(id) ON DELETE CASCADE,
            FOREIGN KEY (alternate_route_id) REFERENCES AlternateRoute(id)
          )
        ''');

        // Town tables - CRUD operations in data_entry_service.dart
        // MANY TO MANY
        await db.execute('''
          CREATE TABLE towns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE full_data_entry_town (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            data_entry_id INTEGER,
            town_id INTEGER,
            FOREIGN KEY (data_entry_id) REFERENCES full_data_entry(id) ON DELETE CASCADE,
            FOREIGN KEY (town_id) REFERENCES towns(id) ON DELETE CASCADE,
            UNIQUE (data_entry_id, town_id) -- Prevents duplicate town entries per data entry
          )
        ''');

        // Wildlife table - CRUD operations in data_entry_service.dart
        // ONE TO MANY ENTRIES
        await db.execute('''
          CREATE TABLE wildlife (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            data_entry_id INTEGER,  -- Foreign key linking to FullDataEntry
            animal TEXT NOT NULL,
            count INTEGER NOT NULL,
            FOREIGN KEY (data_entry_id) REFERENCES full_data_entry(id) ON DELETE CASCADE
          )
        ''');

        // Custom fields table - CRUD operations in data_entry_service.dart
        // ONE TO MANY ENTRIES
        await db.execute('''
          CREATE TABLE custom_fields (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            data_entry_id INTEGER,
            field_name TEXT NOT NULL,
            field_value TEXT NOT NULL, -- Store everything as TEXT and cast in Dart
            FOREIGN KEY (data_entry_id) REFERENCES full_data_entry(id) ON DELETE CASCADE
          )
        ''');
        // Gear item table - CRUD operations in data_entry_service.dart
        await db.execute('''
          CREATE TABLE full_data_entry_gear (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_data_entry_id INTEGER,
            gear_item_id INTEGER,
            miles_used REAL,
            FOREIGN KEY (gear_item_id) REFERENCES GearItem(id)
          )
        ''');
        // Alternate route table connected to data entries - CRUD operations in data_entry_service.dart
        await db.execute('''
          CREATE TABLE full_data_entry_alternate_routes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_data_entry_id INTEGER,  -- Foreign key linking to FullDataEntry (one per day)
            alternate_route_id INTEGER,  -- Foreign key linking to AlternateRoutes
            start_on_alternate INTEGER NOT NULL DEFAULT 0,  -- Whether this day started on the alternate
            end_on_alternate INTEGER NOT NULL DEFAULT 0,  -- Whether this day ended on the alternate
            FOREIGN KEY (full_data_entry_id) REFERENCES FullDataEntry(id) ON DELETE CASCADE,
            FOREIGN KEY (alternate_route_id) REFERENCES AlternateRoutes(id) ON DELETE CASCADE
          )
        ''');
        // Alternate route table - CRUD operations in alternate_route_service.dart
        await db.execute('''
          CREATE TABLE alternate_route (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            distance_added REAL NOT NULL,
            distance_skipped REAL NOT NULL
          )
        ''');

        // Trail journal table - CRUD operations in trail_journal_service.dart
        await db.execute('''
          CREATE TABLE trail_journal(
            id INTEGER PRIMARY KEY, 
            trailName TEXT, 
            startDate TEXT, 
            direction TEXT, 
            trailType TEXT, 
            initialLength REAL, -- Refers to length of trail without alternate routes
            totalLength REAL,   -- Total length of the trail including alternate routes
            totalMilesHiked REAL,   -- Total miles hiked (calculated from FullDataEntry sum)
            trailMilesHiked REAL,   -- Total miles hiked on the trail excluding alternates, based on last recorded trail mile marker
            totalMilesAdded REAL,   -- Total miles added from alternate routes
            totalMilesSkipped REAL,   -- Total miles skipped from alternate routes
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
        // Gear item table - CRUD operations in gear_service.dart
        await db.execute('''
          CREATE TABLE gear_item (
            gear_item_id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL
          )
        ''');
        // Gear item table for each user - CRUD operations in user_service.dart
        await db.execute('''
          CREATE TABLE user_gear (
            id INTEGER PRIMARY KEY,
            trail_journal_id INTEGER NOT NULL,
            gear_item_id INTEGER NOT NULL,
            start_date TEXT NOT NULL, -- Tracks when the gear was used
            end_date TEXT DEFAULT NULL, -- NULL if still in use
            total_miles_used REAL DEFAULT 0,
            FOREIGN KEY (trail_journal_id) REFERENCES TrailJournal(id),
            FOREIGN KEY (gear_item_id) REFERENCES GearItem(id)
          )
        ''');
        // Progress for each trail journal - CRUD operations in user_service.dart
        await db.execute('''
          CREATE TABLE user_trail_progress ( -- will basically keep track of which trails a user is doing
            id INTEGER PRIMARY KEY,
            trail_journal_id INTEGER NOT NULL,
            section_id INTEGER NOT NULL,
            completed INTEGER DEFAULT 0,
            last_mile_marker REAL DEFAULT 0,
            FOREIGN KEY (trail_journal_id) REFERENCES TrailJournal(id),
            FOREIGN KEY (section_id) REFERENCES Section(id),
            UNIQUE (trail_journal_id, section_id)
          )
        ''');
        
        // Trail metadata table - CRUD operations in trail_metadata_service.dart
        await db.execute('''
          CREATE TABLE trail_metadata(
            trail_id TEXT PRIMARY KEY, 
            trail_name TEXT, 
            trail_type TEXT, 
            trail_length REAL, 
            trail_structure TEXT, 
            trail_direction TEXT
          )
        ''');
        // Section table - CRUD operations in trail_metadata_service.dart
        await db.execute('''
          CREATE TABLE section (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            section_name TEXT NOT NULL,
            trail_id TEXT NOT NULL, -- Links to TrailMetadata
            end_mile REAL NOT NULL, -- The mile marker where this section ends
            FOREIGN KEY (trail_id) REFERENCES TrailMetadata(trailId) ON DELETE CASCADE
        )
        ''');

      },
      version: _version,
    );
    return _database!;
  }

  static Future<int> addDataEntry(FullDataEntry entry) async {
    final db = await _getDB();
    try {
      return await db.insert(
        "FullDataEntry",
        entry.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print("Error adding data entry: $e");
      return -1; // Indicate failure
    }
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
  
  static Future<List<FullDataEntry>> getAllDataEntries({int? limit}) async {
    final db = await _getDB();
    final maps = await db.query(
      "FullDataEntry",
      orderBy: "current_date DESC",
      limit: limit,
    );
    return maps.map((map) => FullDataEntry.fromJson(map)).toList();
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
