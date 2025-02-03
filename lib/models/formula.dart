
class Formula {
  final String name; // Name of the formula (e.g., "Miles Hiked NOBO")
  final String description; // Description of the formula
  final String query; // SQL query to calculate the result

  Formula({
    required this.name,
    required this.description,
    required this.query,
  });
}