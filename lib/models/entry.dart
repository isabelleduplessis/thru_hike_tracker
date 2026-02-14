// models/entry.dart
// Represents a single day's hiking entry

enum Direction {
  nobo,   // Northbound
  sobo,   // Southbound
  eabo,
  webo,
  forward,
  backward, 
  clockwise,
  counterclockwise,
}

class Entry {
  final int? id;
  final int tripId; // Foreign key - which trip does this entry belong to?
  final DateTime date;
  final double startMile;
  final double endMile;
  final double extraMiles; // Side trails, detours, etc.
  final double skippedMiles; // Sections skipped (hitchhiked, etc.)
  final String? location; // Campsite name, town, etc. (optional)
  final bool? tentOrShelter; // true = tent, false = shelter, null = not specified
  final bool? shower; // Did they shower today?
  final String notes;
  final Direction? direction;
  
  Entry({
    this.id,
    required this.tripId,
    required this.date,
    required this.startMile,
    required this.endMile,
    this.extraMiles = 0.0,
    this.skippedMiles = 0.0,
    this.location,
    this.tentOrShelter,
    this.shower,
    this.notes = '',
    this.direction,
  });
  
  // Calculated property - net distance from start to end
  double get netDistance => endMile - startMile;
  
  // Calculated property - total distance including adjustments
  // This is what gets added to stats and gear mileage
  double get totalDistance => netDistance + extraMiles - skippedMiles;
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'date': date.toIso8601String(),
      'start_mile': startMile,
      'end_mile': endMile,
      'extra_miles': extraMiles,
      'skipped_miles': skippedMiles,
      'location': location,
      'tent_or_shelter': tentOrShelter != null ? (tentOrShelter! ? 1 : 0) : null,
      'shower': shower != null ? (shower! ? 1 : 0) : null,
      'notes': notes,
      'direction': direction?.index,
    };
  }
  
  factory Entry.fromMap(Map<String, dynamic> map) {
    return Entry(
      id: map['id'] as int?,
      tripId: map['trip_id'] as int,
      date: DateTime.parse(map['date'] as String),
      startMile: map['start_mile'] as double,
      endMile: map['end_mile'] as double,
      extraMiles: (map['extra_miles'] as num?)?.toDouble() ?? 0.0,
      skippedMiles: (map['skipped_miles'] as num?)?.toDouble() ?? 0.0,
      location: map['location'] as String?,
      tentOrShelter: map['tent_or_shelter'] != null 
          ? (map['tent_or_shelter'] as int) == 1
          : null,
      shower: map['shower'] != null 
          ? (map['shower'] as int) == 1
          : null,
      notes: map['notes'] as String? ?? '',
      direction: map['direction'] != null  // ← ADD THESE LINES
        ? Direction.values[map['direction'] as int]
        : null,
    );
  }
  
  Entry copyWith({
    int? id,
    int? tripId,
    DateTime? date,
    double? startMile,
    double? endMile,
    double? extraMiles,
    double? skippedMiles,
    String? location,
    bool? tentOrShelter,
    bool? shower,
    String? notes,
    Direction? direction,
  }) {
    return Entry(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      date: date ?? this.date,
      startMile: startMile ?? this.startMile,
      endMile: endMile ?? this.endMile,
      extraMiles: extraMiles ?? this.extraMiles,
      skippedMiles: skippedMiles ?? this.skippedMiles,
      location: location ?? this.location,
      tentOrShelter: tentOrShelter ?? this.tentOrShelter,
      shower: shower ?? this.shower,
      notes: notes ?? this.notes,
      direction: direction ?? this.direction,
    );
  }
}
