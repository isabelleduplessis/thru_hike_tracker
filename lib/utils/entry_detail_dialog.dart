// lib/utils/entry_detail_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/entry.dart';
import '../models/trip.dart';
import '../models/custom_field.dart';
import '../repositories/custom_field_repository.dart';
import '../services/settings_service.dart';
//import '../utils/section_colors.dart';

/// Show an entry detail dialog.
///
/// For single-entry use (e.g. map screen):
///   pass [entry], [dayNumber], leave [allEntries] null — no arrows shown.
///
/// For list use with arrows (e.g. trip detail screen):
///   pass [allEntries], [currentIndex], [dayNumbers] map — arrows shown.
Future<void> showEntryDetailDialog({
  required BuildContext context,
  required Trip trip,
  required SettingsService settings,
  required CustomFieldRepository customFieldRepository,
  // Single entry mode
  Entry? entry,
  int? dayNumber,
  // List mode with arrows
  List<Entry>? allEntries,
  int? currentIndex,
  Map<int, int>? dayNumbers,
  // Callbacks
  VoidCallback? onEdit,
  Widget Function(Entry)? editScreenBuilder,
}) async {
  assert(entry != null || (allEntries != null && currentIndex != null),
      'Provide either entry or allEntries+currentIndex');

  if (entry != null) {
    // Single entry mode — no arrows
    await _showAtIndex(
      context: context,
      trip: trip,
      allEntries: null,
      index: 0,
      entryOverride: entry,
      dayNumberOverride: dayNumber,
      dayNumbers: null,
      settings: settings,
      customFieldRepository: customFieldRepository,
      onEdit: onEdit,
      editScreenBuilder: editScreenBuilder,
    );
  } else {
    // List mode with arrows
    await _showAtIndex(
      context: context,
      trip: trip,
      allEntries: allEntries,
      index: currentIndex!,
      entryOverride: null,
      dayNumberOverride: null,
      dayNumbers: dayNumbers,
      settings: settings,
      customFieldRepository: customFieldRepository,
      onEdit: onEdit,
      editScreenBuilder: editScreenBuilder,
    );
  }
}

Future<void> _showAtIndex({
  required BuildContext context,
  required Trip trip,
  required List<Entry>? allEntries,
  required int index,
  required Entry? entryOverride,
  required int? dayNumberOverride,
  required Map<int, int>? dayNumbers,
  required SettingsService settings,
  required CustomFieldRepository customFieldRepository,
  required VoidCallback? onEdit,
  required Widget Function(Entry)? editScreenBuilder,
}) async {
  final entry = entryOverride ?? allEntries![index];
  final dayNum = dayNumberOverride ?? dayNumbers?[entry.id];

  final customFieldsWithValues = await customFieldRepository.getCustomFieldsWithValues(
    trip.id!,
    entry.id!,
  );

  if (!context.mounted) return;

  final dateFormat = DateFormat('EEE, MMM d, yyyy');
  final unit = settings.getDistanceUnitLabel() == 'km' ? 'KM' : 'Mile';

  // Section / alternate
  String badgeText = '';
  bool isAlternate = false;
  int sectionIndex = -1;

  if (entry.alternateId != null) {
    try {
      final alt = trip.alternates.firstWhere((a) => a.id == entry.alternateId);
      badgeText = alt.name;
      isAlternate = true;
    } catch (_) {}
  } else {
    for (int i = 0; i < trip.sections.length; i++) {
      final s = trip.sections[i];
      if (entry.endMile >= s.startMile && entry.endMile <= s.endMile) {
        badgeText = s.name;
        sectionIndex = i;
        break;
      }
    }
  }

  final filledFields = customFieldsWithValues.where((fwv) {
    final value = fwv.value;
    if (value == null || value.isEmpty) return false;
    if (fwv.field.type == CustomFieldType.checkbox && value == 'false') return false;
    return true;
  }).toList();

  final hasArrows = allEntries != null && allEntries.length > 1;
  const arrowWidth = 36.0;

  await showDialog(
    context: context,
    builder: (context) {
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      final boxWidth = hasArrows
          ? screenWidth - 16 - arrowWidth * 2
          : screenWidth - 16;

      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Left arrow ──────────────────────────────────────────
            if (hasArrows)
              SizedBox(
                width: arrowWidth,
                child: IconButton(
                  icon: Icon(
                    PhosphorIcons.caretLeft(),
                    size: 22,
                    color: index > 0 ? Colors.white : Colors.white38,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: index > 0
                      ? () {
                          Navigator.pop(context);
                          _showAtIndex(
                            context: context,
                            trip: trip,
                            allEntries: allEntries,
                            index: index - 1,
                            entryOverride: null,
                            dayNumberOverride: null,
                            dayNumbers: dayNumbers,
                            settings: settings,
                            customFieldRepository: customFieldRepository,
                            onEdit: onEdit,
                            editScreenBuilder: editScreenBuilder,
                          );
                        }
                      : null,
                ),
              ),

            // ── Dialog box ──────────────────────────────────────────
            SizedBox(
              width: boxWidth,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
                child: Material(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).dialogBackgroundColor,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ──────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (dayNum != null)
                                    Text(
                                      'Day $dayNum',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  Text(
                                    dateFormat.format(entry.date),
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            if (editScreenBuilder != null)
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          editScreenBuilder(entry),
                                    ),
                                  );
                                  onEdit?.call();
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Edit',
                                    style: TextStyle(fontSize: 13)),
                              ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // ── Scrollable content ───────────────────────
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _boldLabel('Start $unit',
                                  settings.convertToDisplayUnit(entry.startMile).toStringAsFixed(1)),
                              _boldLabel('End $unit',
                                  settings.convertToDisplayUnit(entry.endMile).toStringAsFixed(1)),
                              _boldLabel('Distance',
                                  settings.formatDistance(entry.totalDistance)),
                              if (badgeText.isNotEmpty)
                                _boldLabel(
                                    isAlternate ? 'Alternate' : 'Section',
                                    badgeText),
                              if (entry.extraMiles > 0)
                                _boldLabel('+ Distance',
                                    settings.formatDistance(entry.extraMiles)),
                              if (entry.skippedMiles > 0)
                                _boldLabel('- Distance',
                                    settings.formatDistance(entry.skippedMiles)),
                              if (entry.direction != null)
                                _boldLabel('Direction',
                                    entry.direction!.name.toUpperCase()),
                              if (entry.elevationGain != null)
                                _boldLabel('Elevation Gain',
                                    settings.formatElevation(entry.elevationGain!)),
                              if (entry.elevationLoss != null)
                                _boldLabel('Elevation Loss',
                                    settings.formatElevation(entry.elevationLoss!)),
                              if (entry.tentOrShelter != null)
                                _boldLabel('Sleeping',
                                    entry.tentOrShelter! ? 'Tent' : 'Shelter'),
                              if (entry.shower != null && entry.shower!)
                                _boldLabel('Shower', 'Yes'),
                              if (entry.latitude != null &&
                                  entry.longitude != null)
                                _boldLabel('Coordinates',
                                    '${entry.latitude!.toStringAsFixed(5)}, ${entry.longitude!.toStringAsFixed(5)}'),
                              ...filledFields.map((fwv) {
                                final field = fwv.field;
                                final value = fwv.value!;
                                String displayValue;
                                if (field.type == CustomFieldType.checkbox) {
                                  displayValue = 'Yes';
                                } else if (field.type == CustomFieldType.rating) {
                                  final rating = int.tryParse(value) ?? 0;
                                  displayValue = '★' * rating + '☆' * (5 - rating);
                                } else {
                                  displayValue = value;
                                }
                                return _boldLabel(field.name, displayValue);
                              }),
                              if (entry.notes.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                const Text('Notes:',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(entry.notes,
                                    style: const TextStyle(fontSize: 14)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Right arrow ─────────────────────────────────────────
            if (hasArrows)
              SizedBox(
                width: arrowWidth,
                child: IconButton(
                  icon: Icon(
                    PhosphorIcons.caretRight(),
                    size: 22,
                    color: index < allEntries.length - 1
                        ? Colors.white
                        : Colors.white38,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: index < allEntries.length - 1
                      ? () {
                          Navigator.pop(context);
                          _showAtIndex(
                            context: context,
                            trip: trip,
                            allEntries: allEntries,
                            index: index + 1,
                            entryOverride: null,
                            dayNumberOverride: null,
                            dayNumbers: dayNumbers,
                            settings: settings,
                            customFieldRepository: customFieldRepository,
                            onEdit: onEdit,
                            editScreenBuilder: editScreenBuilder,
                          );
                        }
                      : null,
                ),
              ),
          ],
        ),
      );
    },
  );
}

Widget _boldLabel(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.normal),
          ),
        ],
      ),
    ),
  );
}