import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:thru_hike_tracker/models/data_entry.dart';
import 'package:thru_hike_tracker/models/alternate_route.dart';
import 'package:thru_hike_tracker/models/trail_journal.dart';

void main() {
  group('FullDataEntry Serialization', () {
    test('fromJson() correctly parses JSON', () {
      final json = {
        'id': 1,
        'core_data_entry': {
          'trail_journal_id': 101,
          'date': '2025-02-27',
          'start_mile': 5.0,
          'end_mile': 15.0
        },
        'complete_distance': 10.0,
        'alternate_route_ids': '1, 2',
        'miles_added': '3.5, 2.0',
        'miles_skipped': '1.0, 0.0',
        'start_location': 'Trailhead A',
        'end_location': 'Camp B',
        'camp_type': 'Tent',
        'elevation_gain': 500,
        'elevation_loss': 300,
        'notes': 'Great day on trail!',
        'town': 'Town A, Town B',
        'wildlife': jsonEncode({'bear': 2, 'deer': 1}),
        'gear_used': jsonEncode([
          {'gear_item_id': 1, 'name': 'Hyperlite Pack', 'type': 'Backpack'},
          {'gear_item_id': 2, 'name': 'Altra Lone Peak', 'type': 'Shoes'}
        ]),
        'custom_fields': jsonEncode({'weather': 'Sunny'})
      };

      final entry = FullDataEntry.fromJson(json);

      expect(entry.id, 1);
      expect(entry.coreDataEntry.trailJournalId, 101);
      expect(entry.completeDistance, 10.0);
      expect(entry.alternateRoutes!.length, 2);
      expect(entry.optionalFields!.startLocation, 'Trailhead A');
      expect(entry.optionalFields!.town, ['Town A', 'Town B']);
      expect(entry.optionalFields!.wildlife!['bear'], 2);
      expect(entry.optionalFields!.gearUsed!.length, 2);
      expect(entry.optionalFields!.customFields!['weather'], 'Sunny');
    });

    test('toJson() correctly serializes FullDataEntry', () {
      final entry = FullDataEntry(
        id: 1,
        coreDataEntry: CoreDataEntry(
          trailJournalId: 101,
          date: '2025-02-27',
          startMile: 5.0,
          endMile: 15.0,
        ),
        completeDistance: 10.0,
        alternateRoutes: [
          FullDataEntryAlternateRoute(
            fullDataEntryId: 1,
            alternateRouteId: 1,
            milesAdded: 3.5,
            milesSkipped: 1.0,
          ),
          FullDataEntryAlternateRoute(
            fullDataEntryId: 1,
            alternateRouteId: 2,
            milesAdded: 2.0,
            milesSkipped: 0.0,
          ),
        ],
        optionalFields: OptionalFields(
          startLocation: 'Trailhead A',
          endLocation: 'Camp B',
          campType: 'Tent',
          elevationGain: 500,
          elevationLoss: 300,
          notes: 'Great day on trail!',
          town: ['Town A', 'Town B'],
          wildlife: {'bear': 2, 'deer': 1},
          gearUsed: [
            FullDataEntryGear(gearItemId: 1, name: 'Hyperlite Pack', type: 'Backpack'),
            FullDataEntryGear(gearItemId: 2, name: 'Altra Lone Peak', type: 'Shoes'),
          ],
          customFields: {'weather': 'Sunny'},
        ),
      );

      final json = entry.toJson();

      expect(json['id'], 1);
      expect(json['core_data_entry']['trail_journal_id'], 101);
      expect(json['complete_distance'], 10.0);
      expect(json['alternate_route_ids'], '1, 2');
      expect(json['start_location'], 'Trailhead A');
      expect(json['town'], 'Town A, Town B');
      expect(jsonDecode(json['wildlife'])['bear'], 2);
      expect(jsonDecode(json['gear_used']).length, 2);
      expect(jsonDecode(json['custom_fields'])['weather'], 'Sunny');
    });
  });
}
