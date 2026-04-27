// lib/models/trip.dart
import 'direction.dart';
import 'section.dart';

class Trip {
  final int? id;
  final String name;
  final DateTime startDate;
  final double startMile;
  final TripStatus status;
  final DateTime? endDate;
  final double tripLength;
  final double endMile;
  final Direction? direction;
  final List<Section> sections;
  final List<Alternate> alternates;
  final bool trackCoordinates;
  final bool trackShower;
  final bool trackElevation;
  final bool trackSleeping;
  final double? neroThreshold;
  
  Trip({
    this.id,
    required this.name,
    required this.startDate,
    this.startMile = 0.0,
    this.status = TripStatus.inProgress,
    this.endDate,
    this.tripLength = 0.0,
    double? endMile,
    this.direction,
    this.sections = const [],
    this.alternates = const [],
    this.trackCoordinates = false,
    this.trackShower = false,
    this.trackElevation = false,
    this.trackSleeping = false,
    this.neroThreshold,
  }) : endMile = endMile ?? (startMile + tripLength);
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'start_date': startDate.toIso8601String(),
      'start_mile': startMile,
      'status': status.index,
      'end_date': endDate?.toIso8601String(),
      'trip_length': tripLength,
      'end_mile': endMile,
      'direction': direction?.index,
      'track_coordinates': trackCoordinates ? 1 : 0,
      'track_shower': trackShower ? 1 : 0,
      'track_elevation': trackElevation ? 1 : 0,
      'track_sleeping': trackSleeping ? 1 : 0,
      'nero_threshold': neroThreshold,
      // sections and alternates stored in separate tables
    };
  }
  
  factory Trip.fromMap(
    Map<String, dynamic> map, {
    List<Section> sections = const [],
    List<Alternate> alternates = const [],
  }) {
    return Trip(
      id: map['id'] as int?,
      name: map['name'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      startMile: (map['start_mile'] as num).toDouble(),
      status: TripStatus.values[map['status'] as int],
      endDate: map['end_date'] != null 
          ? DateTime.parse(map['end_date'] as String)
          : null,
      tripLength: (map['trip_length'] as num?)?.toDouble() ?? 0.0,
      endMile: (map['end_mile'] as num?)?.toDouble() ?? 0.0,
      direction: map['direction'] != null 
          ? Direction.values[map['direction'] as int]
          : null,
      sections: sections,
      alternates: alternates,
      trackCoordinates: (map['track_coordinates'] as int? ?? 0) == 1,
      trackShower: (map['track_shower'] as int? ?? 0) == 1,
      trackElevation: (map['track_elevation'] as int? ?? 0) == 1,
      trackSleeping: (map['track_sleeping'] as int? ?? 0) == 1,
      neroThreshold: map['nero_threshold'] as double?,
    );
  }
  
  Trip copyWith({
    int? id,
    String? name,
    DateTime? startDate,
    double? startMile,
    TripStatus? status,
    DateTime? endDate,
    double? tripLength,
    double? endMile,
    Direction? direction,
    List<Section>? sections,
    List<Alternate>? alternates,
    bool? trackCoordinates,
    bool? trackShower,
    bool? trackElevation,
    bool? trackSleeping,
    double? neroThreshold,
  }) {
    return Trip(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      startMile: startMile ?? this.startMile,
      status: status ?? this.status,
      endDate: endDate ?? this.endDate,
      tripLength: tripLength ?? this.tripLength,
      endMile: endMile ?? this.endMile,
      direction: direction ?? this.direction,
      sections: sections ?? this.sections,
      alternates: alternates ?? this.alternates,
      trackCoordinates: trackCoordinates ?? this.trackCoordinates,
      trackShower: trackShower ?? this.trackShower,
      trackElevation: trackElevation ?? this.trackElevation,
      trackSleeping: trackSleeping ?? this.trackSleeping,
      neroThreshold: neroThreshold ?? this.neroThreshold,
    );
  }
}

enum TripStatus { inProgress, completed }