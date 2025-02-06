import 'trail_journal.dart';
import 'alternate_route.dart';
import 'gear.dart';

// FullDataEntry class to represent a single row in the dataset corresponding to a single day on the trail
class FullDataEntry {
  final int? id;
  final CoreDataEntry coreDataEntry;
  final List<FullDataEntryAlternateRoute>? alternateRoutes;
  final OptionalFields? optionalFields;

  FullDataEntry({
    this.id,
    required this.coreDataEntry,
    this.alternateRoutes,
    this.optionalFields
  });

  factory FullDataEntry.fromJson(Map<String, dynamic> json) {
    return FullDataEntry(
      id: json['id'],
      coreDataEntry: CoreDataEntry.fromJson(json['coreDataEntry']),
      alternateRoutes: (json['alternate_routes'] as List?)
          ?.map((a) => FullDataEntryAlternateRoute.fromJson(a))
          .toList(),
      optionalFields: json['optionalFields'] != null
          ? OptionalFields.fromJson(json['optionalFields'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'coreDataEntry': coreDataEntry.toJson(),
      'alternate_routes': alternateRoutes?.map((a) => a.toJson()).toList(),
      'optionalFields': optionalFields?.toJson(),
    };
  }
}

// Minimum required fields for an entry
class CoreDataEntry{
  final DateTime currentDate;     // Corresponds to the 'Current Date' column
  final double start;      // Corresponds to the 'Start' column where value is a measure of distance
  final double end;        // Corresponds to the 'End' column where value is a measure of distance
  final TrailJournal trailJournal;    // Reference to the TrailJournal object

  CoreDataEntry({
    required this.currentDate,
    required this.start,
    required this.end,
    required this.trailJournal,
  });

  factory CoreDataEntry.fromJson(Map<String, dynamic> json) {
    return CoreDataEntry(
      currentDate: DateTime.parse(json['currentDate']),
      start: json['start'],
      end: json['end'],
      trailJournal: TrailJournal.fromJson(json['trailJournal']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentDate': currentDate.toIso8601String(),
      'start': start,
      'end': end,
      'trailJournal': trailJournal.toJson(),
    };
  }
}

class OptionalFields{
  final String? startLocation; // Corresponds to the 'Start Location' column
  final String? endLocation; // Corresponds to the 'End Location' column
  final String? campType; // Corresponds to the 'Sleep Type' column, options being Tent, Cowboy, Shelter, Bed, or Other
  final double? elevationGain; // Corresponds to the 'Elevation Gain' column where value is a measure of distance
  final double? elevationLoss; // Corresponds to the 'Elevation Loss' column where value is a measure of distance
  final String? notes; // Corresponds to the 'Notes' column
  final Map<String, int>? wildlife; // Corresponds to the 'Wildlife' column
  final List<FullDataEntryGear>? gearUsed;  // List of all gear used (shoes + custom gear)
  final Map<String, dynamic> customFields; // Custom fields

  OptionalFields({
    this.startLocation,
    this.endLocation,
    this.campType,
    this.elevationGain,
    this.elevationLoss,
    this.notes,
    this.wildlife,
    this.gearUsed,
    Map<String, dynamic>? customFields,
  }) : customFields = customFields ?? {}; // Ensure it's initialized

  // Method to convert an OptionalFields instance to a JSON object
  Map<String, dynamic> toJson() {
    return {
      'startLocation': startLocation,
      'endLocation': endLocation,
      'campType': campType,
      'elevationGain': elevationGain,
      'elevationLoss': elevationLoss,
      'notes': notes,
      'wildlife': wildlife,
      'gearUsed': gearUsed?.map((g) => g.toJson()).toList(),
      'customFields': customFields,
    };
  }

  // Method to create an instance of OptionalFields from a JSON object
  factory OptionalFields.fromJson(Map<String, dynamic> json) {
    return OptionalFields(
      startLocation: json['startLocation'],
      endLocation: json['endLocation'],
      campType: json['campType'],
      elevationGain: json['elevationGain'],
      elevationLoss: json['elevationLoss'],
      notes: json['notes'],
      wildlife: json['wildlife'] != null
          ? Map<String, int>.from(json['wildlife'])
          : null,
      gearUsed: (json['gear_used'] as List?)
          ?.map((gear) => FullDataEntryGear.fromJson(gear))
          .toList(),
      customFields: json['customFields'] != null
          ? Map<String, dynamic>.from(json['customFields'])
          : {},
    );
  }
}
