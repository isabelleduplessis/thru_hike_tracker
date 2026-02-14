// screens/gear_form_screen.dart
// Form for creating or editing gear

import 'package:flutter/material.dart';
import '../models/gear.dart';
import '../repositories/gear_repository.dart';

class GearFormScreen extends StatefulWidget {
  final Gear? gear;  // null = creating new, not null = editing
  
  const GearFormScreen({Key? key, this.gear}) : super(key: key);

  @override
  State<GearFormScreen> createState() => _GearFormScreenState();
}

class _GearFormScreenState extends State<GearFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final GearRepository _gearRepository = GearRepository();
  
  // Controllers for text inputs
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    
    // If editing existing gear, populate the form
    if (widget.gear != null) {
      _nameController.text = widget.gear!.name;
      _categoryController.text = widget.gear!.category ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _saveGear() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      final gear = Gear(
        id: widget.gear?.id,
        name: _nameController.text.trim(),
        category: _categoryController.text.trim().isEmpty 
            ? null 
            : _categoryController.text.trim(),
      );
      
      if (widget.gear == null) {
        await _gearRepository.createGear(gear);
      } else {
        await _gearRepository.updateGear(gear);
      }
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving gear: $e')),
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
        if (mounted) {
          Navigator.pop(context, 'deleted');
        }
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
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
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
            
            const SizedBox(height: 24),
            
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