import 'data_entry.dart';
import 'alternate_route.dart';
import 'trail_properties.dart';

class TrailJournal{
  final int? id;
  final String trailName; // Corresponds to the 'Trail Name' column
  final DateTime startDate; // Corresponds to the 'Start Date' column
  final String startLocation; // Corresponds to the 'Start Location' column
  final TrailDirection initialDirection; // Corresponds to the 'Trail Direction' column (E.g. NOBO, SOBO, EABO, WEBO)
  //final List<TrailSection> sections; // Sections loaded from database
  final List<CoreDataEntry> entries; // List of CoreDataEntry objects where each is an instance of the CoreDataEntry class
  final List <AlternateRoute>? alternates; // List of AlternateRoute objects where each is an instance of the AlternateRoute class
  final double? neroThreshold; // Corresponds to the 'Near-Zero Threshold' column

  TrailJournal({
    this.id,
    required this.trailName,
    required this.startDate,
    required this.startLocation,
    required this.initialDirection,
    //required this.sections,
    required this.entries,
    this.alternates,
    this.neroThreshold,
  });

  factory TrailJournal.fromJson(Map<String, dynamic> json) {
    return TrailJournal(
      id: json['id'],
      startDate: DateTime.parse(json['startDate']),
      trailName: json['trailName'],
      startLocation: json['startLocation'],
      initialDirection: TrailDirection.values.firstWhere(
        (e) => e.toString().split('.').last == json['initialDirection'],
        orElse: () => TrailDirection.noBo, // Default value if missing/invalid
      ),
      //sections: (json['sections'] as List<dynamic>)
          //.map((section) => TrailSection.fromJson(section))
          //.toList(),
      entries: (json['entries'] as List<dynamic>)
          .map((entry) => CoreDataEntry.fromJson(entry))
          .toList(),
      alternates: json['alternates'] != null
          ? (json['alternates'] as List<dynamic>)
              .map((alt) => AlternateRoute.fromJson(alt))
              .toList()
          : null,
      neroThreshold: json['neroThreshold'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startDate': startDate.toIso8601String(),
      'trailName': trailName,
      'startLocation': startLocation,
      'initialDirection': initialDirection.toString().split('.').last, // Convert enum to string
      //'sections': sections.map((section) => section.toJson()).toList(),
      'entries': entries.map((entry) => entry.toJson()).toList(),
      'alternates': alternates?.map((alt) => alt.toJson()).toList(),
      'neroThreshold': neroThreshold,
    };
  }
}
