import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/trip.dart';
import '../models/custom_field.dart';
import '../models/entry.dart';
import '../repositories/trip_repository.dart';
import '../repositories/entry_repository.dart';
import '../repositories/custom_field_repository.dart';
import '../services/settings_service.dart';
import '../models/section.dart';
import '../utils/section_colors.dart';
import '../utils/day_number.dart';


class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final TripRepository _tripRepository = TripRepository();
  final EntryRepository _entryRepository = EntryRepository();
  final CustomFieldRepository _customFieldRepository = CustomFieldRepository();
  final _settings = SettingsService();

  bool _isLoading = true;
  Trip? _selectedTrip;
  double _totalMiles = 0;
  int _totalDays = 0;
  double _averageMiles = 0;
  List<Entry> _chartEntries = [];
  List<CustomFieldStat> _customFieldStats = [];
  bool _includeZeroDays = true;
  bool _includeExtraSkippedMiles = true;
  double _longestDay = 0;
  int _bestStreak = 0;
  Trip? _longestTrip;
  int _totalTrips = 0;
  List<Trip> _allTrips = [];
  List<double> _allTripMiles = [];
  double _longestTripMiles = 0;
  int _neroDays = 0;
  double _totalElevationGain = 0;
  double _totalElevationLoss = 0;
  double _bestWeekMiles = 0;
  int _completedTrips = 0;

  // alternateId -> total miles logged on that alternate for current trip
  Map<int, double> _altMilesMap = {};

  double _entryDistance(Entry e) =>
      _includeExtraSkippedMiles ? e.totalDistance : e.netDistance;

  List<Entry> get _filteredChartEntries {
    if (_includeZeroDays) return _chartEntries;
    return _chartEntries.where((e) => _entryDistance(e) > 0).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadDefaultTrip();
  }

  Future<void> _loadDefaultTrip() async {
    final mostRecent = await _tripRepository.getMostRecentTrip();
    if (mostRecent != null) {
      _loadStatsForTrip(mostRecent);
    } else {
      _loadStatsForAllTrips();
    }
  }

  Future<void> _recalculateCustomFieldStats() async {
    if (_selectedTrip == null) return;
    final filteredEntryIds = _filteredChartEntries
        .where((e) => e.id != null)
        .map((e) => e.id!)
        .toList();
    final customStats = await _customFieldRepository
        .getCustomFieldStatsForEntries(_selectedTrip!.id!, filteredEntryIds);
    if (mounted) setState(() => _customFieldStats = customStats);
  }

  Future<void> _loadStatsForAllTrips() async {
    setState(() => _isLoading = true);

    final totalMiles = await _entryRepository.getTotalMilesForAllTrips();
    final totalDays = await _entryRepository.getEntryCountForAllTrips();
    final averageMiles = totalDays > 0 ? totalMiles / totalDays : 0.0;
    final customStats = await _customFieldRepository.getCustomFieldStatsLifetime();
    final longestDay = await _entryRepository.getLongestDayAllTrips();
    final bestStreak = await _entryRepository.getBestStreakAllTrips();
    final longestTrip = await _tripRepository.getLongestTrip();
    final allTrips = await _tripRepository.getAllTrips();
    final allTripMiles = await Future.wait(
      allTrips.map((t) => _entryRepository.getTotalMilesForTrip(t.id!))
    );
    final longestTripMiles = longestTrip != null
      ? await _entryRepository.getTotalMilesForTrip(longestTrip.id!)
      : 0.0;
    final elevationGain = await _entryRepository.getTotalElevationGainAllTrips();
    final elevationLoss = await _entryRepository.getTotalElevationLossAllTrips();
    final bestWeek = await _entryRepository.getBestRolling7DayMilesAllTrips();
    final completedTrips = allTrips.where((t) => t.status == "completed").length;

    setState(() {
      _selectedTrip = null;
      _totalMiles = totalMiles;
      _totalDays = totalDays;
      _averageMiles = averageMiles;
      _chartEntries = [];
      _customFieldStats = customStats;
      _longestDay = longestDay;
      _bestStreak = bestStreak;
      _longestTrip = longestTrip;
      _totalTrips = allTrips.length;
      _isLoading = false;
      _allTrips = allTrips;
      _allTripMiles = allTripMiles;
      _longestTripMiles = longestTripMiles;
      _totalElevationGain = elevationGain;
      _totalElevationLoss = elevationLoss;
      _neroDays = 0;
      _altMilesMap = {};
      _bestWeekMiles = bestWeek;
      _completedTrips = completedTrips;
    });
  }

  void _recalculateStats() {
    final entries = _filteredChartEntries;

    if (entries.isEmpty) {
      setState(() {
        _totalMiles = 0;
        _totalDays = 0;
        _averageMiles = 0;
        _bestWeekMiles = 0;
      });
      _recalculateCustomFieldStats();
      return;
    }

    final Map<String, double> dailyMiles = {};
    for (final e in entries) {
      final day = e.date.toIso8601String().substring(0, 10);
      dailyMiles[day] = (dailyMiles[day] ?? 0) + _entryDistance(e);
    }

    final totalMiles = dailyMiles.values.fold(0.0, (sum, v) => sum + v);
    final totalDays = dailyMiles.length;
    final averageMiles = totalMiles / totalDays;
    final bestWeek = _calculateBestRolling7Day(dailyMiles);

    setState(() {
      _totalMiles = totalMiles;
      _totalDays = totalDays;
      _averageMiles = averageMiles;
      _bestWeekMiles = bestWeek;
    });

    _recalculateCustomFieldStats();
  }

  /// Calculates the highest total miles across any rolling 7-day window.
  double _calculateBestRolling7Day(Map<String, double> dailyMiles) {
    if (dailyMiles.isEmpty) return 0.0;
    final sortedDays = dailyMiles.keys.toList()..sort();
    double best = 0.0;
    for (int i = 0; i < sortedDays.length; i++) {
      final windowStart = DateTime.parse(sortedDays[i]);
      final windowEnd = windowStart.add(const Duration(days: 6));
      double sum = 0.0;
      for (int j = i; j < sortedDays.length; j++) {
        final d = DateTime.parse(sortedDays[j]);
        if (d.isAfter(windowEnd)) break;
        sum += dailyMiles[sortedDays[j]]!;
      }
      if (sum > best) best = sum;
    }
    return best;
  }

  Future<void> _loadStatsForTrip(Trip trip) async {
    setState(() => _isLoading = true);

    final totalMiles = await _entryRepository.getTotalMilesForTrip(trip.id!);
    final totalDays = await _entryRepository.getEntryCountForTrip(trip.id!);
    final averageMiles = totalDays > 0 ? totalMiles / totalDays : 0.0;
    final chartEntries = await _entryRepository.getEntriesForTripChronological(trip.id!);
    final longestDay = await _entryRepository.getLongestDayForTrip(trip.id!);
    final bestStreak = await _entryRepository.getBestStreakForTrip(trip.id!);
    final neroDays = trip.neroThreshold != null
        ? await _entryRepository.getNeroDaysForTrip(trip.id!, trip.neroThreshold!)
        : 0;
    final elevationGain = trip.trackElevation
        ? await _entryRepository.getTotalElevationGainForTrip(trip.id!)
        : 0.0;
    final elevationLoss = trip.trackElevation
        ? await _entryRepository.getTotalElevationLossForTrip(trip.id!)
        : 0.0;
    final altMilesMap = await _entryRepository.getAltMilesByAlternateId(trip.id!);

    setState(() {
      _selectedTrip = trip;
      _totalMiles = totalMiles;
      _totalDays = totalDays;
      _averageMiles = averageMiles;
      _chartEntries = chartEntries;
      _longestDay = longestDay;
      _bestStreak = bestStreak;
      _neroDays = neroDays;
      _totalElevationGain = elevationGain;
      _totalElevationLoss = elevationLoss;
      _altMilesMap = altMilesMap;
      _isLoading = false;
      _bestWeekMiles = 0;
    });

    _recalculateStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTripSelector(),
                  const SizedBox(height: 12),
                  _buildToggleRow(),
                  const SizedBox(height: 8),
                  _buildMainStats(),
                  const SizedBox(height: 16),
                  if (_selectedTrip == null && _allTrips.length > 1) ...[
                    _buildDonutChart(_allTrips, _allTripMiles),
                    const SizedBox(height: 16),
                  ],
                  if (_selectedTrip != null && _filteredChartEntries.map((e) => e.date.toIso8601String().substring(0, 10)).toSet().length > 1) ...[
                    _buildChartSection(),
                    const SizedBox(height: 16),
                    if (_selectedTrip!.trackElevation) ...[
                      _buildElevationChartSection(),
                      const SizedBox(height: 16),
                    ],
                  ],
                  if (_selectedTrip != null && _selectedTrip!.tripLength > 0) ...[
                    const Text('Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    _buildOverallProgress(),
                    _buildSectionBreakdown(),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
    );
  }

  // ── Toggles ──────────────────────────────────────────────────────────────

  Widget _buildToggleRow() {
    if (_selectedTrip == null) return const SizedBox.shrink();
    return Column(
      children: [
        _buildCheckboxRow(
          label: 'Include zero days',
          value: _includeZeroDays,
          onChanged: (v) {
            setState(() => _includeZeroDays = v ?? true);
            _recalculateStats();
          },
        ),
        _buildCheckboxRow(
          label: 'Include +/- distance',
          value: _includeExtraSkippedMiles,
          onChanged: (v) {
            setState(() => _includeExtraSkippedMiles = v ?? true);
            _recalculateStats();
          },
        ),
      ],
    );
  }

  Widget _buildCheckboxRow({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ── Stat cards ───────────────────────────────────────────────────────────

  Widget _buildMainStats() {
    return Column(
      children: [
        _buildStatCard('Total Distance', _settings.formatDistance(_totalMiles), PhosphorIconsRegular.path, Colors.green),
        if (_selectedTrip != null) ...[
          _buildStatCard('Total Days', _totalDays.toString(), PhosphorIconsRegular.calendarDots, Colors.blue),
          _buildStatCard('Avg Per Day', _settings.formatDistance(_averageMiles), PhosphorIconsRegular.trendUp, Colors.orange),
          if (_includeZeroDays)
            _buildStatCard('Zero Days', _zeroDays().toString(), PhosphorIconsRegular.moon, Colors.blueGrey),
        ],
        _buildStatCard('Longest Day', _settings.formatDistance(_longestDay), PhosphorIconsRegular.trophy, Colors.purple),
        _buildStatCard('Best Streak', '$_bestStreak days', PhosphorIconsRegular.flame, Colors.deepOrange),
        if (_bestWeekMiles > 0)
          _buildStatCard('Best 7-Day', _settings.formatDistance(_bestWeekMiles), PhosphorIconsRegular.calendarCheck, Colors.teal),
        if (_selectedTrip != null && _selectedTrip!.neroThreshold != null)
          _buildStatCard('Nero Days', _neroDays.toString(), PhosphorIconsRegular.personSimpleWalk, Colors.amber),
        if (_totalElevationGain > 0 || _totalElevationLoss > 0) ...[
          _buildStatCard('Total Gain', _settings.formatElevation(_totalElevationGain), PhosphorIconsRegular.arrowUp, Colors.green),
          _buildStatCard('Total Loss', _settings.formatElevation(_totalElevationLoss), PhosphorIconsRegular.arrowDown, Colors.red),
        ],
        if (_customFieldStats.isNotEmpty)
          ..._customFieldStats.map((stat) => _buildStatCard(
            stat.field.name,
            '${stat.displayValue} ${stat.label}',
            PhosphorIconsRegular.sliders,
            Colors.cyan,
          )),
        if (_selectedTrip == null) ...[
          _buildStatCard('Total Trips', _totalTrips.toString(), PhosphorIconsRegular.mapTrifold, Colors.teal),
          _buildStatCard(
            'Longest Trip',
            _longestTrip != null
                ? '${_longestTrip!.name}  ${_settings.formatDistance(_longestTripMiles)}'
                : '-',
            PhosphorIconsRegular.mountains, Colors.indigo,
          ),
          _buildCompletedTripsCard(),
        ],
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedTripsCard() {
    if (_completedTrips == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsRegular.crown, size: 14, color: Colors.amber[700]),
              const SizedBox(width: 8),
              Text('Completed Trails', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _completedTrips.toString(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(
              _completedTrips,
              (_) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(PhosphorIconsFill.crown, size: 16, color: Colors.amber[600]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Charts ───────────────────────────────────────────────────────────────

  Widget _buildChartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Daily Distance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_filteredChartEntries.map((e) => e.date.toIso8601String().substring(0, 10)).toSet().length > 1)
          SizedBox(height: 260, child: _buildLineChart())
        else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('Not enough entries to show chart', style: TextStyle(color: Colors.grey)),
            ),
          ),
      ],
    );
  }

  Widget _buildLineChart() {
    final entries = _filteredChartEntries;

    final Map<String, double> dailyMiles = {};
    for (final e in entries) {
      final day = e.date.toIso8601String().substring(0, 10);
      dailyMiles[day] = (dailyMiles[day] ?? 0) + _entryDistance(e);
    }
    final sortedDays = dailyMiles.keys.toList()..sort();

    final dayNums = calculateDayNumbers(_filteredChartEntries, _selectedTrip!.startDate);
    final dateToDayNum = <String, int>{};
    for (final entry in _filteredChartEntries) {
      final dateStr = entry.date.toIso8601String().substring(0, 10);
      dateToDayNum[dateStr] = dayNums[entry.id!]!;
    }

    final spots = sortedDays.map((day) {
      return FlSpot(
        dateToDayNum[day]!.toDouble(),
        _settings.convertToDisplayUnit(dailyMiles[day]!),
      );
    }).toList();

    final allDayNums = dateToDayNum.values.toList()..sort();
    final totalDays = allDayNums.length;
    final lastDay = allDayNums.last;
    final firstDay = allDayNums.first;

    final step = totalDays <= 10 ? 1
        : totalDays <= 30 ? 5
        : totalDays <= 100 ? 10
        : 20;

    final maxMiles = dailyMiles.isEmpty
        ? 25.0
        : dailyMiles.values.reduce((a, b) => a > b ? a : b);
    final maxInDisplayUnit = _settings.convertToDisplayUnit(maxMiles);
    final yMax = ((maxInDisplayUnit / 5).ceil() * 5).toDouble();
    final yInterval = yMax <= 25 ? 5.0 : (yMax / 5).ceilToDouble();
    final xGridInterval = step.toDouble();

    return LineChart(
      LineChartData(
        minX: firstDay.toDouble(),
        maxX: lastDay.toDouble(),
        minY: 0,
        maxY: yMax > 0 ? yMax : 25,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: yInterval,
          verticalInterval: xGridInterval,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
          getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Colors.grey.withOpacity(0.4), width: 1),
            left: BorderSide(color: Colors.grey.withOpacity(0.4), width: 1),
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            axisNameWidget: const Padding(
              padding: EdgeInsets.only(top: 0),
              child: Text('Day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              interval: xGridInterval,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final dayNum = value.toInt();
                if (dayNum % step != 0) return const SizedBox.shrink();
                return Text(dayNum.toString(), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Padding(
              padding: const EdgeInsets.only(bottom: 0),
              child: Text(_settings.getDistanceUnitLabel(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              interval: yInterval,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: Colors.green,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withOpacity(0.15),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final dayNum = spot.x.toInt();
                final dateStr = dateToDayNum.entries
                    .firstWhere((e) => e.value == dayNum,
                        orElse: () => const MapEntry('', 0))
                    .key;
                if (dateStr.isEmpty) return null;
                final miles = dailyMiles[dateStr];
                if (miles == null) return null;
                final date = DateTime.parse(dateStr);
                final dateFormat = DateFormat('M/d');
                return LineTooltipItem(
                  'Day $dayNum\n${_settings.formatDistance(miles)}\n${dateFormat.format(date)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  // ── Elevation chart ──────────────────────────────────────────────────────

  Widget _buildElevationChartSection() {
    if (_selectedTrip == null) return const SizedBox.shrink();

    // Build daily gain/loss sums using the same day-number logic as the mileage chart
    final entries = _filteredChartEntries
        .where((e) => (e.elevationGain != null && e.elevationGain! != 0) ||
                      (e.elevationLoss != null && e.elevationLoss! != 0))
        .toList();

    if (entries.length < 2) return const SizedBox.shrink();

    final Map<String, double> dailyGain = {};
    final Map<String, double> dailyLoss = {};
    for (final e in _filteredChartEntries) {
      final day = e.date.toIso8601String().substring(0, 10);
      dailyGain[day] = (dailyGain[day] ?? 0) + (e.elevationGain ?? 0);
      dailyLoss[day] = (dailyLoss[day] ?? 0) + (e.elevationLoss ?? 0);
    }

    final sortedDays = dailyGain.keys.toList()..sort();
    if (sortedDays.length < 2) return const SizedBox.shrink();

    // Reuse the exact same day-number calculation
    final dayNums = calculateDayNumbers(_filteredChartEntries, _selectedTrip!.startDate);
    final dateToDayNum = <String, int>{};
    for (final entry in _filteredChartEntries) {
      final dateStr = entry.date.toIso8601String().substring(0, 10);
      dateToDayNum[dateStr] = dayNums[entry.id!]!;
    }

    final gainSpots = <FlSpot>[];
    final lossSpots = <FlSpot>[];
    for (final day in sortedDays) {
      final dayNum = dateToDayNum[day];
      if (dayNum == null) continue;
      final x = dayNum.toDouble();
      gainSpots.add(FlSpot(x, _settings.convertToDisplayElevation(dailyGain[day]!)));
      // Loss is stored as positive; render below zero
      lossSpots.add(FlSpot(x, -_settings.convertToDisplayElevation(dailyLoss[day]!.abs())));
    }

    final allDayNums = dateToDayNum.values.toList()..sort();
    final totalDays = allDayNums.length;
    final firstDay = allDayNums.first.toDouble();
    final lastDay = allDayNums.last.toDouble();

    final step = totalDays <= 10 ? 1
        : totalDays <= 30 ? 5
        : totalDays <= 100 ? 10
        : 20;
    final xGridInterval = step.toDouble();

    final maxGain = gainSpots.isEmpty ? 0.0 : gainSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxLoss = lossSpots.isEmpty ? 0.0 : lossSpots.map((s) => s.y.abs()).reduce((a, b) => a > b ? a : b);
    final rawMax = maxGain > maxLoss ? maxGain : maxLoss;
    final yAbsMax = ((rawMax / 500).ceil() * 500).toDouble().clamp(500.0, double.infinity);
    final yInterval = yAbsMax <= 2000 ? 500.0 : (yAbsMax / 4).ceilToDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Daily Elevation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          children: [
            _elevLegendDot(Colors.green),
            const SizedBox(width: 4),
            Text('Gain', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(width: 12),
            _elevLegendDot(Colors.red),
            const SizedBox(width: 4),
            Text('Loss', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 260,
          child: LineChart(
            LineChartData(
              minX: firstDay,
              maxX: lastDay,
              minY: -yAbsMax,
              maxY: yAbsMax,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: yInterval,
                verticalInterval: xGridInterval,
                getDrawingHorizontalLine: (value) {
                  if (value == 0) {
                    return FlLine(color: Colors.grey.withOpacity(0.6), strokeWidth: 1.2);
                  }
                  return FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1);
                },
                getDrawingVerticalLine: (value) =>
                    FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.withOpacity(0.4), width: 1),
                  left: BorderSide(color: Colors.grey.withOpacity(0.4), width: 1),
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text('Day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: xGridInterval,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final dayNum = value.toInt();
                      if (dayNum % step != 0) return const SizedBox.shrink();
                      return Text(dayNum.toString(), style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  axisNameWidget: Text(
                    _settings.getElevationUnitLabel(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: yInterval,
                    reservedSize: 45,
                    getTitlesWidget: (value, meta) {
                      return Text(value.toInt().toString(), style: const TextStyle(fontSize: 9));
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                // Gain — green, above zero
                LineChartBarData(
                  spots: gainSpots,
                  isCurved: false,
                  color: Colors.green,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    cutOffY: 0,
                    applyCutOffY: true,
                    color: Colors.green.withOpacity(0.15),
                  ),
                ),
                // Loss — red, below zero
                LineChartBarData(
                  spots: lossSpots,
                  isCurved: false,
                  color: Colors.red,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  aboveBarData: BarAreaData(
                    show: true,
                    cutOffY: 0,
                    applyCutOffY: true,
                    color: Colors.red.withOpacity(0.15),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final dayNum = spot.x.toInt();
                      final dateStr = dateToDayNum.entries
                          .firstWhere((e) => e.value == dayNum,
                              orElse: () => const MapEntry('', 0))
                          .key;
                      if (dateStr.isEmpty) return null;
                      final isGain = spot.barIndex == 0;
                      final rawVal = isGain
                          ? (dailyGain[dateStr] ?? 0)
                          : (dailyLoss[dateStr]?.abs() ?? 0);
                      final date = DateTime.parse(dateStr);
                      return LineTooltipItem(
                        'Day $dayNum\n${isGain ? "Gain" : "Loss"}: ${_settings.formatElevation(rawVal)}\n${DateFormat('M/d').format(date)}',
                        TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _elevLegendDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  // ── Trip selector ────────────────────────────────────────────────────────

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
            const DropdownMenuItem<int?>(value: null, child: Text('All')),
            ...trips.map((trip) => DropdownMenuItem<int?>(
              value: trip.id,
              child: Text(trip.name),
            )),
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

  // ── Progress helpers ─────────────────────────────────────────────────────

  double _sectionExtraMinusSkipped(double rangeStart, double rangeEnd) {
    return _chartEntries
        .where((e) =>
            e.alternateId == null &&
            e.endMile > rangeStart &&
            e.endMile <= rangeEnd)
        .fold(0.0, (sum, e) => sum + e.extraMiles - e.skippedMiles);
  }

  double get _totalExtraMinusSkipped => _chartEntries
      .where((e) => e.alternateId == null)
      .fold(0.0, (sum, e) => sum + e.extraMiles - e.skippedMiles);

  double _calculateUniqueCoverage(double rangeStart, double rangeEnd) {
    if (_chartEntries.isEmpty) return 0.0;

    final regularEntries = _chartEntries.where((e) => e.alternateId == null);

    List<List<double>> ranges = regularEntries.map((e) {
      double start = e.startMile < e.endMile ? e.startMile : e.endMile;
      double end = e.startMile < e.endMile ? e.endMile : e.startMile;
      return [start, end];
    }).toList();

    ranges.sort((a, b) => a[0].compareTo(b[0]));

    List<List<double>> merged = [];
    if (ranges.isNotEmpty) {
      var current = List<double>.from(ranges[0]);
      for (int i = 1; i < ranges.length; i++) {
        if (ranges[i][0] <= current[1]) {
          if (ranges[i][1] > current[1]) current[1] = ranges[i][1];
        } else {
          merged.add(current);
          current = List<double>.from(ranges[i]);
        }
      }
      merged.add(current);
    }

    double totalCoverage = 0;
    for (var m in merged) {
      double overlapStart = m[0] > rangeStart ? m[0] : rangeStart;
      double overlapEnd = m[1] < rangeEnd ? m[1] : rangeEnd;
      if (overlapStart < overlapEnd) {
        totalCoverage += (overlapEnd - overlapStart);
      }
    }
    return totalCoverage;
  }

  List<Alternate> _completedAltsInRange(double rangeStart, double rangeEnd) {
    if (_selectedTrip == null) return [];
    return _selectedTrip!.alternates.where((a) =>
        a.completed &&
        a.departureMile >= rangeStart &&
        a.departureMile < rangeEnd).toList();
  }

  List<Alternate> get _allCompletedAlts {
    if (_selectedTrip == null) return [];
    return _selectedTrip!.alternates.where((a) => a.completed).toList();
  }

  ProgressData _calculateSectionProgress(Section section) {
    final extraSkipped = _sectionExtraMinusSkipped(section.startMile, section.endMile);
    final trailCoverage = _calculateUniqueCoverage(section.startMile, section.endMile);

    double altNumeratorBonus = 0;
    double altDenominatorAdjust = 0;
    for (final alt in _completedAltsInRange(section.startMile, section.endMile)) {
      final altMiles = _altMilesMap[alt.id] ?? 0.0;
      final gap = alt.returnMile - alt.departureMile;
      altNumeratorBonus += altMiles;
      altDenominatorAdjust += altMiles - gap;
    }

    final actualCovered = trailCoverage + altNumeratorBonus + extraSkipped;

    if (section.completed) {
      return ProgressData(actualCovered, actualCovered);
    }

    final sectionLength = section.endMile - section.startMile;
    final denominator = sectionLength + altDenominatorAdjust + extraSkipped;
    return ProgressData(actualCovered, denominator);
  }

  ProgressData _calculateOverallProgress() {
    final trip = _selectedTrip!;
    final extraSkipped = _totalExtraMinusSkipped;
    final trailCoverage = _calculateUniqueCoverage(trip.startMile, trip.endMile);

    double altNumeratorBonus = 0;
    double altDenominatorAdjust = 0;
    for (final alt in _allCompletedAlts) {
      final altMiles = _altMilesMap[alt.id] ?? 0.0;
      final gap = alt.returnMile - alt.departureMile;
      altNumeratorBonus += altMiles;
      altDenominatorAdjust += altMiles - gap;
    }

    double sectionGapReduction = 0;
    for (final section in _selectedTrip!.sections.where((s) => s.completed)) {
      final sectionLength = section.endMile - section.startMile;
      final covered = _calculateUniqueCoverage(section.startMile, section.endMile);
      double sectionAltBonus = 0;
      for (final alt in _completedAltsInRange(section.startMile, section.endMile)) {
        sectionAltBonus += _altMilesMap[alt.id] ?? 0.0;
      }
      final actualCovered = covered + sectionAltBonus;
      final gap = (sectionLength - actualCovered).clamp(0.0, double.infinity);
      sectionGapReduction += gap;
    }

    final numerator = trailCoverage + altNumeratorBonus + extraSkipped;
    final denominator = trip.tripLength + altDenominatorAdjust + extraSkipped - sectionGapReduction;
    return ProgressData(numerator, denominator);
  }

  // ── Progress widgets ─────────────────────────────────────────────────────

  Widget _buildOverallProgress() {
    if (_selectedTrip == null) return const SizedBox.shrink();
    final stats = _calculateOverallProgress();
    return _buildBaseProgressBar(
      stats.percentage,
      stats.coveredWithExtra,
      stats.adjustedTotal,
      'Overall Progress',
    );
  }

  Widget _buildSectionBreakdown() {
    if (_selectedTrip == null || _selectedTrip!.sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(top: 16, bottom: 8)),
        ..._selectedTrip!.sections.asMap().entries.map((e) {
          final index = e.key;
          final section = e.value;
          final stats = _calculateSectionProgress(section);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildBaseProgressBar(
              stats.percentage,
              stats.coveredWithExtra,
              stats.adjustedTotal,
              section.name,
              color: sectionColor(_selectedTrip!.id!, index),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildBaseProgressBar(double progress, double completed, double total, String label, {Color? color}) {
    final barColor = color ?? Theme.of(context).colorScheme.primary;
    final remaining = (total - completed).clamp(0.0, double.infinity);
    final percentText = '${(progress * 100).toStringAsFixed(1)}%';
    final isOverall = label == 'Overall Progress';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isOverall ? 13 : 12,
                fontWeight: isOverall ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth = constraints.maxWidth;
                    final fillWidth = (progress * barWidth).clamp(0.0, barWidth);
                    final showTextInside = fillWidth > 50;

                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        Container(
                          height: 18,
                          width: fillWidth,
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        Positioned(
                          left: showTextInside ? (fillWidth - 48) : (fillWidth + 6),
                          child: Text(
                            percentText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: showTextInside ? Colors.white : barColor,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 2),
                Text(
                  '${_settings.formatDistance(completed)} / ${_settings.formatDistance(total)}  •  ${_settings.formatDistance(remaining)} remaining',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Donut chart ──────────────────────────────────────────────────────────

  Widget _buildDonutChart(List<Trip> trips, List<double> miles) {
    final total = miles.fold(0.0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    const colors = [
      Color(0xFF04E762), Color(0xFFF5B700), Color(0xFF00A1E4),
      Color(0xFFDC0073), Color(0xFF00D7BB),
    ];

    final sections = trips.asMap().entries.map((e) {
      final pct = miles[e.key] / total;
      return PieChartSectionData(
        value: miles[e.key],
        color: colors[e.key % colors.length],
        title: pct > 0.08 ? '${(pct * 100).toStringAsFixed(0)}%' : '',
        radius: 48,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Miles by Trip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: Row(
            children: [
              Expanded(
                child: PieChart(PieChartData(
                  sections: sections,
                  centerSpaceRadius: 52,
                  sectionsSpace: 2,
                )),
              ),
              const SizedBox(width: 16),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: trips.asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: colors[e.key % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(e.value.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  int _zeroDays() {
    final Map<String, double> dailyMiles = {};
    for (final e in _filteredChartEntries) {
      final day = e.date.toIso8601String().substring(0, 10);
      dailyMiles[day] = (dailyMiles[day] ?? 0) + _entryDistance(e);
    }
    return dailyMiles.values.where((v) => v == 0).length;
  }
}

class ProgressData {
  final double coveredWithExtra;
  final double adjustedTotal;
  ProgressData(this.coveredWithExtra, this.adjustedTotal);
  double get percentage => adjustedTotal > 0 ? (coveredWithExtra / adjustedTotal).clamp(0.0, 1.0) : 0.0;
}