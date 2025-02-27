
// Offer user option to enter shoes and custom gear. If they enter something in shoe field, type is automatically shoe
// If they enter something in custom field, type is automatically whatever type they entered
class GearItem {
  final int? id;
  final String name; // e.g., "Altra Lone Peak 7"
  final String type; // "Shoes", "Backpack", etc.

  GearItem({
    this.id,
    required this.name,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    final data = {
      'name': name,
      'type': type,
    };
    if (id != null) data['id'] = id.toString();
    return data;
  }

  factory GearItem.fromJson(Map<String, dynamic> json) {
    return GearItem(
      id: json['id'] as int?,
      name: json['name'] as String,
      type: json['type'] as String,
    );
  }
}


class FullDataEntryGear {
  final int? id;
  final int gearItemId; // Foreign key linking to GearItem
  final double milesUsed; // Miles logged for this gear item in one entry

  FullDataEntryGear({
    this.id,
    required this.gearItemId,
    this.milesUsed = 0.0,
  });

  factory FullDataEntryGear.fromJson(Map<String, dynamic> json) {
    return FullDataEntryGear(
      id: json['id'] as int?,
      gearItemId: json['gear_item_id'] as int,
      milesUsed: (json['miles_used'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    final data = {
      'gear_item_id': gearItemId,
      'miles_used': milesUsed,
    };
    if (id != null) data['id'] = id as num;
    return data;
  }
}


