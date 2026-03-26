import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mvp_odoo/services/timesheet_service.dart';

class TimesheetEntryDialog extends StatefulWidget {
  final Map<String, dynamic>? initialEntry;

  const TimesheetEntryDialog({super.key, this.initialEntry});

  @override
  State<TimesheetEntryDialog> createState() => _TimesheetEntryDialogState();
}

class _TimesheetEntryDialogState extends State<TimesheetEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _hoursController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  int? _selectedProjectId;
  int? _selectedTaskId;

  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEntry != null) {
      _descriptionController.text = widget.initialEntry!['name'] ?? '';
      _hoursController.text = (widget.initialEntry!['unit_amount'] ?? 0.0)
          .toString();
      _selectedDate = DateTime.parse(widget.initialEntry!['date']);
      // Project and Task IDs will be set after fetching lists to ensure validity
    }
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    try {
      final projects = await TimesheetService().getProjects();
      if (mounted) {
        setState(() {
          _projects = projects;
          if (widget.initialEntry != null) {
            // Handle Odoo's [id, name] format or just ID
            final initialProj = widget.initialEntry!['project_id'];
            if (initialProj is List && initialProj.isNotEmpty) {
              _selectedProjectId = initialProj[0];
            } else if (initialProj is int) {
              _selectedProjectId = initialProj;
            }
          }
        });
        if (_selectedProjectId != null) {
          _loadTasks(_selectedProjectId!);
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading projects: $e')));
      }
    }
  }

  Future<void> _loadTasks(int projectId) async {
    // Don't set loading true here to avoid full screen flicker, just task dropdown
    try {
      final tasks = await TimesheetService().getTasks(projectId);
      if (mounted) {
        setState(() {
          _tasks = tasks;
          if (widget.initialEntry != null && _selectedTaskId == null) {
            final initialTask = widget.initialEntry!['task_id'];
            if (initialTask is List && initialTask.isNotEmpty) {
              _selectedTaskId = initialTask[0];
            } else if (initialTask is int) {
              _selectedTaskId = initialTask;
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error loading tasks: $e");
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF007AFF),
              onPrimary: Colors.white,
              onSurface: Color(0xFF112038),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a project')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final double hours = double.parse(_hoursController.text);
      final String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      if (widget.initialEntry == null) {
        // Create
        await TimesheetService().createTimesheet(
          projectId: _selectedProjectId!,
          hours: hours,
          date: dateStr,
          description: _descriptionController.text,
          taskId: _selectedTaskId,
        );
      } else {
        // Update
        await TimesheetService().updateTimesheet(
          id: widget.initialEntry!['id'],
          projectId: _selectedProjectId,
          hours: hours,
          date: dateStr,
          description: _descriptionController.text,
          taskId: _selectedTaskId,
        );
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success/refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving entry: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialEntry != null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? 'Edit Entry' : 'New Entry',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF112038),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Project Dropdown
            DropdownButtonFormField<int>(
              initialValue: _projects.any((p) => p['id'] == _selectedProjectId)
                  ? _selectedProjectId
                  : null,
              decoration: _inputDecoration('Project'),
              items: _projects
                  .fold<List<Map<String, dynamic>>>([], (list, item) {
                    if (!list.any((x) => x['id'] == item['id'])) list.add(item);
                    return list;
                  })
                  .map((p) {
                    return DropdownMenuItem<int>(
                      value: p['id'],
                      child: Text(p['name'] ?? 'Unknown Project'),
                    );
                  })
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProjectId = value;
                  _selectedTaskId = null;
                  _tasks = [];
                });
                if (value != null) _loadTasks(value);
              },
              validator: (val) => val == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Task Dropdown
            DropdownButtonFormField<int>(
              initialValue: _tasks.any((t) => t['id'] == _selectedTaskId)
                  ? _selectedTaskId
                  : null,
              decoration: _inputDecoration('Task (Optional)'),
              items: _tasks
                  .fold<List<Map<String, dynamic>>>([], (list, item) {
                    if (!list.any((x) => x['id'] == item['id'])) list.add(item);
                    return list;
                  })
                  .map((t) {
                    return DropdownMenuItem<int>(
                      value: t['id'],
                      child: Text(t['name'] ?? 'Unknown Task'),
                    );
                  })
                  .toList(),
              onChanged: (value) => setState(() => _selectedTaskId = value),
            ),
            const SizedBox(height: 16),

            // Date Picker
            InkWell(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: _inputDecoration('Date'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMM dd, yyyy').format(_selectedDate),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Hours Input
            TextFormField(
              controller: _hoursController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _inputDecoration('Hours (e.g., 1.5)'),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Required';
                if (double.tryParse(val) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description Input
            TextFormField(
              controller: _descriptionController,
              decoration: _inputDecoration('Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveEntry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Save Entry',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
            // Add bottom padding for keyboard if needed, though scrollable modal is better handled by parent
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF007AFF)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _hoursController.dispose();
    super.dispose();
  }
}
