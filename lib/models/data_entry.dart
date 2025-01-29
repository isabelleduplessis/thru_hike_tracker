import 'trail_journal.dart';

/*
Still TBD if I want to include trail section right now
class TrailSection { // get trail sections from database
  final String sectionName;
  final double startMarker;
  final double endMarker;

  TrailSection({
    required this.sectionName,
    required this.startMarker,
    required this.endMarker,
  });

  factory TrailSection.fromJson(Map<String, dynamic> json) {
    return TrailSection(
      sectionName: json['sectionName'],
      startMarker: json['startMarker'],
      endMarker: json['endMarker'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sectionName': sectionName,
      'startMarker': startMarker,
      'endMarker': endMarker,
    };
  }
}
*/

// FullDataEntry class to represent a single row in the dataset corresponding to a single day on the trail
// Consider adding ID number for each entry
class FullDataEntry {
  final int? id;
  final CoreDataEntry coreDataEntry;
  final List<AlternateRoute>? alternates;
  final Camp? camp;
  final ElevationChange? elevationChange;
  final BonusInfo? bonusInfo;

  FullDataEntry({
    this.id,
    required this.coreDataEntry,
    this.alternates,
    this.camp,
    this.elevationChange,
    this.bonusInfo,
  });

  factory FullDataEntry.fromJson(Map<String, dynamic> json) {
    return FullDataEntry(
      id: json['id'],
      coreDataEntry: CoreDataEntry.fromJson(json['coreDataEntry']),
      alternates: json['alternates'] != null
          ? (json['alternates'] as List<dynamic>)
              .map((alt) => AlternateRoute.fromJson(alt))
              .toList()
          : null,
      camp: json['camp'] != null ? Camp.fromJson(json['camp']) : null,
      elevationChange: json['elevationChange'] != null
          ? ElevationChange.fromJson(json['elevationChange'])
          : null,
      bonusInfo: json['bonusInfo'] != null
          ? BonusInfo.fromJson(json['bonusInfo'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'coreDataEntry': coreDataEntry.toJson(),
      'alternates': alternates?.map((alt) => alt.toJson()).toList(),
      'camp': camp?.toJson(),
      'elevationChange': elevationChange?.toJson(),
      'bonusInfo': bonusInfo?.toJson(),
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

  // Day-level calculations:

  // Getter for the distance covered on this day
  double get distance => end - start;


  // Getter for the day number on the trail
  int get trailDayNumber {
    // Calculate the difference in days between the start date of the trail and the current date
    return currentDate.difference(trailJournal.startDate).inDays + 1;  // +1 to start counting from Day 1
  }

}

// To be used for sidequests (additional miles), alternates (additional and skipped miles), and closures (skipped miles)
// These will be stored at the Trail level
class AlternateRoute{ 
  final String? name; // Corresponds to the 'Name' column
  final double? distanceAdded; // Corresponds to the 'Distance Added' column where value is a measure of distance
  final double? distanceSkipped; // Corresponds to the 'Distance Skipped' column where value is a measure of distance

  /*
  Examples:
  name: Kearsarge Pass Trail, Eagle Creek Alternate, William's Mine Fire Closure
  distanceAdded: 7.8, 15.5, 0.0
  distanceSkipped: 0.0, 19.0, 22.0

  */

  AlternateRoute({
    this.name,
    this.distanceAdded,
    this.distanceSkipped,
  });

  // Factory constructor to create an instance of AlternateRoute from a JSON object
  factory AlternateRoute.fromJson(Map<String, dynamic> json) {
    return AlternateRoute(
      name: json['name'],
      distanceAdded: (json['distanceAdded'] as num?)?.toDouble(),
      distanceSkipped: (json['distanceSkipped'] as num?)?.toDouble(),
    );
  }

  // Method to convert an AlternateRoute instance to a JSON object
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'distanceAdded': distanceAdded,
      'distanceSkipped': distanceSkipped,
    };
  }
}

class Camp{
  final String? startLocation; // Corresponds to the 'Start Location' column
  final String? endLocation; // Corresponds to the 'End Location' column
  final String? campType; // Corresponds to the 'Sleep Type' column, options being Tent, Cowboy, Shelter, Bed, or Other

  Camp({
    this.startLocation,
    this.endLocation,
    this.campType,
  });

  // Method to convert a Camp instance to a JSON object
  Map<String, dynamic> toJson() {
    return {
      'startLocation': startLocation,
      'endLocation': endLocation,
      'campType': campType,
    };
  }

  // Method to create an instance of Camp from a JSON object
  factory Camp.fromJson(Map<String, dynamic> json) {
    return Camp(
      startLocation: json['startLocation'],
      endLocation: json['endLocation'],
      campType: json['campType'],
    );
  }
}

class ElevationChange{ // Both are entered as positive values
  final double? elevationGain; // Corresponds to the 'Elevation Gain' column where value is a measure of distance
  final double? elevationLoss; // Corresponds to the 'Elevation Loss' column where value is a measure of distance

  ElevationChange({
    this.elevationGain,
    this.elevationLoss,
  });

  // Getter for the net elevation change on this day
  double get totalElevationChange { 
    return (elevationGain ?? 0.0) - (elevationLoss ?? 0.0);
  }

  // Method to convert an ElevationChange instance to a JSON object
  Map<String, dynamic> toJson() {
    return {
      'elevationGain': elevationGain,
      'elevationLoss': elevationLoss,
    };
  }

  // Method to create an instance of ElevationChange from a JSON object
  factory ElevationChange.fromJson(Map<String, dynamic> json) {
    return ElevationChange(
      elevationGain: (json['elevationGain'] as num?)?.toDouble(),
      elevationLoss: (json['elevationLoss'] as num?)?.toDouble(),
    );
  }
}

class BonusInfo{
  final String? notes; // Corresponds to the 'Notes' column
  final Map<String, int>? wildlife; // Corresponds to the 'Wildlife' column
  final String? resupply; // Corresponds to the 'Resupply' column, options being Full, Partial, or None
  final String? townDay; // Corresponds to the 'Town Day' column, options 1 or 0 where 1 indicates a day spent in town (consider asking about hero or nero)
  final int? shower; // Corresponds to the 'Shower' column where 1 indicates a shower taken and 0 indicates no shower taken
  final String? shoes; // Corresponds to the 'Shoes' column
  final int? trailMagic; // Corresponds to the 'Trail Magic' column where value is the number of trail magics experienced
  final Map<String, dynamic> customFields; // Custom fields

  BonusInfo({
    this.notes,
    this.wildlife,
    this.resupply,
    this.townDay,
    this.shower,
    this.shoes,
    this.trailMagic,
    Map<String, dynamic>? customFields,
  }) : customFields = customFields ?? {}; // Ensure it's initialized

  // Method to convert a BonusInfo instance to a JSON object
  Map<String, dynamic> toJson() {
    return {
      'notes': notes,
      'wildlife': wildlife,
      'resupply': resupply,
      'townDay': townDay,
      'shower': shower,
      'shoes': shoes,
      'trailMagic': trailMagic,
    };
  }

  // Method to create an instance of BonusInfo from a JSON object
  factory BonusInfo.fromJson(Map<String, dynamic> json) {
    return BonusInfo(
      notes: json['notes'],
      wildlife: json['wildlife'] != null
          ? Map<String, int>.from(json['wildlife'])
          : null,
      resupply: json['resupply'],
      townDay: json['townDay'],
      shower: json['shower'],
      shoes: json['shoes'],
      trailMagic: json['trailMagic'],
    );
  }
}



/// Daily entries should be complete for now
/// Still need to do whole trail calculations

/* NEXT STEPS
* Work on trail section sql databases
* work on section of trail calculations for each day
* nero calculations for each day - add this later
* direction for each day - done



*/


/* calculated for each day
* section of trail - add this later
* direction - DONE
* day # - DONE
*distance - DONE
*zero/nero - add this later
*/

/* Calculated for whole trail
* total trail mileage
* total mileage including alternates and side quests
* percent of trail completed
* percent of each section completed
* total days on trail
* total miles on current pair of shoes
* number of resupplies
* number of town days
* number of trail magics
* number of wildlife sightings
* number of zeros/neros
*/


// have an option in settings to set nero threshold

// consider adding campfires, number of hitches, CUSTOM FIELDS FOR PEOPLE TO TRACK

// maybe for now I don't need towns - no you don't yet