// screens/trip_form_screen.dart
// Form for creating or editing a trip

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../repositories/trip_repository.dart';
import '../models/custom_field.dart';
import '../repositories/custom_field_repository.dart';

class TripFormScreen extends StatefulWidget {
  final Trip? trip;  // null = creating new, not null = editing existing
  
  const TripFormScreen({Key? key, this.trip}) : super(key: key);

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TripRepository _tripRepository = TripRepository();
  
  // Form fields
  final _nameController = TextEditingController();
  final _startMileController = TextEditingController(text: '0.0');
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  TripStatus _status = TripStatus.active;
  final CustomFieldRepository _customFieldRepository = CustomFieldRepository();
  List<CustomField> _availableFields = [];  // All existing fields
  List<CustomField> _selectedFields = [];   // Fields selected for this trip
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCustomFields();
    
    // If editing existing trip, populate the form
    if (widget.trip != null) {
      final trip = widget.trip!;
      _nameController.text = trip.name;
      _startMileController.text = trip.startMile.toString();
      _startDate = trip.startDate;
      _endDate = trip.endDate;
      _status = trip.status;
      
      // Load custom fields for this trip
      _loadTripCustomFields();
    }
  }

  Future<void> _loadCustomFields() async {
    final fields = await _customFieldRepository.getAllCustomFields();
    setState(() {
      _availableFields = fields;
    });
  }

  Future<void> _loadTripCustomFields() async {
    if (widget.trip != null) {
      final fields = await _customFieldRepository.getCustomFieldsForTrip(widget.trip!.id!);
      setState(() {
        _selectedFields = fields;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startMileController.dispose();
    super.dispose();
  }

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      final trip = Trip(
        id: widget.trip?.id,
        name: _nameController.text.trim(),
        startDate: _startDate,
        startMile: double.tryParse(_startMileController.text) ?? 0.0,
        status: _status,
        endDate: _endDate,
      );

      Trip savedTrip;
        if (widget.trip == null) {
          // Creating new trip
          savedTrip = await _tripRepository.createTrip(trip);
        } else {
          // Updating existing trip
          await _tripRepository.updateTrip(trip);
          savedTrip = trip;
        }
      // Save custom fields for this trip
      if (_selectedFields.isNotEmpty) {
        await _customFieldRepository.setCustomFieldsForTrip(
          savedTrip.id!,
          _selectedFields,
        );
      }
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving hike: $e')),
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

  Future<void> _deleteTrip() async {
    // Show confirmation dialog
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
        if (mounted) {
          // Pop twice: once to close edit screen, once to close trip detail
          Navigator.pop(context, 'deleted');
        }
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
            // Trip Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g., PCT 2026, Weekend Backpack',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name for your hike';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Start Date
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
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (picked != null) {
                  setState(() {
                    _startDate = picked;
                  });
                }
              },
            ),
            
            const Divider(),
            
            // End Date (optional)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End Date (Optional)'),
              subtitle: Text(
                _endDate != null
                    ? DateFormat('MMM dd, yyyy').format(_endDate!)
                    : 'Not set',
                style: const TextStyle(fontSize: 16),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_endDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _endDate = null;
                        });
                      },
                    ),
                  const Icon(Icons.calendar_today),
                ],
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? DateTime.now(),
                  firstDate: _startDate,
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (picked != null) {
                  setState(() {
                    _endDate = picked;
                  });
                }
              },
            ),
            
            const Divider(),
            const SizedBox(height: 8),
            
            // Start Mile
            TextFormField(
              controller: _startMileController,
              decoration: const InputDecoration(
                labelText: 'Starting Mile Marker',
                hintText: '0.0',
                border: OutlineInputBorder(),
                helperText: 'Enter 0 if starting from the beginning',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a starting mile';
                }
                final num = double.tryParse(value);
                if (num == null || num < 0) {
                  return 'Please enter a valid number';
                }
                return null;
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
                DropdownMenuItem(
                  value: TripStatus.active,
                  child: Text('Active'),
                ),                
                DropdownMenuItem(
                  value: TripStatus.paused,
                  child: Text('Paused'),
                ),

                DropdownMenuItem(
                  value: TripStatus.completed,
                  child: Text('Completed'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _status = value;
                  });
                }
              },
            ),
            
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Custom Fields Section
            _buildCustomFieldsSection(),

            const SizedBox(height: 24),
            
            // Save Button
            FilledButton(
              onPressed: _isSaving ? null : _saveTrip,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        isEditing ? 'Update Hike' : 'Create Hike',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
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
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
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
                  onPressed: () {
                    setState(() {
                      _selectedFields.remove(field);
                    });
                  },
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
          setState(() {
            _selectedFields = fields;
          });
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
                hintText: 'e.g., Bear sightings, weather, ',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CustomFieldType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Field Type',
              ),
              items: CustomFieldType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getTypeLabel(type)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _showCreateNew = false;
              });
            },
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

    // Show existing fields to select from
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
              const Text('All existing fields added.')
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
              onTap: () {
                setState(() {
                  _showCreateNew = true;
                });
              },
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