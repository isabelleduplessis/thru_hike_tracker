import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
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
    });
  }

  void _recalculateStats() {
    final entries = _filteredChartEntries;

    if (entries.isEmpty) {
      setState(() {
        _totalMiles = 0;
        _totalDays = 0;
        _averageMiles = 0;
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

    setState(() {
      _totalMiles = totalMiles;
      _totalDays = totalDays;
      _averageMiles = averageMiles;
    });

    _recalculateCustomFieldStats();
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
                  const SizedBox(height: 16),
                  _buildStatsHeader(),
                  const SizedBox(height: 8),
                  _buildMainStats(),
                  const SizedBox(height: 24),
                  if (_selectedTrip == null && _allTrips.length > 1) ...[
                    const SizedBox(height: 24),
                    _buildDonutChart(_allTrips, _allTripMiles),
                  ],
                  if (_selectedTrip != null && _filteredChartEntries.map((e) => e.date.toIso8601String().substring(0, 10)).toSet().length > 1) ...[
                    _buildChartSection(),
                    const SizedBox(height: 24),
                  ],
                  if (_selectedTrip != null && _selectedTrip!.tripLength > 0) ...[
                    const Text('Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildOverallProgress(),
                    _buildSectionBreakdown(),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatsHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_selectedTrip != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text('Include zero days', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _includeZeroDays,
                  onChanged: (value) {
                    setState(() => _includeZeroDays = value);
                    _recalculateStats();
                  },
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text('Include +/- distance', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _includeExtraSkippedMiles,
                  onChanged: (value) {
                    setState(() => _includeExtraSkippedMiles = value);
                    _recalculateStats();
                  },
                ),
              ],
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
              child: _buildStatCard('Total Distance', _settings.formatDistance(_totalMiles), Icons.terrain, Colors.green),
            ),
            const SizedBox(width: 10),
            if (_selectedTrip != null)
              Expanded(
                child: _buildStatCard('Total Days', _totalDays.toString(), Icons.calendar_today, Colors.blue),
              )
            else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
        const SizedBox(height: 10),
        if (_selectedTrip != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Avg Per Day', _settings.formatDistance(_averageMiles), Icons.trending_up, Colors.orange),
              ),
              const SizedBox(width: 10),
              if (_includeZeroDays)
                Expanded(
                  child: _buildStatCard('Zero Days', _zeroDays().toString(), Icons.bedtime, Colors.blueGrey),
                )
              else
                const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatCard('Longest Day', _settings.formatDistance(_longestDay), Icons.emoji_events, Colors.purple),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard('Best Streak', '$_bestStreak days', Icons.local_fire_department, Colors.deepOrange),
            ),
          ],
        ),
        if (_selectedTrip != null && _selectedTrip!.neroThreshold != null) ...[
          const SizedBox(height: 10),
          _buildStatCard('Nero Days', _neroDays.toString(), Icons.directions_walk, Colors.amber),
        ],
        if (_totalElevationGain > 0 || _totalElevationLoss > 0) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Total Gain', _settings.formatElevation(_totalElevationGain), Icons.trending_up, Colors.green),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard('Total Loss', _settings.formatElevation(_totalElevationLoss), Icons.trending_down, Colors.red),
              ),
            ],
          ),
        ],
        if (_customFieldStats.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _customFieldStats.map((stat) {
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 44) / 2,
                child: _buildStatCard(
                  stat.field.name,
                  '${stat.displayValue} ${stat.label}',
                  Icons.tune,
                  Colors.cyan,
                ),
              );
            }).toList(),
          ),
        ],
        if (_selectedTrip == null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Total Trips', _totalTrips.toString(), Icons.map, Colors.teal),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  'Longest Trip',
                  _longestTrip != null
                      ? '${_longestTrip!.name}\n${_settings.formatDistance(_longestTripMiles)}'
                      : '-',
                  Icons.hiking,
                  Colors.indigo,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Progress helpers ────────────────────────────────────────────────────

  /// Sum of extra miles - skipped miles for regular (non-alternate) entries
  /// that fall within [rangeStart, rangeEnd] by end mile.
  double _sectionExtraMinusSkipped(double rangeStart, double rangeEnd) {
    return _chartEntries
        .where((e) =>
            e.alternateId == null &&
            e.endMile > rangeStart &&
            e.endMile <= rangeEnd)
        .fold(0.0, (sum, e) => sum + e.extraMiles - e.skippedMiles);
  }

  /// Total extra - skipped across all regular entries for the trip.
  double get _totalExtraMinusSkipped => _chartEntries
      .where((e) => e.alternateId == null)
      .fold(0.0, (sum, e) => sum + e.extraMiles - e.skippedMiles);

  /// Unique trail coverage (ignoring alternate entries) within [rangeStart, rangeEnd].
  double _calculateUniqueCoverage(double rangeStart, double rangeEnd) {
    if (_chartEntries.isEmpty) return 0.0;

    // Only regular (non-alternate) entries contribute to trail coverage
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

  /// Returns completed alternates whose departure mile falls within
  /// [rangeStart, rangeEnd] — used for section-level progress.
  List<Alternate> _completedAltsInRange(double rangeStart, double rangeEnd) {
    if (_selectedTrip == null) return [];
    return _selectedTrip!.alternates.where((a) =>
        a.completed &&
        a.departureMile >= rangeStart &&
        a.departureMile < rangeEnd).toList();
  }

  /// All completed alternates for the trip.
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
      // 100% — denominator equals what was actually hiked, not section length
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

    // Alternate adjustments
    double altNumeratorBonus = 0;
    double altDenominatorAdjust = 0;
    for (final alt in _allCompletedAlts) {
      final altMiles = _altMilesMap[alt.id] ?? 0.0;
      final gap = alt.returnMile - alt.departureMile;
      altNumeratorBonus += altMiles;
      altDenominatorAdjust += altMiles - gap;
    }

    // Completed section gap reduction
    // For each completed section, subtract the uncovered trail gap from denominator
    double sectionGapReduction = 0;
    for (final section in _selectedTrip!.sections.where((s) => s.completed)) {
      final sectionLength = section.endMile - section.startMile;
      final covered = _calculateUniqueCoverage(section.startMile, section.endMile);
      // Also account for completed alts departing from this section
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

  // ── Progress widgets ────────────────────────────────────────────────────

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

  // ── Unchanged below ─────────────────────────────────────────────────────

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

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
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
        const Text('Daily Distance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
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
        const Text('Miles by Trip', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
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