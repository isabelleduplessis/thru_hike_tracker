import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../models/custom_field.dart';
import '../models/entry.dart';
import '../repositories/trip_repository.dart';
import '../repositories/entry_repository.dart';
import '../repositories/custom_field_repository.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final TripRepository _tripRepository = TripRepository();
  final EntryRepository _entryRepository = EntryRepository();
  final CustomFieldRepository _customFieldRepository = CustomFieldRepository();

  bool _isLoading = true;
  Trip? _selectedTrip;
  double _totalMiles = 0;
  int _totalDays = 0;
  double _averageMiles = 0;
  List<Entry> _chartEntries = [];
  List<CustomFieldStat> _customFieldStats = [];

  @override
  void initState() {
    super.initState();
    _loadStatsForAllTrips();
  }

  Future<void> _loadStatsForAllTrips() async {
    setState(() => _isLoading = true);

    final totalMiles = await _entryRepository.getTotalMilesForAllTrips();
    final totalDays = await _entryRepository.getEntryCountForAllTrips();
    final averageMiles = totalDays > 0 ? totalMiles / totalDays : 0.0;
    final customStats = await _customFieldRepository.getCustomFieldStatsLifetime();

    setState(() {
      _selectedTrip = null;
      _totalMiles = totalMiles;
      _totalDays = totalDays;
      _averageMiles = averageMiles;
      _chartEntries = [];  // No chart for all trips
      _customFieldStats = customStats;
      _isLoading = false;
    });
  }

  Future<void> _loadStatsForTrip(Trip trip) async {
    setState(() => _isLoading = true);

    final totalMiles = await _entryRepository.getTotalMilesForTrip(trip.id!);
    final totalDays = await _entryRepository.getEntryCountForTrip(trip.id!);
    final averageMiles = totalDays > 0 ? totalMiles / totalDays : 0.0;
    final chartEntries = await _entryRepository.getEntriesForTripChronological(trip.id!);
    final customStats = await _customFieldRepository.getCustomFieldStatsForTrip(trip.id!);

    setState(() {
      _selectedTrip = trip;
      _totalMiles = totalMiles;
      _totalDays = totalDays;
      _averageMiles = averageMiles;
      _chartEntries = chartEntries;
      _customFieldStats = customStats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Trip Selector
                  _buildTripSelector(),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  if (_totalDays == 0)
                    _buildEmptyState()
                  else ...[
                    // Main Stats Cards
                    _buildMainStats(),
                    const SizedBox(height: 24),
                    
                    // Miles Per Day Chart (only for specific trip)
                    if (_selectedTrip != null && _chartEntries.length > 1) ...[
                      _buildChartSection(),
                      const SizedBox(height: 24),
                    ],
                    
                    // Custom Field Stats
                    if (_customFieldStats.isNotEmpty) ...[
                      _buildCustomFieldStats(),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
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

  Widget _buildMainStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Miles',
                _totalMiles.toStringAsFixed(1),
                Icons.terrain,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Days',
                _totalDays.toString(),
                Icons.calendar_today,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Average Miles/Day',
          _averageMiles.toStringAsFixed(1),
          Icons.trending_up,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
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

  Widget _buildChartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Miles Per Day',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: _buildLineChart(),
        ),
      ],
    );
  }

  Widget _buildLineChart() {
    // Build chart data points
    final spots = _chartEntries.asMap().entries.map((e) {
      return FlSpot(
        e.key.toDouble(),
        e.value.totalDistance,
      );
    }).toList();

    // Build x-axis labels (show fewer when many entries)
    final dateFormat = DateFormat('M/d');
    final interval = (_chartEntries.length / 5).ceil().toDouble();

    return LineChart(
      LineChartData(
        // Grid lines
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.2),
            strokeWidth: 1,
          ),
        ),
        
        // Border
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Colors.grey.withOpacity(0.4)),
            left: BorderSide(color: Colors.grey.withOpacity(0.4)),
          ),
        ),
        
        // X axis
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: interval,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _chartEntries.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      dateFormat.format(_chartEntries[index].date),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        
        // The actual line
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: Colors.green,
            barWidth: 2.5,
            
            // Dots on each data point
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: Colors.green,
                );
              },
            ),
            
            // Area fill under the curve
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withOpacity(0.15),
            ),
          ),
        ],
        
        // Touch tooltip
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final entry = _chartEntries[spot.x.toInt()];
                return LineTooltipItem(
                  '${entry.totalDistance.toStringAsFixed(1)} mi\n${dateFormat.format(entry.date)}',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCustomFieldStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Custom Stats',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(                    // ← Replace GridView.builder with this
          spacing: 12,
          runSpacing: 12,
          children: _customFieldStats.map((stat) {
            return SizedBox(
              width: (MediaQuery.of(context).size.width - 44) / 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.field.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            stat.displayValue,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            stat.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTripSelector() {
    return FutureBuilder<List<Trip>>(
      future: _tripRepository.getAllTrips(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No hikes available'));
        }

        final trips = snapshot.data!;

        return DropdownButtonFormField<int?>(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            labelText: 'Select Hike',
          ),
          value: _selectedTrip?.id,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('All'),
            ),
            ...trips.map((trip) {
              return DropdownMenuItem<int?>(
                value: trip.id,
                child: Text(trip.name),
              );
            }),
          ],
          onChanged: (int? newValue) {
            if (newValue == null) {
              _loadStatsForAllTrips();
            } else {
              final selectedTrip = trips.firstWhere((t) => t.id == newValue);
              _loadStatsForTrip(selectedTrip);
            }
          },
        );
      },
    );
  }
}