// models/gear.dart
// Represents a piece of hiking gear (boots, tent, pack, etc.)

class Gear {
  final int? id;
  final String name;
  final String? category; // "Footwear", "Shelter", "Pack", etc.
  final DateTime startDate;
  final DateTime? endDate;
  
  Gear({
    this.id,
    required this.name,
    this.category,
    DateTime? startDate,
    this.endDate,
  }) : startDate = startDate ?? DateTime.now();

  bool get isActive => endDate == null;

  bool isActiveOn(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    
    if (dateOnly.isBefore(start)) return false;
    
    if (endDate == null) return true;
    
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return !dateOnly.isAfter(end);
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
    };
  }
  
  factory Gear.fromMap(Map<String, dynamic> map) {
    return Gear(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: map['category'] as String?,
      startDate: map['start_date'] != null             
        ? DateTime.parse(map['start_date'] as String)
        : DateTime.now(),
      endDate: map['end_date'] != null
        ? DateTime.parse(map['end_date'] as String)
        : null,
    );
  }
  
  Gear copyWith({
    int? id,
    String? name,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return Gear(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
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
