// For operations for each trail journal (calculating stats)

// ideas - fastest day, highest mileage day


import 'package:sqflite/sqflite.dart';
//import 'database_helper.dart'; // Ensure you have a DatabaseHelper class managing DB initialization

class TrailJournalService {
  final Database db;

  TrailJournalService(this.db);

  // Create a new trail journal
  Future<int> createTrailJournal(Map<String, dynamic> journal) async {
    return await db.insert('TrailJournal', journal);
  }

  // Get trail journal by ID
  Future<Map<String, dynamic>?> getTrailJournal(int id) async {
    final List<Map<String, dynamic>> result = await db.query(
      'TrailJournal',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // 🔹 READ all Trail Journals
  Future<List<Map<String, dynamic>>> getAllTrailJournals() async {
    return await db.query('TrailJournal');
  }

  // 🔹 UPDATE a Trail Journal
  Future<int> updateTrailJournal(int id, Map<String, dynamic> updates) async {
    return await db.update(
      'TrailJournal',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 🔹 DELETE a Trail Journal (also remove related entries)
  Future<int> deleteTrailJournal(int id) async {
    await db.delete('TrailJournalGear', where: 'trail_journal_id = ?', whereArgs: [id]);
    await db.delete('UserTrailProgress', where: 'trail_journal_id = ?', whereArgs: [id]);
    return await db.delete('TrailJournal', where: 'id = ?', whereArgs: [id]);
  }

  // 🔹 ADD Gear to a Trail Journal
  Future<int> addGearToJournal(int journalId, int gearItemId, String startDate) async {
    return await db.insert('TrailJournalGear', {
      'trail_journal_id': journalId,
      'gear_item_id': gearItemId,
      'start_date': startDate,
      'total_miles_used': 0,
    });
  }

  // 🔹 UPDATE Gear miles for a specific trail journal
  Future<int> updateGearMiles(int journalId, int gearItemId, double miles) async {
    return await db.update(
      'TrailJournalGear',
      {'total_miles_used': miles},
      where: 'trail_journal_id = ? AND gear_item_id = ?',
      whereArgs: [journalId, gearItemId],
    );
  }

  // 🔹 END Gear usage in a Journal
  Future<int> endGearUsage(int journalId, int gearItemId, String endDate) async {
    return await db.update(
      'TrailJournalGear',
      {'end_date': endDate},
      where: 'trail_journal_id = ? AND gear_item_id = ? AND end_date IS NULL',
      whereArgs: [journalId, gearItemId],
    );
  }

  // 🔹 TRACK Section Progress (Add or Update Progress)
  Future<int> updateUserTrailProgress(int journalId, int sectionId, double lastMile, bool completed) async {
    final existing = await db.query(
      'UserTrailProgress',
      where: 'trail_journal_id = ? AND section_id = ?',
      whereArgs: [journalId, sectionId],
    );

    if (existing.isNotEmpty) {
      return await db.update(
        'UserTrailProgress',
        {'last_mile_marker': lastMile, 'completed': completed ? 1 : 0},
        where: 'trail_journal_id = ? AND section_id = ?',
        whereArgs: [journalId, sectionId],
      );
    } else {
      return await db.insert('UserTrailProgress', {
        'trail_journal_id': journalId,
        'section_id': sectionId,
        'last_mile_marker': lastMile,
        'completed': completed ? 1 : 0,
      });
    }
  }

  // 🔹 GET Section Progress for a Journal
  Future<List<Map<String, dynamic>>> getTrailProgress(int journalId) async {
    return await db.query(
      'UserTrailProgress',
      where: 'trail_journal_id = ?',
      whereArgs: [journalId],
    );
  }

  // 🔹 UPDATE Trail Stats (Total Miles, Skipped Miles, etc.)
  Future<void> updateTrailStats(int journalId) async {
    final result = await db.rawQuery("""
      SELECT 
        SUM(totalMilesHiked) AS totalMiles,
        SUM(trailMilesHiked) AS trailMiles,
        SUM(totalMilesAdded) AS milesAdded,
        SUM(totalMilesSkipped) AS milesSkipped,
        SUM(totalElevationGain) AS elevation
      FROM FullDataEntry
      WHERE trail_journal_id = ?;
    """, [journalId]);

    if (result.isNotEmpty) {
      final stats = result.first;
      await db.update(
        'TrailJournal',
        {
          'totalMilesHiked': stats['totalMiles'] ?? 0,
          'trailMilesHiked': stats['trailMiles'] ?? 0,
          'totalMilesAdded': stats['milesAdded'] ?? 0,
          'totalMilesSkipped': stats['milesSkipped'] ?? 0,
          'totalElevationGain': stats['elevation'] ?? 0,
          //'percentTrailComplete': (stats['trailMiles'] ?? 0) / (stats['initialLength'] ?? 1) * 100, ERROR SAYING / OPERATOR ISN'T DEFINED FOR OBJECT
          //'percentTotalComplete': (stats['totalMiles'] ?? 0) / (stats['totalLength'] ?? 1) * 100,
        },
        where: 'id = ?',
        whereArgs: [journalId],
      );
    }
  }
  // 🔹 GET Gear Usage for a Trail Journal
  Future<double> getMilesForGearInTrailJournal(int gearItemId, int trailJournalId) async {
  final result = await db.rawQuery('''
    SELECT SUM(fdg.miles_used) as totalMiles
    FROM FullDataEntryGear fdg
    JOIN FullDataEntry fde ON fdg.full_data_entry_id = fde.id
    WHERE fdg.gear_item_id = ? AND fde.trail_journal_id = ?
  ''', [gearItemId, trailJournalId]);

  return (result.first['totalMiles'] as num?)?.toDouble() ?? 0.0;
}

}
