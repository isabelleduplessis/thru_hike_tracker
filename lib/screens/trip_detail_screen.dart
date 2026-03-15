// trip_detail_screen.dart
// Shows all entries for a specific trip

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../models/entry.dart';
import '../repositories/entry_repository.dart';
import 'entry_form_screen.dart';
import 'trip_form_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/custom_field.dart';
import '../repositories/custom_field_repository.dart';
import '../utils/newsletter_generator.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/settings_service.dart';
import '../repositories/trip_repository.dart';
import '../utils/section_colors.dart';
import '../utils/day_number.dart';


class TripDetailScreen extends StatefulWidget {
  final Trip trip; // why do we have this here but not in gear screen? - because we need to know which trip's entries to show, whereas the gear screen just shows all gear regardless of tri

  const TripDetailScreen({Key? key, required this.trip}) : super(key: key);

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final EntryRepository _entryRepository = EntryRepository();
  final _settings = SettingsService();
  List<Entry> _entries = [];
  bool _isLoading = true;
  final CustomFieldRepository _customFieldRepository = CustomFieldRepository();
  bool _isSelectionMode = false;
  Set<int> _selectedEntryIds = {};
  bool _isCalendarView = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Entry>> _entriesByDate = {};
  Map<int, int> _entryDayNumbers = {};

  // Inside _TripDetailScreenState
  late Trip _currentTrip; // Use this instead of widget.trip everywhere in build
  final TripRepository _tripRepository = TripRepository(); // Need this to fetch fresh data

  @override
  void initState() {
    super.initState();
    _currentTrip = widget.trip; // Initialize with the passed trip
    _loadEntries();
  }

  String _getSectionForEntry(double mile) {
    for (var section in _currentTrip.sections) {
      if (mile >= section.startMile && mile <= section.endMile) {
        return section.name;
      }
    }
    return "";
  }

  int _getSectionIndexForEntry(double mile) {
    for (int i = 0; i < _currentTrip.sections.length; i++) {
      final section = _currentTrip.sections[i];
      if (mile >= section.startMile && mile <= section.endMile) return i;
    }
    return -1;
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
    });
    
    // 1. Fetch the latest Trip data (including new sections/direction)
    final updatedTrip = await _tripRepository.getTripById(_currentTrip.id!);
    
    // 2. Fetch the entries
    final entries = await _entryRepository.getEntriesForTrip(_currentTrip.id!);
    
    setState(() {
      if (updatedTrip != null) {
        _currentTrip = updatedTrip;
      }
      _entries = entries;
      _isLoading = false;
      _groupEntriesByDate();
      _entryDayNumbers = calculateDayNumbers(_entries, _currentTrip.startDate);
    });
  }
  void _groupEntriesByDate() {
    _entriesByDate = {};
    for (final entry in _entries) {
      final dateKey = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (_entriesByDate[dateKey] == null) {
        _entriesByDate[dateKey] = [];
      }
      _entriesByDate[dateKey]!.add(entry);
    }
  }
  // Map<int, int> _calculateDayNumbers() {
  //   // Get sorted unique dates
  //   final uniqueDates = _entries
  //       .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
  //       .toSet()
  //       .toList()
  //     ..sort();

  //   // Map each entry to the rank of its date
  //   final dayNumbers = <int, int>{};
  //   for (final entry in _entries) {
  //     final dateKey = DateTime(entry.date.year, entry.date.month, entry.date.day);
  //     dayNumbers[entry.id!] = uniqueDates.indexOf(dateKey) + 1;
  //   }

  //   return dayNumbers;
  // }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // CHANGE 1: Use _currentTrip.name so it updates after an edit
        title: Text(_isSelectionMode 
            ? '${_selectedEntryIds.length} selected'
            : _currentTrip.name), 
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedEntryIds.clear();
                  });
                },
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            if (_selectedEntryIds.length < _entries.length)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedEntryIds = _entries.map((e) => e.id!).toSet();
                  });
                },
                child: const Text('Select All'),
              ),
            IconButton(
              icon: const Icon(Icons.email_outlined),
              onPressed: _selectedEntryIds.isEmpty ? null : _exportToEmail,
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    // CHANGE 2: Pass _currentTrip to the form, not widget.trip
                    builder: (context) => TripFormScreen(trip: _currentTrip),
                  ),
                );
                
                if (result == true) {
                  // This triggers _loadEntries which now fetches the 
                  // fresh trip + fresh sections from the DB
                  _loadEntries(); 
                } else if (result == 'deleted') {
                  if (mounted) {
                    Navigator.pop(context, true);
                  }
                }
              },
            ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('List'),
                          icon: Icon(Icons.list),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Calendar'),
                          icon: Icon(Icons.calendar_month),
                        ),
                      ],
                      selected: {_isCalendarView},
                      showSelectedIcon: false,
                      onSelectionChanged: (Set<bool> selected) {
                        setState(() {
                          _isCalendarView = selected.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isCalendarView
                    ? _buildCalendarView()
                    : (_entries.isEmpty
                        ? _buildEmptyState()
                        : _buildEntryList()),
              ),
            ],
          ),
      floatingActionButton: _isSelectionMode
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_entries.isNotEmpty)
                FloatingActionButton(
                  heroTag: 'select',
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = true;
                    });
                  },
                  child: const Icon(Icons.checklist),
                ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'add',
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EntryFormScreen(
                        // CHANGE 3: Use _currentTrip here too
                        trip: _currentTrip, 
                      ),
                    ),
                  );
                  
                  if (result == true) {
                    _loadEntries();
                  }
                },
                child: const Icon(Icons.add),
              ),
            ],
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No entries yet!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to log your first day',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
  Widget _buildEntryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _buildEntryCard(entry);
      },
    );
  }
  Widget _buildEntryCard(Entry entry) {
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final isSelected = _selectedEntryIds.contains(entry.id);
    final sectionName = _getSectionForEntry(entry.endMile);
    final sectionIndex = _getSectionIndexForEntry(entry.endMile);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      clipBehavior: Clip.antiAlias, // Ensures the InkWell splash stays inside the card corners
      child: InkWell( // Wrap the entire content to fix the hover/highlight issue
        onTap: _isSelectionMode
            ? () {
                setState(() {
                  if (isSelected) {
                    _selectedEntryIds.remove(entry.id!);
                  } else {
                    _selectedEntryIds.add(entry.id!);
                  }
                });
              }
            : () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EntryFormScreen(
                      trip: _currentTrip,
                      entry: entry,
                    ),
                  ),
                );
                if (result == true || result == 'deleted') {
                  _loadEntries();
                }
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              // Reduces the gap between the text and the bottom badge
              visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
              contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0), // Bottom padding set to 0
              leading: _isSelectionMode
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        // Trigger the same logic as the card tap
                        if (value != null) {
                          setState(() => value ? _selectedEntryIds.add(entry.id!) : _selectedEntryIds.remove(entry.id!));
                        }
                      },
                    )
                  : null,
              title: Text(
                'Day ${_entryDayNumbers[entry.id] ?? '?'} - ${dateFormat.format(entry.date)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    _settings.formatDistance(entry.totalDistance),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.cyan.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_settings.getDistanceUnitLabel() == "km" ? "KM" : "Mile"} '
                    '${_settings.convertToDisplayUnit(entry.startMile).toStringAsFixed(1)} → '
                    '${_settings.convertToDisplayUnit(entry.endMile).toStringAsFixed(1)}',
                  ),
                  if (entry.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16),
                        const SizedBox(width: 4),
                        Text(entry.location!),
                      ],
                    ),
                  ],
                ],
              ),
              trailing: _isSelectionMode ? null : const Icon(Icons.chevron_right),
            ),
            
            // --- THE SECTION HEADER BADGE ---
            if (sectionName.isNotEmpty)
              Padding(
                // Reduced top padding to move it closer to the text above
                padding: const EdgeInsets.only(left: 16, top: 4, bottom: 12), 
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: sectionIndex >= 0 ? sectionColor(_currentTrip.id!, sectionIndex) : Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    sectionName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: sectionIndex >= 0 ? Colors.white : Theme.of(context).colorScheme.onSecondaryContainer,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  Future<void> _exportToEmail() async {
    // Get selected entries
    final selectedEntries = _entries
        .where((e) => _selectedEntryIds.contains(e.id))
        .toList();
    
    if (selectedEntries.isEmpty) return;
    
    // Load custom field values for selected entries
    final customFieldValues = <int, Map<int, String>>{};
    for (final entry in selectedEntries) {
      final values = await _customFieldRepository.getCustomFieldValues(entry.id!);
      if (values.isNotEmpty) {
        customFieldValues[entry.id!] = values;
      }
    }
    
    // Calculate custom field stats for selected entries
    final customFieldStats = await _calculateCustomFieldStatsForEntries(selectedEntries);
    
    // Generate newsletter text
    final newsletter = NewsletterGenerator.generate(
      trip: widget.trip,
      entries: selectedEntries,
      customFieldValues: customFieldValues,
      customFieldStats: customFieldStats,
    );
    
    // Create mailto URL
    final dateFormat = DateFormat('MMM d, yyyy');
    final subject = selectedEntries.length == 1
        ? '${widget.trip.name} - ${dateFormat.format(selectedEntries.first.date)}'
        : '${widget.trip.name} - ${dateFormat.format(selectedEntries.first.date)} to ${dateFormat.format(selectedEntries.last.date)}';
    
    final Uri emailUri = Uri(
      scheme: 'mailto',
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(newsletter)}',
    );
    
    // Launch email app
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app')),
        );
      }
    }
  }

  Future<List<CustomFieldStat>> _calculateCustomFieldStatsForEntries(
    List<Entry> entries,
  ) async {
    final fields = await _customFieldRepository.getCustomFieldsForTrip(widget.trip.id!);
    final stats = <CustomFieldStat>[];
    
    for (final field in fields) {
      if (field.type == CustomFieldType.text) continue;
      
      final values = <String>[];
      for (final entry in entries) {
        final entryValues = await _customFieldRepository.getCustomFieldValues(entry.id!);
        final value = entryValues[field.id];
        if (value != null && value.isNotEmpty) {
          values.add(value);
        }
      }
      
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
            label: 'avg',
          ));
        }
      } else if (field.type == CustomFieldType.checkbox) {
        final total = values.where((v) => v == 'true').length;
        if (total > 0) {
          stats.add(CustomFieldStat(
            field: field,
            displayValue: total.toString(),
            label: 'days',
          ));
        }
      }
    }
    
    return stats;
  }
  Widget _buildCalendarView() {
    return Column(
      children: [
        TableCalendar(
          firstDay: widget.trip.startDate,
          lastDay: DateTime.now().add(const Duration(days: 365)),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) {
            return isSameDay(_selectedDay, day);
          },
          eventLoader: (day) {
            final dateKey = DateTime(day.year, day.month, day.day);
            return _entriesByDate[dateKey] ?? [];
          },
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          calendarStyle: CalendarStyle(
            markerDecoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildSelectedDayEntries(),
        ),
      ],
    );
  }

  Widget _buildSelectedDayEntries() {
    if (_selectedDay == null) {
      return const Center(
        child: Text(
          'Select a day to see entries',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    
    final dateKey = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final dayEntries = _entriesByDate[dateKey] ?? [];
    
    if (dayEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No entry for this day',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                // Create entry for selected day
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EntryFormScreen(
                      trip: widget.trip,
                      // Could pre-fill date here if we modify EntryFormScreen
                    ),
                  ),
                );
                
                if (result == true) {
                  _loadEntries();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Entry'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: dayEntries.length,
      itemBuilder: (context, index) {
        return _buildEntryCard(dayEntries[index]);
      },
    );
  }
}

