// database/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  
  DatabaseHelper._init();
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('thru_hike_tracker.db');
    return _database!;
  }
  
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 13,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE entries ADD COLUMN direction INTEGER');
    }
    
    if (oldVersion < 3) {
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
    
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE trips ADD COLUMN trip_length REAL NOT NULL DEFAULT 0.0');
      await db.execute('ALTER TABLE trips ADD COLUMN end_mile REAL NOT NULL DEFAULT 0.0');
    }
    
    if (oldVersion < 5) {
      await db.execute('DROP TABLE IF EXISTS custom_field_values');
      await db.execute('DROP TABLE IF EXISTS trip_custom_fields');
      await db.execute('DROP TABLE IF EXISTS custom_fields');
      await db.execute('DROP TABLE IF EXISTS entry_gear');
      await db.execute('DROP TABLE IF EXISTS gear');
      await db.execute('DROP TABLE IF EXISTS entries');
      await db.execute('DROP TABLE IF EXISTS trips');
      await _createDB(db, 5);
    }
    
    if (oldVersion < 8) {
      await db.execute('DROP TABLE IF EXISTS entry_gear');
      await db.execute('DROP TABLE IF EXISTS gear');
      await db.execute('''
        CREATE TABLE gear (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          category TEXT,
          start_date TEXT NOT NULL DEFAULT "${DateTime.now().toIso8601String()}",
          end_date TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE entry_gear (
          entry_id INTEGER NOT NULL,
          gear_id INTEGER NOT NULL,
          PRIMARY KEY (entry_id, gear_id),
          FOREIGN KEY (entry_id) REFERENCES entries (id) ON DELETE CASCADE,
          FOREIGN KEY (gear_id) REFERENCES gear (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 9) {
      await db.execute('ALTER TABLE trips ADD COLUMN direction INTEGER');
      await db.execute('''
        CREATE TABLE sections (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          trip_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          start_mile REAL NOT NULL,
          end_mile REAL NOT NULL,
          FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX idx_sections_trip_id ON sections (trip_id)');
    }

    if (oldVersion < 10) {
      await db.execute('ALTER TABLE entries ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE entries ADD COLUMN longitude REAL');
    }

    if (oldVersion < 11) {
      await db.execute('ALTER TABLE trips ADD COLUMN track_coordinates INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE trips ADD COLUMN track_shower INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE trips ADD COLUMN track_elevation INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE trips ADD COLUMN track_sleeping INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE trips ADD COLUMN nero_threshold REAL');
      await db.execute('ALTER TABLE entries ADD COLUMN elevation_gain REAL');
      await db.execute('ALTER TABLE entries ADD COLUMN elevation_loss REAL');
    }

    if (oldVersion < 12) {
      // Fresh start with foreign keys properly enforced
      await db.execute('DROP TABLE IF EXISTS custom_field_values');
      await db.execute('DROP TABLE IF EXISTS trip_custom_fields');
      await db.execute('DROP TABLE IF EXISTS custom_fields');
      await db.execute('DROP TABLE IF EXISTS entry_gear');
      await db.execute('DROP TABLE IF EXISTS gear');
      await db.execute('DROP TABLE IF EXISTS sections');
      await db.execute('DROP TABLE IF EXISTS entries');
      await db.execute('DROP TABLE IF EXISTS trips');
      await _createDB(db, 12);
    }

    if (oldVersion < 13) {
      // Add completed column to sections
      await db.execute('ALTER TABLE sections ADD COLUMN completed INTEGER NOT NULL DEFAULT 0');

      // Add alternates table
      await db.execute('''
        CREATE TABLE alternates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          trip_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          departure_mile REAL NOT NULL,
          return_mile REAL NOT NULL,
          length REAL NOT NULL,
          completed INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX idx_alternates_trip_id ON alternates (trip_id)');

      // Add alternate_id to entries
      await db.execute('ALTER TABLE entries ADD COLUMN alternate_id INTEGER REFERENCES alternates (id) ON DELETE SET NULL');
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('PRAGMA foreign_keys = ON');

    await db.execute('''
      CREATE TABLE trips (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        start_mile REAL NOT NULL DEFAULT 0.0,
        status INTEGER NOT NULL DEFAULT 1,
        end_date TEXT,
        trip_length REAL NOT NULL DEFAULT 0.0,
        end_mile REAL NOT NULL DEFAULT 0.0,
        direction INTEGER,
        track_coordinates INTEGER NOT NULL DEFAULT 0,
        track_shower INTEGER NOT NULL DEFAULT 0,
        track_elevation INTEGER NOT NULL DEFAULT 0,
        track_sleeping INTEGER NOT NULL DEFAULT 0,
        nero_threshold REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE sections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        start_mile REAL NOT NULL,
        end_mile REAL NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE alternates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        departure_mile REAL NOT NULL,
        return_mile REAL NOT NULL,
        length REAL NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

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
        latitude REAL,
        longitude REAL,
        elevation_gain REAL,
        elevation_loss REAL,
        alternate_id INTEGER,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE,
        FOREIGN KEY (alternate_id) REFERENCES alternates (id) ON DELETE SET NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE gear (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT,
        start_date TEXT NOT NULL,
        end_date TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE entry_gear (
        entry_id INTEGER NOT NULL,
        gear_id INTEGER NOT NULL,
        PRIMARY KEY (entry_id, gear_id),
        FOREIGN KEY (entry_id) REFERENCES entries (id) ON DELETE CASCADE,
        FOREIGN KEY (gear_id) REFERENCES gear (id) ON DELETE CASCADE
      )
    ''');

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
    
    await db.execute('CREATE INDEX idx_entries_trip_id ON entries (trip_id)');
    await db.execute('CREATE INDEX idx_entries_date ON entries (date)');
    await db.execute('CREATE INDEX idx_entry_gear_entry ON entry_gear (entry_id)');
    await db.execute('CREATE INDEX idx_entry_gear_gear ON entry_gear (gear_id)');
    await db.execute('CREATE INDEX idx_sections_trip_id ON sections (trip_id)');
    await db.execute('CREATE INDEX idx_alternates_trip_id ON alternates (trip_id)');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}