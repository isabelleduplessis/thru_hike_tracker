// utils/newsletter_generator.dart
// Generates newsletter text from selected entries

import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../models/entry.dart';
import '../models/custom_field.dart';

class NewsletterGenerator {
  static String generate({
    required Trip trip,
    required List<Entry> entries,
    required Map<int, Map<int, String>> customFieldValues, // entryId -> fieldId -> value
    required List<CustomFieldStat> customFieldStats,
  }) {
    if (entries.isEmpty) return '';
    
    final dateFormat = DateFormat('MMMM d, yyyy');
    final buffer = StringBuffer();
    
    // Sort entries by date
    entries.sort((a, b) => a.date.compareTo(b.date));
    
    // Subject/Header
    final startDate = dateFormat.format(entries.first.date);
    final endDate = dateFormat.format(entries.last.date);
    buffer.writeln('${trip.name}');
    buffer.writeln(entries.length == 1 ? startDate : '$startDate - $endDate');
    buffer.writeln('=' * 50);
    buffer.writeln();
    
    // Trip Summary
    buffer.writeln('TRIP SUMMARY');
    buffer.writeln('-' * 50);
    
    final totalMiles = entries.fold(0.0, (sum, e) => sum + e.totalDistance);
    final avgMiles = totalMiles / entries.length;
    
    buffer.writeln('Total Miles: ${totalMiles.toStringAsFixed(1)}');
    buffer.writeln('Days: ${entries.length}');
    buffer.writeln('Average: ${avgMiles.toStringAsFixed(1)} mi/day');
    
    // Custom field stats
    if (customFieldStats.isNotEmpty) {
      buffer.writeln();
      for (final stat in customFieldStats) {
        buffer.writeln('${stat.field.name}: ${stat.displayValue} ${stat.label}');
      }
    }
    
    buffer.writeln();
    buffer.writeln();
    
    // Daily Entries
    buffer.writeln('DAILY ENTRIES');
    buffer.writeln('-' * 50);
    buffer.writeln();
    
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      
      // Day header
      buffer.writeln('Day ${i + 1} - ${dateFormat.format(entry.date)}');
      
      // Miles
      buffer.write('Miles: ${entry.totalDistance.toStringAsFixed(1)}');
      buffer.write(' (Mile ${entry.startMile.toStringAsFixed(1)} → ${entry.endMile.toStringAsFixed(1)})');
      
      if (entry.extraMiles > 0) {
        buffer.write(' [+${entry.extraMiles.toStringAsFixed(1)} extra]');
      }
      if (entry.skippedMiles > 0) {
        buffer.write(' [-${entry.skippedMiles.toStringAsFixed(1)} skipped]');
      }
      buffer.writeln();
      
      // coordinates
      if (entry.latitude != null && entry.longitude != null) {
        buffer.writeln(
          'Location: https://maps.google.com/?q=${entry.latitude},${entry.longitude}'
        );
      }
      
      // Direction
      if (entry.direction != null) {
        buffer.writeln('Direction: ${entry.direction.toString().split('.').last}');
      }
      
      // Tent/Shelter
      if (entry.tentOrShelter != null) {
        buffer.writeln('Accommodation: ${entry.tentOrShelter! ? "Tent" : "Shelter"}');
      }
      
      // Shower
      if (entry.shower == true) {
        buffer.writeln('Shower: Yes');
      }
      
      // Custom fields for this entry
      final entryCustomFields = customFieldValues[entry.id];
      if (entryCustomFields != null && entryCustomFields.isNotEmpty) {
        for (final fieldEntry in entryCustomFields.entries) {
          final fieldId = fieldEntry.key;
          final value = fieldEntry.value;
          
          // Find field name from stats
          final field = customFieldStats
              .map((s) => s.field)
              .firstWhere((f) => f.id == fieldId, orElse: () => null as CustomField);
          
          if (field != null && value.isNotEmpty) {
            String displayValue = value;
            if (field.type == CustomFieldType.checkbox) {
              displayValue = value == 'true' ? 'Yes' : 'No';
            }
            buffer.writeln('${field.name}: $displayValue');
          }
        }
      }
      
      // Notes
      if (entry.notes.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Notes:');
        buffer.writeln(entry.notes);
      }
      
      buffer.writeln();
      if (i < entries.length - 1) {
        buffer.writeln('- ' * 25);
        buffer.writeln();
      }
    }
    
    return buffer.toString();
  }
}