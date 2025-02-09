import 'database_helper.dart'; // Import the database helper
import 'package:thru_hike_tracker/models/data_entry.dart';


class DataEntryService {

 Future<void> insertFullDataEntry(FullDataEntry entry) async {
  final db = await DatabaseHelper.getDatabase();

  // 1. Insert FullDataEntry
  int entryId = await db.insert('FullDataEntry', entry.toJson());

  // 2. Insert related data (OptionalFields)
  if (entry.optionalFields != null) {
    if (entry.optionalFields!.town != null) {
      for (var town in entry.optionalFields!.town!) {
        await db.insert('fullDataEntry_town', {
          'data_entry_id': entryId,
          'town_id': town,
        });
      }
    }

    // Insert wildlife sightings
    if (entry.optionalFields!.wildlife != null) {
      for (var animal in entry.optionalFields!.wildlife!.entries) {
        await db.insert('Wildlife', {
          'data_entry_id': entryId,
          'animal': animal.key,
          'count': animal.value,
        });
      }
    }

    // Insert custom fields
    if (entry.optionalFields!.customFields.isNotEmpty) {
      for (var field in entry.optionalFields!.customFields.entries) {
        await db.insert('custom_fields', {
          'data_entry_id': entryId,
          'field_name': field.key,
          'field_value': field.value,
        });
      }
    }
  }
}

}
