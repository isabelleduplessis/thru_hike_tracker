import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();
  late UnitSystem _selectedSystem;

  @override
  void initState() {
    super.initState();
    _selectedSystem = _settings.getUnitSystem();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Units', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          RadioListTile<UnitSystem>(
            dense: true,
            visualDensity: VisualDensity.compact,
            title: const Text('Imperial', style: TextStyle(fontSize: 13)),
            subtitle: const Text('Miles & Feet', style: TextStyle(fontSize: 12)),
            value: UnitSystem.imperial,
            groupValue: _selectedSystem,
            onChanged: (value) async {
              if (value != null) {
                await _settings.setUnitSystem(value);
                setState(() => _selectedSystem = value);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unit preference saved.'), duration: Duration(seconds: 2)),
                  );
                }
              }
            },
          ),
          RadioListTile<UnitSystem>(
            dense: true,
            visualDensity: VisualDensity.compact,
            title: const Text('Metric', style: TextStyle(fontSize: 13)),
            subtitle: const Text('Kilometers & Meters', style: TextStyle(fontSize: 12)),
            value: UnitSystem.metric,
            groupValue: _selectedSystem,
            onChanged: (value) async {
              if (value != null) {
                await _settings.setUnitSystem(value);
                setState(() => _selectedSystem = value);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unit preference saved.'), duration: Duration(seconds: 2)),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}