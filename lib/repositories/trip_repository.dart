// lib/repositories/trip_repository.dart
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/trip.dart';
import '../models/section.dart';

class TripRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ── Internal helpers ──────────────────────────────────────────────────────

  Future<List<Section>> _getSectionsForTrip(DatabaseExecutor db, int tripId) async {
    final maps = await db.query(
      'sections',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'start_mile ASC',
    );
    return maps.map((map) => Section.fromMap(map)).toList();
  }

  Future<List<Alternate>> _getAlternatesForTrip(DatabaseExecutor db, int tripId) async {
    final maps = await db.query(
      'alternates',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'departure_mile ASC',
    );
    return maps.map((map) => Alternate.fromMap(map)).toList();
  }

  // ── CREATE ────────────────────────────────────────────────────────────────

  Future<Trip> createTrip(Trip trip) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final id = await txn.insert('trips', trip.toMap());
      for (var section in trip.sections) {
        await txn.insert('sections', section.copyWith(tripId: id).toMap());
      }
      for (var alternate in trip.alternates) {
        await txn.insert('alternates', alternate.copyWith(tripId: id).toMap());
      }
      return trip.copyWith(id: id);
    });
  }

  // ── READ — Single ─────────────────────────────────────────────────────────

  Future<Trip?> getTripById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('trips', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;

    final sections = await _getSectionsForTrip(db, id);
    final alternates = await _getAlternatesForTrip(db, id);
    return Trip.fromMap(maps.first, sections: sections, alternates: alternates);
  }

  // ── READ — All ────────────────────────────────────────────────────────────

  Future<List<Trip>> getAllTrips() async {
    final db = await _dbHelper.database;
    final maps = await db.query('trips', orderBy: 'start_date DESC');

    List<Trip> trips = [];
    for (var map in maps) {
      final id = map['id'] as int;
      final sections = await _getSectionsForTrip(db, id);
      final alternates = await _getAlternatesForTrip(db, id);
      trips.add(Trip.fromMap(map, sections: sections, alternates: alternates));
    }
    return trips;
  }

  // ── READ — By Status ──────────────────────────────────────────────────────

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
      final alternates = await _getAlternatesForTrip(db, id);
      trips.add(Trip.fromMap(map, sections: sections, alternates: alternates));
    }
    return trips;
  }

  // ── UPDATE ────────────────────────────────────────────────────────────────

  Future<int> updateTrip(Trip trip) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      final result = await txn.update(
        'trips',
        trip.toMap(),
        where: 'id = ?',
        whereArgs: [trip.id],
      );

      // Replace sections
      await txn.delete('sections', where: 'trip_id = ?', whereArgs: [trip.id]);
      for (var section in trip.sections) {
        await txn.insert('sections', section.copyWith(tripId: trip.id).toMap());
      }

      // Replace alternates
      await txn.delete('alternates', where: 'trip_id = ?', whereArgs: [trip.id]);
      for (var alternate in trip.alternates) {
        await txn.insert('alternates', alternate.copyWith(tripId: trip.id).toMap());
      }

      return result;
    });
  }

  // ── UPDATE — Alternate completion only ────────────────────────────────────
  // Used when marking an alternate complete from the stats screen
  // without going through the full trip update flow

  Future<void> setAlternateCompleted(int alternateId, bool completed) async {
    final db = await _dbHelper.database;
    await db.update(
      'alternates',
      {'completed': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [alternateId],
    );
  }

  // ── UPDATE — Section completion only ─────────────────────────────────────

  Future<void> setSectionCompleted(int sectionId, bool completed) async {
    final db = await _dbHelper.database;
    await db.update(
      'sections',
      {'completed': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [sectionId],
    );
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  Future<int> deleteTrip(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('trips', where: 'id = ?', whereArgs: [id]);
  }

  // ── Specialized queries ───────────────────────────────────────────────────

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
    final alternates = await _getAlternatesForTrip(db, id);
    return Trip.fromMap(result.first, sections: sections, alternates: alternates);
  }

  Future<Trip?> getLongestTrip() async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('''
      SELECT t.*, SUM(
        ABS(e.end_mile - e.start_mile) + e.extra_miles - e.skipped_miles
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
    final alternates = await _getAlternatesForTrip(db, id);
    return Trip.fromMap(result.first, sections: sections, alternates: alternates);
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

  // ── Alternates — get incomplete for a trip ────────────────────────────────
  // Used in entry form to show available alternates to select

  Future<List<Alternate>> getIncompleteAlternatesForTrip(int tripId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'alternates',
      where: 'trip_id = ? AND completed = 0',
      whereArgs: [tripId],
      orderBy: 'departure_mile ASC',
    );
    return maps.map((map) => Alternate.fromMap(map)).toList();
  }
}