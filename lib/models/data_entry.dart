import 'trail_journal.dart';
import 'alternate_route.dart';
import 'gear.dart';
import 'dart:convert';

// FullDataEntry class to represent a single row in the dataset corresponding to a single day on the trail
class FullDataEntry {
  final int? id;
  final CoreDataEntry coreDataEntry;
  final double completeDistance;
  final List<FullDataEntryAlternateRoute>? alternateRoutes;
  final OptionalFields? optionalFields;

  FullDataEntry({
    this.id,
    required this.coreDataEntry,
    required this.completeDistance,
    this.alternateRoutes,
    this.optionalFields
  });

  factory FullDataEntry.fromJson(Map<String, dynamic> json) {
    return FullDataEntry(
      id: json['id'],
      coreDataEntry: CoreDataEntry.fromJson(json['core_data_entry']),
      completeDistance: (json['complete_distance'] as num).toDouble(),
      alternateRoutes: json['alternate_route_ids'] != null
          ? (json['alternate_route_ids'] as String)
              .split(', ')
              .map((id) => FullDataEntryAlternateRoute(
                    fullDataEntryId: json['id'],
                    alternateRouteId: int.parse(id),
                    milesAdded: json['miles_added'],
                    milesSkipped: json['miles_skipped']))
              .toList()
          : [],
      optionalFields: OptionalFields(
        startLocation: json['start_location'],
        endLocation: json['end_location'],
        campType: json['camp_type'],
        elevationGain: json['elevation_gain'],
        elevationLoss: json['elevation_loss'],
        notes: json['notes'],
        town: json['town'] != null ? (json['town'] as String).split(', ') : null,
        wildlife: json['wildlife'] != null ? Map<String, int>.from(jsonDecode(json['wildlife'])) : null,
        gearUsed: json['gear_used'] != null
            ? (jsonDecode(json['gear_used']) as List)
                .map((g) => FullDataEntryGear.fromJson(g))
                .toList()
            : null,
        customFields: json['custom_fields'] != null
            ? Map<String, dynamic>.from(jsonDecode(json['custom_fields']))
            : {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'core_data_entry': coreDataEntry.toJson(),
      'complete_distance': completeDistance,
      'alternate_route_ids': alternateRoutes?.map((route) => route.alternateRouteId).join(', ') ?? '',
      'miles_added': alternateRoutes?.map((route) => route.milesAdded).join(', ') ?? '',
      'miles_skipped': alternateRoutes?.map((route) => route.milesSkipped).join(', ') ?? '',
      'start_location': optionalFields?.startLocation,
      'end_location': optionalFields?.endLocation,
      'camp_type': optionalFields?.campType,
      'elevation_gain': optionalFields?.elevationGain,
      'elevation_loss': optionalFields?.elevationLoss,
      'notes': optionalFields?.notes,
      'town': optionalFields?.town?.join(', ') ?? '',
      'wildlife': optionalFields?.wildlife != null
          ? jsonEncode(optionalFields!.wildlife)
          : jsonEncode({}),
      'gear_used': optionalFields?.gearUsed != null
          ? jsonEncode(optionalFields!.gearUsed!.map((g) => g.toJson()).toList())
          : jsonEncode([]),
      'custom_fields': optionalFields?.customFields != null
          ? jsonEncode(optionalFields!.customFields)
          : jsonEncode({}),
    };
  }
}

class CoreDataEntry{
  final DateTime currentDate;     
  final double startMile;      
  final double endMile;        
  final TrailJournal trailJournal;    

  CoreDataEntry({
    required this.currentDate,
    required this.startMile,
    required this.endMile, 
    required this.trailJournal,
  });

  factory CoreDataEntry.fromJson(Map<String, dynamic> json) {
    return CoreDataEntry(
      currentDate: DateTime.parse(json['currentDate']),
      startMile: json['startMile'],
      endMile: json['endMile'],
      trailJournal: TrailJournal.fromJson(json['trailJournal']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentDate': currentDate.toIso8601String(),
      'startMile': startMile,
      'endMile': endMile,
      'trailJournal': trailJournal.toJson(),
    };
  }
}

class OptionalFields{
  final String? startLocation; 
  final String? endLocation; 
  final String? campType; 
  final double? elevationGain; 
  final double? elevationLoss; 
  final String? notes; 
  final List<String>? town; 
  final Map<String, int>? wildlife; 
  final List<FullDataEntryGear>? gearUsed; 
  final Map<String, dynamic> customFields; 

  OptionalFields({
    this.startLocation,
    this.endLocation,
    this.campType,
    this.elevationGain,
    this.elevationLoss,
    this.notes,
    this.town,
    this.wildlife,
    this.gearUsed,
    Map<String, dynamic>? customFields,
  }) : customFields = customFields ?? {}; 

  Map<String, dynamic> toJson() {
    return {
      'startLocation': startLocation,
      'endLocation': endLocation,
      'campType': campType,
      'elevationGain': elevationGain,
      'elevationLoss': elevationLoss,
      'notes': notes,
      'town': town,
      'wildlife': wildlife,
      'gearUsed': gearUsed?.map((g) => g.toJson()).toList(),
      'customFields': customFields,
    };
  }

  factory OptionalFields.fromJson(Map<String, dynamic> json) {
    return OptionalFields(
      startLocation: json['startLocation'],
      endLocation: json['endLocation'],
      campType: json['campType'],
      elevationGain: (json['elevationGain'] as num?)?.toDouble(),
      elevationLoss: (json['elevationLoss'] as num?)?.toDouble(),
      notes: json['notes'],
      town: json['town'] != null ? List<String>.from(json['town']) : null,
      wildlife: json['wildlife'] != null
          ? Map<String, int>.from(json['wildlife'])
          : null,
      gearUsed: json['gearUsed'] != null
          ? (json['gearUsed'] as List).map((gear) => FullDataEntryGear.fromJson(gear)).toList()
          : null,
      customFields: json['customFields'] != null
          ? Map<String, dynamic>.from(json['customFields'])
          : {},
    );
  }
}
