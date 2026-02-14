// Imports
import 'package:flutter/material.dart';
import '../repositories/trip_repository.dart';
  // from here maybe we will have methods for stats screen like total number of trips?
import '../repositories/entry_repository.dart';
  // from here - getTotalMilesForTrip(), getEntryCountForTrip(), getAverageMilesPerDayForTrip()

import '../models/trip.dart';

// screen class
class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);
  
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

// state class
class _StatsScreenState extends State<StatsScreen> {
  // do I need repositories here? - yes, we will need the TripRepository to get the list of trips and the EntryRepository to get the entries for the selected trip(s) in order to calculate the stats
  final TripRepository _tripRepository = TripRepository();
  final EntryRepository _entryRepository = EntryRepository();
  bool _isLoading = true;
  Trip? _selectedTrip; // what does the question mark mean? - it means that this variable can be null, which makes sense because when we first load the screen, we won't have a selected trip yet, and we want to be able to set this variable to null when we want to show stats for all trips combined
  double _totalMiles = 0;
  int _totalDays = 0;
  double _averageMiles = 0;

  // what should go in the init state part? - we can check if the widget has a trip passed in, and if so, we can load the stats for that trip, otherwise we can load the stats for all trips combined
  @override
void initState() {
  super.initState();
  _loadStatsForAllTrips(); // Start with "All Trips" by default
}

  Future<void> _loadStatsForTrip(Trip trip) async {
    setState(() {
      _isLoading = true;
    });
    
    // get total miles, total days, and average miles per day for the selected trip using the entry repository
    final totalMiles = await _entryRepository.getTotalMilesForTrip(trip.id!);
    final totalDays = await _entryRepository.getEntryCountForTrip(trip.id!);
    final averageMiles = totalDays > 0 ? totalMiles / totalDays : 0;

    setState(() {
      _selectedTrip = trip;
      _totalMiles = totalMiles;
      _totalDays = totalDays;
      _averageMiles = averageMiles.toDouble(); // what's num vs double? is it like int vs double? - num is a more general type that can represent both integers and floating-point numbers, while double specifically represents floating-point numbers. In this case, since we are calculating average miles per day, which can be a decimal value, we want to make sure that we are treating it as a double to preserve the decimal precision, even if the total miles and total days are integers. By converting it to a double, we ensure that we get an accurate average value that can include decimal points if necessary.
      _isLoading = false;
    });
  }

  Future<void> _loadStatsForAllTrips() async { // what does async mean? - it means that this function is asynchronous, which allows us to use the await keyword inside the function to wait for the results of asynchronous operations, such as fetching data from a database or an API, without blocking the main thread of the application. This is important for maintaining a responsive user interface while performing potentially time-consuming tasks.
    setState(() {
      _isLoading = true;
    });
    
    // get total miles, total days, and average miles per day for all trips combined using the entry repository
    final totalMiles = await _entryRepository.getTotalMilesForAllTrips(); // where should these be defined? - these should be defined in the EntryRepository class, where we can have methods like getTotalMilesForTrip(int tripId) and getTotalMilesForAllTrips() that will query the database and return the appropriate results based on the trip ID or for all trips combined
    final totalDays = await _entryRepository.getEntryCountForAllTrips();
    final averageMiles = totalDays > 0 ? totalMiles / totalDays : 0;

    setState(() {
      _selectedTrip = null; // we can set this to null since we are showing stats for all trips combined
      _totalMiles = totalMiles;
      _totalDays = totalDays;
      _averageMiles = averageMiles.toDouble();
      _isLoading = false;
    });
  }

  // now add build, build empty state, build other things? what should be built? - we can build a simple stats display that shows the total miles, total days, and average miles per day for the selected trip, and if showAllTripsStats is true, we can show the combined stats for all trips instead
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildTripSelector(),
                const Divider(),
                Expanded(
                  child: _buildStatsDisplay(),  // ← Just always show stats display
                ),
              ],
            ),
    );
  }

  Widget _buildStatsDisplay() {
    // If no data, show empty message
    if (_totalDays == 0) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 100, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No entries yet!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Start logging your hikes to see stats',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    // Otherwise show the stats cards
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatCard(
            'Total Miles',
            _totalMiles.toStringAsFixed(1),
            Icons.terrain,
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Total Days',
            _totalDays.toString(),
            Icons.calendar_today,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Average Miles/Day',
            _averageMiles.toStringAsFixed(1),
            Icons.trending_up,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

    Widget _buildTripSelector() {
    return FutureBuilder<List<Trip>>(
      future: _tripRepository.getAllTrips(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No hikes available'));
        }
        
        final trips = snapshot.data!;
        
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Hike:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(  // ← Changed from Trip? to int?
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                value: _selectedTrip?.id,  // ← Use the ID, not the whole object
                hint: const Text('Select a hike'),
                items: [
                  // "All Trips" option
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All'),
                  ),
                  // Individual trips
                  ...trips.map((trip) {
                    return DropdownMenuItem<int?>(
                      value: trip.id,  // ← Use ID as value
                      child: Text(trip.name),
                    );
                  }),
                ],
                onChanged: (int? newValue) {  // ← Changed from Trip? to int?
                  if (newValue == null) {
                    _loadStatsForAllTrips();
                  } else {
                    // Find the trip with this ID
                    final selectedTrip = trips.firstWhere((t) => t.id == newValue);
                    _loadStatsForTrip(selectedTrip);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}