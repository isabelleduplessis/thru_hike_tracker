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
            padding: EdgeInsets.all(16.0),
            child: Text('Units', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          RadioListTile<UnitSystem>(
            title: const Text('Imperial'),
            subtitle: const Text('Miles & Feet'),
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
            title: const Text('Metric'),
            subtitle: const Text('Kilometers & Meters'),
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