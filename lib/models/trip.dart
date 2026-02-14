// models/trip.dart
// Represents a hiking trip or trail (e.g., "PCT 2026", "Weekend Backpack")

class Trip {
  final int? id; // Nullable because new trips don't have an ID yet
  final String name;
  final DateTime startDate;
  final double startMile;
  final TripStatus status;
  final DateTime? endDate; // Nullable - trip might still be active
  
  Trip({
    this.id,
    required this.name,
    required this.startDate,
    this.startMile = 0.0,
    this.status = TripStatus.active,
    this.endDate,
  });
  
  // Convert Trip object to Map (for storing in SQLite)
  // SQLite stores data as key-value maps
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'start_date': startDate.toIso8601String(), // Convert DateTime to string
      'start_mile': startMile,
      'status': status.index, // Store enum as integer (0, 1, 2)
      'end_date': endDate?.toIso8601String(), // ? means "if not null"
    };
  }
  
  // Create Trip object from Map (when reading from SQLite)
  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'] as int?,
      name: map['name'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      startMile: map['start_mile'] as double,
      status: TripStatus.values[map['status'] as int],
      endDate: map['end_date'] != null 
          ? DateTime.parse(map['end_date'] as String)
          : null,
    );
  }
  
  // Create a copy of this Trip with some fields changed
  // Useful for updating trips without mutating the original
  Trip copyWith({
    int? id,
    String? name,
    DateTime? startDate,
    double? startMile,
    TripStatus? status,
    DateTime? endDate,
  }) {
    return Trip(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      startMile: startMile ?? this.startMile,
      status: status ?? this.status,
      endDate: endDate ?? this.endDate,
    );
  }
}

// Enum for trip status
// Enums are type-safe constants - can only be these values
enum TripStatus {
  planning,  // index 0
  active,    // index 1
  completed, // index 2
}
