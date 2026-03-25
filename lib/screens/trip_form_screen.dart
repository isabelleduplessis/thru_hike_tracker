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
  final _endMileController = TextEditingController(text: '0.0');
  final _neroThresholdController = TextEditingController();

  DateTime _startDate = DateTime.now();
  TripStatus _status = TripStatus.active;
  Direction? _direction;
  List<Section> _sections = [];
  List<Alternate> _alternates = [];
  bool _isSaving = false;

  bool _trackCoordinates = false;
  bool _trackShower = false;
  bool _trackElevation = false;
  bool _trackSleeping = false;

  List<CustomField> _availableFields = [];
  List<CustomField> _selectedFields = [];

  // ── Shared styles ─────────────────────────────────────────────
  static const _sectionTitleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold);
  static const _sectionSubtitleStyle = TextStyle(fontSize: 11, color: Colors.grey);
  static const _infoIconSize = 18.0;

  @override
  void initState() {
    super.initState();
    _loadCustomFields();
    _loadTripCustomFields();

    if (widget.trip != null) {
      final trip = widget.trip!;
      _nameController.text = trip.name;
      _startMileController.text = _settings.convertToDisplayUnit(trip.startMile).toStringAsFixed(1);
      _endMileController.text = _settings.convertToDisplayUnit(trip.endMile).toStringAsFixed(1);
      _startDate = trip.startDate;
      _status = trip.status;
      _direction = trip.direction;
      _sections = trip.sections.map((s) => Section(
        id: s.id,
        tripId: s.tripId,
        name: s.name,
        startMile: _settings.convertToDisplayUnit(s.startMile),
        endMile: _settings.convertToDisplayUnit(s.endMile),
        completed: s.completed,
      )).toList();
      _alternates = trip.alternates.map((a) => Alternate(
        id: a.id,
        tripId: a.tripId,
        name: a.name,
        departureMile: _settings.convertToDisplayUnit(a.departureMile),
        returnMile: _settings.convertToDisplayUnit(a.returnMile),
        length: _settings.convertToDisplayUnit(a.length),
        completed: a.completed,
      )).toList();
      _trackCoordinates = trip.trackCoordinates;
      _trackShower = trip.trackShower;
      _trackElevation = trip.trackElevation;
      _trackSleeping = trip.trackSleeping;
      _neroThresholdController.text = trip.neroThreshold != null
          ? _settings.convertToDisplayUnit(trip.neroThreshold!).toStringAsFixed(1)
          : '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startMileController.dispose();
    _endMileController.dispose();
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

  double get _displayStartMile => double.tryParse(_startMileController.text) ?? 0.0;
  double get _displayEndMile => double.tryParse(_endMileController.text) ?? 0.0;
  double get _displayLength => (_displayEndMile - _displayStartMile).abs();

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final startMile = _settings.convertFromDisplayUnit(_displayStartMile);
      final endMile = _settings.convertFromDisplayUnit(_displayEndMile);
      final tripLength = (endMile - startMile).abs();

      final baseSections = _sections.map((s) => Section(
        id: s.id,
        tripId: s.tripId,
        name: s.name,
        startMile: _settings.convertFromDisplayUnit(s.startMile),
        endMile: _settings.convertFromDisplayUnit(s.endMile),
        completed: s.completed,
      )).toList();

      final baseAlternates = _alternates.map((a) => Alternate(
        id: a.id,
        tripId: a.tripId,
        name: a.name,
        departureMile: _settings.convertFromDisplayUnit(a.departureMile),
        returnMile: _settings.convertFromDisplayUnit(a.returnMile),
        length: _settings.convertFromDisplayUnit(a.length),
        completed: a.completed,
      )).toList();

      final trip = Trip(
        id: widget.trip?.id,
        name: _nameController.text.trim(),
        startDate: _startDate,
        startMile: startMile,
        tripLength: tripLength,
        endMile: endMile,
        status: _status,
        direction: _direction,
        sections: baseSections,
        alternates: baseAlternates,
        trackCoordinates: _trackCoordinates,
        trackShower: _trackShower,
        trackElevation: _trackElevation,
        trackSleeping: _trackSleeping,
        neroThreshold: _neroThresholdController.text.isNotEmpty
            ? _settings.convertFromDisplayUnit(double.parse(_neroThresholdController.text))
            : null,
      );

      Trip savedTrip;
      if (widget.trip == null) {
        savedTrip = await _tripRepository.createTrip(trip);
      } else {
        await _tripRepository.updateTrip(trip);
        savedTrip = trip;
      }

      await _customFieldRepository.setCustomFieldsForTrip(savedTrip.id!, _selectedFields);

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

  // ── Info dialogs ──────────────────────────────────────────────

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content, style: const TextStyle(fontSize: 14))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
        ],
      ),
    );
  }

  Widget _infoIcon(String title, String content) {
    return IconButton(
      icon: const Icon(Icons.info_outline, size: _infoIconSize),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      tooltip: title,
      onPressed: () => _showInfoDialog(title, content),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.trip != null;
    final unit = _settings.getDistanceUnitLabel();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Hike' : 'New Hike'),
        actions: isEditing
            ? [IconButton(icon: const Icon(Icons.delete), onPressed: _deleteTrip, tooltip: 'Delete Hike')]
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Hike Name', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<Direction>(
              value: _direction,
              decoration: const InputDecoration(labelText: 'Direction', border: OutlineInputBorder()),
              items: Direction.values
                  .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                  .toList(),
              onChanged: (v) => setState(() => _direction = v),
            ),
            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start Date', style: TextStyle(fontSize: 14)),
              subtitle: Text(DateFormat('MMM dd, yyyy').format(_startDate), style: const TextStyle(fontSize: 13)),
              trailing: const Icon(Icons.calendar_today, size: 18),
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
            const SizedBox(height: 8),

            DropdownButtonFormField<TripStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: TripStatus.active, child: Text('Active')),
                DropdownMenuItem(value: TripStatus.paused, child: Text('Paused')),
                DropdownMenuItem(value: TripStatus.completed, child: Text('Completed')),
              ],
              onChanged: (v) { if (v != null) setState(() => _status = v); },
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startMileController,
                    decoration: InputDecoration(labelText: 'Start $unit', border: const OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _endMileController,
                    decoration: InputDecoration(labelText: 'End $unit', border: const OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'Total Distance: ${_displayLength.toStringAsFixed(1)} $unit',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Divider(),
            _buildSectionEditor(),

            const SizedBox(height: 20),
            const Divider(),
            _buildAlternateEditor(),

            const SizedBox(height: 20),
            const Divider(),
            _buildNeroDays(),

            const SizedBox(height: 20),
            const Divider(),
            _buildOptionalTracking(),

            const SizedBox(height: 20),
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

  Widget _buildSectionHeader(String title, String infoTitle, String infoContent, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(title, style: _sectionTitleStyle),
            const SizedBox(width: 4),
            _infoIcon(infoTitle, infoContent),
          ],
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildSectionEditor() {
    final unit = _settings.getDistanceUnitLabel();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Trail Sections',
          'Trail Sections',
          'Sections let you divide your trail into named segments (e.g. "Southern Terminus to Silverton"). '
          'Each section has a start and end mile. The app automatically determines which section an entry '
          'belongs to based on the end mile. You can manually mark a section as completed if you\'ve '
          'finished it regardless of logged coverage.',
          trailing: TextButton.icon(
            onPressed: () {
              setState(() {
                double start = _sections.isEmpty ? _displayStartMile : _sections.last.endMile;
                _sections.add(Section(name: '', startMile: start, endMile: start + 50));
              });
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add', style: TextStyle(fontSize: 13)),
          ),
        ),
        ..._sections.asMap().entries.map((entry) {
          int index = entry.key;
          Section section = entry.value;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: section.name,
                          decoration: const InputDecoration(labelText: 'Section Name'),
                          onChanged: (val) => setState(() =>
                              _sections[index] = section.copyWith(name: val)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _sections.removeAt(index)),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: section.startMile.toStringAsFixed(1),
                          decoration: InputDecoration(labelText: 'Start $unit'),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => setState(() => _sections[index] =
                              section.copyWith(startMile: double.tryParse(val) ?? 0.0)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: section.endMile.toStringAsFixed(1),
                          decoration: InputDecoration(labelText: 'End $unit'),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => setState(() => _sections[index] =
                              section.copyWith(endMile: double.tryParse(val) ?? 0.0)),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: section.completed,
                        onChanged: (val) => setState(() =>
                            _sections[index] = section.copyWith(completed: val ?? false)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Text('Completed', style: TextStyle(fontSize: 13)),
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

  Widget _buildAlternateEditor() {
    final unit = _settings.getDistanceUnitLabel();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Alternate Routes',
          'Alternate Routes',
          'An alternate route is an off-trail route that diverges from the main trail.\n\n'
          'Departure: the trail mile where the alternate begins.\n\n'
          'Return: the trail mile where the alternate rejoins the main trail.\n\n'
          'Length: the total distance of the alternate route itself — independent of the main trail mile system.\n\n'
          'When logging entries on an alternate, select it from the entry form. Your start and end miles will '
          'be in alternate miles (starting from 0).\n\n'
          'Mark the alternate as completed when you finish it. Completed alternates count toward your total '
          'distance and the trail miles between departure and return are treated as covered in progress tracking.',
          trailing: TextButton.icon(
            onPressed: () {
              setState(() {
                _alternates.add(Alternate(name: '', departureMile: 0.0, returnMile: 0.0, length: 0.0));
              });
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add', style: TextStyle(fontSize: 13)),
          ),
        ),
        if (_alternates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('No alternate routes defined.', style: _sectionSubtitleStyle),
          ),
        ..._alternates.asMap().entries.map((entry) {
          int index = entry.key;
          Alternate alt = entry.value;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: alt.name,
                          decoration: const InputDecoration(labelText: 'Alternate Name'),
                          onChanged: (val) => setState(() =>
                              _alternates[index] = alt.copyWith(name: val)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _alternates.removeAt(index)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: alt.departureMile.toStringAsFixed(1),
                          decoration: InputDecoration(labelText: 'Departure $unit'),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => setState(() => _alternates[index] =
                              alt.copyWith(departureMile: double.tryParse(val) ?? 0.0)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: alt.returnMile.toStringAsFixed(1),
                          decoration: InputDecoration(labelText: 'Return $unit'),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => setState(() => _alternates[index] =
                              alt.copyWith(returnMile: double.tryParse(val) ?? 0.0)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: alt.length.toStringAsFixed(1),
                    decoration: InputDecoration(
                      labelText: 'Alternate Length',
                      suffixText: unit,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => setState(() => _alternates[index] =
                        alt.copyWith(length: double.tryParse(val) ?? 0.0)),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: alt.completed,
                        onChanged: (val) => setState(() =>
                            _alternates[index] = alt.copyWith(completed: val ?? false)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Text('Completed', style: TextStyle(fontSize: 13)),
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

  Widget _buildNeroDays() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Nero Days', style: _sectionTitleStyle),
            const SizedBox(width: 4),
            _infoIcon(
              'Nero Days',
              'A nero (nearly zero) day is a day where you hiked a very short distance — not quite a zero but close. '
              'Set a threshold distance here and any day where your total mileage is greater than zero but at or '
              'below that threshold will count as a nero day in your stats.',
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _neroThresholdController,
          decoration: InputDecoration(
            labelText: 'Nero Threshold',
            hintText: 'e.g. 10',
            border: const OutlineInputBorder(),
            suffixText: _settings.getDistanceUnitLabel(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  Widget _buildOptionalTracking() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Optional Tracking', style: _sectionTitleStyle),
            const SizedBox(width: 4),
            _infoIcon(
              'Optional Tracking',
              'These fields are hidden by default to keep your daily entries clean. Enable only what you want '
              'to track for this hike. You can change these settings at any time and existing entries won\'t be affected.',
            ),
          ],
        ),
        CheckboxListTile(
          dense: true,
          title: const Text('Coordinates', style: TextStyle(fontSize: 14)),
          subtitle: const Text('Log GPS location per entry', style: _sectionSubtitleStyle),
          value: _trackCoordinates,
          onChanged: (v) => setState(() => _trackCoordinates = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          dense: true,
          title: const Text('Shower', style: TextStyle(fontSize: 14)),
          subtitle: const Text('Track whether you showered', style: _sectionSubtitleStyle),
          value: _trackShower,
          onChanged: (v) => setState(() => _trackShower = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          dense: true,
          title: const Text('Elevation', style: TextStyle(fontSize: 14)),
          subtitle: const Text('Log elevation gain and loss', style: _sectionSubtitleStyle),
          value: _trackElevation,
          onChanged: (v) => setState(() => _trackElevation = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          dense: true,
          title: const Text('Sleeping Arrangement', style: TextStyle(fontSize: 14)),
          subtitle: const Text('Track tent vs shelter', style: _sectionSubtitleStyle),
          value: _trackSleeping,
          onChanged: (v) => setState(() => _trackSleeping = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
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
            Row(
              children: [
                const Text('Custom Fields', style: _sectionTitleStyle),
                const SizedBox(width: 4),
                _infoIcon(
                  'Custom Fields',
                  'Custom fields let you track anything specific to your hike — bear canisters used, weather '
                  'conditions, towns visited, mood ratings, etc. Fields are shared across all hikes but you '
                  'choose which ones appear in each hike\'s entries. Drag to reorder them.',
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _showAddFieldDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Field', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedFields.isEmpty)
          const Text(
            'No custom fields yet. Add fields to track specific data for this hike.',
            style: _sectionSubtitleStyle,
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
                dense: true,
                leading: const Icon(Icons.drag_handle, size: 18),
                title: Text(field.name, style: const TextStyle(fontSize: 14)),
                subtitle: Text(_getFieldTypeLabel(field.type), style: _sectionSubtitleStyle),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _selectedFields.remove(field)),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  String _getFieldTypeLabel(CustomFieldType type) {
    switch (type) {
      case CustomFieldType.text: return 'Text';
      case CustomFieldType.number: return 'Number';
      case CustomFieldType.checkbox: return 'Checkbox';
      case CustomFieldType.rating: return 'Rating (1-5)';
    }
  }

  void _showAddFieldDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddCustomFieldDialog(
        availableFields: _availableFields,
        selectedFields: _selectedFields,
        onFieldsSelected: (fields) => setState(() => _selectedFields = fields),
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
                  .map((type) => DropdownMenuItem(value: type, child: Text(_getTypeLabel(type))))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedType = value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => setState(() => _showCreateNew = false), child: const Text('Back')),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.trim().isNotEmpty) {
                widget.onCreateNew(CustomField(name: _nameController.text.trim(), type: _selectedType));
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
              ...unselectedFields.map((field) => ListTile(
                dense: true,
                title: Text(field.name, style: const TextStyle(fontSize: 14)),
                subtitle: Text(_getTypeLabel(field.type),
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () {
                  widget.onFieldsSelected([...widget.selectedFields, field]);
                  Navigator.pop(context);
                },
              )),
            const Divider(),
            ListTile(
              dense: true,
              leading: const Icon(Icons.add_circle, size: 18),
              title: const Text('Create New Field', style: TextStyle(fontSize: 14)),
              onTap: () => setState(() => _showCreateNew = true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }

  String _getTypeLabel(CustomFieldType type) {
    switch (type) {
      case CustomFieldType.text: return 'Text';
      case CustomFieldType.number: return 'Number';
      case CustomFieldType.checkbox: return 'Checkbox';
      case CustomFieldType.rating: return 'Rating (1-5)';
    }
  }
}