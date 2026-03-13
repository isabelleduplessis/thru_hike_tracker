import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/trip.dart';
import '../models/entry.dart';
import '../repositories/trip_repository.dart';
import '../repositories/entry_repository.dart';
import '../utils/section_colors.dart';
import '../services/settings_service.dart';

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
      _isLoading = false;
    });
    if (_mapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToEntries(entries));
    }
    // if not ready, onMapReady will call _fitToEntries
  }

  Future<void> _loadForTrip(Trip trip) async {
    setState(() => _isLoading = true);
    final entries = await _entryRepository.getEntriesWithCoordinatesForTrip(trip.id!);
    setState(() {
      _selectedTrip = trip;
      _entries = entries;
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
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trip?.name ?? 'Unknown Trip', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
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
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No entries with coordinates yet.'),
                            SizedBox(height: 8),
                            Text(
                              'Use the location button when logging entries.',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
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