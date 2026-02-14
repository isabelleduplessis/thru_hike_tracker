// models/gear.dart
// Represents a piece of hiking gear (boots, tent, pack, etc.)

class Gear {
  final int? id;
  final String name;
  final String? category; // "Footwear", "Shelter", "Pack", etc.
  
  Gear({
    this.id,
    required this.name,
    this.category,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
    };
  }
  
  factory Gear.fromMap(Map<String, dynamic> map) {
    return Gear(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: map['category'] as String?,
    );
  }
  
  Gear copyWith({
    int? id,
    String? name,
    String? category,
  }) {
    return Gear(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
    );
  }
}

// This represents the link between an Entry and Gear
// "On this day, I used these pieces of gear"
class EntryGear {
  final int entryId;
  final int gearId;
  
  EntryGear({
    required this.entryId,
    required this.gearId,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'entry_id': entryId,
      'gear_id': gearId,
    };
  }
  
  factory EntryGear.fromMap(Map<String, dynamic> map) {
    return EntryGear(
      entryId: map['entry_id'] as int,
      gearId: map['gear_id'] as int,
    );
  }
}

// This holds calculated stats for a piece of gear
// Not stored in database - calculated on the fly
class GearStats {
  final Gear gear;
  final double totalMiles;
  final int daysUsed;
  final DateTime? firstUsed;
  final DateTime? lastUsed;
  
  GearStats({
    required this.gear,
    required this.totalMiles,
    required this.daysUsed,
    this.firstUsed,
    this.lastUsed,
  });
}
