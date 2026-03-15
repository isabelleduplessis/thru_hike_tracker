import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/trip.dart';
import '../models/entry.dart';
import '../repositories/trip_repository.dart';
import '../repositories/entry_repository.dart';
import '../utils/section_colors.dart';
import '../services/settings_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../utils/day_number.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final TripRepository _tripRepository = TripRepository();
  final EntryRepository _entryRepository = EntryRepository();
  final _settings = SettingsService();
  final MapController _mapController = MapController();

  List<Trip> _trips = [];
  List<Entry> _entries = [];
  Trip? _selectedTrip;
  bool _isLoading = true;
  bool _mapReady = false;
  Map<int, int> _dayNumbers = {};

  Color _colorForEntry(Entry entry, Trip trip) {
    if (trip.sections.isEmpty) {
      final offset = trip.id! % sectionColors.length;
      return sectionColors[offset];
    }
    for (int i = 0; i < trip.sections.length; i++) {
      final section = trip.sections[i];
      if (entry.endMile >= section.startMile && entry.endMile <= section.endMile) {
        return sectionColor(trip.id!, i);
      }
    }
    final offset = trip.id! % sectionColors.length;
    return sectionColors[offset];
  }

  // Map<int, int> _calculateDayNumbers(List<Entry> allEntries) {
  //   final uniqueDates = allEntries
  //       .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
  //       .toSet()
  //       .toList()
  //     ..sort();
  //   final dayNumbers = <int, int>{};
  //   for (final entry in allEntries) {
  //     final dateKey = DateTime(entry.date.year, entry.date.month, entry.date.day);
  //     dayNumbers[entry.id!] = uniqueDates.indexOf(dateKey) + 1;
  //   }
  //   return dayNumbers;
  // }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fitToEntries(List<Entry> entries) {
    if (entries.isEmpty) return;
    final points = entries.map((e) => LatLng(e.latitude!, e.longitude!)).toList();
    final fit = points.length == 1
        ? CameraFit.coordinates(coordinates: points, minZoom: 12, maxZoom: 12)
        : CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(48));
    _mapController.fitCamera(fit);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final trips = await _tripRepository.getAllTrips();
    final entries = await _entryRepository.getEntriesWithCoordinates();
    setState(() {
      _trips = trips;
      _entries = entries;
      _selectedTrip = null;
      _dayNumbers = {};
      _isLoading = false;
    });
    if (_mapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToEntries(entries));
    }
  }

  Future<void> _loadForTrip(Trip trip) async {
    setState(() => _isLoading = true);
    final entries = await _entryRepository.getEntriesWithCoordinatesForTrip(trip.id!);
    // Load ALL entries for day number calculation
    final allEntries = await _entryRepository.getEntriesForTripChronological(trip.id!);
    setState(() {
      _selectedTrip = trip;
      _entries = entries;
      _dayNumbers = calculateDayNumbers(allEntries, trip.startDate);
      _isLoading = false;
    });
    if (_mapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToEntries(entries));
    }
  }

  Trip? _tripForEntry(Entry entry) {
    try {
      return _trips.firstWhere((t) => t.id == entry.tripId);
    } catch (_) {
      return null;
    }
  }

  List<Marker> _buildMarkers() {
    return _entries.map((entry) {
      final trip = _selectedTrip ?? _tripForEntry(entry);
      final color = trip != null ? _colorForEntry(entry, trip) : sectionColors[0];
      return Marker(
        point: LatLng(entry.latitude!, entry.longitude!),
        width: 16,
        height: 16,
        child: GestureDetector(
          onTap: () => _showEntryPopup(entry, trip),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  void _showEntryPopup(Entry entry, Trip? trip) {
    final dayNumber = _dayNumbers[entry.id];
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip!.name,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (dayNumber != null)
                Text(
                  'Day $dayNumber',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              Text(
                entry.date.toIso8601String().substring(0, 10),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${_settings.getDistanceUnitLabel() == "km" ? "KM" : "Mile"} '
                '${_settings.convertToDisplayUnit(entry.startMile).toStringAsFixed(1)} → '
                '${_settings.convertToDisplayUnit(entry.endMile).toStringAsFixed(1)}',
              ),
              Text('Distance: ${_settings.formatDistance(entry.totalDistance)}'),
              if (entry.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  entry.notes,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: DropdownButtonFormField<int?>(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                labelText: 'Select Hike',
              ),
              value: _selectedTrip?.id,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All Hikes')),
                ..._trips.map((trip) => DropdownMenuItem<int?>(
                  value: trip.id,
                  child: Text(trip.name),
                )),
              ],
              onChanged: (int? value) {
                if (value == null) {
                  _loadData();
                } else {
                  final trip = _trips.firstWhere((t) => t.id == value);
                  _loadForTrip(trip);
                }
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(PhosphorIcons.mapTrifold(PhosphorIconsStyle.bold), size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('No entries with coordinates yet.'),
                          ],
                        ),
                      )
                    : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: const LatLng(37.0902, -95.7129),
                          initialZoom: 4,
                          onMapReady: () {
                            _mapReady = true;
                            _fitToEntries(_entries);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.thru_hike_tracker',
                          ),
                          MarkerLayer(markers: _buildMarkers()),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}