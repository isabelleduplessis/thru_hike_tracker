// lib/services/export_service.dart
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/trip.dart';
// import '../models/entry.dart';
// import '../models/custom_field.dart';
import '../repositories/entry_repository.dart';
import '../repositories/gear_repository.dart';
import '../repositories/custom_field_repository.dart';
import '../services/settings_service.dart';

class ExportService {
  final EntryRepository _entryRepository = EntryRepository();
  final GearRepository _gearRepository = GearRepository();
  final CustomFieldRepository _customFieldRepository = CustomFieldRepository();
  final SettingsService _settings = SettingsService();

  Future<void> exportTripToCsv(Trip trip) async {
    // ── Load all entries chronologically ──────────────────────────
    final entries = await _entryRepository.getEntriesForTripChronological(trip.id!);
    final customFields = await _customFieldRepository.getCustomFieldsForTrip(trip.id!);
    final unitLabel = _settings.getDistanceUnitLabel();
    final elevLabel = _settings.getElevationUnitLabel();

    // ── Calculate day numbers ─────────────────────────────────────
    final uniqueDates = entries
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet()
        .toList()
      ..sort();
    final dayNumbers = <int, int>{};
    for (final entry in entries) {
      final dateKey = DateTime(entry.date.year, entry.date.month, entry.date.day);
      dayNumbers[entry.id!] = uniqueDates.indexOf(dateKey) + 1;
    }

    // ── Determine which optional columns to include ───────────────
    final hasElevation    = trip.trackElevation;
    final hasCoordinates  = trip.trackCoordinates;
    final hasSleeping     = trip.trackSleeping;
    final hasShower       = trip.trackShower;

    // ── Build header row ──────────────────────────────────────────
    final headers = <String>[
      'name',
      'date',
      'day',
      'units',
      'start',
      'end',
      'distance',
      'extra',
      'skipped',
      'direction',
      'section',
      'notes',
    ];
    if (hasElevation) {
      headers.add('elevation_gain');
      headers.add('elevation_loss');
      headers.add('elevation_units');
    }
    if (hasCoordinates) {
      headers.add('latitude');
      headers.add('longitude');
    }
    if (hasSleeping) headers.add('sleeping');
    if (hasShower)   headers.add('shower');
    headers.add('gear');
    for (final field in customFields) {
      headers.add(field.name);
    }

    final rows = <List<dynamic>>[headers];

    for (final entry in entries) {
      // Gear for this entry
      final gear = await _gearRepository.getGearForEntry(entry.id!);
      final gearStr = gear.map((g) => g.name).join(', ');

      // Custom field values for this entry
      final customValues = await _customFieldRepository.getCustomFieldValues(entry.id!);

      // Section name
      String sectionName = '';
      for (final section in trip.sections) {
        if (entry.endMile >= section.startMile && entry.endMile <= section.endMile) {
          sectionName = section.name;
          break;
        }
      }

      // Convert to display units
      final startDisplay    = _settings.convertToDisplayUnit(entry.startMile);
      final endDisplay      = _settings.convertToDisplayUnit(entry.endMile);
      final distDisplay     = _settings.convertToDisplayUnit(entry.totalDistance);
      final extraDisplay    = _settings.convertToDisplayUnit(entry.extraMiles);
      final skippedDisplay  = _settings.convertToDisplayUnit(entry.skippedMiles);

      final row = <dynamic>[
        trip.name,
        entry.date.toIso8601String().substring(0, 10),
        dayNumbers[entry.id!] ?? '',
        unitLabel,
        startDisplay.toStringAsFixed(2),
        endDisplay.toStringAsFixed(2),
        distDisplay.toStringAsFixed(2),
        extraDisplay.toStringAsFixed(2),
        skippedDisplay.toStringAsFixed(2),
        entry.direction?.name ?? '',
        sectionName,
        entry.notes,
      ];

      if (hasElevation) {
        row.add(elevLabel);
        row.add(entry.elevationGain != null
            ? _settings.convertToDisplayElevation(entry.elevationGain!).toStringAsFixed(0)
            : '');
        row.add(entry.elevationLoss != null
            ? _settings.convertToDisplayElevation(entry.elevationLoss!).toStringAsFixed(0)
            : '');
      }
      if (hasCoordinates) {
        row.add(entry.latitude?.toStringAsFixed(6) ?? '');
        row.add(entry.longitude?.toStringAsFixed(6) ?? '');
      }
      if (hasSleeping) {
        row.add(entry.tentOrShelter == null
            ? ''
            : entry.tentOrShelter! ? 'tent' : 'shelter');
      }
      if (hasShower) {
        row.add(entry.shower == null ? '' : entry.shower! ? 'yes' : 'no');
      }

      row.add(gearStr);

      for (final field in customFields) {
        row.add(customValues[field.id] ?? '');
      }

      rows.add(row);
    }

    // ── Convert to CSV string ─────────────────────────────────────
    final csv = const ListToCsvConverter().convert(rows);

    // ── Write to temp file and share ──────────────────────────────
    final dir = await getTemporaryDirectory();
    final safeName = trip.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
    final file = File('${dir.path}/${safeName}_export.csv');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '${trip.name} — Hike Export',
    );
  }
}