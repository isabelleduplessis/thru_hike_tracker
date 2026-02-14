// repositories/entry_repository.dart
// Handles all database operations for Entries

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/entry.dart';

class EntryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  // CREATE
  Future<Entry> createEntry(Entry entry) async {
    final db = await _dbHelper.database;
    final id = await db.insert('entries', entry.toMap());
    return entry.copyWith(id: id);
  }
  
  // READ - Get single entry
  Future<Entry?> getEntryById(int id) async {
    final db = await _dbHelper.database;
    
    final maps = await db.query(
      'entries',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) return null;
    return Entry.fromMap(maps.first);
  }
  
  // READ - Get all entries for a trip
  Future<List<Entry>> getEntriesForTrip(int tripId) async {
    final db = await _dbHelper.database;
    
    final maps = await db.query(
      'entries',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'date DESC', // Newest first
    );
    
    return maps.map((map) => Entry.fromMap(map)).toList();
  }
  
  // READ - Get entry for a specific date on a trip
  Future<Entry?> getEntryByDate(int tripId, DateTime date) async {
    final db = await _dbHelper.database;
    
    // Format date to compare just the date part (ignore time)
    final dateStr = date.toIso8601String().split('T')[0];
    
    final maps = await db.query(
      'entries',
      where: 'trip_id = ? AND date LIKE ?',
      whereArgs: [tripId, '$dateStr%'],
    );
    
    if (maps.isEmpty) return null;
    return Entry.fromMap(maps.first);
  }
  
  // READ - Get entries in a date range
  Future<List<Entry>> getEntriesInRange(
    int tripId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _dbHelper.database;
    
    final maps = await db.query(
      'entries',
      where: 'trip_id = ? AND date >= ? AND date <= ?',
      whereArgs: [
        tripId,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'date ASC',
    );
    
    return maps.map((map) => Entry.fromMap(map)).toList();
  }
  
  // UPDATE
  Future<int> updateEntry(Entry entry) async {
    final db = await _dbHelper.database;
    
    return await db.update(
      'entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }
  
  // DELETE
  Future<int> deleteEntry(int id) async {
    final db = await _dbHelper.database;
    
    return await db.delete(
      'entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // STATS - Get total miles for a trip
  Future<double> getTotalMilesForTrip(int tripId) async {
    final db = await _dbHelper.database;
    
    // SQL to calculate: SUM(end_mile - start_mile + extra_miles - skipped_miles)
    final result = await db.rawQuery('''
      SELECT SUM(
        (end_mile - start_mile) + extra_miles - skipped_miles
      ) as total
      FROM entries
      WHERE trip_id = ?
    ''', [tripId]);
    
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
  
  // STATS - Get entry count for a trip
  Future<int> getEntryCountForTrip(int tripId) async {
    final db = await _dbHelper.database;
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM entries
      WHERE trip_id = ?
    ''', [tripId]);
    
    return (result.first['count'] as int?) ?? 0;
  }
  
  // STATS - Get average miles per day
  Future<double> getAverageMilesPerDay(int tripId) async {
    final total = await getTotalMilesForTrip(tripId);
    final count = await getEntryCountForTrip(tripId);
    
    if (count == 0) return 0.0;
    return total / count;
  }
  // how to define getTotalMilesForAllTrips()?
  Future<double> getTotalMilesForAllTrips() async {
    final db = await _dbHelper.database;
    
    final result = await db.rawQuery('''
      SELECT SUM(
        (end_mile - start_mile) + extra_miles - skipped_miles
      ) as total
      FROM entries
    ''');
    
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
  Future<int> getEntryCountForAllTrips() async {
    final db = await _dbHelper.database;
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM entries
    ''');
    
    return (result.first['count'] as int?) ?? 0;
  }
}
