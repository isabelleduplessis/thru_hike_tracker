import 'data_entry.dart';

enum TrailDirection { // referring to where they want mile 0 to start and what direction the miles increase in
  noBo, // Northbound
  soBo, // Southbound
  eaBo, // Eastbound
  weBo, // Westbound
  clockWise, // Clockwise
  counterClockWise, // Counter-clockwise
  forward, // Forward
  backward,; // Backward

// Method to get the opposite direction
  TrailDirection get opposite {
    switch (this) {
      case TrailDirection.noBo:
        return TrailDirection.soBo;
      case TrailDirection.soBo:
        return TrailDirection.noBo;
      case TrailDirection.eaBo:
        return TrailDirection.weBo;
      case TrailDirection.weBo:
        return TrailDirection.eaBo;
      case TrailDirection.clockWise:
        return TrailDirection.counterClockWise;
      case TrailDirection.counterClockWise:
        return TrailDirection.clockWise;
      case TrailDirection.forward:
        return TrailDirection.backward;
      case TrailDirection.backward:
        return TrailDirection.forward;
    }
  }
}

class TrailJournal{
  final int? id;
  final String trailName; // Corresponds to the 'Trail Name' column
  final DateTime startDate; // Corresponds to the 'Start Date' column
  final String startLocation; // Corresponds to the 'Start Location' column
  final TrailDirection initialDirection; // Corresponds to the 'Trail Direction' column (E.g. NOBO, SOBO, EABO, WEBO)
  //final List<TrailSection> sections; // Sections loaded from database
  final List<CoreDataEntry> entries; // List of CoreDataEntry objects where each is an instance of the CoreDataEntry class
  final List <AlternateRoute>? alternates; // List of AlternateRoute objects where each is an instance of the AlternateRoute class

  TrailJournal({
    this.id,
    required this.trailName,
    required this.startDate,
    required this.startLocation,
    required this.initialDirection,
    //required this.sections,
    required this.entries,
    this.alternates,
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
    };
  }
}