// lib/repositories/trip_repository.dart
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/trip.dart';
import '../models/section.dart';

class TripRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // --- INTERNAL HELPER ---
  Future<List<Section>> _getSectionsForTrip(DatabaseExecutor db, int tripId) async {
    final maps = await db.query(
      'sections',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'start_mile ASC',
    );
    return maps.map((map) => Section.fromMap(map)).toList();
  }

  // CREATE
  Future<Trip> createTrip(Trip trip) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final id = await txn.insert('trips', trip.toMap());
      for (var section in trip.sections) {
        await txn.insert('sections', section.copyWith(tripId: id).toMap());
      }
      return trip.copyWith(id: id);
    });
  }

  // READ - Single
  Future<Trip?> getTripById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('trips', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;

    final sections = await _getSectionsForTrip(db, id);
    return Trip.fromMap(maps.first, sections: sections);
  }

  // READ - All
  Future<List<Trip>> getAllTrips() async {
    final db = await _dbHelper.database;
    final maps = await db.query('trips', orderBy: 'start_date DESC');

    List<Trip> trips = [];
    for (var map in maps) {
      final id = map['id'] as int;
      final sections = await _getSectionsForTrip(db, id);
      trips.add(Trip.fromMap(map, sections: sections));
    }
    return trips;
  }

  // READ - By Status
  Future<List<Trip>> getTripsByStatus(TripStatus status) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'trips',
      where: 'status = ?',
      whereArgs: [status.index],
      orderBy: 'start_date DESC',
    );

    List<Trip> trips = [];
    for (var map in maps) {
      final id = map['id'] as int;
      final sections = await _getSectionsForTrip(db, id);
      trips.add(Trip.fromMap(map, sections: sections));
    }
    return trips;
  }

  // UPDATE
  // UPDATE - Modify an existing trip and its sections
  Future<int> updateTrip(Trip trip) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      // 1. Update the Trip row itself
      final result = await txn.update(
        'trips',
        trip.toMap(),
        where: 'id = ?',
        whereArgs: [trip.id],
      );

      // 2. Remove all old sections associated with this trip
      await txn.delete('sections', where: 'trip_id = ?', whereArgs: [trip.id]);

      // 3. Insert the new/updated sections
      for (var section in trip.sections) {
        // Copy the section to ensure it has the correct tripId before saving
        await txn.insert('sections', section.copyWith(tripId: trip.id).toMap());
      }

      return result;
    });
  }

  // DELETE
  Future<int> deleteTrip(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('trips', where: 'id = ?', whereArgs: [id]);
  }

  // PRESERVED SPECIALIZED METHODS
  Future<Trip?> getMostRecentTrip() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT t.* FROM trips t
      LEFT JOIN entries e ON t.id = e.trip_id
      GROUP BY t.id
      ORDER BY MAX(COALESCE(e.date, t.start_date)) DESC
      LIMIT 1
    ''');

    if (result.isEmpty) return null;
    
    final id = result.first['id'] as int;
    final sections = await _getSectionsForTrip(db, id);
    return Trip.fromMap(result.first, sections: sections);
  }

  Future<Trip?> getLongestTrip() async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('''
      SELECT t.*, SUM(
        (e.end_mile - e.start_mile) + e.extra_miles - e.skipped_miles
      ) as total_miles
      FROM trips t
      LEFT JOIN entries e ON t.id = e.trip_id
      GROUP BY t.id
      ORDER BY total_miles DESC
      LIMIT 1
    ''');

    if (result.isEmpty) return null;

    final id = result.first['id'] as int;
    final sections = await _getSectionsForTrip(db, id);
    return Trip.fromMap(result.first, sections: sections);
  }

  Future<void> updateTripEndDate(int tripId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT MAX(date) as max_date
      FROM entries
      WHERE trip_id = ? AND date >= (
        SELECT start_date FROM trips WHERE id = ?
      )
    ''', [tripId, tripId]);

    final maxDateStr = result.first['max_date'] as String?;
    if (maxDateStr != null) {
      await db.update('trips', {'end_date': maxDateStr}, where: 'id = ?', whereArgs: [tripId]);
    }
  }
}