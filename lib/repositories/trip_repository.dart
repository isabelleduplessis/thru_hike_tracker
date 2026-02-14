// repositories/trip_repository.dart
// Handles all database operations for Trips
// This is the ONLY place that knows how to save/load trips

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/trip.dart';

class TripRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  // CREATE - Insert a new trip
  Future<Trip> createTrip(Trip trip) async {
    final db = await _dbHelper.database;
    
    // Insert returns the new row's ID
    final id = await db.insert('trips', trip.toMap());
    
    // Return a copy of the trip with the ID filled in
    return trip.copyWith(id: id);
  }
  
  // READ - Get a single trip by ID
  Future<Trip?> getTripById(int id) async {
    final db = await _dbHelper.database;
    
    // Query returns a list of maps
    final maps = await db.query(
      'trips',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) return null;
    return Trip.fromMap(maps.first);
  }
  
  // READ - Get all trips
  Future<List<Trip>> getAllTrips() async {
    final db = await _dbHelper.database;
    
    // Order by start_date descending (newest first)
    final maps = await db.query(
      'trips',
      orderBy: 'start_date DESC',
    );
    
    // Convert each map to a Trip object
    return maps.map((map) => Trip.fromMap(map)).toList();
  }
  
  // READ - Get trips by status
  Future<List<Trip>> getTripsByStatus(TripStatus status) async {
    final db = await _dbHelper.database;
    
    final maps = await db.query(
      'trips',
      where: 'status = ?',
      whereArgs: [status.index],
      orderBy: 'start_date DESC',
    );
    
    return maps.map((map) => Trip.fromMap(map)).toList();
  }
  
  // UPDATE - Modify an existing trip
  Future<int> updateTrip(Trip trip) async {
    final db = await _dbHelper.database;
    
    // Returns number of rows affected (should be 1)
    return await db.update(
      'trips',
      trip.toMap(),
      where: 'id = ?',
      whereArgs: [trip.id],
    );
  }
  
  // DELETE - Remove a trip
  Future<int> deleteTrip(int id) async {
    final db = await _dbHelper.database;
    
    // CASCADE delete will also remove all entries for this trip
    return await db.delete(
      'trips',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // Get the most recent trip (by latest entry date or start date)
  Future<Trip?> getMostRecentTrip() async {
    final db = await _dbHelper.database;
    
    // This gets trips ordered by their most recent entry
    final result = await db.rawQuery('''
      SELECT t.* 
      FROM trips t
      LEFT JOIN entries e ON t.id = e.trip_id
      GROUP BY t.id
      ORDER BY MAX(COALESCE(e.date, t.start_date)) DESC
      LIMIT 1
    ''');
    
    if (result.isEmpty) return null;
    return Trip.fromMap(result.first);
  }
}
