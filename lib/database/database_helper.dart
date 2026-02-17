// database/database_helper.dart
// Handles SQLite database setup and migrations

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // Singleton pattern - only one instance of DatabaseHelper exists
  // This ensures we don't create multiple database connections
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  
  DatabaseHelper._init(); // Private constructor
  
  // Get the database, creating it if it doesn't exist
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('thru_hike_tracker.db');
    return _database!;
  }
  
  // Initialize the database file
  Future<Database> _initDB(String filePath) async {
    // Get the default database location for this platform
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    
    // Open the database, creating it if it doesn't exist
    // version: used for migrations (when we change the schema)
    return await openDatabase(
      path,
      version: 3,  // 
      onCreate: _createDB,
      onUpgrade: _onUpgrade,  // ← Add this line
    );
  }

  // Add this method after _createDB
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add direction column to existing entries table
      await db.execute('ALTER TABLE entries ADD COLUMN direction INTEGER');
    }
    
    if (oldVersion < 3) {
      // Add custom fields tables
      await db.execute('''
        CREATE TABLE custom_fields (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type INTEGER NOT NULL
        )
      ''');
      
      await db.execute('''
        CREATE TABLE trip_custom_fields (
          trip_id INTEGER NOT NULL,
          custom_field_id INTEGER NOT NULL,
          display_order INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (trip_id, custom_field_id),
          FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE,
          FOREIGN KEY (custom_field_id) REFERENCES custom_fields (id) ON DELETE CASCADE
        )
      ''');
      
      await db.execute('''
        CREATE TABLE custom_field_values (
          entry_id INTEGER NOT NULL,
          custom_field_id INTEGER NOT NULL,
          value TEXT NOT NULL,
          PRIMARY KEY (entry_id, custom_field_id),
          FOREIGN KEY (entry_id) REFERENCES entries (id) ON DELETE CASCADE,
          FOREIGN KEY (custom_field_id) REFERENCES custom_fields (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  // Create all tables - runs only on first install
  Future _createDB(Database db, int version) async {
    // TRIPS TABLE
    await db.execute('''
      CREATE TABLE trips (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        start_mile REAL NOT NULL DEFAULT 0.0,
        status INTEGER NOT NULL DEFAULT 1,
        end_date TEXT
      )
    ''');
    
    // ENTRIES TABLE
    await db.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        start_mile REAL NOT NULL,
        end_mile REAL NOT NULL,
        extra_miles REAL NOT NULL DEFAULT 0.0,
        skipped_miles REAL NOT NULL DEFAULT 0.0,
        location TEXT,
        tent_or_shelter INTEGER,
        shower INTEGER,
        notes TEXT NOT NULL DEFAULT '',
        direction INTEGER,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');
    
    // GEAR TABLE
    await db.execute('''
      CREATE TABLE gear (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT
      )
    ''');
    
    // ENTRY_GEAR TABLE (many-to-many relationship)
    // Links entries to gear used on that day
    await db.execute('''
      CREATE TABLE entry_gear (
        entry_id INTEGER NOT NULL,
        gear_id INTEGER NOT NULL,
        PRIMARY KEY (entry_id, gear_id),
        FOREIGN KEY (entry_id) REFERENCES entries (id) ON DELETE CASCADE,
        FOREIGN KEY (gear_id) REFERENCES gear (id) ON DELETE CASCADE
      )
    ''');

    // CUSTOM FIELDS TABLE
    await db.execute('''
      CREATE TABLE custom_fields (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type INTEGER NOT NULL
      )
    ''');

    // TRIP_CUSTOM_FIELDS TABLE (many-to-many: trips <-> custom_fields)
    await db.execute('''
      CREATE TABLE trip_custom_fields (
        trip_id INTEGER NOT NULL,
        custom_field_id INTEGER NOT NULL,
        display_order INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (trip_id, custom_field_id),
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE,
        FOREIGN KEY (custom_field_id) REFERENCES custom_fields (id) ON DELETE CASCADE
      )
    ''');

    // CUSTOM FIELD VALUES TABLE (stores actual entry values)
    await db.execute('''
      CREATE TABLE custom_field_values (
        entry_id INTEGER NOT NULL,
        custom_field_id INTEGER NOT NULL,
        value TEXT NOT NULL,
        PRIMARY KEY (entry_id, custom_field_id),
        FOREIGN KEY (entry_id) REFERENCES entries (id) ON DELETE CASCADE,
        FOREIGN KEY (custom_field_id) REFERENCES custom_fields (id) ON DELETE CASCADE
      )
    ''');
    
    // Create indexes for faster queries
    // Index on foreign keys speeds up JOIN operations
    await db.execute('CREATE INDEX idx_entries_trip_id ON entries (trip_id)');
    await db.execute('CREATE INDEX idx_entries_date ON entries (date)');
    await db.execute('CREATE INDEX idx_entry_gear_entry ON entry_gear (entry_id)');
    await db.execute('CREATE INDEX idx_entry_gear_gear ON entry_gear (gear_id)');
  }
  
  // Future: When we need to add fields, we'll add migration logic here
  // Example:
  // Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
  //   if (oldVersion < 2) {
  //     await db.execute('ALTER TABLE entries ADD COLUMN elevation_gain REAL');
  //   }
  // }
  
  // Close the database
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
