import 'database_helper.dart';
import 'package:thru_hike_tracker/models/alternate_route.dart';

class AlternateRouteService {
  // Add a new alternate route
  Future<int> insertAlternateRoute(AlternateRoute route) async {
    final db = await DatabaseHelper.getDatabase();
    return await db.insert('alternate_route', route.toJson());
  }

  // Link an alternate route to a daily entry
  Future<int> insertFullDataEntryAlternateRoute(int fullDataEntryId, int alternateRouteId, bool startOnAlternate, bool endOnAlternate) async {
    final db = await DatabaseHelper.getDatabase();
    return await db.insert('full_data_entry_alternate_routes', {
      'full_data_entry_id': fullDataEntryId,
      'alternate_route_id': alternateRouteId,
      'start_on_alternate': startOnAlternate ? 1 : 0,
      'end_on_alternate': endOnAlternate ? 1 : 0,
    });
  }

  // Get all alternate routes linked to a specific trail journal
  Future<List<AlternateRoute>> getAlternateRoutesForTrailJournal(int trailJournalId) async {
    final db = await DatabaseHelper.getDatabase();
    final result = await db.rawQuery('''
      SELECT ar.*
      FROM alternate_route ar
      JOIN full_data_entry_alternate_routes fda ON ar.id = fda.alternate_route_id
      JOIN full_data_entry fde ON fda.full_data_entry_id = fde.id
      WHERE fde.trail_journal_id = ?
    ''', [trailJournalId]);

    return result.map((json) => AlternateRoute.fromJson(json)).toList();
  }

  // Calculate total miles added and skipped for a trail journal
  Future<Map<String, double>> getTotalMilesAddedAndSkipped(int trailJournalId) async {
    final db = await DatabaseHelper.getDatabase();
    final result = await db.rawQuery('''
      SELECT 
        SUM(ar.distance_added) AS total_miles_added,
        SUM(ar.distance_skipped) AS total_miles_skipped
      FROM alternate_route ar
      JOIN full_data_entry_alternate_routes fda ON ar.id = fda.alternate_route_id
      JOIN full_data_entry fde ON fda.full_data_entry_id = fde.id
      WHERE fde.trail_journal_id = ?
    ''', [trailJournalId]);

    final totalMilesAdded = (result.first['total_miles_added'] as num?)?.toDouble() ?? 0.0;
    final totalMilesSkipped = (result.first['total_miles_skipped'] as num?)?.toDouble() ?? 0.0;

    return {
      'totalMilesAdded': totalMilesAdded,
      'totalMilesSkipped': totalMilesSkipped,
    };
  }

  // Delete an alternate route (cascades to daily entries)
  Future<void> deleteAlternateRoute(int id) async {
    final db = await DatabaseHelper.getDatabase();
    await db.delete('alternate_route', where: 'id = ?', whereArgs: [id]);
  }
}
