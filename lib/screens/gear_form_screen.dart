// screens/gear_form_screen.dart
// Form for creating or editing gear

import 'package:flutter/material.dart';
import '../models/gear.dart';
import '../repositories/gear_repository.dart';
import 'gear_entry_assign_screen.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class GearFormScreen extends StatefulWidget {
  final Gear? gear;
  
  const GearFormScreen({Key? key, this.gear}) : super(key: key);

  @override
  State<GearFormScreen> createState() => _GearFormScreenState();
}

class _GearFormScreenState extends State<GearFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final GearRepository _gearRepository = GearRepository();
  static const _labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
  static const _fieldTextStyle = TextStyle(fontSize: 13);
  
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isRetired = false;
  DateTime? _lastUsedDate;
  bool _isLoadingLastUse = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.gear != null) {
      _nameController.text = widget.gear!.name;
      _categoryController.text = widget.gear!.category ?? '';
      _startDate = widget.gear!.startDate;
      _endDate = widget.gear!.endDate;
      _isRetired = widget.gear!.endDate != null;
      _loadLastUsedDate();
    }
  }

  Future<void> _loadLastUsedDate() async {
    if (widget.gear?.id == null) return;
    setState(() => _isLoadingLastUse = true);
    final lastDate = await _gearRepository.getLastUsedDate(widget.gear!.id!);
    setState(() {
      _lastUsedDate = lastDate;
      _isLoadingLastUse = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _saveGear() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isRetired && _endDate != null && _lastUsedDate != null) {
      if (_endDate!.isBefore(_lastUsedDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot retire gear before last use (${DateFormat('MMM dd, yyyy').format(_lastUsedDate!)})',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    setState(() => _isSaving = true);
    
    try {
      final gear = Gear(
        id: widget.gear?.id,
        name: _nameController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        startDate: _startDate,
        endDate: _isRetired ? _endDate ?? DateTime.now() : null,
      );
      
      if (widget.gear == null) {
        await _gearRepository.createGear(gear);
      } else {
        await _gearRepository.updateGear(gear);
      }
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving gear: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteGear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Gear'),
        content: const Text(
          'Are you sure you want to delete this gear item? This cannot be undone.',
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
        await _gearRepository.deleteGear(widget.gear!.id!);
        if (mounted) Navigator.pop(context, 'deleted');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting gear: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.gear != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Gear' : 'Add Gear'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              style: _fieldTextStyle,
              decoration: const InputDecoration(
                labelText: 'Gear Name',
                labelStyle: _labelStyle,
                hintText: 'e.g., Altra Lone Peaks, Big Agnes Tent',
                hintStyle: TextStyle(fontSize: 12),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Please enter a name';
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _categoryController,
              style: _fieldTextStyle,
              decoration: const InputDecoration(
                labelText: 'Category (Optional)',
                labelStyle: _labelStyle,
                hintText: 'e.g., Footwear, Shelter, Pack',
                hintStyle: TextStyle(fontSize: 12),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            
            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start Date', style: _labelStyle),
              subtitle: Text(
                DateFormat('MMM dd, yyyy').format(_startDate),
                style: _fieldTextStyle,
              ),
              trailing: Icon(PhosphorIcons.calendarBlank()),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
            ),

            const Divider(),

            Row(
              children: [
                const Text('Status:', style: _labelStyle),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: const Text('Active', style: TextStyle(fontSize: 13)),
                  selected: !_isRetired,
                  onSelected: (selected) {
                    setState(() {
                      _isRetired = false;
                      _endDate = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Retired', style: TextStyle(fontSize: 13)),
                  selected: _isRetired,
                  onSelected: (selected) {
                    setState(() {
                      _isRetired = true;
                      _endDate = _endDate ?? DateTime.now();
                    });
                  },
                ),
              ],
            ),

            if (_isRetired) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End Date', style: _labelStyle),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _endDate != null
                          ? DateFormat('MMM dd, yyyy').format(_endDate!)
                          : 'Not set',
                      style: _fieldTextStyle,
                    ),
                    if (_isLoadingLastUse)
                      const Text('Loading last use', style: TextStyle(fontSize: 12, color: Colors.grey))
                    else if (_lastUsedDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Last used: ${DateFormat('MMM dd, yyyy').format(_lastUsedDate!)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                  ],
                ),
                trailing: Icon(PhosphorIcons.calendarBlank()),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? (_lastUsedDate ?? DateTime.now()),
                    firstDate: _lastUsedDate ?? _startDate,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    helpText: _lastUsedDate != null ? 'Must be on or after last use' : null,
                  );
                  if (picked != null) setState(() => _endDate = picked);
                },
              ),
            ],

            const Divider(),
            const SizedBox(height: 16),

            // ── Assign to Entries (editing only) ──────────────────────
            if (isEditing) ...[
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GearEntryAssignScreen(gear: widget.gear!),
                    ),
                  );
                },
                icon: Icon(PhosphorIcons.checkSquare()),
                label: const Text('Assign to Entries', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(height: 12),
            ],
            
            if (isEditing)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _deleteGear,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Delete Gear', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _saveGear,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Gear', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              )
            else
              FilledButton(
                onPressed: _isSaving ? null : _saveGear,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add Gear', style: TextStyle(fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }
}