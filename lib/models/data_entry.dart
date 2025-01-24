// Trail information consistent across all entries
class Trail{
  final DateTime startDate; // Corresponds to the 'Start Date' column
  final String trail; // Corresponds to the 'Trail' column
  final String initialDirection; // Corresponds to the 'Trail Direction' column (E.g. NOBO, SOBO, EABO, WEBO)
  final List<TrailSection> sections; // Sections loaded from database
  final List<CoreDataEntry> entries; // List of CoreDataEntry objects where each is an instance of the CoreDataEntry class
  final List <AlternateRoute>? alternates; // List of AlternateRoute objects where each is an instance of the AlternateRoute class

  Trail({
    required this.startDate,
    required this.trail,
    required this.initialDirection,
    required this.sections,
    required this.entries,
    this.alternates,
  });
}

class TrailSection { // get trail sections from database
  final String sectionName;
  final double startMarker;
  final double endMarker;

  TrailSection({
    required this.sectionName,
    required this.startMarker,
    required this.endMarker,
  });
}

// FullDataEntry class to represent a single row in the dataset corresponding to a single day on the trail
class FullDataEntry{
  final CoreDataEntry coreDataEntry; // Corresponds to the CoreDataEntry object
  final List <AlternateRoute>? alternates; // List of AlternateRoute objects because there can be multiple alternates for a single day
  final Camp? camp; // Corresponds to the Camp object
  final ElevationChange? elevationChange; // Corresponds to the ElevationChange object
  final BonusInfo? bonusInfo; // Corresponds to the BonusInfo object

  FullDataEntry({
    required this.coreDataEntry,
    this.alternates,
    this.camp,
    this.elevationChange,
    this.bonusInfo,
  });
}

// Minimum required fields for an entry
class CoreDataEntry{
  final DateTime currentDate;     // Corresponds to the 'Current Date' column
  final double start;      // Corresponds to the 'Start' column where value is a measure of distance
  final double end;        // Corresponds to the 'End' column where value is a measure of distance
  final Trail trail;    // Reference to the Trail object

  CoreDataEntry({
    required this.currentDate,
    required this.start,
    required this.end,
    required this.trail,
  });

  // Day-level calculations:

  // Getter for the distance covered on this day
  double get distance => end - start;

  // Function to reverse direction (if needed)
  String reverseDirection(String direction) {
    switch (direction.toLowerCase()) {
      case "nobo":
        return "SOBO";
      case "sobo":
        return "NOBO";
      case "eabo":
        return "WEBO";
      case "webo":
        return "EABO";
      default:
        throw Exception("Invalid trail direction");
    }
  }

  // Function to calculate direction based on mileage difference
  String calculateDirection(double distance, Trail trail) {
    if (distance > 0) {
      return trail.initialDirection; // Matches the initial direction
    } else {
      return reverseDirection(trail.initialDirection);
    }
  }

  // Getter for the day number on the trail
  int get trailDayNumber {
    // Calculate the difference in days between the start date of the trail and the current date
    return currentDate.difference(trail.startDate).inDays + 1;  // +1 to start counting from Day 1
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
}

class BonusInfo{
  final String? notes; // Corresponds to the 'Notes' column
  final Map<String, int>? wildlife; // Corresponds to the 'Wildlife' column
  final String? resupply; // Corresponds to the 'Resupply' column, options being Full, Partial, or None
  final String? townDay; // Corresponds to the 'Town Day' column, options 1 or 0 where 1 indicates a day spent in town (consider asking about hero or nero)
  final int? shower; // Corresponds to the 'Shower' column where 1 indicates a shower taken and 0 indicates no shower taken
  final String? shoes; // Corresponds to the 'Shoes' column
  final int? trailMagic; // Corresponds to the 'Trail Magic' column where value is the number of trail magics experienced

  BonusInfo({
    this.notes,
    this.wildlife,
    this.resupply,
    this.townDay,
    this.shower,
    this.shoes,
    this.trailMagic,
  });
}



/* NEXT STEPS
* Work on trail section sql databases
* work on section of trail calculations for each day
* nero calculations for each day - add this later
* direction for each day - done



*/


/* calculated for each day
* section of trail
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

// maybe for now I don't need towns