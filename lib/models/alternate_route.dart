class AlternateRoute {
  final int? id;
  final String name; // Required
  final double distanceAdded; // Required (Minimum info needed)
  final double distanceSkipped; // Required (Minimum info needed)
  final String? startDate; // Optional (Calculated based on usage)
  final String? endDate; // Optional (Calculated based on usage)

  AlternateRoute({
    this.id,
    required this.name,
    required this.distanceAdded, // Required
    required this.distanceSkipped, // Required
    this.startDate, // Optional
    this.endDate, // Optional
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'route_name': name,
      'distance_added': distanceAdded,
      'distance_skipped': distanceSkipped,
      'start_date': startDate,
      'end_date': endDate,
    };
  }

  factory AlternateRoute.fromJson(Map<String, dynamic> json) {
    return AlternateRoute(
      id: json['id'],
      name: json['route_name'],
      distanceAdded: (json['distance_added'] as num).toDouble(),
      distanceSkipped: (json['distance_skipped'] as num).toDouble(),
      startDate: json['start_date'], // Nullable
      endDate: json['end_date'], // Nullable
    );
  }
}

class FullDataEntryAlternateRoute {
  final int? id;
  final int fullDataEntryId;
  final int alternateRouteId;
  final bool startOnAlternate;
  final bool endOnAlternate;

  FullDataEntryAlternateRoute({
    this.id,
    required this.fullDataEntryId,
    required this.alternateRouteId,
    bool? startOnAlternate,
    bool? endOnAlternate,
  })  : startOnAlternate = startOnAlternate ?? false,
        endOnAlternate = endOnAlternate ?? false;

  factory FullDataEntryAlternateRoute.fromJson(Map<String, dynamic> json) {
    return FullDataEntryAlternateRoute(
      id: json['id'],
      fullDataEntryId: json['fullDataEntryId'],
      alternateRouteId: json['alternateRouteId'],
      startOnAlternate: json['startOnAlternate'] ?? false,
      endOnAlternate: json['endOnAlternate'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullDataEntryId': fullDataEntryId,
      'alternateRouteId': alternateRouteId,
      'startOnAlternate': startOnAlternate,
      'endOnAlternate': endOnAlternate,
    };
  }
}
