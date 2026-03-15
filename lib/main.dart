// main.dart
// Entry point for the app

import 'package:flutter/material.dart';
import 'screens/trip_list_screen.dart';
import 'screens/gear_list_screen.dart';
import 'screens/stats_screen.dart';
import 'services/settings_service.dart';
import 'screens/settings_screen.dart';
import 'screens/map_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
        textTheme: GoogleFonts.getTextTheme('Work Sans'), // Replace 'YourFontName' with the name  Google Fonts
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(0, 188, 212, 1),
          brightness: Brightness.light,
          //primary: Colors.blue,
          //onPrimary: Colors.white,
          //secondary: Colors.green,
          //onSecondary: Colors.black,
          // surface: Colors.white,
          // onBackground: Colors.black,
          surface: Color.fromARGB(255, 248, 248, 248),
          onSurface: Colors.black,
          error: Colors.red,
          onError: Colors.white,
          outline: Colors.grey,
        ),
        cardTheme: CardTheme(
          elevation: 0.3, // what is the number range of these values? 
          color: Color.fromRGBO(255, 255, 255, 1), // your card color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        useMaterial3: true,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Color.fromRGBO(1, 141, 159, 1), // bar background color
          selectedItemColor: Color.fromRGBO(255, 255, 255, 1), // selected icon + label color
          unselectedItemColor: Color.fromRGBO(255, 255, 255, 0.624), // unselected icon + label color
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: TextStyle(fontSize: 12), // , fontWeight: FontWeight.bold
          unselectedLabelStyle: TextStyle(fontSize: 12),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Color.fromRGBO(1, 141, 159, 1),
          foregroundColor: Color.fromRGBO(255, 255, 255, 1), // icon color
          elevation: 0.3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18), // adjust roundness
          ),
        ),
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
        items: [ // should i add const to labels below? 
          BottomNavigationBarItem(
            icon: Icon(PhosphorIcons.personSimpleHike(PhosphorIconsStyle.regular)),
            label: 'Hikes',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIcons.chartLine(PhosphorIconsStyle.regular)),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIcons.mapTrifold(PhosphorIconsStyle.regular)),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIcons.tent(PhosphorIconsStyle.regular)),
            label: 'Gear',
          ),
          BottomNavigationBarItem(  // ← Add this
            icon: Icon(PhosphorIcons.gearSix(PhosphorIconsStyle.regular)),
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
