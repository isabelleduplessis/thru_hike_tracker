// trip_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
import '../utils/entry_detail_dialog.dart';

class TripDetailScreen extends StatefulWidget {
  final Trip trip;

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

  int _selectedTab = 0;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  Map<DateTime, List<Entry>> _entriesByDate = {};
  Map<int, int> _entryDayNumbers = {};

  late Trip _currentTrip;
  final TripRepository _tripRepository = TripRepository();

  @override
  void initState() {
    super.initState();
    _currentTrip = widget.trip;
    _loadEntries();
  }

  String _getSectionForEntry(double mile) {
    for (var section in _currentTrip.sections) {
      if (mile >= section.startMile && mile <= section.endMile) return section.name;
    }
    return '';
  }

  int _getSectionIndexForEntry(double mile) {
    for (int i = 0; i < _currentTrip.sections.length; i++) {
      final section = _currentTrip.sections[i];
      if (mile >= section.startMile && mile <= section.endMile) return i;
    }
    return -1;
  }

  String _getAlternateNameForEntry(Entry entry) {
    if (entry.alternateId == null) return '';
    try {
      final alt = _currentTrip.alternates.firstWhere((a) => a.id == entry.alternateId);
      return alt.name;
    } catch (_) {
      return '';
    }
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    final updatedTrip = await _tripRepository.getTripById(_currentTrip.id!);
    final entries = await _entryRepository.getEntriesForTrip(_currentTrip.id!);
    setState(() {
      if (updatedTrip != null) _currentTrip = updatedTrip;
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
      _entriesByDate[dateKey] ??= [];
      _entriesByDate[dateKey]!.add(entry);
    }
  }

  Future<void> _pickYearMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _focusedDay,
      firstDate: widget.trip.startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialEntryMode: DatePickerEntryMode.input,
      helpText: 'Go to month',
    );
    if (picked != null) setState(() => _focusedDay = picked);
  }

  // Bold label, normal value — using Text.rich to avoid RichText overflow issues
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEntryDetail(Entry entry) async {
    await _showEntryDetailAtIndex(_entries.indexOf(entry));
  }

  Future<void> _showEntryDetailAtIndex(int index) async {
    await showEntryDetailDialog(
      context: context,
      trip: _currentTrip,
      allEntries: _entries,
      currentIndex: index,
      dayNumbers: _entryDayNumbers,
      settings: _settings,
      customFieldRepository: _customFieldRepository,
      onEdit: _loadEntries,
      editScreenBuilder: (entry) => EntryFormScreen(trip: _currentTrip, entry: entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          _isSelectionMode
              ? '${_selectedEntryIds.length} selected'
              : _currentTrip.name,
          softWrap: true,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: Icon(PhosphorIcons.x()),
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
                child: const Text('All', style: TextStyle(fontSize: 13)),
              ),
            IconButton(
              icon: Icon(PhosphorIcons.envelope(), size: 20),
              onPressed: _selectedEntryIds.isEmpty ? null : _exportToEmail,
            ),
          ] else ...[
            if (_selectedTab == 0 && _entries.isNotEmpty)
              IconButton(
                icon: Icon(PhosphorIcons.checkSquare(), size: 20),
                tooltip: 'Select entries',
                onPressed: () => setState(() => _isSelectionMode = true),
              ),
            IconButton(
              icon: Icon(PhosphorIcons.plus(), size: 20),
              tooltip: 'New entry',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EntryFormScreen(trip: _currentTrip),
                  ),
                );
                if (result == true) _loadEntries();
              },
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text('Entries', style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('Calendar', style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: 2,
                        label: Text('Edit', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    selected: {_selectedTab},
                    showSelectedIcon: false,
                    onSelectionChanged: (Set<int> selected) async {
                      final tab = selected.first;
                      if (tab == 2) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TripFormScreen(trip: _currentTrip),
                          ),
                        );
                        if (result == true) {
                          _loadEntries();
                        } else if (result == 'deleted') {
                          if (mounted) Navigator.pop(context, true);
                        }
                      } else {
                        setState(() => _selectedTab = tab);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _selectedTab == 1
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
          Icon(PhosphorIcons.calendarBlank(), size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No entries yet!', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Tap + to log your first day', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildEntryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _entries.length,
      itemBuilder: (context, index) => _buildEntryCard(_entries[index]),
    );
  }

  Widget _buildEntryCard(Entry entry) {
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final isSelected = _selectedEntryIds.contains(entry.id);
    final sectionName = entry.isOnAlternate ? '' : _getSectionForEntry(entry.endMile);
    final sectionIndex = entry.isOnAlternate ? -1 : _getSectionIndexForEntry(entry.endMile);
    final alternateName = _getAlternateNameForEntry(entry);
    final badgeText = alternateName.isNotEmpty ? alternateName : sectionName;
    final isAlternate = alternateName.isNotEmpty;
    final unit = _settings.getDistanceUnitLabel() == 'km' ? 'KM' : 'Mile';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
            : () => _showEntryDetail(entry),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Checkbox(
                    value: isSelected,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => value
                            ? _selectedEntryIds.add(entry.id!)
                            : _selectedEntryIds.remove(entry.id!));
                      }
                    },
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day ${_entryDayNumbers[entry.id] ?? '?'}  ·  ${dateFormat.format(entry.date)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _settings.formatDistance(entry.totalDistance),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.cyan.shade700,
                          ),
                        ),
                        if (badgeText.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAlternate
                                  ? Colors.grey.shade400
                                  : (sectionIndex >= 0
                                      ? sectionColor(_currentTrip.id!, sectionIndex)
                                      : Theme.of(context).colorScheme.secondaryContainer),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badgeText.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isAlternate
                                    ? Colors.white
                                    : (sectionIndex >= 0
                                        ? Colors.white
                                        : Theme.of(context).colorScheme.onSecondaryContainer),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$unit ${_settings.convertToDisplayUnit(entry.startMile).toStringAsFixed(1)} → ${_settings.convertToDisplayUnit(entry.endMile).toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (!_isSelectionMode)
                Icon(PhosphorIcons.caretRight(), size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportToEmail() async {
    final selectedEntries =
        _entries.where((e) => _selectedEntryIds.contains(e.id)).toList();
    if (selectedEntries.isEmpty) return;

    final customFieldValues = <int, Map<int, String>>{};
    for (final entry in selectedEntries) {
      final values = await _customFieldRepository.getCustomFieldValues(entry.id!);
      if (values.isNotEmpty) customFieldValues[entry.id!] = values;
    }

    final customFieldStats = await _calculateCustomFieldStatsForEntries(selectedEntries);

    final newsletter = NewsletterGenerator.generate(
      trip: widget.trip,
      entries: selectedEntries,
      customFieldValues: customFieldValues,
      customFieldStats: customFieldStats,
    );

    final dateFormat = DateFormat('MMM d, yyyy');
    final subject = selectedEntries.length == 1
        ? '${widget.trip.name} - ${dateFormat.format(selectedEntries.first.date)}'
        : '${widget.trip.name} - ${dateFormat.format(selectedEntries.first.date)} to ${dateFormat.format(selectedEntries.last.date)}';

    final Uri emailUri = Uri(
      scheme: 'mailto',
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(newsletter)}',
    );

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
      List<Entry> entries) async {
    final fields = await _customFieldRepository.getCustomFieldsForTrip(widget.trip.id!);
    final stats = <CustomFieldStat>[];

    for (final field in fields) {
      if (field.type == CustomFieldType.text) continue;
      final values = <String>[];
      for (final entry in entries) {
        final entryValues = await _customFieldRepository.getCustomFieldValues(entry.id!);
        final value = entryValues[field.id];
        if (value != null && value.isNotEmpty) values.add(value);
      }
      if (values.isEmpty) continue;

      if (field.type == CustomFieldType.number) {
        final total = values
            .map((v) => double.tryParse(v) ?? 0.0)
            .fold(0.0, (sum, v) => sum + v);
        if (total > 0) {
          stats.add(CustomFieldStat(
            field: field,
            displayValue: total % 1 == 0 ? total.toInt().toString() : total.toStringAsFixed(1),
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
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
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
          onHeaderTapped: (_) => _pickYearMonth(),
          calendarStyle: CalendarStyle(
            markerDecoration: const BoxDecoration(
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
            titleTextStyle: TextStyle(fontSize: 15),
            titleTextFormatter: null,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildSelectedDayEntries()),
      ],
    );
  }

  Widget _buildSelectedDayEntries() {
    if (_selectedDay == null) {
      return const Center(
        child: Text('Select a day to see entries', style: TextStyle(color: Colors.grey)),
      );
    }

    final dateKey = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final dayEntries = _entriesByDate[dateKey] ?? [];

    if (dayEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No entry for this day', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EntryFormScreen(trip: widget.trip),
                  ),
                );
                if (result == true) _loadEntries();
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
      itemBuilder: (context, index) => _buildEntryCard(dayEntries[index]),
    );
  }
}