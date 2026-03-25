// screens/gear_form_screen.dart
// Form for creating or editing gear

import 'package:flutter/material.dart';
import '../models/gear.dart';
import '../repositories/gear_repository.dart';
import 'gear_entry_assign_screen.dart';
import 'package:intl/intl.dart';

class GearFormScreen extends StatefulWidget {
  final Gear? gear;
  
  const GearFormScreen({Key? key, this.gear}) : super(key: key);

  @override
  State<GearFormScreen> createState() => _GearFormScreenState();
}

class _GearFormScreenState extends State<GearFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final GearRepository _gearRepository = GearRepository();
  
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
        actions: isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteGear,
                  tooltip: 'Delete Gear',
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
                labelText: 'Gear Name',
                hintText: 'e.g., Altra Lone Peaks, Big Agnes Tent',
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
              decoration: const InputDecoration(
                labelText: 'Category (Optional)',
                hintText: 'e.g., Footwear, Shelter, Pack',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            
            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start Date'),
              subtitle: Text(
                DateFormat('MMM dd, yyyy').format(_startDate),
                style: const TextStyle(fontSize: 16),
              ),
              trailing: const Icon(Icons.calendar_today),
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
                const Text('Status:', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: const Text('Active'),
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
                  label: const Text('Retired'),
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
                title: const Text('End Date'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _endDate != null
                          ? DateFormat('MMM dd, yyyy').format(_endDate!)
                          : 'Not set',
                      style: const TextStyle(fontSize: 16),
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
                trailing: const Icon(Icons.calendar_today),
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
                icon: const Icon(Icons.checklist),
                label: const Text('Assign to Entries'),
              ),
              const SizedBox(height: 12),
            ],
            
            FilledButton(
              onPressed: _isSaving ? null : _saveGear,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        isEditing ? 'Update Gear' : 'Add Gear',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}