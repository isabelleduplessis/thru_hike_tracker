// screens/entry_form_screen.dart
// Form for creating or editing a daily entry

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../models/entry.dart';
import '../repositories/entry_repository.dart';
import '../models/gear.dart';
import '../repositories/gear_repository.dart';

class EntryFormScreen extends StatefulWidget {
  final Trip trip;
  final Entry? entry;  // null = creating new, not null = editing existing
  
  const EntryFormScreen({
    Key? key,
    required this.trip,
    this.entry,
  }) : super(key: key);

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final EntryRepository _entryRepository = EntryRepository();
  final GearRepository _gearRepository = GearRepository();
  List<Gear> _availableGear = [];
  List<int> _selectedGearIds = [];
  
  // Controllers for text inputs
  final _startMileController = TextEditingController();
  final _endMileController = TextEditingController();
  final _extraMilesController = TextEditingController();
  final _skippedMilesController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  
  // State variables
  DateTime _selectedDate = DateTime.now();
  Direction? _selectedDirection;
  bool? _isTent;  // true = tent, false = shelter, null = not set
  bool _hadShower = false;
  bool _isSaving = false;
  // non text inputs use state variables


  @override
  void initState() {
    super.initState();
    _loadGear();
    
    // If editing existing entry, populate the form
    if (widget.entry != null) {
      final entry = widget.entry!;
      _startMileController.text = entry.startMile.toString();
      _endMileController.text = entry.endMile.toString();
      _extraMilesController.text = entry.extraMiles.toString();
      _skippedMilesController.text = entry.skippedMiles.toString();
      _locationController.text = entry.location ?? '';
      _notesController.text = entry.notes;
      
      _selectedDate = entry.date;
      _selectedDirection = entry.direction;
      _isTent = entry.tentOrShelter;
      _hadShower = entry.shower ?? false;
      
      // Load gear for this entry
      _loadGearForEntry();
    } else {
      // New entry - set default values
      _extraMilesController.text = '0.0';
      _skippedMilesController.text = '0.0';
    }
  }
  
  @override
  void dispose() {
    // IMPORTANT: Clean up controllers when widget is disposed
    _startMileController.dispose();
    _endMileController.dispose();
    _extraMilesController.dispose();
    _skippedMilesController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  

  Future<void> _loadGear() async {
    final gear = await _gearRepository.getAllGear();
    setState(() {
      _availableGear = gear;
    });
  }

  Future<void> _loadGearForEntry() async {
    if (widget.entry != null) {
      final gear = await _gearRepository.getGearForEntry(widget.entry!.id!);
      setState(() {
        _selectedGearIds = gear.map((g) => g.id!).toList();
      });
    }
  }

  Future<void> _saveEntry() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Create entry object from form data
      final entry = Entry(
        id: widget.entry?.id,  // Keep ID if editing, null if creating
        tripId: widget.trip.id!,
        date: _selectedDate,
        startMile: double.parse(_startMileController.text),
        endMile: double.parse(_endMileController.text),
        extraMiles: double.tryParse(_extraMilesController.text) ?? 0.0,
        skippedMiles: double.tryParse(_skippedMilesController.text) ?? 0.0,
        location: _locationController.text.isEmpty ? null : _locationController.text,
        tentOrShelter: _isTent,
        shower: _hadShower,
        notes: _notesController.text,
        direction: _selectedDirection,
      );
      
      // Save to database
      if (widget.entry == null) {
        // Creating new entry
        await _entryRepository.createEntry(entry);
      } else {
        // Updating existing entry
        await _entryRepository.updateEntry(entry);
      }

      // Save to database
      Entry savedEntry;
      if (widget.entry == null) {
        // Creating new entry
        savedEntry = await _entryRepository.createEntry(entry);
      } else {
        // Updating existing entry
        await _entryRepository.updateEntry(entry);
        savedEntry = entry;
      }

      // Save gear linkages
      await _gearRepository.setGearForEntry(savedEntry.id!, _selectedGearIds);
      
      // Return to previous screen with success
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving entry: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'New Entry' : 'Edit Entry'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Date picker
            _buildDatePicker(),
            const SizedBox(height: 16),
            
            // Mile inputs
            Row(
              children: [
                Expanded(child: _buildStartMileInput()),
                const SizedBox(width: 16),
                Expanded(child: _buildEndMileInput()),
              ],
            ),
            const SizedBox(height: 16),
            
            // Adjustments
            Row(
              children: [
                Expanded(child: _buildExtraMilesInput()),
                const SizedBox(width: 16),
                Expanded(child: _buildSkippedMilesInput()),
              ],
            ),
            const SizedBox(height: 16),
            
            // Location
            _buildLocationInput(),
            const SizedBox(height: 16),
            
            // Direction dropdown
            _buildDirectionDropdown(),
            const SizedBox(height: 16),
            
            // Tent/Shelter toggle
            _buildTentShelterToggle(),
            const SizedBox(height: 16),
            
            // Shower switch
            _buildShowerSwitch(),
            const SizedBox(height: 16),
            
            // Notes
            _buildNotesInput(),
            const SizedBox(height: 24),

            // Gear selection
            if (_availableGear.isNotEmpty) ...[
              _buildGearSelector(),
              const SizedBox(height: 16),
            ],
            
            // Save button
            FilledButton(
              onPressed: _isSaving ? null : _saveEntry,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.entry == null ? 'Create Entry' : 'Update Entry',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Row(
      children: [
        const Icon(Icons.calendar_today, size: 20),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _pickDate,
          child: Text(DateFormat.yMMMd().format(_selectedDate)),
        ),
      ],
    );
  }

  Widget _buildStartMileInput() {
    return TextFormField(
      controller: _startMileController,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Start Mile',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter start mile';
        }
        if (double.tryParse(value) == null) {
          return 'Please enter a valid number';
        }
        return null;
      },
    );
  }

  Widget _buildEndMileInput() {
    return TextFormField(
      controller: _endMileController,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'End Mile',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter end mile';
        }
        if (double.tryParse(value) == null) {
          return 'Please enter a valid number';
        }
        return null;
      },
    );
  }

  Widget _buildExtraMilesInput() {
    return TextFormField(
      controller: _extraMilesController,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Extra Miles',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildSkippedMilesInput() {
    return TextFormField(
      controller: _skippedMilesController,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Skipped Miles',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildLocationInput() {
    return TextFormField(
      controller: _locationController,
      decoration: const InputDecoration(
        labelText: 'Location',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildDirectionDropdown() {
    return DropdownButtonFormField<Direction>(
      decoration: const InputDecoration(
        labelText: 'Direction',
        border: OutlineInputBorder(),
      ),
      value: _selectedDirection,
      items: Direction.values.map((direction) {
        return DropdownMenuItem(
          value: direction,
          child: Text(direction.toString().split('.').last),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedDirection = value;
        });
      },
    );
  }

  Widget _buildTentShelterToggle() {
    return Row(
      children: [
        const Text('Sleeping Arrangement:'),
        const SizedBox(width: 16),
        ToggleButtons(
          isSelected: [
            _isTent == true,
            _isTent == false,
          ],
          onPressed: (index) {
            setState(() {
              if (index == 0) {
                _isTent = true;
              } else {
                _isTent = false;
              }
            });
          },
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('Tent'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('Shelter'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShowerSwitch() {
    return Row(
      children: [
        const Text('Had Shower:'),
        const SizedBox(width: 16),
        Switch(
          value: _hadShower,
          onChanged: (value) {
            setState(() {
              _hadShower = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildNotesInput() {
    return TextFormField(
      controller: _notesController,
      maxLines: 4,
      decoration: const InputDecoration(
        labelText: 'Notes',
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildGearSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Track Gear',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_availableGear.isEmpty)
          const Text('No gear items yet. Add some in the Gear tab!')
        else
          ..._availableGear.map((gear) {
            final isSelected = _selectedGearIds.contains(gear.id);
            return CheckboxListTile(
              title: Text(gear.name),
              subtitle: gear.category != null ? Text(gear.category!) : null,
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedGearIds.add(gear.id!);
                  } else {
                    _selectedGearIds.remove(gear.id);
                  }
                });
              },
            );
          }).toList(),
      ],
    );
  }
  
}