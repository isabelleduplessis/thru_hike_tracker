// main.dart
// Entry point for the app

import 'package:flutter/material.dart';
import 'package:thru_hike_tracker/screens/stats_screen.dart';
import 'screens/trip_list_screen.dart';
import 'screens/gear_list_screen.dart';

void main() {
  runApp(const ThruHikeTrackerApp());
}

class ThruHikeTrackerApp extends StatelessWidget {
  const ThruHikeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thru Hike Tracker',
      theme: ThemeData(
        // Modern Material 3 theme
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// Main navigation screen with bottom nav bar
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  
  // Placeholder screens - we'll build these properly next
  final List<Widget> _screens = [
  const TripListScreen(),
  const StatsScreen(),
  const GearListScreen(),  // ← Changed this!
];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.hiking),
            label: 'Hikes',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.backpack),
            label: 'Gear',
          ),
        ],
      ),
    );
  }
}

// Temporary placeholder screen
class PlaceholderScreen extends StatelessWidget {
  final String title;
  
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Text(
          '$title screen coming soon!',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
