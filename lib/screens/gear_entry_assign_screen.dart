// screens/gear_entry_assign_screen.dart
// Allows mass-assigning a gear item to entries within its active date range

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gear.dart';
import '../models/entry.dart';
import '../models/trip.dart';
//import '../models/section.dart';
import '../repositories/gear_repository.dart';
import '../repositories/entry_repository.dart';
import '../repositories/trip_repository.dart';
import '../utils/day_number.dart';
import '../utils/section_colors.dart';

class GearEntryAssignScreen extends StatefulWidget {
  final Gear gear;

  const GearEntryAssignScreen({Key? key, required this.gear}) : super(key: key);

  @override
  State<GearEntryAssignScreen> createState() => _GearEntryAssignScreenState();
}

class _GearEntryAssignScreenState extends State<GearEntryAssignScreen> {
  final GearRepository _gearRepository = GearRepository();
  final EntryRepository _entryRepository = EntryRepository();
  final TripRepository _tripRepository = TripRepository();

  bool _isLoading = true;
  bool _isSaving = false;

  // All entries in gear's date range, grouped by trip
  List<Trip> _trips = [];
  Map<int, List<Entry>> _entriesByTrip = {}; // tripId -> entries
  Map<int, Map<int, int>> _dayNumbersByTrip = {}; // tripId -> {entryId -> dayNum}

  // Currently selected entry IDs
  Set<int> _selectedEntryIds = {};

  // Original linked entry IDs (to diff on save)
  Set<int> _originalLinkedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final endDate = widget.gear.endDate ?? DateTime.now();
    final startDate = widget.gear.startDate;

    // Load entries in date range and already-linked IDs in parallel
    final results = await Future.wait([
      _entryRepository.getEntriesInDateRangeAllTrips(startDate, endDate),
      _gearRepository.getEntryIdsForGear(widget.gear.id!),
      _tripRepository.getAllTrips(),
    ]);

    final entries = results[0] as List<Entry>;
    final linkedIds = results[1] as Set<int>;
    final trips = results[2] as List<Trip>;

    // Group entries by trip
    final entriesByTrip = <int, List<Entry>>{};
    for (final entry in entries) {
      entriesByTrip[entry.tripId] ??= [];
      entriesByTrip[entry.tripId]!.add(entry);
    }

    // Calculate day numbers per trip
    final dayNumbersByTrip = <int, Map<int, int>>{};
    for (final tripId in entriesByTrip.keys) {
      final trip = trips.firstWhere((t) => t.id == tripId, orElse: () => trips.first);
      dayNumbersByTrip[tripId] = calculateDayNumbers(
        entriesByTrip[tripId]!,
        trip.startDate,
      );
    }

    // Only keep trips that have entries in range
    final relevantTrips = trips.where((t) => entriesByTrip.containsKey(t.id)).toList();

    setState(() {
      _trips = relevantTrips;
      _entriesByTrip = entriesByTrip;
      _dayNumbersByTrip = dayNumbersByTrip;
      _selectedEntryIds = Set.from(linkedIds);
      _originalLinkedIds = Set.from(linkedIds);
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      // Diff: find newly added and newly removed
      final toAdd = _selectedEntryIds.difference(_originalLinkedIds);
      final toRemove = _originalLinkedIds.difference(_selectedEntryIds);

      for (final entryId in toAdd) {
        await _gearRepository.linkGearToEntry(entryId, widget.gear.id!);
      }
      for (final entryId in toRemove) {
        await _gearRepository.unlinkGearFromEntry(entryId, widget.gear.id!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gear assignments saved.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Get section name for an entry
  String _getSectionName(Entry entry, Trip trip) {
    for (final section in trip.sections) {
      if (entry.endMile >= section.startMile && entry.endMile <= section.endMile) {
        return section.name;
      }
    }
    return '';
  }

  int _getSectionIndex(Entry entry, Trip trip) {
    for (int i = 0; i < trip.sections.length; i++) {
      final section = trip.sections[i];
      if (entry.endMile >= section.startMile && entry.endMile <= section.endMile) return i;
    }
    return -1;
  }

  // Get alternate name for an entry
  String _getAlternateName(Entry entry, Trip trip) {
    if (entry.alternateId == null) return '';
    try {
      final alt = trip.alternates.firstWhere((a) => a.id == entry.alternateId);
      return alt.name;
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gear.name),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No entries found in this gear\'s active period.',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(
                        'Active: ${DateFormat('MMM d, yyyy').format(widget.gear.startDate)}'
                        '${widget.gear.endDate != null ? ' – ${DateFormat('MMM d, yyyy').format(widget.gear.endDate!)}' : ' – present'}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView(
                  children: _trips.map((trip) => _buildTripTile(trip)).toList(),
                ),
    );
  }

  Widget _buildTripTile(Trip trip) {
    final entries = _entriesByTrip[trip.id!] ?? [];
    final selectedCount = entries.where((e) => _selectedEntryIds.contains(e.id)).length;
    final allSelected = selectedCount == entries.length;
    final someSelected = selectedCount > 0 && !allSelected;
    final hasAnySelected = selectedCount > 0;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: hasAnySelected,
        leading: Checkbox(
          value: allSelected ? true : (someSelected ? null : false),
          tristate: true,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: (val) {
            setState(() {
              if (allSelected) {
                // Deselect all in this trip
                for (final e in entries) _selectedEntryIds.remove(e.id);
              } else {
                // Select all in this trip
                for (final e in entries) _selectedEntryIds.add(e.id!);
              }
            });
          },
        ),
        title: Text(trip.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(
          '$selectedCount / ${entries.length} selected',
          style: const TextStyle(fontSize: 12),
        ),
        children: entries.map((entry) => _buildEntryRow(entry, trip)).toList(),
      ),
    );
  }

  Widget _buildEntryRow(Entry entry, Trip trip) {
    final isSelected = _selectedEntryIds.contains(entry.id);
    final dayNum = _dayNumbersByTrip[trip.id!]?[entry.id];
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final sectionName = entry.isOnAlternate
        ? _getAlternateName(entry, trip)
        : _getSectionName(entry, trip);
    final sectionIndex = entry.isOnAlternate ? -1 : _getSectionIndex(entry, trip);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedEntryIds.remove(entry.id);
          } else {
            _selectedEntryIds.add(entry.id!);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: isSelected,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedEntryIds.add(entry.id!);
                    } else {
                      _selectedEntryIds.remove(entry.id);
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayNum != null
                        ? 'Day $dayNum — ${dateFormat.format(entry.date)}'
                        : dateFormat.format(entry.date),
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (sectionName.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        // Section gets color, alternate gets grey
                        color: entry.isOnAlternate
                            ? Colors.grey.shade400
                            : (sectionIndex >= 0
                                ? sectionColor(trip.id!, sectionIndex)
                                : Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sectionName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}