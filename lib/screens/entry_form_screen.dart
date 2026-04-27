// screens/entry_form_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../models/entry.dart';
import '../models/section.dart';
import '../repositories/entry_repository.dart';
import '../repositories/trip_repository.dart';
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
  final TripRepository _tripRepository = TripRepository();
  final GearRepository _gearRepository = GearRepository();
  final CustomFieldRepository _customFieldRepository = CustomFieldRepository();
  final _settings = SettingsService();

  List<Gear> _availableGear = [];
  List<int> _selectedGearIds = [];
  List<Alternate> _availableAlternates = [];
  int? _selectedAlternateId;

  final _startMileController = TextEditingController();
  final _endMileController = TextEditingController();
  final _extraMilesController = TextEditingController();
  final _skippedMilesController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _elevationGainController = TextEditingController();
  final _elevationLossController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  Direction? _selectedDirection;
  bool? _isTent;
  bool _hadShower = false;
  bool _isSaving = false;

  List<CustomFieldWithValue> _customFields = [];
  Map<int, TextEditingController> _customFieldControllers = {};
  Map<int, bool> _customFieldYesNo = {};
  Map<int, int> _customFieldRatings = {};

  bool _isFetchingLocation = false;

  bool get _isOnAlternate => _selectedAlternateId != null;

  static const _labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
  static const _fieldTextStyle = TextStyle(fontSize: 13);

  InputDecoration _slimDecoration({String? suffixText, String? hintText}) {
    return InputDecoration(
      suffixText: suffixText,
      hintText: hintText,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      isDense: true,
    );
  }

  Widget _fieldRow(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _labelStyle),
          const SizedBox(height: 4),
          field,
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadGear();
    _loadCustomFields();
    _loadAlternates();

    if (widget.entry != null) {
      final entry = widget.entry!;
      _locationController.text = entry.location ?? '';
      _notesController.text = entry.notes;
      _selectedDate = entry.date;
      _selectedDirection = entry.direction;
      _isTent = entry.tentOrShelter;
      _hadShower = entry.shower ?? false;
      _selectedAlternateId = entry.alternateId;

      if (entry.latitude != null) _latitudeController.text = entry.latitude!.toStringAsFixed(5);
      if (entry.longitude != null) _longitudeController.text = entry.longitude!.toStringAsFixed(5);

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

  Future<void> _loadAlternates() async {
    final alternates = await _tripRepository.getIncompleteAlternatesForTrip(widget.trip.id!);
    if (widget.entry?.alternateId != null) {
      final alreadyIncluded = alternates.any((a) => a.id == widget.entry!.alternateId);
      if (!alreadyIncluded) {
        final current = widget.trip.alternates.where((a) => a.id == widget.entry!.alternateId).toList();
        alternates.addAll(current);
      }
    }
    if (mounted) setState(() => _availableAlternates = alternates);
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
    _elevationGainController.dispose();
    _elevationLossController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission permanently denied. Enable it in Settings.')),
        );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(5);
        _longitudeController.text = position.longitude.toStringAsFixed(5);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final lat = double.tryParse(_latitudeController.text);
      final lng = double.tryParse(_longitudeController.text);

      final entry = Entry(
        id: widget.entry?.id,
        tripId: widget.trip.id!,
        date: _selectedDate,
        startMile: _settings.convertFromDisplayUnit(double.parse(_startMileController.text)),
        endMile: _settings.convertFromDisplayUnit(double.parse(_endMileController.text)),
        extraMiles: _isOnAlternate ? 0.0 : _settings.convertFromDisplayUnit(double.tryParse(_extraMilesController.text) ?? 0.0),
        skippedMiles: _isOnAlternate ? 0.0 : _settings.convertFromDisplayUnit(double.tryParse(_skippedMilesController.text) ?? 0.0),
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
        latitude: lat,
        longitude: lng,
        alternateId: _selectedAlternateId,
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
    final distUnit = _settings.getDistanceUnitLabel();
    final elevUnit = _settings.getElevationUnitLabel();
    final isEditing = widget.entry != null;
    final theme = Theme.of(context);

    // Force dropdown text to use normal on-surface color regardless of theme
    final dropdownTheme = theme.copyWith(
      textTheme: theme.textTheme.apply(bodyColor: theme.colorScheme.onSurface),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Entry' : 'New Entry'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── Date ─────────────────────────────────────────────────
            _fieldRow('Date', InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 14),
                    const SizedBox(width: 8),
                    Text(DateFormat.yMMMd().format(_selectedDate), style: _fieldTextStyle),
                  ],
                ),
              ),
            )),

            // ── Direction ─────────────────────────────────────────────
            _fieldRow('Direction', Theme(
              data: dropdownTheme,
              child: DropdownButtonFormField<Direction>(
                decoration: _slimDecoration(),
                style: _fieldTextStyle.copyWith(color: theme.colorScheme.onSurface),
                value: _selectedDirection,
                items: Direction.values.map((d) => DropdownMenuItem(
                  value: d,
                  child: Text(d.toString().split('.').last),
                )).toList(),
                onChanged: (value) => setState(() => _selectedDirection = value),
              ),
            )),

            // ── Start / End ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Start', style: _labelStyle),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _startMileController,
                          style: _fieldTextStyle,
                          cursorHeight: 14,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _slimDecoration(suffixText: distUnit),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('End', style: _labelStyle),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _endMileController,
                          style: _fieldTextStyle,
                          cursorHeight: 14,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _slimDecoration(suffixText: distUnit),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Added / Skipped ───────────────────────────────────────
            if (!_isOnAlternate)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Added', style: _labelStyle),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _extraMilesController,
                            style: _fieldTextStyle,
                            cursorHeight: 14,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _slimDecoration(suffixText: distUnit),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Skipped', style: _labelStyle),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _skippedMilesController,
                            style: _fieldTextStyle,
                            cursorHeight: 14,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _slimDecoration(suffixText: distUnit),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ── Elevation ─────────────────────────────────────────────
            // ── Elevation ─────────────────────────────────────────────
            if (widget.trip.trackElevation)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Elev Gain', style: _labelStyle),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _elevationGainController,
                            style: _fieldTextStyle,
                            cursorHeight: 14,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _slimDecoration(suffixText: elevUnit),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Elev Loss', style: _labelStyle),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _elevationLossController,
                            style: _fieldTextStyle,
                            cursorHeight: 14,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _slimDecoration(suffixText: elevUnit),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // ── Coordinates ───────────────────────────────────────────
            // ── Coordinates ───────────────────────────────────────────
            if (widget.trip.trackCoordinates) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Coordinates', style: _labelStyle),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 26,
                          child: OutlinedButton(
                          onPressed: _isFetchingLocation ? null : _fetchLocation,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: _isFetchingLocation
                            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location, size: 13),
                          ),
                        ),
                        if (_latitudeController.text.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          SizedBox(
                            height: 26,
                            child: OutlinedButton.icon(
                              onPressed: () => setState(() {
                                _latitudeController.clear();
                                _longitudeController.clear();
                              }),
                              icon: const Icon(Icons.clear, size: 13),
                              label: const Text('Clear', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                foregroundColor: Colors.grey[600],
                                side: BorderSide(color: Colors.grey.shade400),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latitudeController,
                            style: _fieldTextStyle,
                            cursorHeight: 14,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            decoration: _slimDecoration(hintText: 'Latitude'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _longitudeController,
                            style: _fieldTextStyle,
                            cursorHeight: 14,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            decoration: _slimDecoration(hintText: 'Longitude'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // ── Alternate Route ───────────────────────────────────────
            if (_availableAlternates.isNotEmpty)
              _fieldRow('Alternate Route', Theme(
                data: dropdownTheme,
                child: DropdownButtonFormField<int?>(
                  decoration: _slimDecoration(),
                  style: _fieldTextStyle.copyWith(color: theme.colorScheme.onSurface),
                  value: _selectedAlternateId,
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text('None', style: _fieldTextStyle.copyWith(color: theme.colorScheme.onSurface)),
                    ),
                    ..._availableAlternates.map((alt) => DropdownMenuItem<int?>(
                      value: alt.id,
                      child: Text(alt.name),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedAlternateId = value;
                      if (value != null) {
                        _startMileController.text = '0.00';
                        _endMileController.text = '0.00';
                      }
                    });
                  },
                ),
              )),

            // ── Sleeping ──────────────────────────────────────────────
            if (widget.trip.trackSleeping)
              _fieldRow('Sleeping', _buildTentShelterToggle()),

            // ── Shower ────────────────────────────────────────────────
            if (widget.trip.trackShower)
              _fieldRow('Shower', _buildShowerSwitch()),

            // ── Custom Fields ─────────────────────────────────────────
            if (_customFields.isNotEmpty) ...[
              ..._customFields.map((fwv) => _buildCustomFieldInput(fwv.field)),
              const SizedBox(height: 4),
            ],

            // ── Gear ──────────────────────────────────────────────────
            if (_availableGear.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('Gear', style: _labelStyle),
              ),
              ..._availableGear.map((gear) {
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
                    padding: const EdgeInsets.symmetric(vertical: 5),
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
                        Text(gear.name, style: _fieldTextStyle),
                        if (gear.category != null) ...[
                          const SizedBox(width: 6),
                          Text(gear.category!, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 10),
            ],

            // ── Notes ─────────────────────────────────────────────────
            Text('Notes', style: _labelStyle),
            const SizedBox(height: 4),
            TextFormField(
              controller: _notesController,
              maxLines: 6,
              style: _fieldTextStyle,
              cursorHeight: 14,
              decoration: _slimDecoration(),
            ),

            const SizedBox(height: 16),

            // ── Save / Delete ─────────────────────────────────────────
            if (isEditing)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _deleteEntry,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Delete Entry', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _saveEntry,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                      child: _isSaving
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save Entry', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              )
            else
              FilledButton(
                onPressed: _isSaving ? null : _saveEntry,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                child: _isSaving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create Entry', style: TextStyle(fontSize: 13)),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTentShelterToggle() {
    return ToggleButtons(
      isSelected: [_isTent == true, _isTent == false],
      onPressed: (index) => setState(() => _isTent = index == 0 ? true : false),
      constraints: const BoxConstraints(minHeight: 30, minWidth: 72),
      children: const [
        Text('Tent', style: TextStyle(fontSize: 13)),
        Text('Shelter', style: TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildShowerSwitch() {
    return SizedBox(
      height: 30,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Switch(
          value: _hadShower,
          onChanged: (value) => setState(() => _hadShower = value),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Widget _buildCustomFieldInput(CustomField field) {
    switch (field.type) {
      case CustomFieldType.text:
        return _fieldRow(field.name, TextFormField(
          controller: _customFieldControllers[field.id!],
          style: _fieldTextStyle,
          cursorHeight: 14,
          decoration: _slimDecoration(),
        ));

      case CustomFieldType.number:
        return _fieldRow(field.name, SizedBox(
          width: 100,
          child: TextFormField(
            controller: _customFieldControllers[field.id!],
            style: _fieldTextStyle,
            cursorHeight: 14,
            decoration: _slimDecoration(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
          ),
        ));

      case CustomFieldType.checkbox:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Text(field.name, style: _labelStyle),
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
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(field.name, style: _labelStyle),
              const SizedBox(height: 4),
              Row(
                children: List.generate(5, (index) {
                  final rating = _customFieldRatings[field.id!] ?? 0;
                  return GestureDetector(
                    onTap: () => setState(() => _customFieldRatings[field.id!] = index + 1),
                    child: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: const Color.fromRGBO(255, 193, 7, 1),
                      size: 22,
                    ),
                  );
                }),
              ),
            ],
          ),
        );
    }
  }
}