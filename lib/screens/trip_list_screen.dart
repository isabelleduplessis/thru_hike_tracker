// screens/trip_list_screen.dart
// Shows list of all trips, allows creating new ones

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../repositories/trip_repository.dart';
import '../repositories/entry_repository.dart';
import 'trip_detail_screen.dart';
import 'trip_form_screen.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/import_service.dart';
import '../services/export_service.dart';
import 'package:share_plus/share_plus.dart';

class TripListScreen extends StatefulWidget {
  const TripListScreen({Key? key}) : super(key: key);

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  final TripRepository _tripRepository = TripRepository();
  final EntryRepository _entryRepository = EntryRepository();
  List<Trip> _trips = [];
  bool _isLoading = true;
  final ImportService _importService = ImportService();
  bool _isImporting = false;
  final ExportService _exportService = ExportService();
  Map<int, DateTime?> _latestEntryDates = {};

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
    });
    
    final trips = await _tripRepository.getAllTrips();
    
    final latestDates = <int, DateTime?>{};
    for (final trip in trips) {
      latestDates[trip.id!] = await _entryRepository.getLastEntryDateForTrip(trip.id!);
    }
    setState(() {
      _trips = trips;
      _latestEntryDates = latestDates;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Hikes'),
        actions: [
          if (_isImporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'import') _importCsv();
                if (value == 'export') _exportTrip();
                if (value == 'template') _downloadTemplate();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'import',
                  child: Row(children: [Icon(Icons.upload_file), SizedBox(width: 12), Text('Import from CSV')]),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(children: [Icon(Icons.download), SizedBox(width: 12), Text('Export to CSV')]),
                ),
                const PopupMenuItem(
                  value: 'template',
                  child: Row(children: [Icon(Icons.download), SizedBox(width: 12), Text('Download template')]),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? _buildEmptyState()
              : _buildTripList(),
      
      floatingActionButton: FloatingActionButton( 
        onPressed: () async {
          // Navigate to create trip screen
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TripFormScreen(), 
            ),
          );
          
          // If a trip was created, reload the list
          if (result == true) {
            _loadTrips();
          }
        },
        child: const Icon(Icons.add),
      ),
      // Add this somewhere you can tap it

    );
    
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hiking,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hikes yet!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to start your first hike',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTripList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _trips.length,
      itemBuilder: (context, index) {
        final trip = _trips[index];
        return _buildTripCard(trip);
      },
    );
  }

  Widget _buildTripCard(Trip trip) {
    // Format dates
    final dateFormat = DateFormat('MMM d, yyyy');
    final startStr = dateFormat.format(trip.startDate);
    final latestDate = _latestEntryDates[trip.id];
    final endStr = latestDate != null
        ? dateFormat.format(latestDate)
        : trip.endDate != null
            ? dateFormat.format(trip.endDate!)
            : dateFormat.format(trip.startDate);
    
    // Show date range only if spans multiple months
    final dateDisplay = '$startStr - $endStr';
    
    // Status badge color
    final statusColor = _getStatusColor(trip.status);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          trip.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(dateDisplay),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusText(trip.status),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          // Navigate to trip detail/entries screen
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TripDetailScreen(trip: trip),
            ),
          );
          
          // Reload trips in case anything changed
          _loadTrips();
        },
      ),
    );
  }

  bool _spansMultipleMonths(DateTime start, DateTime? end) {
    if (end == null) return true;
    return start.month != end.month || start.year != end.year;
  }

  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.paused:
        return Colors.blue;
      case TripStatus.active:
        return Colors.green;
      case TripStatus.completed:
        return Colors.grey;
    }
  }

  String _getStatusText(TripStatus status) {
    switch (status) {
      case TripStatus.paused:
        return 'Paused';
      case TripStatus.active:
        return 'Active';
      case TripStatus.completed:
        return 'Completed';
    }
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.single.path == null) return;
    setState(() => _isImporting = true);
    final importResult = await _importService.importFromCsv(result.files.single.path!);
    setState(() => _isImporting = false);
    if (!mounted) return;
    if (!importResult.success) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Failed'),
          content: Text(importResult.error!),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }
    await _loadTrips();
    if (!mounted) return;
    final message = importResult.warning != null
        ? '${importResult.entriesCreated} entries imported.\n\n⚠️ ${importResult.warning}'
        : '${importResult.entriesCreated} entries imported successfully.';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Complete'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (importResult.trip != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TripDetailScreen(trip: importResult.trip!)),
                ).then((_) => _loadTrips());
              }
            },
            child: const Text('View Hike'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadTemplate() async {
    const template =
        '"name","date","direction","start","end","units","notes"\n'
        '"Pacific Crest Trail","2025-04-15","NOBO",0.0,20.0,"mi",First day on trail!\n';
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/hike_entry_template.csv');
      await file.writeAsString(template);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Hike Entry Template',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export template: $e')),
      );
    }
  }

  Future<void> _exportTrip() async {
    if (_trips.isEmpty) return;
    final trip = await showDialog<Trip>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select hike to export'),
        children: _trips.map((t) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, t),
          child: Text(t.name),
        )).toList(),
      ),
    );
    if (trip == null) return;
    await _exportService.exportTripToCsv(trip);
  }
}
