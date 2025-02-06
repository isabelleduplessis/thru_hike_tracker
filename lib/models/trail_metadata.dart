import 'trail_properties.dart';


class Section{
  final String name;          // Name of the section (e.g., "Desert", "Sierra")
  final double endMile;       // End mile marker
  final String trailId;       // Reference to the trail (e.g., PCT, CDT)

  Section({
    required this.name,
    required this.endMile,
    required this.trailId,
  });

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      name: json['name'],
      endMile: json['endMile'],
      trailId: json['trailId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'endMile': endMile,
      'trailId': trailId,
    };
  }
}

class DefinedTrail{
  final int? id;
  final String? trailId; // Identifier for the trail
  final String trailName; // Name of the trail - can still select fr
  final double length; // Length of the trail
  final TrailStructure structure; // Structure of the trail (e.g., out-and-back, loop, point-to-point)
  final TrailDirection defaultDirection; // Default direction of the trail (e.g. NOBO for PCT)
  final List<Section> sections;

  DefinedTrail({
    this.id,
    this.trailId,
    required this.trailName,
    required this.length,
    required this.structure,
    required this.defaultDirection,
    this.sections = const [],
  });

 factory DefinedTrail.fromJson(Map<String, dynamic> json) {
  return DefinedTrail(
    id: json['id'] as int?,
    trailId: json['trailId'] as String?,
    trailName: json['trailName'] as String,
    length: json['length'] as double,
    structure: TrailStructure.values.firstWhere(
      (e) => e.toString() == 'TrailStructure.${json['structure']}',
    ),
    defaultDirection: TrailDirection.values.firstWhere(
      (e) => e.toString() == 'TrailDirection.${json['defaultDirection']}',
    ),
    sections: json['sections'] != null
          ? List<Section>.from(json['sections'].map((e) => Section.fromJson(e)))
          : [],
  );
}


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trailId': trailId,
      'trailName': trailName,
      'length': length,
      'structure': structure.toString().split('.').last,
      'defaultDirection': defaultDirection.toString().split('.').last,
      'sections': sections.map((e) => e.toJson()).toList(),
    };
  }
}

class CustomTrail {
  final int? id;
  final String? trailId; // User-defined identifier for the trail
  final String trailName; // User-defined name for the trail
  final double length; // User-defined length for the trail
  final TrailStructure structure; // User-defined structure for the trail
  final TrailDirection defaultDirection; // User-defined default direction for the trail
  final List<Section> sections;

  CustomTrail({
    this.id,
    this.trailId,
    required this.trailName,
    required this.length,
    required this.structure,
    required this.defaultDirection,
    this.sections = const [],
  });

  factory CustomTrail.fromJson(Map<String, dynamic> json) {
    return CustomTrail(
      id: json['id'] as int?,
      trailId: json['trailId'] as String?,
      trailName: json['trailName'] as String,
      length: json['length'] as double,
      structure: TrailStructure.values.firstWhere(
        (e) => e.toString() == 'TrailStructure.${json['structure']}',
      ),
      defaultDirection: TrailDirection.values.firstWhere(
        (e) => e.toString() == 'TrailDirection.${json['defaultDirection']}',
      ),
      sections: json['sections'] != null
          ? List<Section>.from(json['sections'].map((e) => Section.fromJson(e)))
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return{
      'id': id,
      'trailId': trailId,
      'trailName': trailName,
      'length': length,
      'structure': structure.toString().split('.').last,
      'defaultDirection': defaultDirection.toString().split('.').last,
      'sections': sections.map((e) => e.toJson()).toList(),
    };
  }
}