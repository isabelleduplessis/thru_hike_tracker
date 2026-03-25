// repositories/entry_repository.dart
// Handles all database operations for Entries

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
    final maps = await db.query('entries', where: 'id = ?', whereArgs: [id]);
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
      orderBy: 'date DESC',
    );
    return maps.map((map) => Entry.fromMap(map)).toList();
  }
  
  // READ - Get entry for a specific date on a trip
  Future<Entry?> getEntryByDate(int tripId, DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().split('T')[0];
    final maps = await db.query(
      'entries',
      where: 'trip_id = ? AND date LIKE ?',
      whereArgs: [tripId, '$dateStr%'],
    );
    if (maps.isEmpty) return null;
    return Entry.fromMap(maps.first);
  }
  
  // READ - Get entries in a date range for a specific trip
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

  // READ - Get all entries across all trips within a date range
  // Used for gear entry assignment
  Future<List<Entry>> getEntriesInDateRangeAllTrips(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _dbHelper.database;
    final startStr = startDate.toIso8601String().split('T')[0];
    final endStr = endDate.toIso8601String().split('T')[0];
    final maps = await db.rawQuery('''
      SELECT * FROM entries
      WHERE DATE(date) >= DATE(?)
      AND DATE(date) <= DATE(?)
      ORDER BY trip_id ASC, date DESC
    ''', [startStr, endStr]);
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
    return await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }
  
  // STATS - Get total miles for a trip
  Future<double> getTotalMilesForTrip(int tripId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT SUM(
        (end_mile - start_mile) + extra_miles - skipped_miles
      ) as total
      FROM entries
      WHERE trip_id = ?
    ''', [tripId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
  
  // STATS - Get entry count for a trip (unique dates)
  Future<int> getEntryCountForTrip(int tripId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT SUBSTR(date, 1, 10)) as count
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
      SELECT COUNT(DISTINCT SUBSTR(date, 1, 10)) as count
      FROM entries
    ''');
    return (result.first['count'] as int?) ?? 0;
  }

  // Get all entries for a trip ordered by date (for chart)
  Future<List<Entry>> getEntriesForTripChronological(int tripId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'entries',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'date ASC',
    );
    return maps.map((map) => Entry.fromMap(map)).toList();
  }

  Future<double> getLongestDayForTrip(int tripId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT SUM((end_mile - start_mile) + extra_miles - skipped_miles) as day_total
      FROM entries
      WHERE trip_id = ?
      GROUP BY SUBSTR(date, 1, 10)
      ORDER BY day_total DESC
      LIMIT 1
    ''', [tripId]);
    if (result.isEmpty) return 0.0;
    return (result.first['day_total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getLongestDayAllTrips() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT SUM((end_mile - start_mile) + extra_miles - skipped_miles) as day_total
      FROM entries
      GROUP BY trip_id, SUBSTR(date, 1, 10)
      ORDER BY day_total DESC
      LIMIT 1
    ''');
    if (result.isEmpty) return 0.0;
    return (result.first['day_total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getBestStreakForTrip(int tripId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT SUBSTR(date, 1, 10) as day,
            SUM((end_mile - start_mile) + extra_miles - skipped_miles) as day_total
      FROM entries
      WHERE trip_id = ?
      GROUP BY day
      HAVING day_total > 0
      ORDER BY day ASC
    ''', [tripId]);
    return _calculateStreak(result);
  }

  Future<int> getBestStreakAllTrips() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT SUBSTR(date, 1, 10) as day,
            SUM((end_mile - start_mile) + extra_miles - skipped_miles) as day_total
      FROM entries
      GROUP BY day
      HAVING day_total > 0
      ORDER BY day ASC
    ''');
    return _calculateStreak(result);
  }

  int _calculateStreak(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return 0;
    final dates = rows.map((r) => DateTime.parse(r['day'] as String)).toList();
    int best = 1;
    int current = 1;
    for (int i = 1; i < dates.length; i++) {
      final diff = dates[i].difference(dates[i - 1]).inDays;
      if (diff == 1) {
        current++;
        if (current > best) best = current;
      } else {
        current = 1;
      }
    }
    return best;
  }

  Future<List<Entry>> getEntriesWithCoordinates() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'entries',
      where: 'latitude IS NOT NULL AND longitude IS NOT NULL',
      orderBy: 'date ASC',
    );
    return maps.map((map) => Entry.fromMap(map)).toList();
  }

  Future<List<Entry>> getEntriesWithCoordinatesForTrip(int tripId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'entries',
      where: 'trip_id = ? AND latitude IS NOT NULL AND longitude IS NOT NULL',
      whereArgs: [tripId],
      orderBy: 'date ASC',
    );
    return maps.map((map) => Entry.fromMap(map)).toList();
  }

  Future<int> getNeroDaysForTrip(int tripId, double threshold) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT SUBSTR(date, 1, 10) as day,
            SUM((end_mile - start_mile) + extra_miles - skipped_miles) as day_total
      FROM entries
      WHERE trip_id = ?
      GROUP BY day
      HAVING day_total > 0 AND day_total <= ?
    ''', [tripId, threshold]);
    return result.length;
  }

  Future<double> getTotalElevationGainForTrip(int tripId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT SUM(elevation_gain) as total
      FROM entries
      WHERE trip_id = ? AND elevation_gain IS NOT NULL
    ''', [tripId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalElevationLossForTrip(int tripId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT SUM(elevation_loss) as total
      FROM entries
      WHERE trip_id = ? AND elevation_loss IS NOT NULL
    ''', [tripId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalElevationGainAllTrips() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT SUM(elevation_gain) as total
      FROM entries
      WHERE elevation_gain IS NOT NULL
    ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalElevationLossAllTrips() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT SUM(elevation_loss) as total
      FROM entries
      WHERE elevation_loss IS NOT NULL
    ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double?> getLastEndMileForTrip(int tripId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT end_mile FROM entries WHERE trip_id = ? ORDER BY id DESC LIMIT 1',
      [tripId],
    );
    if (result.isEmpty) return null;
    return (result.first['end_mile'] as num).toDouble();
  }

  Future<DateTime?> getLastEntryDateForTrip(int tripId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT MAX(date) as last_date FROM entries WHERE trip_id = ?',
      [tripId],
    );
    if (result.isEmpty || result.first['last_date'] == null) return null;
    return DateTime.parse(result.first['last_date'] as String);
  }
}