import 'package:sqflite/sqflite.dart';
//import 'database_helper.dart'; // Import DatabaseHelper
import 'package:thru_hike_tracker/models/data_entry.dart';

class FullDataEntryService {
  final Database db;

  FullDataEntryService(this.db);

  // Table creation for FullDataEntry
  Future<void> createFullDataEntryTable() async {
    

  // Add a new data entry
  Future<int> addDataEntry(FullDataEntry entry) async {
    return await db.insert("FullDataEntry", entry.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Update an existing data entry
  Future<int> updateDataEntry(FullDataEntry entry) async {
    return await db.update("FullDataEntry", entry.toJson(),
        where: "id = ?",
        whereArgs: [entry.id],
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Delete a data entry
  Future<int> deleteDataEntry(FullDataEntry entry) async {
    return await db.delete("FullDataEntry",
        where: "id = ?",
        whereArgs: [entry.id]);
  }

  // Get all data entries
  Future<List<FullDataEntry>?> getAllDataEntries() async {
    final List<Map<String, dynamic>> maps = await db.query("FullDataEntry");
    if (maps.isEmpty) {
      return null;
    }
    return List.generate(maps.length, (index) => FullDataEntry.fromJson(maps[index]));
  }
}
}