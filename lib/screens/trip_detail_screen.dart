// Shows all entries for a specific trip

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../models/entry.dart';
import '../repositories/entry_repository.dart';
import 'entry_form_screen.dart';
import 'trip_form_screen.dart';
//import '../repositories/gear_repository.dart';
//import '../models/gear.dart';

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
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip.name),
        actions: [
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
            tooltip: 'Edit Hike',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _buildEmptyState()
              : _buildEntryList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EntryFormScreen(trip: widget.trip),
            ),
          );
          
          if (result == true) {
            _loadEntries();
          }
        },
        child: const Icon(Icons.add),
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
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
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
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
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
}