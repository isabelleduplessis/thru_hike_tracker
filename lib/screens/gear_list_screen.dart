// gear_list_screen.dart
// 1. import packages
import 'package:flutter/material.dart';
import '../models/gear.dart';
import '../repositories/gear_repository.dart';
import 'gear_form_screen.dart';
import '../services/settings_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class GearListScreen extends StatefulWidget {
  const GearListScreen({Key? key}) : super(key: key);

  @override
  State<GearListScreen> createState() => _GearListScreenState();
}

class _GearListScreenState extends State<GearListScreen> {
  final GearRepository _gearRepository = GearRepository();
  List<Gear> _gear = [];
  bool _isLoading = true;
  final _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadGear();
  }

  Future<void> _loadGear() async {
    setState(() {
      _isLoading = true;
    });
    
    final gear = await _gearRepository.getAllGear();
    
    setState(() {
      _gear = gear;
      _isLoading = false;
    });
  }
  
  // Build widgets next...

  // main build widget
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Gear'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _gear.isEmpty
              ? _buildEmptyState()
              : _buildGearList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const GearFormScreen(),
            ),
          );
          
          if (result == true) {
            _loadGear();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
  // build empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.tent(PhosphorIconsStyle.regular),
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No gear yet!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first item',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
  // build gear list widget
  Widget _buildGearList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _gear.length,
      itemBuilder: (context, index) {
        final gear = _gear[index];
        return _buildGearCard(gear);
      },
    );
  }
  // gear card widget
  Widget _buildGearCard(Gear gear) {
    return FutureBuilder<GearStats>(
      future: _gearRepository.getGearStats(gear.id!),
      builder: (context, snapshot) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GearFormScreen(gear: gear),
                ),
              );
              if (result == true || result == 'deleted') {
                _loadGear();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gear.name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3),
                        if (gear.category != null)
                          Text(
                            gear.category!,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          )
                        else
                          Text(
                            'No category',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                          ),
                        if (snapshot.hasData) ...[
                          const SizedBox(height: 3),
                          Text(
                            '${_settings.formatDistance(snapshot.data!.totalMiles)} • ${snapshot.data!.daysUsed} days',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(PhosphorIcons.caretRight(), size: 16, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}