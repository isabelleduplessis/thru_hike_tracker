// models/section.dart
// Represents a specific portion of a trail (e.g., "The Sierras", "Section J")
// Also contains the Alternate class for off-trail alternate routes

class Section {
  final int? id;
  final int? tripId;
  final String name;
  final double startMile;
  final double endMile;
  final bool completed;

  Section({
    this.id,
    this.tripId,
    required this.name,
    required this.startMile,
    required this.endMile,
    this.completed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'name': name,
      'start_mile': startMile,
      'end_mile': endMile,
      'completed': completed ? 1 : 0,
    };
  }

  factory Section.fromMap(Map<String, dynamic> map) {
    return Section(
      id: map['id'] as int?,
      tripId: map['trip_id'] as int?,
      name: map['name'] as String,
      startMile: (map['start_mile'] as num).toDouble(),
      endMile: (map['end_mile'] as num).toDouble(),
      completed: (map['completed'] as int? ?? 0) == 1,
    );
  }

  bool containsMile(double mile) {
    return mile >= startMile && mile <= endMile;
  }

  Section copyWith({
    int? id,
    int? tripId,
    String? name,
    double? startMile,
    double? endMile,
    bool? completed,
  }) {
    return Section(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      name: name ?? this.name,
      startMile: startMile ?? this.startMile,
      endMile: endMile ?? this.endMile,
      completed: completed ?? this.completed,
    );
  }
}

// ── Alternate ─────────────────────────────────────────────────────────────────
// Represents an off-trail alternate route
// departure_mile and return_mile are in main trail miles
// length is the total length of the alternate itself (independent of trail miles)
// start_mile and end_mile on entries are in alternate miles when alternate_id is set

class Alternate {
  final int? id;
  final int? tripId;
  final String name;
  final double departureMile;  // trail mile where alternate begins
  final double returnMile;     // trail mile where alternate rejoins
  final double length;         // total length of the alternate route
  final bool completed;

  Alternate({
    this.id,
    this.tripId,
    required this.name,
    required this.departureMile,
    required this.returnMile,
    required this.length,
    this.completed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'name': name,
      'departure_mile': departureMile,
      'return_mile': returnMile,
      'length': length,
      'completed': completed ? 1 : 0,
    };
  }

  factory Alternate.fromMap(Map<String, dynamic> map) {
    return Alternate(
      id: map['id'] as int?,
      tripId: map['trip_id'] as int?,
      name: map['name'] as String,
      departureMile: (map['departure_mile'] as num).toDouble(),
      returnMile: (map['return_mile'] as num).toDouble(),
      length: (map['length'] as num).toDouble(),
      completed: (map['completed'] as int? ?? 0) == 1,
    );
  }

  Alternate copyWith({
    int? id,
    int? tripId,
    String? name,
    double? departureMile,
    double? returnMile,
    double? length,
    bool? completed,
  }) {
    return Alternate(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      name: name ?? this.name,
      departureMile: departureMile ?? this.departureMile,
      returnMile: returnMile ?? this.returnMile,
      length: length ?? this.length,
      completed: completed ?? this.completed,
    );
  }
}