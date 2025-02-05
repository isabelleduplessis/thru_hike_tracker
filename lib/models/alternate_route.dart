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
    required this.startOnAlternate,
    required this.endOnAlternate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_data_entry_id': fullDataEntryId,
      'alternate_route_id': alternateRouteId,
      'start_on_alternate': startOnAlternate ? 1 : 0,
      'end_on_alternate': endOnAlternate ? 1 : 0,
    };
  }

  factory FullDataEntryAlternateRoute.fromJson(Map<String, dynamic> json) {
    return FullDataEntryAlternateRoute(
      id: json['id'],
      fullDataEntryId: json['full_data_entry_id'],
      alternateRouteId: json['alternate_route_id'],
      startOnAlternate: (json['start_on_alternate'] as int) == 1,
      endOnAlternate: (json['end_on_alternate'] as int) == 1,
    );
  }
}