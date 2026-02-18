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


class TripDetailScreen extends StatefulWidget {
  final Trip trip; // why do we have this here but not in gear screen? - because we need to know which trip's entries to show, whereas the gear screen just shows all gear regardless of trip
  
  const TripDetailScreen({Key? key, required this.trip}) : super(key: key);

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final EntryRepository _entryRepository = EntryRepository();
  List<Entry> _entries = [];
  bool _isLoading = true;
  final CustomFieldRepository _customFieldRepository = CustomFieldRepository();
  bool _isSelectionMode = false;
  Set<int> _selectedEntryIds = {};
  bool _isCalendarView = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Entry>> _entriesByDate = {};

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
    });
    
    final entries = await _entryRepository.getEntriesForTrip(widget.trip.id!);
    
    setState(() {
      _entries = entries;
      _isLoading = false;
      _groupEntriesByDate();  // ← Add this line
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode 
            ? '${_selectedEntryIds.length} selected'
            : widget.trip.name),
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
              icon: const Icon(Icons.email),
              onPressed: _selectedEntryIds.isEmpty ? null : _exportToEmail,
              tooltip: 'Export to Email',
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TripFormScreen(trip: widget.trip),
                  ),
                );
                
                if (result == true) {
                  _loadEntries();
                  setState(() {});
                } else if (result == 'deleted') {
                  if (mounted) {
                    Navigator.pop(context, true);
                  }
                }
              },
              tooltip: 'Edit Trip',
            ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // View toggle
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
                      onSelectionChanged: (Set<bool> selected) {
                        setState(() {
                          _isCalendarView = selected.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: _isCalendarView
                    ? _buildCalendarView()
                    : (_entries.isEmpty
                        ? _buildEmptyState()
                        : _buildEntryList()),
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
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: _isSelectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedEntryIds.add(entry.id!);
                    } else {
                      _selectedEntryIds.remove(entry.id!);
                    }
                  });
                },
              )
            : null,
        title: Text(
          dateFormat.format(entry.date),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              '${entry.totalDistance.toStringAsFixed(1)} miles',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Mile ${entry.startMile.toStringAsFixed(1)} → ${entry.endMile.toStringAsFixed(1)}',
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
                      trip: widget.trip,
                      entry: entry,
                    ),
                  ),
                );
                
                if (result == true) {
                  _loadEntries();
                }
              },
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