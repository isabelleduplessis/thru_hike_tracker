// repositories/gear_repository.dart
// Handles all database operations for Gear

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/gear.dart';
import '../models/entry.dart';

class GearRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  // CREATE - Add new gear
  Future<Gear> createGear(Gear gear) async {
    final db = await _dbHelper.database;
    final id = await db.insert('gear', gear.toMap());
    return gear.copyWith(id: id);
  }
  
  // READ - Get all gear
  Future<List<Gear>> getAllGear() async {
    final db = await _dbHelper.database;
    
    final maps = await db.query(
      'gear',
      orderBy: 'name ASC',
    );
    
    return maps.map((map) => Gear.fromMap(map)).toList();
  }
  
  // READ - Get gear by ID
  Future<Gear?> getGearById(int id) async {
    final db = await _dbHelper.database;
    
    final maps = await db.query(
      'gear',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) return null;
    return Gear.fromMap(maps.first);
  }
  
  // UPDATE
  Future<int> updateGear(Gear gear) async {
    final db = await _dbHelper.database;
    
    return await db.update(
      'gear',
      gear.toMap(),
      where: 'id = ?',
      whereArgs: [gear.id],
    );
  }
  
  // DELETE
  Future<int> deleteGear(int id) async {
    final db = await _dbHelper.database;
    
    // CASCADE will also remove entry_gear links
    return await db.delete(
      'gear',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // LINK GEAR TO ENTRY
  Future<void> linkGearToEntry(int entryId, int gearId) async {
    final db = await _dbHelper.database;
    
    await db.insert(
      'entry_gear',
      {'entry_id': entryId, 'gear_id': gearId},
      conflictAlgorithm: ConflictAlgorithm.ignore, // Ignore if already linked
    );
  }
  
  // UNLINK GEAR FROM ENTRY
  Future<void> unlinkGearFromEntry(int entryId, int gearId) async {
    final db = await _dbHelper.database;
    
    await db.delete(
      'entry_gear',
      where: 'entry_id = ? AND gear_id = ?',
      whereArgs: [entryId, gearId],
    );
  }
  
  // SET all gear for an entry (replaces existing links)
  Future<void> setGearForEntry(int entryId, List<int> gearIds) async {
    final db = await _dbHelper.database;
    
    // Transaction ensures all-or-nothing
    await db.transaction((txn) async {
      // Remove all existing links
      await txn.delete(
        'entry_gear',
        where: 'entry_id = ?',
        whereArgs: [entryId],
      );
      
      // Add new links
      for (final gearId in gearIds) {
        await txn.insert(
          'entry_gear',
          {'entry_id': entryId, 'gear_id': gearId},
        );
      }
    });
  }
  
  // GET gear used in an entry
  Future<List<Gear>> getGearForEntry(int entryId) async {
    final db = await _dbHelper.database;
    
    final maps = await db.rawQuery('''
      SELECT g.*
      FROM gear g
      INNER JOIN entry_gear eg ON g.id = eg.gear_id
      WHERE eg.entry_id = ?
      ORDER BY g.name
    ''', [entryId]);
    
    return maps.map((map) => Gear.fromMap(map)).toList();
  }
  
  // GET STATS for a piece of gear
  Future<GearStats> getGearStats(int gearId) async {
    final db = await _dbHelper.database;
    
    // Get the gear itself
    final gear = await getGearById(gearId);
    if (gear == null) {
      throw Exception('Gear not found');
    }
    
    // Calculate total miles and days used
    final result = await db.rawQuery('''
      SELECT 
        COUNT(DISTINCT eg.entry_id) as days_used,
        SUM((e.end_mile - e.start_mile) + e.extra_miles - e.skipped_miles) as total_miles,
        MIN(e.date) as first_used,
        MAX(e.date) as last_used
      FROM entry_gear eg
      INNER JOIN entries e ON eg.entry_id = e.id
      WHERE eg.gear_id = ?
    ''', [gearId]);
    
    final data = result.first;
    
    return GearStats(
      gear: gear,
      totalMiles: (data['total_miles'] as num?)?.toDouble() ?? 0.0,
      daysUsed: (data['days_used'] as int?) ?? 0,
      firstUsed: data['first_used'] != null 
          ? DateTime.parse(data['first_used'] as String)
          : null,
      lastUsed: data['last_used'] != null 
          ? DateTime.parse(data['last_used'] as String)
          : null,
    );
  }
  
  // GET STATS for all gear
  Future<List<GearStats>> getAllGearStats() async {
    final allGear = await getAllGear();
    
    final statsList = <GearStats>[];
    for (final gear in allGear) {
      final stats = await getGearStats(gear.id!);
      statsList.add(stats);
    }
    
    return statsList;
  }
  
  // GET gear stats filtered by trip(s)
  Future<GearStats> getGearStatsForTrips(int gearId, List<int> tripIds) async {
    final db = await _dbHelper.database;
    
    final gear = await getGearById(gearId);
    if (gear == null) {
      throw Exception('Gear not found');
    }
    
    // Build WHERE clause for multiple trip IDs
    final placeholders = tripIds.map((_) => '?').join(',');
    
    final result = await db.rawQuery('''
      SELECT 
        COUNT(DISTINCT eg.entry_id) as days_used,
        SUM((e.end_mile - e.start_mile) + e.extra_miles - e.skipped_miles) as total_miles,
        MIN(e.date) as first_used,
        MAX(e.date) as last_used
      FROM entry_gear eg
      INNER JOIN entries e ON eg.entry_id = e.id
      WHERE eg.gear_id = ? AND e.trip_id IN ($placeholders)
    ''', [gearId, ...tripIds]);
    
    final data = result.first;
    
    return GearStats(
      gear: gear,
      totalMiles: (data['total_miles'] as num?)?.toDouble() ?? 0.0,
      daysUsed: (data['days_used'] as int?) ?? 0,
      firstUsed: data['first_used'] != null 
          ? DateTime.parse(data['first_used'] as String)
          : null,
      lastUsed: data['last_used'] != null 
          ? DateTime.parse(data['last_used'] as String)
          : null,
    );
  }

  // Get gear that was active on a specific date
  Future<List<Gear>> getActiveGearOnDate(DateTime date) async {
    final db = await _dbHelper.database;
    
    final dateStr = date.toIso8601String().split('T')[0];
    
    final maps = await db.rawQuery('''
      SELECT * FROM gear
      WHERE DATE(start_date) <= DATE(?)
      AND (end_date IS NULL OR DATE(end_date) >= DATE(?))
      ORDER BY name ASC
    ''', [dateStr, dateStr]);
    
    return maps.map((map) => Gear.fromMap(map)).toList();
  }

  // Get the last date this gear was used in an entry
  Future<DateTime?> getLastUsedDate(int gearId) async {
    final db = await _dbHelper.database;
    
    final result = await db.rawQuery('''
      SELECT MAX(e.date) as last_date
      FROM entries e
      INNER JOIN entry_gear eg ON e.id = eg.entry_id
      WHERE eg.gear_id = ?
    ''', [gearId]);
    
    if (result.isEmpty || result.first['last_date'] == null) {
      return null;
    }
    
    return DateTime.parse(result.first['last_date'] as String);
  }
}
