// 1. import packages
import 'package:flutter/material.dart';
import '../models/gear.dart';
import '../repositories/gear_repository.dart';
import 'gear_form_screen.dart';

class GearListScreen extends StatefulWidget {
  const GearListScreen({Key? key}) : super(key: key);

  @override
  State<GearListScreen> createState() => _GearListScreenState();
}

class _GearListScreenState extends State<GearListScreen> {
  final GearRepository _gearRepository = GearRepository();
  List<Gear> _gear = [];
  bool _isLoading = true;

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
            Icons.backpack,
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
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const Icon(Icons.backpack, size: 40),
            title: Text(
              gear.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (gear.category != null)
                  Text(gear.category!)
                else
                  const Text(
                    'No category',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                if (snapshot.hasData) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${snapshot.data!.totalMiles.toStringAsFixed(1)} miles • ${snapshot.data!.daysUsed} days',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
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
          ),
        );
      },
    );
  }
}