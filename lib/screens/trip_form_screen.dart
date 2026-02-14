// screens/trip_form_screen.dart
// Form for creating or editing a trip

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../repositories/trip_repository.dart';

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
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    
    // If editing existing trip, populate the form
    if (widget.trip != null) {
      final trip = widget.trip!;
      _nameController.text = trip.name;
      _startMileController.text = trip.startMile.toString();
      _startDate = trip.startDate;
      _endDate = trip.endDate;
      _status = trip.status;
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
        id: widget.trip?.id,  // Keep ID if editing, null if creating
        name: _nameController.text.trim(),
        startDate: _startDate,
        startMile: double.tryParse(_startMileController.text) ?? 0.0,
        status: _status,
        endDate: _endDate,
      );
      
      if (widget.trip == null) {
        // Creating new trip
        await _tripRepository.createTrip(trip);
      } else {
        // Updating existing trip
        await _tripRepository.updateTrip(trip);
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
                  value: TripStatus.planning,
                  child: Text('Planning'),
                ),
                DropdownMenuItem(
                  value: TripStatus.active,
                  child: Text('Active'),
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
}