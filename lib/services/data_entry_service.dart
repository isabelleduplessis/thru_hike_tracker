import 'package:thru_hike_tracker/models/gear.dart';
import 'database_helper.dart'; // Import the database helper
import 'package:thru_hike_tracker/models/data_entry.dart';



class DataEntryService {

  Future<void> insertFullDataEntry(FullDataEntry entry) async {
  final db = await DatabaseHelper.getDatabase();
  final batch = db.batch();

  try {
    // Calculate miles added and skipped from alternate routes
    double milesAdded = 0;
    double milesSkipped = 0;

    if (entry.alternateRoutes != null) {
      for (var route in entry.alternateRoutes!) {
        milesAdded += route.milesAdded;
        milesSkipped += route.milesSkipped;
      }
    }

    // Calculate complete distance
    double completeDistance = entry.coreDataEntry.endMile -
        entry.coreDataEntry.startMile -
        milesSkipped +
        milesAdded;

    // Prepare data for FullDataEntry table, including complete distance
    final fullDataEntryMap = entry.toJson();
    fullDataEntryMap['complete_distance'] = completeDistance;

    // Insert FullDataEntry and get its ID
    int entryId = await db.insert('FullDataEntry', fullDataEntryMap);

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

      // Insert custom fields
      for (var field in optionalFields.customFields.entries) {
        batch.insert('custom_fields', {
          'data_entry_id': entryId,
          'field_name': field.key,
          'field_value': field.value,
        });
      }
    }

    // Insert alternate routes
    if (entry.alternateRoutes != null) {
      for (var route in entry.alternateRoutes!) {
        batch.insert('AlternateRoute', {
          'full_data_entry_id': entryId,
          'miles_added': route.milesAdded,
          'miles_skipped': route.milesSkipped,
        });
      }
    }

    // Commit batch inserts
    await batch.commit();
  } catch (e) {
    print('Error inserting full data entry: $e');
  }
}



  Future<void> insertFullDataEntryWithGear(List<FullDataEntryGear> gearEntries) async {
  final db = await DatabaseHelper.getDatabase();

  for (var entry in gearEntries) {
    // Insert each gear entry into FullDataEntryGear
    await db.insert('FullDataEntryGear', {
      'full_data_entry_id': entry.id, // Use the correct entry ID
      'gear_item_id': entry.gearItemId,
      'miles_used': entry.milesUsed,
    });
  }
}
}
