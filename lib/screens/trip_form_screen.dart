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
  TripStatus _status = TripStatus.inProgress;
  Direction? _direction;
  List<Section> _sections = [];
  List<Alternate> _alternates = [];
  bool _isSaving = false;

  List<CustomField> _availableFields = [];
  List<CustomField> _selectedFields = [];

  static const _labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
  static const _fieldTextStyle = TextStyle(fontSize: 13);
  static const _subtitleStyle = TextStyle(fontSize: 11, color: Colors.grey);

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

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final startMile = _settings.convertFromDisplayUnit(double.tryParse(_startMileController.text) ?? 0.0);
      final endMile = _settings.convertFromDisplayUnit(double.tryParse(_endMileController.text) ?? 0.0);
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
        trackCoordinates: true,
        trackElevation: true,
        trackShower: false,
        trackSleeping: false,
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

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content, style: const TextStyle(fontSize: 13))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
        ],
      ),
    );
  }

  Widget _infoIcon(String title, String content) {
    return GestureDetector(
      onTap: () => _showInfoDialog(title, content),
      child: Icon(Icons.info_outline, size: 15, color: Colors.grey[500]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.trip != null;
    final unit = _settings.getDistanceUnitLabel();
    final theme = Theme.of(context);
    final dropdownTheme = theme.copyWith(
      textTheme: theme.textTheme.apply(bodyColor: theme.colorScheme.onSurface),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Hike' : 'New Hike'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [

            // ── Start Date / Status ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Start Date', style: _labelStyle),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(const Duration(days: 730)),
                            );
                            if (picked != null) setState(() => _startDate = picked);
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 14),
                                const SizedBox(width: 8),
                                Text(DateFormat.yMMMd().format(_startDate), style: _fieldTextStyle),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status', style: _labelStyle),
                        const SizedBox(height: 4),
                        Theme(
                          data: dropdownTheme,
                          child: DropdownButtonFormField<TripStatus>(
                            decoration: _slimDecoration(),
                            style: _fieldTextStyle.copyWith(color: theme.colorScheme.onSurface),
                            value: _status,
                            items: const [
                              DropdownMenuItem(value: TripStatus.inProgress, child: Text('In Progress')),
                              //DropdownMenuItem(value: TripStatus.paused, child: Text('Paused')),
                              DropdownMenuItem(value: TripStatus.completed, child: Text('Completed')),
                            ],
                            onChanged: (v) { if (v != null) setState(() => _status = v); },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Hike Name ─────────────────────────────────────────────
            _fieldRow('Hike Name', TextFormField(
              controller: _nameController,
              style: _fieldTextStyle,
              cursorHeight: 14,
              decoration: _slimDecoration(),
              validator: (v) => v!.isEmpty ? 'Enter a name' : null,
            )),

            // ── Direction ─────────────────────────────────────────────
            _fieldRow('Direction', Theme(
              data: dropdownTheme,
              child: DropdownButtonFormField<Direction>(
                decoration: _slimDecoration(),
                style: _fieldTextStyle.copyWith(color: theme.colorScheme.onSurface),
                value: _direction,
                items: Direction.values
                    .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                    .toList(),
                onChanged: (v) => setState(() => _direction = v),
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
                          decoration: _slimDecoration(suffixText: unit),
                          onChanged: (_) => setState(() {}),
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
                          decoration: _slimDecoration(suffixText: unit),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Nero Threshold ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Nero Threshold', style: _labelStyle),
                      const SizedBox(width: 4),
                      _infoIcon(
                        'Nero Days',
                        'A nero (nearly zero) day is a day where you hiked a very short distance — not quite a zero but close. '
                        'Set a threshold distance here and any day where your total mileage is greater than zero but at or '
                        'below that threshold will count as a nero day in your stats.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _neroThresholdController,
                    style: _fieldTextStyle,
                    cursorHeight: 14,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _slimDecoration(suffixText: unit, hintText: 'e.g. 10'),
                  ),
                ],
              ),
            ),

                        // ── Sections ──────────────────────────────────────────────
            _buildSectionEditor(unit),

            const SizedBox(height: 10),

            // ── Alternates ────────────────────────────────────────────
            _buildAlternateEditor(unit),

            const SizedBox(height: 10),

            // ── Custom Fields ─────────────────────────────────────────
            _buildCustomFieldsSection(),

            const SizedBox(height: 16),

            // ── Save / Delete ─────────────────────────────────────────
            if (isEditing)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _deleteTrip,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Delete Hike', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _saveTrip,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                      child: _isSaving
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save Hike', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              )
            else
              FilledButton(
                onPressed: _isSaving ? null : _saveTrip,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                child: _isSaving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create Hike', style: TextStyle(fontSize: 13)),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionEditor(String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('Sections', style: _labelStyle),
                const SizedBox(width: 4),
                _infoIcon(
                  'Trail Sections',
                  'Sections let you divide your trail into named segments (e.g. "Southern Terminus to Silverton"). '
                  'Each section has a start and end mile. The app automatically determines which section an entry '
                  'belongs to based on the end mile.',
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  double start = _sections.isEmpty
                      ? (double.tryParse(_startMileController.text) ?? 0.0)
                      : _sections.last.endMile;
                  _sections.add(Section(name: '', startMile: start, endMile: start + 50));
                });
              },
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Icon(Icons.add, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ..._sections.asMap().entries.map((entry) {
          final index = entry.key;
          final section = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: section.name,
                          style: _fieldTextStyle,
                          cursorHeight: 14,
                          decoration: _slimDecoration(hintText: 'Section name'),
                          onChanged: (val) => setState(() =>
                              _sections[index] = section.copyWith(name: val)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _sections.removeAt(index)),
                        child: Icon(Icons.close, size: 16, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Start', style: _labelStyle),
                            const SizedBox(height: 4),
                            TextFormField(
                              initialValue: section.startMile.toStringAsFixed(1),
                              style: _fieldTextStyle,
                              cursorHeight: 14,
                              keyboardType: TextInputType.number,
                              decoration: _slimDecoration(suffixText: unit),
                              onChanged: (val) => setState(() => _sections[index] =
                                  section.copyWith(startMile: double.tryParse(val) ?? 0.0)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('End', style: _labelStyle),
                            const SizedBox(height: 4),
                            TextFormField(
                              initialValue: section.endMile.toStringAsFixed(1),
                              style: _fieldTextStyle,
                              cursorHeight: 14,
                              keyboardType: TextInputType.number,
                              decoration: _slimDecoration(suffixText: unit),
                              onChanged: (val) => setState(() => _sections[index] =
                                  section.copyWith(endMile: double.tryParse(val) ?? 0.0)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: section.completed,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (val) => setState(() =>
                              _sections[index] = section.copyWith(completed: val ?? false)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Completed', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAlternateEditor(String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('Alternates', style: _labelStyle),
                const SizedBox(width: 4),
                _infoIcon(
                  'Alternate Routes',
                  'An alternate route diverges from the main trail.\n\n'
                  'Departure: the trail mile where the alternate begins.\n\n'
                  'Return: the trail mile where the alternate rejoins the main trail.\n\n'
                  'When logging entries on an alternate, select it from the entry form. '
                  'Mark the alternate as completed when you finish it.',
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _alternates.add(Alternate(name: '', departureMile: 0.0, returnMile: 0.0, length: 0.0));
                });
              },
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Icon(Icons.add, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ..._alternates.asMap().entries.map((entry) {
          final index = entry.key;
          final alt = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: alt.name,
                          style: _fieldTextStyle,
                          cursorHeight: 14,
                          decoration: _slimDecoration(hintText: 'Alternate name'),
                          onChanged: (val) => setState(() =>
                              _alternates[index] = alt.copyWith(name: val)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _alternates.removeAt(index)),
                        child: Icon(Icons.close, size: 16, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Departure', style: _labelStyle),
                            const SizedBox(height: 4),
                            TextFormField(
                              initialValue: alt.departureMile.toStringAsFixed(1),
                              style: _fieldTextStyle,
                              cursorHeight: 14,
                              keyboardType: TextInputType.number,
                              decoration: _slimDecoration(suffixText: unit),
                              onChanged: (val) => setState(() => _alternates[index] =
                                  alt.copyWith(departureMile: double.tryParse(val) ?? 0.0)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Return', style: _labelStyle),
                            const SizedBox(height: 4),
                            TextFormField(
                              initialValue: alt.returnMile.toStringAsFixed(1),
                              style: _fieldTextStyle,
                              cursorHeight: 14,
                              keyboardType: TextInputType.number,
                              decoration: _slimDecoration(suffixText: unit),
                              onChanged: (val) => setState(() => _alternates[index] =
                                  alt.copyWith(returnMile: double.tryParse(val) ?? 0.0)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: alt.completed,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (val) => setState(() =>
                              _alternates[index] = alt.copyWith(completed: val ?? false)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Completed', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
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
                Text('Custom Fields', style: _labelStyle),
                const SizedBox(width: 4),
                _infoIcon(
                  'Custom Fields',
                  'Custom fields let you track anything specific to your hike — bear canisters used, weather '
                  'conditions, towns visited, mood ratings, etc. Fields are shared across all hikes but you '
                  'choose which ones appear in each hike\'s entries.',
                ),
              ],
            ),
            TextButton(
              onPressed: _showAddFieldDialog,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Icon(Icons.add, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_selectedFields.isEmpty)
          const Text('No custom fields added.', style: TextStyle(fontSize: 12, color: Colors.grey))
        else
          ..._selectedFields.map((field) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(field.name, style: _fieldTextStyle),
                        const SizedBox(width: 8),
                        Text(_getFieldTypeLabel(field.type), style: const TextStyle(fontSize: 12, color: Colors.grey)), // how to make drop
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _selectedFields.remove(field)),
                    child: Icon(Icons.close, size: 15, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          )),
      ],
    );
  }

  String _getFieldTypeLabel(CustomFieldType type) {
    switch (type) {
      case CustomFieldType.text: return 'Text';
      case CustomFieldType.number: return 'Number';
      case CustomFieldType.checkbox: return 'Checkbox';
      case CustomFieldType.rating: return 'Rating';
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
                title: Text(field.name, style: const TextStyle(fontSize: 13)),
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
              title: const Text('Create New Field', style: TextStyle(fontSize: 13)),
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