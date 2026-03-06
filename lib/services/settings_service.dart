import 'package:shared_preferences/shared_preferences.dart';

enum UnitSystem {
  imperial,
  metric,
}

class SettingsService {
  static const String _unitSystemKey = 'unit_system';

  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  UnitSystem getUnitSystem() {
    final value = _prefs?.getString(_unitSystemKey);
    if (value == 'metric') return UnitSystem.metric;
    return UnitSystem.imperial;
  }

  Future<void> setUnitSystem(UnitSystem system) async {
    await _prefs?.setString(
      _unitSystemKey,
      system == UnitSystem.metric ? 'metric' : 'imperial',
    );
  }

  // --- DISTANCE ---

  double convertToDisplayUnit(double miles) {
    if (getUnitSystem() == UnitSystem.metric) return miles * 1.60934;
    return miles;
  }

  double convertFromDisplayUnit(double value) {
    if (getUnitSystem() == UnitSystem.metric) return value / 1.60934;
    return value;
  }

  String getDistanceUnitLabel() {
    return getUnitSystem() == UnitSystem.metric ? 'km' : 'mi';
  }

  String formatDistance(double miles, {int decimals = 1}) {
    final converted = convertToDisplayUnit(miles);
    return '${converted.toStringAsFixed(decimals)} ${getDistanceUnitLabel()}';
  }

  // --- ELEVATION ---

  double convertToDisplayElevation(double feet) {
    if (getUnitSystem() == UnitSystem.metric) return feet * 0.3048;
    return feet;
  }

  double convertFromDisplayElevation(double value) {
    if (getUnitSystem() == UnitSystem.metric) return value / 0.3048;
    return value;
  }

  String getElevationUnitLabel() {
    return getUnitSystem() == UnitSystem.metric ? 'm' : 'ft';
  }

  String formatElevation(double feet, {int decimals = 0}) {
    final converted = convertToDisplayElevation(feet);
    return '${converted.toStringAsFixed(decimals)} ${getElevationUnitLabel()}';
  }
}