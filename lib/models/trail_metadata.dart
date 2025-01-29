enum TrailStructure {
  outAndBack,
  loop,
  pointToPoint,
  other,
}

class DefinedTrail{
  final int? id;
  final String? trailId; // Identifier for the trail
  final String trailName; // Name of the trail
  final double length; // Length of the trail
  final TrailStructure structure; // Structure of the trail

  DefinedTrail({
    this.id,
    this.trailId,
    required this.trailName,
    required this.length,
    required this.structure,
  });

  factory DefinedTrail.fromJson(Map<String, dynamic> json) {
    return DefinedTrail(
      id: json['id'] as int?,
      trailId: json['trailId'] as String?,
      trailName: json['trailName'] as String,
      length: json['length'] as double,
      structure: TrailStructure.values.firstWhere((e) => e.toString() == 'TrailStructure.${json['structure']}',
        orElse: () => TrailStructure.other, // Fallback to "Other" if missing or invalid
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trailId': trailId,
      'trailName': trailName,
      'length': length,
      'structure': structure.toString().split('.').last,
    };
  }
}

class CustomTrail {
  final int? id;
  final String? trailId; // User-defined identifier for the trail
  final String trailName; // User-defined name for the trail
  final double length; // User-defined length for the trail
  final TrailStructure structure; // User-defined structure for the trail

  CustomTrail({
    this.id,
    this.trailId,
    required this.trailName,
    required this.length,
    required this.structure,
  });

  factory CustomTrail.fromJson(Map<String, dynamic> json) {
    return CustomTrail(
      id: json['id'] as int?,
      trailId: json['trailId'] as String?,
      trailName: json['trailName'] as String,
      length: json['length'] as double,
      structure: TrailStructure.values.firstWhere((e) => e.toString() == 'TrailStructure.${json['structure']}',
        orElse: () => TrailStructure.other, // Fallback to "Other" if missing or invalid
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return{
      'id': id,
      'trailId': trailId,
      'trailName': trailName,
      'length': length,
      'structure': structure.toString().split('.').last,
    };
  }
}