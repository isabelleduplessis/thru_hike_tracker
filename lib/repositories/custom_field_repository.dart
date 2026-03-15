// custom_field_repository.dart
// import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/custom_field.dart';

class CustomFieldRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  // now we add methods

  Future<CustomField> createCustomField(CustomField field) async {
    final db = await _dbHelper.database;
    final id = await db.insert('custom_fields', field.toMap());
    return field.copyWith(id: id);
  }

  // Get all custom fields (for selecting when editing trip)
  Future<List<CustomField>> getAllCustomFields() async {
    final db = await _dbHelper.database;
    final maps = await db.query('custom_fields', orderBy: 'name ASC');
    return maps.map((map) => CustomField.fromMap(map)).toList();
  }

  // Get a single custom field by ID
  Future<CustomField?> getCustomFieldById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'custom_fields',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return CustomField.fromMap(maps.first);
  }

  // Update a custom field (rename only, can't change type)
  Future<int> updateCustomField(CustomField field) async {
    final db = await _dbHelper.database;
    return await db.update(
      'custom_fields',
      field.toMap(),
      where: 'id = ?',
      whereArgs: [field.id],
    );
  }

  // Delete a custom field
  // WARNING: This cascades and deletes all values for this field!
  Future<int> deleteCustomField(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'custom_fields',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== TRIP <-> CUSTOM FIELDS ====================
  // Link custom fields to a trip with display order
  Future<void> setCustomFieldsForTrip(
    int tripId,
    List<CustomField> fields,
  ) async {
    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      // Remove all existing links for this trip
      await txn.delete(
        'trip_custom_fields',
        where: 'trip_id = ?',
        whereArgs: [tripId],
      );
      
      // Add new links with display order
      for (int i = 0; i < fields.length; i++) {
        await txn.insert('trip_custom_fields', {
          'trip_id': tripId,
          'custom_field_id': fields[i].id!,
          'display_order': i,
        });
      }
    });
  }

  // Get custom fields for a trip (in display order)
  Future<List<CustomField>> getCustomFieldsForTrip(int tripId) async {
    final db = await _dbHelper.database;
    
    final maps = await db.rawQuery('''
      SELECT cf.*
      FROM custom_fields cf
      INNER JOIN trip_custom_fields tcf ON cf.id = tcf.custom_field_id
      WHERE tcf.trip_id = ?
      ORDER BY tcf.display_order ASC
    ''', [tripId]);
    
    return maps.map((map) => CustomField.fromMap(map)).toList();
  }

  // ==================== ENTRY VALUES ====================
  // Save custom field values for an entry
  Future<void> saveCustomFieldValues(
    int entryId,
    Map<int, String> values,  // customFieldId -> value
  ) async {
    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      // Delete existing values for this entry
      await txn.delete(
        'custom_field_values',
        where: 'entry_id = ?',
        whereArgs: [entryId],
      );
      
      // Insert new values (only non-empty ones)
      for (final entry in values.entries) {
        if (entry.value.isNotEmpty) {
          await txn.insert('custom_field_values', {
            'entry_id': entryId,
            'custom_field_id': entry.key,
            'value': entry.value,
          });
        }
      }
    });
  }

  // Get custom field values for an entry
  Future<Map<int, String>> getCustomFieldValues(int entryId) async {
    final db = await _dbHelper.database;
    
    final maps = await db.query(
      'custom_field_values',
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );
    
    return {
      for (var map in maps)
        map['custom_field_id'] as int: map['value'] as String,
    };
  }

  // Get custom fields with their values for an entry
  Future<List<CustomFieldWithValue>> getCustomFieldsWithValues(
    int tripId,
    int entryId,
  ) async {
    final fields = await getCustomFieldsForTrip(tripId);
    final values = await getCustomFieldValues(entryId);
    
    return fields.map((field) {
      return CustomFieldWithValue(
        field: field,
        value: values[field.id],
      );
    }).toList();
  }

  // ==================== STATS ====================
  // Get all values for a custom field across all entries in a trip
  Future<List<String>> getCustomFieldValuesForTrip(
    int customFieldId,
    int tripId,
  ) async {
    final db = await _dbHelper.database;
    
    final maps = await db.rawQuery('''
      SELECT cfv.value
      FROM custom_field_values cfv
      INNER JOIN entries e ON cfv.entry_id = e.id
      WHERE cfv.custom_field_id = ? AND e.trip_id = ?
    ''', [customFieldId, tripId]);
    
    return maps.map((m) => m['value'] as String).toList();
  }

  // Get all values for a custom field across ALL trips (lifetime)
  Future<List<String>> getCustomFieldValuesLifetime(int customFieldId) async {
    final db = await _dbHelper.database;
    
    final maps = await db.query(
      'custom_field_values',
      columns: ['value'],
      where: 'custom_field_id = ?',
      whereArgs: [customFieldId],
    );
    
    return maps.map((m) => m['value'] as String).toList();
  }

  // Get custom field stats for a trip
  Future<List<CustomFieldStat>> getCustomFieldStatsForTrip(int tripId) async {
    final fields = await getCustomFieldsForTrip(tripId);
    final stats = <CustomFieldStat>[];
    
    for (final field in fields) {
      // Skip text fields
      if (field.type == CustomFieldType.text) continue;
      
      final values = await getCustomFieldValuesForTrip(field.id!, tripId);
      if (values.isEmpty) continue;
      
      if (field.type == CustomFieldType.number) {
        final total = values
            .map((v) => double.tryParse(v) ?? 0.0)
            .fold(0.0, (sum, v) => sum + v);
        if (total > 0) {
          stats.add(CustomFieldStat(
            field: field,
            displayValue: total % 1 == 0
                ? total.toInt().toString()
                : total.toStringAsFixed(1),
            label: 'total',
          ));
        }
      } else if (field.type == CustomFieldType.rating) {
        final ratings = values
            .map((v) => double.tryParse(v) ?? 0.0)
            .where((v) => v > 0)
            .toList();
        if (ratings.isNotEmpty) {
          final avg = ratings.fold(0.0, (sum, v) => sum + v) / ratings.length;
          stats.add(CustomFieldStat(
            field: field,
            displayValue: avg.toStringAsFixed(1),
            label: 'avg rating',
          ));
        }
      } else if (field.type == CustomFieldType.checkbox) {
        final total = values
            .where((v) => v == 'true')
            .length;
        if (total > 0) {
          stats.add(CustomFieldStat(
            field: field,
            displayValue: total.toString(),
            label: 'days checked',
          ));
        }
      }
    }
    
    return stats;
  }

  // Get custom field stats for all trips combined
  Future<List<CustomFieldStat>> getCustomFieldStatsLifetime() async {
    final fields = await getAllCustomFields();
    final stats = <CustomFieldStat>[];
    
    for (final field in fields) {
      if (field.type == CustomFieldType.text) continue;
      
      final values = await getCustomFieldValuesLifetime(field.id!);
      if (values.isEmpty) continue;
      
      if (field.type == CustomFieldType.number) {
        final total = values
            .map((v) => double.tryParse(v) ?? 0.0)
            .fold(0.0, (sum, v) => sum + v);
        if (total > 0) {
          stats.add(CustomFieldStat(
            field: field,
            displayValue: total % 1 == 0
                ? total.toInt().toString()
                : total.toStringAsFixed(1),
            label: 'total',
          ));
        }
      } else if (field.type == CustomFieldType.rating) {
        final ratings = values
            .map((v) => double.tryParse(v) ?? 0.0)
            .where((v) => v > 0)
            .toList();
        if (ratings.isNotEmpty) {
          final avg = ratings.fold(0.0, (sum, v) => sum + v) / ratings.length;
          stats.add(CustomFieldStat(
            field: field,
            displayValue: avg.toStringAsFixed(1),
            label: 'avg rating',
          ));
        }
      } else if (field.type == CustomFieldType.checkbox) {
        final total = values
            .where((v) => v == 'true')
            .length;
        if (total > 0) {
          stats.add(CustomFieldStat(
            field: field,
            displayValue: total.toString(),
            label: 'days checked',
          ));
        }
      }
    }
    
    return stats;
  }
  Future<List<CustomFieldStat>> getCustomFieldStatsForEntries(
    int tripId,
    List<int> entryIds,
  ) async {
    if (entryIds.isEmpty) return [];
    final fields = await getCustomFieldsForTrip(tripId);
    final stats = <CustomFieldStat>[];

    for (final field in fields) {
      if (field.type == CustomFieldType.text) continue;

      final placeholders = entryIds.map((_) => '?').join(', ');
      final db = await _dbHelper.database;
      final maps = await db.rawQuery('''
        SELECT value FROM custom_field_values
        WHERE custom_field_id = ? AND entry_id IN ($placeholders)
      ''', [field.id!, ...entryIds]);

      final values = maps.map((m) => m['value'] as String).toList();
      if (values.isEmpty) continue;

      if (field.type == CustomFieldType.number) {
        final total = values
            .map((v) => double.tryParse(v) ?? 0.0)
            .fold(0.0, (sum, v) => sum + v);
        if (total > 0) {
          stats.add(CustomFieldStat(
            field: field,
            displayValue: total % 1 == 0
                ? total.toInt().toString()
                : total.toStringAsFixed(1),
            label: 'total',
          ));
        }
      } else if (field.type == CustomFieldType.rating) {
        final ratings = values
            .map((v) => double.tryParse(v) ?? 0.0)
            .where((v) => v > 0)
            .toList();
        if (ratings.isNotEmpty) {
          final avg = ratings.fold(0.0, (sum, v) => sum + v) / ratings.length;
          stats.add(CustomFieldStat(
            field: field,
            displayValue: avg.toStringAsFixed(1),
            label: 'avg rating',
          ));
        }
      } else if (field.type == CustomFieldType.checkbox) {
        final count = values.where((v) => v == 'true').length;
        if (count > 0) {
          stats.add(CustomFieldStat(
            field: field,
            displayValue: count.toString(),
            label: 'days checked',
          ));
        }
      }
    }

    return stats;
  }

}

// so repositories are where calculations happen
