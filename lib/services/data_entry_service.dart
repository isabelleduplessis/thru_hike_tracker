import 'database_helper.dart'; // Import the database helper
import 'package:thru_hike_tracker/models/data_entry.dart';

class DataEntryService {

  Future<void> insertFullDataEntry(FullDataEntry entry) async {
    final db = await DatabaseHelper.getDatabase();
    final batch = db.batch();

    try {
      // Insert FullDataEntry and get its ID
      int entryId = await db.insert('FullDataEntry', entry.toJson());

      // Insert related data using batch operations
      final optionalFields = entry.optionalFields;

      if (optionalFields != null) {
        // Insert towns
        optionalFields.town?.forEach((townId) {
          batch.insert('fullDataEntry_town', {
            'data_entry_id': entryId,
            'town_id': townId,
          });
        });

        // Insert wildlife sightings
        optionalFields.wildlife?.entries.forEach((animal) {
          batch.insert('Wildlife', {
            'data_entry_id': entryId,
            'animal': animal.key,
            'count': animal.value,
          });
        });

        // Insert custom fields (handling key-value pairs)
        for (var field in optionalFields.customFields.entries) {
          batch.insert('custom_fields', {
            'data_entry_id': entryId,
            'field_name': field.key,
            'field_value': field.value,
          });
        }
      }

      // Commit batch inserts
      await batch.commit();
    } catch (e) {
      print('Error inserting full data entry: $e');
    }
  }
}
