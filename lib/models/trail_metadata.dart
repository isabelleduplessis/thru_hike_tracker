enum TrailStructure {
  outAndBack,
  loop,
  pointToPoint,
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
}