// screens/entry_form_screen.dart
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
  final Entry? entry;

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
  final CustomFieldRepository _customFieldRepository = CustomFieldRepository();
  final _settings = SettingsService();

  List<Gear> _availableGear = [];
  List<int> _selectedGearIds = [];

  final _startMileController = TextEditingController();
  final _endMileController = TextEditingController();
  final _extraMilesController = TextEditingController();
  final _skippedMilesController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _elevationGainController = TextEditingController();
  final _elevationLossController = TextEditingController();
  final _sectionController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  Direction? _selectedDirection;
  bool? _isTent;
  bool _hadShower = false;
  bool _isSaving = false;

  List<CustomFieldWithValue> _customFields = [];
  Map<int, TextEditingController> _customFieldControllers = {};
  Map<int, bool> _customFieldYesNo = {};
  Map<int, int> _customFieldRatings = {};

  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;

  InputDecoration _slimDecoration(String label, {String? suffixText}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffixText,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    );
  }

  // Only removes the divider line, keeps natural highlight
  Theme _quietExpansion({required Widget child}) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadGear();
    _loadCustomFields();

    if (widget.entry != null) {
      final entry = widget.entry!;
      _locationController.text = entry.location ?? '';
      _notesController.text = entry.notes;
      _selectedDate = entry.date;
      _selectedDirection = entry.direction;
      _isTent = entry.tentOrShelter;
      _hadShower = entry.shower ?? false;
      _latitude = entry.latitude;
      _longitude = entry.longitude;
      _sectionController.text = _determineSection(entry.endMile);

      _startMileController.text = _settings.convertToDisplayUnit(entry.startMile).toStringAsFixed(2);
      _endMileController.text = _settings.convertToDisplayUnit(entry.endMile).toStringAsFixed(2);
      _extraMilesController.text = _settings.convertToDisplayUnit(entry.extraMiles).toStringAsFixed(2);
      _skippedMilesController.text = _settings.convertToDisplayUnit(entry.skippedMiles).toStringAsFixed(2);
      _elevationGainController.text = entry.elevationGain != null
          ? _settings.convertToDisplayElevation(entry.elevationGain!).toStringAsFixed(0)
          : '';
      _elevationLossController.text = entry.elevationLoss != null
          ? _settings.convertToDisplayElevation(entry.elevationLoss!).toStringAsFixed(0)
          : '';

      _loadGearForEntry();
    } else {
      _extraMilesController.text = '0.0';
      _skippedMilesController.text = '0.0';
      _selectedDirection = widget.trip.direction;
      _loadNewEntryDefaults();
    }
  }

  Future<void> _loadNewEntryDefaults() async {
    final lastEndMile = await _entryRepository.getLastEndMileForTrip(widget.trip.id!);
    if (mounted) {
      setState(() {
        final defaultMile = lastEndMile ?? widget.trip.startMile;
        _startMileController.text = _settings.convertToDisplayUnit(defaultMile).toStringAsFixed(2);
      });
    }
  }

  Future<void> _loadCustomFields() async {
    final fieldsWithValues = await _customFieldRepository.getCustomFieldsWithValues(
      widget.trip.id!,
      widget.entry?.id ?? 0,
    );
    setState(() {
      _customFields = fieldsWithValues;
      for (var fwv in fieldsWithValues) {
        final field = fwv.field;
        final value = fwv.value ?? '';
        if (field.type == CustomFieldType.text || field.type == CustomFieldType.number) {
          String defaultValue = value;
          if (field.type == CustomFieldType.number) defaultValue = value.isEmpty ? '0' : value;
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
    _startMileController.dispose();
    _endMileController.dispose();
    _extraMilesController.dispose();
    _skippedMilesController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _sectionController.dispose();
    _elevationGainController.dispose();
    _elevationLossController.dispose();
    for (var c in _customFieldControllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadGear() async {
    final gear = await _gearRepository.getActiveGearOnDate(_selectedDate);
    setState(() {
      _availableGear = gear;
      if (widget.entry == null) {
        _selectedGearIds = gear.map((g) => g.id!).toList();
      }
    });
  }

  Future<void> _loadGearForEntry() async {
    if (widget.entry == null) return;
    final linkedGear = await _gearRepository.getGearForEntry(widget.entry!.id!);
    final activeGear = await _gearRepository.getActiveGearOnDate(_selectedDate);
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

  Future<void> _fetchLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission permanently denied. Enable it in Settings.')),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() { _latitude = position.latitude; _longitude = position.longitude; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _enterCoordinatesManually() async {
    final latController = TextEditingController(text: _latitude?.toString() ?? '');
    final lngController = TextEditingController(text: _longitude?.toString() ?? '');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Coordinates'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              decoration: const InputDecoration(labelText: 'Latitude', hintText: 'e.g. 37.12345', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lngController,
              decoration: const InputDecoration(labelText: 'Longitude', hintText: 'e.g. -119.12345', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final lat = double.tryParse(latController.text);
              final lng = double.tryParse(lngController.text);
              if (lat != null && lng != null) {
                setState(() { _latitude = lat; _longitude = lng; });
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final entry = Entry(
        id: widget.entry?.id,
        tripId: widget.trip.id!,
        date: _selectedDate,
        startMile: _settings.convertFromDisplayUnit(double.parse(_startMileController.text)),
        endMile: _settings.convertFromDisplayUnit(double.parse(_endMileController.text)),
        extraMiles: _settings.convertFromDisplayUnit(double.tryParse(_extraMilesController.text) ?? 0.0),
        skippedMiles: _settings.convertFromDisplayUnit(double.tryParse(_skippedMilesController.text) ?? 0.0),
        elevationGain: _elevationGainController.text.isNotEmpty
            ? _settings.convertFromDisplayElevation(double.parse(_elevationGainController.text))
            : null,
        elevationLoss: _elevationLossController.text.isNotEmpty
            ? _settings.convertFromDisplayElevation(double.parse(_elevationLossController.text))
            : null,
        location: _locationController.text.isEmpty ? null : _locationController.text,
        tentOrShelter: _isTent,
        shower: _hadShower,
        notes: _notesController.text,
        direction: _selectedDirection,
        latitude: _latitude,
        longitude: _longitude,
      );

      Entry savedEntry;
      if (widget.entry == null) {
        savedEntry = await _entryRepository.createEntry(entry);
      } else {
        await _entryRepository.updateEntry(entry);
        savedEntry = entry;
      }

      await _gearRepository.setGearForEntry(savedEntry.id!, _selectedGearIds);

      final customFieldValues = <int, String>{};
      for (var fwv in _customFields) {
        final field = fwv.field;
        String value = '';
        if (field.type == CustomFieldType.text || field.type == CustomFieldType.number) {
          value = _customFieldControllers[field.id!]?.text ?? '';
        } else if (field.type == CustomFieldType.checkbox) {
          value = (_customFieldYesNo[field.id!] ?? false).toString();
        } else if (field.type == CustomFieldType.rating) {
          final rating = _customFieldRatings[field.id!] ?? 0;
          if (rating > 0) value = rating.toString();
        }
        if (value.isNotEmpty) customFieldValues[field.id!] = value;
      }
      if (customFieldValues.isNotEmpty) {
        await _customFieldRepository.saveCustomFieldValues(savedEntry.id!, customFieldValues);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving entry: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteEntry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
        if (mounted) Navigator.pop(context, 'deleted');
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting entry: $e')));
      }
    }
  }

  String _determineSection(double mile) {
    for (var section in widget.trip.sections) {
      if (mile >= section.startMile && mile <= section.endMile) return section.name;
    }
    return '';
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadGear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = _settings.getDistanceUnitLabel() == 'km' ? 'KM' : 'Mile';
    final distUnit = _settings.getDistanceUnitLabel();
    final elevUnit = _settings.getElevationUnitLabel();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'New Entry' : 'Edit Entry'),
        actions: widget.entry != null
            ? [IconButton(icon: const Icon(Icons.delete), onPressed: _deleteEntry, tooltip: 'Delete Entry')]
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [

            // ── Date ─────────────────────────────────────────────────
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat.yMMMd().format(_selectedDate),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Direction + Section ───────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Direction>(
                    decoration: _slimDecoration('Direction'),
                    value: _selectedDirection,
                    items: Direction.values.map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(d.toString().split('.').last.toUpperCase()),
                    )).toList(),
                    onChanged: (value) => setState(() => _selectedDirection = value),
                  ),
                ),
                if (widget.trip.sections.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _sectionController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Section',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // ── Start / End mile ──────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startMileController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _slimDecoration('Start $unit'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _endMileController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _slimDecoration('End $unit'),
                    onChanged: (value) {
                      final inputMile = double.tryParse(value);
                      if (inputMile != null) {
                        final baseMile = _settings.convertFromDisplayUnit(inputMile);
                        setState(() => _sectionController.text = _determineSection(baseMile));
                      }
                    },
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),

            // ── More (optional fields) ────────────────────────────────
            const SizedBox(height: 6),
            _quietExpansion(
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('More', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _extraMilesController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _slimDecoration('+ Distance', suffixText: distUnit),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _skippedMilesController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _slimDecoration('- Distance', suffixText: distUnit),
                        ),
                      ),
                    ],
                  ),
                  if (widget.trip.trackElevation) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _elevationGainController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _slimDecoration('Elevation Gain', suffixText: elevUnit),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _elevationLossController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _slimDecoration('Elevation Loss', suffixText: elevUnit),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (widget.trip.trackCoordinates) ...[
                    const SizedBox(height: 10),
                    _buildCoordinatesRow(),
                  ],
                  if (widget.trip.trackSleeping) ...[
                    const SizedBox(height: 8),
                    _buildTentShelterToggle(),
                  ],
                  if (widget.trip.trackShower) ...[
                    const SizedBox(height: 4),
                    _buildShowerSwitch(),
                  ],
                ],
              ),
            ),

            // ── Custom Fields ─────────────────────────────────────────
            if (_customFields.isNotEmpty) ...[
              const SizedBox(height: 6),
              _quietExpansion(
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text('Custom Fields', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  initiallyExpanded: true,
                  childrenPadding: const EdgeInsets.only(bottom: 4),
                  children: [
                    const SizedBox(height: 4),
                    ..._customFields.map((fwv) => _buildCustomFieldInput(fwv.field)),
                  ],
                ),
              ),
            ],

            // ── Gear ──────────────────────────────────────────────────
            if (_availableGear.isNotEmpty) ...[
              const SizedBox(height: 6),
              _quietExpansion(
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text('Gear', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  initiallyExpanded: false,
                  childrenPadding: const EdgeInsets.only(bottom: 4),
                  children: _availableGear.map((gear) {
                    final isSelected = _selectedGearIds.contains(gear.id);
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedGearIds.remove(gear.id);
                          } else {
                            _selectedGearIds.add(gear.id!);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: isSelected,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedGearIds.add(gear.id!);
                                    } else {
                                      _selectedGearIds.remove(gear.id);
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(gear.name, style: const TextStyle(fontSize: 14)),
                            if (gear.category != null) ...[
                              const SizedBox(width: 6),
                              Text(gear.category!, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // ── Notes ─────────────────────────────────────────────────
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // ── Save ──────────────────────────────────────────────────
            FilledButton(
              onPressed: _isSaving ? null : _saveEntry,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _isSaving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        widget.entry == null ? 'Create Entry' : 'Update Entry',
                        style: const TextStyle(fontSize: 15),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinatesRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Coordinates', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                _latitude != null && _longitude != null
                    ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                    : 'No coordinates set',
                style: TextStyle(fontSize: 13, color: _latitude != null ? null : Colors.grey),
              ),
            ),
            _isFetchingLocation
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    icon: const Icon(Icons.my_location, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Fetch location',
                    onPressed: _fetchLocation,
                  ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Enter manually',
              onPressed: _enterCoordinatesManually,
            ),
            if (_latitude != null) ...[
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Clear',
                onPressed: () => setState(() { _latitude = null; _longitude = null; }),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTentShelterToggle() {
    return Row(
      children: [
        const Text('Sleeping:', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 12),
        ToggleButtons(
          isSelected: [_isTent == true, _isTent == false],
          onPressed: (index) => setState(() => _isTent = index == 0 ? true : false),
          constraints: const BoxConstraints(minHeight: 32, minWidth: 64),
          children: const [
            Text('Tent', style: TextStyle(fontSize: 13)),
            Text('Shelter', style: TextStyle(fontSize: 13)),
          ],
        ),
      ],
    );
  }

  Widget _buildShowerSwitch() {
    return Row(
      children: [
        const Text('Shower:', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 12),
        Switch(
          value: _hadShower,
          onChanged: (value) => setState(() => _hadShower = value),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  Widget _buildCustomFieldInput(CustomField field) {
    switch (field.type) {
      case CustomFieldType.text:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            controller: _customFieldControllers[field.id!],
            decoration: _slimDecoration(field.name),
          ),
        );

      case CustomFieldType.number:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Text('${field.name}:', style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 10),
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: _customFieldControllers[field.id!],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
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
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text('${field.name}:', style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 12),
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: _customFieldYesNo[field.id!] ?? false,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) => setState(() => _customFieldYesNo[field.id!] = value ?? false),
                ),
              ),
            ],
          ),
        );

      case CustomFieldType.rating:
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text('${field.name}:', style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 12),
              ...List.generate(5, (index) {
                final rating = _customFieldRatings[field.id!] ?? 0;
                return GestureDetector(
                  onTap: () => setState(() => _customFieldRatings[field.id!] = index + 1),
                  child: Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 24,
                  ),
                );
              }),
            ],
          ),
        );
    }
  }
}