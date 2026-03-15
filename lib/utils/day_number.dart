// lib/utils/day_number.dart

import '../models/entry.dart';


Map<int, int> calculateDayNumbers(List<Entry> entries, DateTime tripStartDate) {
  // Get all unique dates sorted
  final uniqueDates = entries
      .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
      .toSet()
      .toList()
    ..sort();

  // Find the start date normalized
  final start = DateTime(tripStartDate.year, tripStartDate.month, tripStartDate.day);

  // Assign day numbers relative to start date
  // Dates on or after start: 1, 2, 3...
  // Dates before start: 0, -1, -2...
  final datesOnOrAfter = uniqueDates.where((d) => !d.isBefore(start)).toList();
  final datesBefore = uniqueDates.where((d) => d.isBefore(start)).toList();
  // datesBefore is already sorted ascending, so last element = day 0, second to last = day -1, etc.

  final dateToDay = <DateTime, int>{};
  for (int i = 0; i < datesOnOrAfter.length; i++) {
    dateToDay[datesOnOrAfter[i]] = i + 1;
  }
  for (int i = 0; i < datesBefore.length; i++) {
    // datesBefore[last] = day 0, datesBefore[last-1] = day -1, etc.
    dateToDay[datesBefore[i]] = -(datesBefore.length - 1 - i);
  }

  // Map entry IDs to day numbers
  final dayNumbers = <int, int>{};
  for (final entry in entries) {
    final dateKey = DateTime(entry.date.year, entry.date.month, entry.date.day);
    dayNumbers[entry.id!] = dateToDay[dateKey]!;
  }

  return dayNumbers;
}