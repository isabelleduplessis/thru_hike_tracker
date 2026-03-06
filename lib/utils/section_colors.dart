import 'package:flutter/material.dart';

const List<Color> sectionColors = [
  Color(0xFFF5B700),
  Color(0xFF00A1E4),
  Color(0xFFDC0073),
  Color(0xFF00D7BB),
];

Color sectionColor(int tripId, int sectionIndex) {
  final offset = tripId % sectionColors.length;
  return sectionColors[(offset + sectionIndex) % sectionColors.length];
}