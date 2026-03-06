// models/section.dart
// Represents a specific portion of a trail (e.g., "The Sierras", "Section J")

class Section {
  final int? id;
  final int? tripId; // Link to the parent Trip
  final String name;
  final double startMile;
  final double endMile;

  Section({
    this.id,
    this.tripId,
    required this.name,
    required this.startMile,
    required this.endMile,
  });

  // Convert Section to Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'name': name,
      'start_mile': startMile,
      'end_mile': endMile,
    };
  }

  // Create Section from Map
  factory Section.fromMap(Map<String, dynamic> map) {
    return Section(
      id: map['id'] as int?,
      tripId: map['trip_id'] as int?,
      name: map['name'] as String,
      startMile: (map['start_mile'] as num).toDouble(),
      endMile: (map['end_mile'] as num).toDouble(),
    );
  }

  // Helper to check if a specific mile marker falls within this section
  bool containsMile(double mile) {
    return mile >= startMile && mile <= endMile;
  }

  Section copyWith({
    int? id,
    int? tripId,
    String? name,
    double? startMile,
    double? endMile,
  }) {
    return Section(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      name: name ?? this.name,
      startMile: startMile ?? this.startMile,
      endMile: endMile ?? this.endMile,
    );
  }
}