// models/custom_field.dart
// Custom field definitions that can be reused across trips

enum CustomFieldType {
  text,
  number,
  checkbox,
  rating,
}

// A custom field definition (e.g., "Bears seen" as a number field)
class CustomField {
  final int? id;
  final String name;
  final CustomFieldType type;
  
  CustomField({
    this.id,
    required this.name,
    required this.type,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.index,  // Store as 0, 1, 2, 3
    };
  }
  
  factory CustomField.fromMap(Map<String, dynamic> map) {
    return CustomField(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: CustomFieldType.values[map['type'] as int],
    );
  }
  
  CustomField copyWith({
    int? id,
    String? name,
    CustomFieldType? type,
  }) {
    return CustomField(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
    );
  }
}

// Links a custom field to a trip with display order
class TripCustomField {
  final int tripId;
  final int customFieldId;
  final int displayOrder;
  
  TripCustomField({
    required this.tripId,
    required this.customFieldId,
    required this.displayOrder,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'trip_id': tripId,
      'custom_field_id': customFieldId,
      'display_order': displayOrder,
    };
  }
  
  factory TripCustomField.fromMap(Map<String, dynamic> map) {
    return TripCustomField(
      tripId: map['trip_id'] as int,
      customFieldId: map['custom_field_id'] as int,
      displayOrder: map['display_order'] as int,
    );
  }
}

// Stores the actual value of a custom field for a specific entry
class CustomFieldValue {
  final int entryId;
  final int customFieldId;
  final String value;  // Store everything as string, parse based on field type
  
  CustomFieldValue({
    required this.entryId,
    required this.customFieldId,
    required this.value,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'entry_id': entryId,
      'custom_field_id': customFieldId,
      'value': value,
    };
  }
  
  factory CustomFieldValue.fromMap(Map<String, dynamic> map) {
    return CustomFieldValue(
      entryId: map['entry_id'] as int,
      customFieldId: map['custom_field_id'] as int,
      value: map['value'] as String,
    );
  }
}

// Helper class to hold a field with its value (for display in entry form)
class CustomFieldWithValue {
  final CustomField field;
  final String? value;
  
  CustomFieldWithValue({
    required this.field,
    this.value,
  });
}

// Helper class for displaying stats
class CustomFieldStat {
  final CustomField field;
  final String displayValue;
  final String label;
  
  CustomFieldStat({
    required this.field,
    required this.displayValue,
    required this.label,
  });
}