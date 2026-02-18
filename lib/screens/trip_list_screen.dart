// screens/trip_list_screen.dart
// Shows list of all trips, allows creating new ones

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../repositories/trip_repository.dart';
import 'trip_detail_screen.dart';
import 'trip_form_screen.dart';

class TripListScreen extends StatefulWidget {
  const TripListScreen({Key? key}) : super(key: key);

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  final TripRepository _tripRepository = TripRepository();
  List<Trip> _trips = [];
  bool _isLoading = true;

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
    
    setState(() {
      _trips = trips;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Hikes'),
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
            'No trips yet!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to start your first adventure',
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
    final dateFormat = DateFormat('MMM yyyy');
    final startStr = dateFormat.format(trip.startDate);
    final endStr = trip.endDate != null 
        ? dateFormat.format(trip.endDate!)
        : 'Current';
    
    // Show date range only if spans multiple months
    final dateDisplay = _spansMultipleMonths(trip.startDate, trip.endDate)
        ? '$startStr - $endStr'
        : startStr;
    
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
}
