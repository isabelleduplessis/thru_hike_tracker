// screens/trip_form_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../models/section.dart';
import '../models/direction.dart';
import '../models/custom_field.dart';
import '../repositories/trip_repository.dart';
import '../repositories/custom_field_repository.dart';
import '../services/settings_service.dart';

class TripFormScreen extends StatefulWidget {
  final Trip? trip;

  const TripFormScreen({Key? key, this.trip}) : super(key: key);

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TripRepository _tripRepository = TripRepository();
  final CustomFieldRepository _customFieldRepository = CustomFieldRepository();
  final _settings = SettingsService();

  final _nameController = TextEditingController();
  final _startMileController = TextEditingController(text: '0.0');
  final _tripLengthController = TextEditingController(text: '0.0');
  final _neroThresholdController = TextEditingController();

  DateTime _startDate = DateTime.now();
  TripStatus _status = TripStatus.active;
  Direction? _direction;
  List<Section> _sections = [];
  bool _isSaving = false;

  bool _trackCoordinates = false;
  bool _trackShower = false;
  bool _trackElevation = false;
  bool _trackSleeping = false;

  List<CustomField> _availableFields = [];
  List<CustomField> _selectedFields = [];

  @override
  void initState() {
    super.initState();
    _loadCustomFields();
    _loadTripCustomFields();

    if (widget.trip != null) {
      final trip = widget.trip!;
      _nameController.text = trip.name;
      _startMileController.text = trip.startMile.toStringAsFixed(1);
      _tripLengthController.text = trip.tripLength.toStringAsFixed(1);
      _startDate = trip.startDate;
      _status = trip.status;
      _direction = trip.direction;
      _sections = List.from(trip.sections);
      _trackCoordinates = trip.trackCoordinates;
      _trackShower = trip.trackShower;
      _trackElevation = trip.trackElevation;
      _trackSleeping = trip.trackSleeping;
      _neroThresholdController.text = trip.neroThreshold?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startMileController.dispose();
    _tripLengthController.dispose();
    _neroThresholdController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomFields() async {
    final fields = await _customFieldRepository.getAllCustomFields();
    setState(() => _availableFields = fields);
  }

  Future<void> _loadTripCustomFields() async {
    if (widget.trip != null) {
      final fields = await _customFieldRepository.getCustomFieldsForTrip(widget.trip!.id!);
      setState(() => _selectedFields = fields);
    }
  }

  double get _currentEndMile {
    double start = double.tryParse(_startMileController.text) ?? 0.0;
    double length = double.tryParse(_tripLengthController.text) ?? 0.0;
    return start + length;
  }

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final startMile = double.tryParse(_startMileController.text) ?? 0.0;
      final tripLength = double.tryParse(_tripLengthController.text) ?? 0.0;

      final trip = Trip(
        id: widget.trip?.id,
        name: _nameController.text.trim(),
        startDate: _startDate,
        startMile: startMile,
        tripLength: tripLength,
        endMile: startMile + tripLength,
        status: _status,
        direction: _direction,
        sections: _sections,
        trackCoordinates: _trackCoordinates,
        trackShower: _trackShower,
        trackElevation: _trackElevation,
        trackSleeping: _trackSleeping,
        neroThreshold: double.tryParse(_neroThresholdController.text),
      );

      Trip savedTrip;
      if (widget.trip == null) {
        savedTrip = await _tripRepository.createTrip(trip);
      } else {
        await _tripRepository.updateTrip(trip);
        savedTrip = trip;
      }

      await _customFieldRepository.setCustomFieldsForTrip(
        savedTrip.id!,
        _selectedFields,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Hike'),
        content: const Text(
          'Are you sure you want to delete this hike? All entries will also be deleted. This cannot be undone.',
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
        await _tripRepository.deleteTrip(widget.trip!.id!);
        if (mounted) Navigator.pop(context, 'deleted');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting hike: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.trip != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Hike' : 'New Hike'),
        actions: isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteTrip,
                  tooltip: 'Delete Hike',
                ),
              ]
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Trip Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<Direction>(
              value: _direction,
              decoration: const InputDecoration(
                labelText: 'Default Direction',
                border: OutlineInputBorder(),
              ),
              items: Direction.values
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(d.name.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _direction = v),
            ),
            const SizedBox(height: 16),

            ListTile(
              title: const Text('Start Date'),
              subtitle: Text(DateFormat('MMM dd, yyyy').format(_startDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
            ),
            const SizedBox(height: 16),

            // Status
            DropdownButtonFormField<TripStatus>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: TripStatus.active, child: Text('Active')),
                DropdownMenuItem(value: TripStatus.paused, child: Text('Paused')),
                DropdownMenuItem(value: TripStatus.completed, child: Text('Completed')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _status = v);
              },
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startMileController,
                    decoration: const InputDecoration(
                      labelText: 'Start Mile',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _tripLengthController,
                    decoration: const InputDecoration(
                      labelText: 'Total Length',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),

            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'End Mile: ${_currentEndMile.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),

            const Divider(),
            _buildSectionEditor(),
            const SizedBox(height: 24),

            const Divider(),
            _buildOptionalFieldsAndNero(),
            const SizedBox(height: 24),

            const Divider(),
            _buildCustomFieldsSection(),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: _isSaving ? null : _saveTrip,
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(isEditing ? 'Update Hike' : 'Save Hike'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Trail Sections',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  double start = _sections.isEmpty
                      ? (double.tryParse(_startMileController.text) ?? 0.0)
                      : _sections.last.endMile;
                  _sections.add(Section(name: '', startMile: start, endMile: start + 50));
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Section'),
            ),
          ],
        ),
        ..._sections.asMap().entries.map((entry) {
          int index = entry.key;
          Section section = entry.value;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  TextFormField(
                    initialValue: section.name,
                    decoration: const InputDecoration(labelText: 'Section Name'),
                    onChanged: (val) =>
                        _sections[index] = section.copyWith(name: val),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: section.startMile.toString(),
                          decoration: const InputDecoration(labelText: 'Start'),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => _sections[index] = section.copyWith(
                              startMile: double.tryParse(val) ?? 0.0),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: section.endMile.toString(),
                          decoration: const InputDecoration(labelText: 'End'),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => _sections[index] = section.copyWith(
                              endMile: double.tryParse(val) ?? 0.0),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            setState(() => _sections.removeAt(index)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildOptionalFieldsAndNero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Optional Tracking',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose what to track in daily entries for this hike.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        SwitchListTile(
          title: const Text('Coordinates'),
          subtitle: const Text('Log GPS location per entry'),
          value: _trackCoordinates,
          onChanged: (v) => setState(() => _trackCoordinates = v),
        ),
        SwitchListTile(
          title: const Text('Shower'),
          subtitle: const Text('Track whether you showered'),
          value: _trackShower,
          onChanged: (v) => setState(() => _trackShower = v),
        ),
        SwitchListTile(
          title: const Text('Elevation'),
          subtitle: const Text('Log elevation gain and loss'),
          value: _trackElevation,
          onChanged: (v) => setState(() => _trackElevation = v),
        ),
        SwitchListTile(
          title: const Text('Sleeping Arrangement'),
          subtitle: const Text('Track tent vs shelter'),
          value: _trackSleeping,
          onChanged: (v) => setState(() => _trackSleeping = v),
        ),
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'Nero Days',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _neroThresholdController,
          decoration: InputDecoration(
            labelText: 'Nero Threshold',
            hintText: 'e.g. 10',
            helperText: 'Days at or below this distance count as nero days.',
            border: const OutlineInputBorder(),
            suffixText: _settings.getDistanceUnitLabel(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  Widget _buildCustomFieldsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Custom Fields',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _showAddFieldDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Field'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedFields.isEmpty)
          const Text(
            'No custom fields yet. Add fields to track specific data for this hike.',
            style: TextStyle(color: Colors.grey),
          )
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final field = _selectedFields.removeAt(oldIndex);
                _selectedFields.insert(newIndex, field);
              });
            },
            children: _selectedFields.map((field) {
              return ListTile(
                key: ValueKey(field.id),
                leading: const Icon(Icons.drag_handle),
                title: Text(field.name),
                subtitle: Text(_getFieldTypeLabel(field.type)),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      setState(() => _selectedFields.remove(field)),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  String _getFieldTypeLabel(CustomFieldType type) {
    switch (type) {
      case CustomFieldType.text:
        return 'Text';
      case CustomFieldType.number:
        return 'Number';
      case CustomFieldType.checkbox:
        return 'Checkbox';
      case CustomFieldType.rating:
        return 'Rating (1-5)';
    }
  }

  void _showAddFieldDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddCustomFieldDialog(
        availableFields: _availableFields,
        selectedFields: _selectedFields,
        onFieldsSelected: (fields) {
          setState(() => _selectedFields = fields);
        },
        onCreateNew: (field) async {
          final created = await _customFieldRepository.createCustomField(field);
          setState(() {
            _availableFields.add(created);
            _selectedFields.add(created);
          });
        },
      ),
    );
  }
}

class _AddCustomFieldDialog extends StatefulWidget {
  final List<CustomField> availableFields;
  final List<CustomField> selectedFields;
  final Function(List<CustomField>) onFieldsSelected;
  final Function(CustomField) onCreateNew;

  const _AddCustomFieldDialog({
    required this.availableFields,
    required this.selectedFields,
    required this.onFieldsSelected,
    required this.onCreateNew,
  });

  @override
  State<_AddCustomFieldDialog> createState() => _AddCustomFieldDialogState();
}

class _AddCustomFieldDialogState extends State<_AddCustomFieldDialog> {
  bool _showCreateNew = false;
  final _nameController = TextEditingController();
  CustomFieldType _selectedType = CustomFieldType.text;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showCreateNew) {
      return AlertDialog(
        title: const Text('Create Custom Field'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Field Name',
                hintText: 'e.g., Bear sightings, Weather',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CustomFieldType>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Field Type'),
              items: CustomFieldType.values
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(_getTypeLabel(type)),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedType = value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() => _showCreateNew = false),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.trim().isNotEmpty) {
                widget.onCreateNew(CustomField(
                  name: _nameController.text.trim(),
                  type: _selectedType,
                ));
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      );
    }

    final unselectedFields = widget.availableFields
        .where((f) => !widget.selectedFields.any((s) => s.id == f.id))
        .toList();

    return AlertDialog(
      title: const Text('Add Custom Field'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unselectedFields.isEmpty)
              const Text('All existing fields have been added.')
            else
              ...unselectedFields.map((field) {
                return ListTile(
                  title: Text(field.name),
                  subtitle: Text(_getTypeLabel(field.type)),
                  onTap: () {
                    widget.onFieldsSelected([...widget.selectedFields, field]);
                    Navigator.pop(context);
                  },
                );
              }),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_circle),
              title: const Text('Create New Field'),
              onTap: () => setState(() => _showCreateNew = true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  String _getTypeLabel(CustomFieldType type) {
    switch (type) {
      case CustomFieldType.text:
        return 'Text';
      case CustomFieldType.number:
        return 'Number';
      case CustomFieldType.checkbox:
        return 'Checkbox';
      case CustomFieldType.rating:
        return 'Rating (1-5)';
    }
  }
}