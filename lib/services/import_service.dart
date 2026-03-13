// lib/services/import_service.dart
import 'dart:io';
import 'package:csv/csv.dart';
import '../models/trip.dart';
import '../models/entry.dart';
import '../models/direction.dart';
import '../repositories/trip_repository.dart';
import '../repositories/entry_repository.dart';

class ImportResult {
  final bool success;
  final String? error;
  final String? warning;
  final Trip? trip;
  final int entriesCreated;

  ImportResult.failure(this.error)
      : success = false,
        warning = null,
        trip = null,
        entriesCreated = 0;

  ImportResult.success({this.warning, required this.trip, required this.entriesCreated})
      : success = true,
        error = null;
}

class ImportService {
  final TripRepository _tripRepository = TripRepository();
  final EntryRepository _entryRepository = EntryRepository();

  static const _required = ['name', 'units', 'date', 'start', 'end'];

  Future<ImportResult> importFromCsv(String filePath) async {
    // ── Read file ─────────────────────────────────────────────────
    final file = File(filePath);
    final contents = await file.readAsString();
    final rows = const CsvToListConverter(eol: '\n').convert(contents);

    if (rows.isEmpty) return ImportResult.failure('File is empty.');

    // ── Parse headers ─────────────────────────────────────────────
    final headers = rows.first.map((h) => h.toString().trim().toLowerCase()).toList();

    final missing = _required.where((col) => !headers.contains(col)).toList();
    if (missing.isNotEmpty) {
      return ImportResult.failure('Missing required columns: ${missing.join(', ')}.');
    }

    final int iName      = headers.indexOf('name');
    final int iUnits     = headers.indexOf('units');
    final int iDate      = headers.indexOf('date');
    final int iDirection = headers.indexOf('direction');
    final int iStart     = headers.indexOf('start');
    final int iEnd       = headers.indexOf('end');
    final int iNotes     = headers.indexOf('notes');

    final dataRows = rows.skip(1).where((r) => r.any((c) => c.toString().trim().isNotEmpty)).toList();
    if (dataRows.isEmpty) return ImportResult.failure('No data rows found.');

    // ── Validate single name ──────────────────────────────────────
    final names = dataRows.map((r) => r[iName].toString().trim()).toSet();
    if (names.length > 1) {
      return ImportResult.failure(
        'Multiple names found: ${names.join(', ')}. Each hike must contain exactly one trip.',
      );
    }

    // ── Validate single units ─────────────────────────────────────
    final unitsRaw = dataRows.map((r) => r[iUnits].toString().trim().toLowerCase()).toSet();
    if (unitsRaw.length > 1) {
      return ImportResult.failure(
        'Multiple unit values found: ${unitsRaw.join(', ')}. All rows must use the same unit.',
      );
    }

    final unitsStr = unitsRaw.first;
    final bool? isMetricNullable = _parseIsMetric(unitsStr);
    if (isMetricNullable == null) {
      return ImportResult.failure(
        'Unrecognized units "$unitsStr". Use: mi, mile, miles, imperial, km, kilometer, kilometers, or metric.',
      );
    }
    final bool isMetric = isMetricNullable;

    // ── Parse rows ────────────────────────────────────────────────
    final tripName = names.first;
    final parsedRows = <_ParsedRow>[];

    for (int i = 0; i < dataRows.length; i++) {
      final r = dataRows[i];
      final rowNum = i + 2;

      final dateStr = r[iDate].toString().trim();
      final date = _parseDate(dateStr);
      if (date == null) {
        return ImportResult.failure(
          'Row $rowNum: invalid date "$dateStr". Use YYYY-MM-DD or M/D/YYYY.',
        );
      }

      final startRaw = double.tryParse(r[iStart].toString().trim());
      if (startRaw == null) {
        return ImportResult.failure('Row $rowNum: invalid start value "${r[iStart]}".');
      }

      final endRaw = double.tryParse(r[iEnd].toString().trim());
      if (endRaw == null) {
        return ImportResult.failure('Row $rowNum: invalid end value "${r[iEnd]}".');
      }

      Direction? direction;
      if (iDirection >= 0) {
        final dirStr = r[iDirection].toString().trim();
        if (dirStr.isNotEmpty) {
          direction = _parseDirection(dirStr);
          if (direction == null) {
            return ImportResult.failure(
              'Row $rowNum: invalid direction "$dirStr". '
              'Valid values: NOBO, SOBO, Eastbound, Westbound, Forward, Backwarrd, Clockwise, Counterclockwise.',
            );
          }
        }
      }

      final notes = iNotes >= 0 ? r[iNotes].toString().trim() : '';

      final startMile = isMetric ? _kmToMiles(startRaw) : startRaw;
      final endMile   = isMetric ? _kmToMiles(endRaw)   : endRaw;

      parsedRows.add(_ParsedRow(
        date: date,
        startMile: startMile,
        endMile: endMile,
        direction: direction,
        notes: notes,
      ));
    }

    // ── Derive trip-level fields ───────────────────────────────────
    final allDates      = parsedRows.map((r) => r.date).toList()..sort();
    final allStarts     = parsedRows.map((r) => r.startMile);
    final allEnds       = parsedRows.map((r) => r.endMile);
    final tripStartMile = allStarts.reduce((a, b) => a < b ? a : b);
    final tripEndMile   = allEnds.reduce((a, b) => a > b ? a : b);
    final tripStartDate = allDates.first;
    final tripEndDate   = allDates.last;
    final tripDirection = parsedRows.first.direction;

    // ── Check duplicate name (warn, don't block) ──────────────────
    final existingTrips = await _tripRepository.getAllTrips();
    final duplicateName = existingTrips.any((t) => t.name == tripName);
    final warning = duplicateName
        ? 'A hike named "$tripName" already exists. Creating another "$tripName".'
        : null;

    // ── Create trip ───────────────────────────────────────────────
    final trip = Trip(
      name: tripName,
      startDate: tripStartDate,
      endDate: tripEndDate,
      startMile: tripStartMile,
      endMile: tripEndMile,
      tripLength: (tripEndMile - tripStartMile).abs(),
      direction: tripDirection,
      status: TripStatus.completed,
    );

    final savedTrip = await _tripRepository.createTrip(trip);

    // ── Create entries ────────────────────────────────────────────
    for (final row in parsedRows) {
      final entry = Entry(
        tripId: savedTrip.id!,
        date: row.date,
        startMile: row.startMile,
        endMile: row.endMile,
        notes: row.notes,
        direction: row.direction,
      );
      await _entryRepository.createEntry(entry);
    }

    return ImportResult.success(
      warning: warning,
      trip: savedTrip,
      entriesCreated: parsedRows.length,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────

  bool? _parseIsMetric(String raw) {
    const imperial = ['mi', 'mile', 'miles', 'imperial'];
    const metric   = ['km', 'kilometer', 'kilometers', 'metric'];
    if (imperial.contains(raw)) return false;
    if (metric.contains(raw))   return true;
    return null;
  }

  DateTime? _parseDate(String raw) {
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;

    final parts = raw.split('/');
    if (parts.length == 3) {
      final month = int.tryParse(parts[0]);
      final day   = int.tryParse(parts[1]);
      final year  = int.tryParse(parts[2]);
      if (month != null && day != null && year != null) {
        try {
          return DateTime(year, month, day);
        } catch (_) {}
      }
    }
    return null;
  }

  Direction? _parseDirection(String raw) {
    final lower = raw.trim().toLowerCase();
    for (final d in Direction.values) {
      if (d.name.toLowerCase() == lower) return d;
    }
    return null;
  }

  double _kmToMiles(double km) => km / 1.60934;
}

class _ParsedRow {
  final DateTime date;
  final double startMile;
  final double endMile;
  final Direction? direction;
  final String notes;

  _ParsedRow({
    required this.date,
    required this.startMile,
    required this.endMile,
    required this.direction,
    required this.notes,
  });
}