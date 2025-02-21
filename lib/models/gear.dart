
// Offer user option to enter shoes and custom gear. If they enter something in shoe field, type is automatically shoe
// If they enter something in custom field, type is automatically whatever type they entered
class GearItem { 
  final int? id;
  final String name; // e.g., "Altra Lone Peak 7", "Osprey Exos 58"
  final String type; // "Shoes", "Backpack", "Trekking Poles", etc.

  GearItem({
    this.id,
    required this.name,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
    };
  }

  factory GearItem.fromJson(Map<String, dynamic> json) {
    return GearItem(
      id: json['id'],
      name: json['name'],
      type: json['type'],
    );
  }
}

class FullDataEntryGear {
  final int id;
  final int fullDataEntryId; // Links to FullDataEntry (one per day)
  final int gearItemId; // Links to GearItem

  FullDataEntryGear({
    required this.id,
    required this.fullDataEntryId,
    required this.gearItemId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_data_entry_id': fullDataEntryId,
      'gear_item_id': gearItemId,
    };
  }

  factory FullDataEntryGear.fromJson(Map<String, dynamic> json) {
    return FullDataEntryGear(
      id: json['id'],
      fullDataEntryId: json['full_data_entry_id'],
      gearItemId: json['gear_item_id'],
    );
  }
}
