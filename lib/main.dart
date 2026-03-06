// main.dart
// Entry point for the app

import 'package:flutter/material.dart';
import 'screens/trip_list_screen.dart';
import 'screens/gear_list_screen.dart';
import 'screens/stats_screen.dart';
import 'services/settings_service.dart';
import 'screens/settings_screen.dart';
import 'screens/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();  // ← Add this
  await SettingsService().init();  // ← Add this
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
          seedColor: Colors.cyan,
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
    const MapScreen(),
    const GearListScreen(),
    const SettingsScreen(), 
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,  // ← Add this to show all 4 tabs
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.hiking),
            label: 'Hikes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.backpack),
            label: 'Gear',
          ),
          BottomNavigationBarItem(  // ← Add this
            icon: Icon(Icons.settings),
            label: 'Settings',
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
