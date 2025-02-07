import 'package:sqflite/sqflite.dart';
import 'package:thru_hike_tracker/models/gear.dart';

//add trail journal gear


class GearService {
  final Database db;

  // Constructor accepts the database instance
  GearService(this.db);

  // 1. Create tables if they don't exist (called once on database creation)
  static Future<void> onCreate(Database db, int version) async {
    
    
    // Add any other tables you need (e.g., FullDataEntry, CoreDataEntry, etc.)
  }

  // 2. Insert a new GearItem (e.g., shoes, custom gear)
  Future<int> insertGearItem(GearItem gearItem) async {
    return await db.insert(
      'GearItem',
      gearItem.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,  // Handle conflicts by replacing
    );
  }

  // 3. Insert FullDataEntryGear (link gear to daily entries)
  Future<int> insertFullDataEntryGear(FullDataEntryGear entryGear) async {
    return await db.insert(
      'FullDataEntryGear',
      entryGear.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,  // Handle conflicts by replacing
    );
  }

  // 4. Get all gear used for a specific day (given fullDataEntryId)
  Future<List<FullDataEntryGear>> getGearUsedForDay(int fullDataEntryId) async {
    final result = await db.query(
      'FullDataEntryGear',
      where: 'full_data_entry_id = ?',
      whereArgs: [fullDataEntryId],
    );

    return result.map((json) => FullDataEntryGear.fromJson(json)).toList();
  }

  // 5. Get total miles used for a specific gear item
  Future<double> getTotalMilesForGear(int gearItemId) async {
    final result = await db.rawQuery('''
      SELECT SUM(miles_used) as totalMiles
      FROM FullDataEntryGear
      WHERE gear_item_id = ?
    ''', [gearItemId]);

    return (result.first['totalMiles'] as num?)?.toDouble() ?? 0.0;
  }

  // 6. Get the details of a specific gear item by its ID (name, type)
  Future<GearItem?> getGearItemDetails(int gearItemId) async {
    final result = await db.query(
      'GearItem',
      where: 'id = ?',
      whereArgs: [gearItemId],
    );

    if (result.isNotEmpty) {
      return GearItem.fromJson(result.first);
    }
    return null;  // Return null if the gear item doesn't exist
  }

  // 7. Update an existing GearItem (if needed)
  Future<int> updateGearItem(GearItem gearItem) async {
    return await db.update(
      'GearItem',
      gearItem.toJson(),
      where: 'id = ?',
      whereArgs: [gearItem.id],
    );
  }

  // 8. Delete a GearItem (if needed)
  Future<int> deleteGearItem(int gearItemId) async {
    return await db.delete(
      'GearItem',
      where: 'id = ?',
      whereArgs: [gearItemId],
    );
  }
}
