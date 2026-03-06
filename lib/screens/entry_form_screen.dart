// screens/entry_form_screen.dart
// Form for creating or editing a daily entry

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../models/entry.dart';
import '../repositories/entry_repository.dart';
import '../models/gear.dart';
import '../repositories/gear_repository.dart';
import '../models/custom_field.dart';
import '../repositories/custom_field_repository.dart';
import '../services/settings_service.dart';
import '../models/direction.dart';
import 'package:geolocator/geolocator.dart';

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
  final _settings = SettingsService();
  
  // Controllers for text inputs
  final _startMileController = TextEditingController();
  final _endMileController = TextEditingController();
  final _extraMilesController = TextEditingController();
  final _skippedMilesController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _elevationGainController = TextEditingController();
  final _elevationLossController = TextEditingController();
  
  // State variables
  DateTime _selectedDate = DateTime.now();
  Direction? _selectedDirection;
  bool? _isTent;  // true = tent, false = shelter, null = not set
  bool _hadShower = false;
  bool _isSaving = false;
  final CustomFieldRepository _customFieldRepository = CustomFieldRepository();
  List<CustomFieldWithValue> _customFields = [];
  Map<int, TextEditingController> _customFieldControllers = {};  // For text/number fields
  Map<int, bool> _customFieldYesNo = {};  // For yes/no fields
  Map<int, int> _customFieldRatings = {};  // For rating fields
  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;
  // non text inputs use state variables

  final _sectionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGear();
    _loadCustomFields();
    
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

      _latitude = entry.latitude;
      _longitude = entry.longitude;

      _sectionController.text = _determineSection(widget.entry!.endMile);

      _elevationGainController.text = entry.elevationGain?.toString() ?? '';
      _elevationLossController.text = entry.elevationLoss?.toString() ?? '';
      
      // Load gear for this entry
      _loadGearForEntry();
    } else {
      // New entry - set default values
      _extraMilesController.text = '0.0';
      _skippedMilesController.text = '0.0';
    }
  }

  Future<void> _fetchLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission permanently denied. Enable it in Settings.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print('Location result: ${position.latitude}, ${position.longitude}');
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
    
  }

  Future<void> _loadCustomFields() async {
    final fieldsWithValues = await _customFieldRepository.getCustomFieldsWithValues(
      widget.trip.id!,
      widget.entry?.id ?? 0,  // 0 if creating new entry
    );
    
    setState(() {
      _customFields = fieldsWithValues;
      
      // Initialize controllers and values
      for (var fieldWithValue in fieldsWithValues) {
        final field = fieldWithValue.field;
        final value = fieldWithValue.value ?? '';
        
        if (field.type == CustomFieldType.text || field.type == CustomFieldType.number) {
          // For new entries, default number fields to '0'
          String defaultValue = value;
          if (field.type == CustomFieldType.number) {
            defaultValue = value.isEmpty ? '0' : value;
          }
          _customFieldControllers[field.id!] = TextEditingController(text: defaultValue);
        } else if (field.type == CustomFieldType.checkbox) {
          _customFieldYesNo[field.id!] = value == 'true';
        } else if (field.type == CustomFieldType.rating) {
          _customFieldRatings[field.id!] = int.tryParse(value) ?? 0;
        }
      }
    });
  }
  
  @override
  void dispose() {
    // Clean up controllers when widget is disposed
    _startMileController.dispose();
    _endMileController.dispose();
    _extraMilesController.dispose();
    _skippedMilesController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _sectionController.dispose();
    _elevationGainController.dispose();
  _elevationLossController.dispose();
    
    // Clean up custom field controllers
    for (var controller in _customFieldControllers.values) {
      controller.dispose();
    }
    
    super.dispose();
  }
  

  Future<void> _loadGear() async {
    final gear = await _gearRepository.getActiveGearOnDate(_selectedDate);
    
    setState(() {
      _availableGear = gear;
      
      // Auto-check all active gear for NEW entries
      if (widget.entry == null) {
        _selectedGearIds = gear.map((g) => g.id!).toList();
      }
    });
  }

  Future<void> _loadGearForEntry() async {
    if (widget.entry != null) {
      // Get gear that's currently linked
      final linkedGear = await _gearRepository.getGearForEntry(widget.entry!.id!);
      
      // Get gear that was active on this date
      final activeGear = await _gearRepository.getActiveGearOnDate(_selectedDate);
      
      // Combine both (remove duplicates)
      final allGearIds = <int>{};
      final allGear = <Gear>[];
      
      for (final gear in [...activeGear, ...linkedGear]) {
        if (!allGearIds.contains(gear.id)) {
          allGearIds.add(gear.id!);
          allGear.add(gear);
        }
      }
      
      setState(() {
        _availableGear = allGear;
        _selectedGearIds = linkedGear.map((g) => g.id!).toList();
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
        latitude: _latitude,
        longitude: _longitude,
        elevationGain: double.tryParse(_elevationGainController.text),
        elevationLoss: double.tryParse(_elevationLossController.text),
      );
      
      // Save to database
      Entry savedEntry;
      if (widget.entry == null) {
        // Creating new entry
        savedEntry = await _entryRepository.createEntry(entry);  // ← Capture returned entry
      } else {
        // Updating existing entry
        await _entryRepository.updateEntry(entry);
        savedEntry = entry;  // ← Use the entry we just updated
      }

      // Save gear linkages
      await _gearRepository.setGearForEntry(savedEntry.id!, _selectedGearIds);

      //custom fields
      final customFieldValues = <int, String>{};
      for (var fieldWithValue in _customFields) {
        final field = fieldWithValue.field;
        String value = '';
        
        if (field.type == CustomFieldType.text || field.type == CustomFieldType.number) {
          value = _customFieldControllers[field.id!]?.text ?? '';
        } else if (field.type == CustomFieldType.checkbox) {
          value = (_customFieldYesNo[field.id!] ?? false).toString();
        } else if (field.type == CustomFieldType.rating) {
          final rating = _customFieldRatings[field.id!] ?? 0;
          if (rating > 0) {
            value = rating.toString();
          }
        }
        
        if (value.isNotEmpty) {
          customFieldValues[field.id!] = value;
        }
      }

      if (customFieldValues.isNotEmpty) {
        await _customFieldRepository.saveCustomFieldValues(
          savedEntry.id!,
          customFieldValues,
        );
      }


      
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

  Widget _buildElevationInputs() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _elevationGainController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Elevation Gain',
              border: const OutlineInputBorder(),
              suffixText: _settings.getElevationUnitLabel(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _elevationLossController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Elevation Loss',
              border: const OutlineInputBorder(),
              suffixText: _settings.getElevationUnitLabel(),
            ),
          ),
        ),
      ],
    );
  }

  String _determineSection(double mile) {
    // We look at the sections inside the trip we passed to this screen
    for (var section in widget.trip.sections) {
      if (mile >= section.startMile && mile <= section.endMile) {
        return section.name;
      }
    }
    return ""; // Return empty if the mile doesn't fit anywhere
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'New Entry' : 'Edit Entry'),
        actions: widget.entry != null  // ← ADD THIS ENTIRE SECTION
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteEntry,
                  tooltip: 'Delete Entry',
                ),
              ]
            : null,
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
            
            if (widget.trip.trackElevation) ...[
              const SizedBox(height: 16),
              _buildElevationInputs(),
            ],

            const SizedBox(height: 16),

            _buildSectionDisplay(), 
            const SizedBox(height: 16),
            
            if (widget.trip.trackCoordinates) ...[
              _buildCoordinatesRow(),
              const SizedBox(height: 16),
            ],
            
            // Direction dropdown
            _buildDirectionDropdown(),
            const SizedBox(height: 16),
            
            if (widget.trip.trackSleeping) ...[
              _buildTentShelterToggle(),
              const SizedBox(height: 16),
            ],
            
            if (widget.trip.trackShower) ...[
              _buildShowerSwitch(),
              const SizedBox(height: 16),
            ],

            // Custom Fields
            if (_customFields.isNotEmpty) ...[
              _buildCustomFieldsSection(),
              const SizedBox(height: 16),
            ],

            // Gear selection
            if (_availableGear.isNotEmpty) ...[
              _buildGearSelector(),
              const SizedBox(height: 16),
            ],
            // Notes
            _buildNotesInput(),
            const SizedBox(height: 24),

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
        const Text(
          "Date:",
          // style: TextStyle(fontSize: 16),
        ),
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
      decoration: InputDecoration(
        labelText: 'Start ${_settings.getDistanceUnitLabel() == "km" ? "KM" : "Mile"}',
        border: const OutlineInputBorder(),
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'End ${_settings.getDistanceUnitLabel() == "km" ? "KM" : "Mile"}',
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) {
        final inputMile = double.tryParse(value);
        if (inputMile != null) {
          final baseMile = _settings.convertFromDisplayUnit(inputMile);
          final foundSection = _determineSection(baseMile);
          
          // WE ONLY UPDATE THE SECTION CONTROLLER HERE
          setState(() {
            _sectionController.text = foundSection;
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter end marker';
        if (double.tryParse(value) == null) return 'Please enter a valid number';
        return null;
      },
    );
  }


  Widget _buildExtraMilesInput() {
    return TextFormField(
      controller: _extraMilesController,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: '+ Distance ${_settings.getDistanceUnitLabel()}',
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildSkippedMilesInput() {
    return TextFormField(
      controller: _skippedMilesController,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      // Skipped Miles
      decoration: InputDecoration(
        labelText: '- Distance ${_settings.getDistanceUnitLabel()}',
        border: const OutlineInputBorder(),
      ),
    );
  }

  // NEW WIDGET
  Widget _buildSectionDisplay() {
    return TextFormField(
      controller: _sectionController,
      readOnly: true, // User cannot edit this, it's auto-calculated
      decoration: InputDecoration(
        labelText: 'Section',
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        suffixIcon: const Icon(Icons.map_outlined),
        border: const OutlineInputBorder(),
        // helperText: 'Based on your end mile and trip settings.',
      ),
    );
  }

  // RESTORED LOCATION WIDGET (Removed the auto-fill logic)
  Widget _buildLocationInput() {
    return TextFormField(
      controller: _locationController,
      decoration: const InputDecoration(
        labelText: 'Location ',
        border: OutlineInputBorder(),
        suffixIcon: Icon(Icons.location_on_outlined),
      )
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
      _loadGear();  // ← ADD THIS - Reload gear for new date
    }
  }

  Widget _buildGearSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gear',
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
  Widget _buildCustomFieldsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ..._customFields.map((fieldWithValue) {
          return _buildCustomFieldInput(fieldWithValue.field);
        }),
      ],
    );
  }
  Widget _buildCustomFieldInput(CustomField field) {
    switch (field.type) {
      case CustomFieldType.text:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(
                width: 150,
                child: Text(
                  '${field.name}:',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: _customFieldControllers[field.id!],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        );
        
      case CustomFieldType.number:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(
                '${field.name}:',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: _customFieldControllers[field.id!],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
        
      case CustomFieldType.checkbox:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(
                '${field.name}:',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 16),
              Checkbox(
                value: _customFieldYesNo[field.id!] ?? false,
                onChanged: (value) {
                  setState(() {
                    _customFieldYesNo[field.id!] = value ?? false;
                  });
                },
              ),
            ],
          ),
        );
        
      case CustomFieldType.rating:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(
                '${field.name}:',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 16),
              ...List.generate(5, (index) {
                final rating = _customFieldRatings[field.id!] ?? 0;
                return IconButton(
                  icon: Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 28,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _customFieldRatings[field.id!] = index + 1;
                    });
                  },
                );
              }),
            ],
          ),
        );
    }
  }
  Future<void> _deleteEntry() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text(
          'Are you sure you want to delete this entry? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _entryRepository.deleteEntry(widget.entry!.id!);
        if (mounted) {
          Navigator.pop(context, 'deleted');  // Signal deletion
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting entry: $e')),
          );
        }
      }
    }
  }

  Widget _buildCoordinatesRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Coordinates', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                _latitude != null && _longitude != null
                    ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                    : 'No coordinates set',
                style: TextStyle(
                  fontSize: 14,
                  color: _latitude != null ? null : Colors.grey,
                ),
              ),
            ),
            _isFetchingLocation
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.my_location),
                    tooltip: 'Fetch current location',
                    onPressed: _fetchLocation,
                  ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Enter coordinates manually',
              onPressed: _enterCoordinatesManually,
            ),
            if (_latitude != null)
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Clear coordinates',
                onPressed: () => setState(() {
                  _latitude = null;
                  _longitude = null;
                }),
              ),
          ],
        ),
      ],
    );
  }
  Future<void> _enterCoordinatesManually() async {
    final latController = TextEditingController(
      text: _latitude?.toString() ?? '',
    );
    final lngController = TextEditingController(
      text: _longitude?.toString() ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Coordinates'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: 'e.g. 37.12345',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lngController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: 'e.g. -119.12345',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final lat = double.tryParse(latController.text);
              final lng = double.tryParse(lngController.text);
              if (lat != null && lng != null) {
                setState(() {
                  _latitude = lat;
                  _longitude = lng;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}