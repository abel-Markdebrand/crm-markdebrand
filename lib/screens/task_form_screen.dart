import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mvp_odoo/services/project_service.dart';
import 'package:intl/intl.dart';

class TaskFormScreen extends StatefulWidget {
  final Map<String, dynamic> project;
  final Map<String, dynamic>? task;

  const TaskFormScreen({super.key, required this.project, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProjectService _projectService = ProjectService();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _plannedHoursController;

  List<Map<String, dynamic>> _selectedUsers = [];
  List<Map<String, dynamic>> _selectedTags = [];
  Map<String, dynamic>? _selectedMilestone;
  Map<String, dynamic>? _selectedStage;
  DateTime? _selectedDeadline;
  int _priority = 0; // 0, 1, 2, 3 (user asked for 3 stars)

  bool _isLoadingStages = true;
  List<Map<String, dynamic>> _stages = [];
  bool _isSaving = false;

  // Timer State

  String _stripHtmlTags(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').replaceAll('&nbsp;', ' ').trim();
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.task?['name'] is String ? widget.task!['name'] : '',
    );
    _descriptionController = TextEditingController(
      text: widget.task?['description'] is String
          ? _stripHtmlTags(widget.task!['description'])
          : '',
    );

    // Handle priority mapping
    final rawPriority = widget.task?['priority']?.toString() ?? '0';
    _priority = int.tryParse(rawPriority) ?? 0;
    if (_priority > 3) _priority = 3;

    // Handle planned/allocated hours
    double pours = 0.0;
    if (widget.task?['planned_hours'] is num) {
      pours = (widget.task!['planned_hours'] as num).toDouble();
    } else if (widget.task?['allocated_hours'] is num) {
      pours = (widget.task!['allocated_hours'] as num).toDouble();
    }

    _plannedHoursController = TextEditingController(
      text: pours > 0 ? pours.toStringAsFixed(2) : '',
    );

    // Load assignees safely from pre-injected ProjectService mapping
    // Load assignees safely from pre-injected ProjectService mapping
    if (widget.task?['user_ids'] is List) {
      final uIds = widget.task!['user_ids'] as List;
      final uNames = widget.task?['assignee_names'] is List
          ? widget.task!['assignee_names'] as List
          : [];

      for (int i = 0; i < uIds.length; i++) {
        if (uIds[i] is int) {
          String name = "Assigned ${uIds[i]}";
          if (i < uNames.length) {
            name = uNames[i].toString();
          } else if (uNames.isNotEmpty) {
            name = uNames.last.toString();
          }
          _selectedUsers.add({'id': uIds[i], 'name': name});
        }
      }
    }

    // Fallback for legacy mode or single user assignation:
    if (_selectedUsers.isEmpty &&
        widget.task?['user_id'] is List &&
        (widget.task!['user_id'] as List).isNotEmpty) {
      _selectedUsers.add({
        'id': widget.task!['user_id'][0],
        'name': widget.task!['user_id'][1],
      });
    }

    if (widget.task?['stage_id'] is List) {
      _selectedStage = {
        'id': widget.task!['stage_id'][0],
        'name': widget.task!['stage_id'][1],
      };
    }

    if (widget.task?['date_deadline'] != null &&
        widget.task?['date_deadline'] != false &&
        widget.task!['date_deadline'].toString().trim().isNotEmpty) {
      try {
        _selectedDeadline = DateTime.parse(
          widget.task!['date_deadline'].toString(),
        );
      } catch (_) {}
    }

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final stages = await _projectService.getProjectStages(widget.project['id']);

    List<Map<String, dynamic>> tags = [];
    if (widget.task?['tag_ids'] is List &&
        (widget.task!['tag_ids'] as List).isNotEmpty) {
      if ((widget.task!['tag_ids'] as List).first is int) {
        tags = await _projectService.getRecordsByIds(
          'project.tags',
          widget.task!['tag_ids'],
        );
      }
    }

    if (widget.task?['milestone_id'] is List &&
        (widget.task!['milestone_id'] as List).isNotEmpty) {
      _selectedMilestone = {
        'id': widget.task!['milestone_id'][0],
        'name': widget.task!['milestone_id'][1],
      };
    }

    List<Map<String, dynamic>> users = [];
    if (widget.task?['user_ids'] is List &&
        (widget.task!['user_ids'] as List).isNotEmpty) {
      if ((widget.task!['user_ids'] as List).first is int) {
        users = await _projectService.getRecordsByIds(
          'res.users',
          widget.task!['user_ids'],
        );
      }
    }

    if (mounted) {
      setState(() {
        _stages = stages;
        if (tags.isNotEmpty) _selectedTags = tags;
        if (users.isNotEmpty && _selectedUsers.isEmpty) _selectedUsers = users;
        _isLoadingStages = false;

        // Ensure the current selected stage is actually in the _stages list,
        // otherwise DropdownButton will crash
        if (_selectedStage != null) {
          final exists = _stages.any((s) => s['id'] == _selectedStage!['id']);
          if (!exists) {
            _stages.add(_selectedStage!);
          }
        } else if (_stages.isNotEmpty) {
          _selectedStage = _stages.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _plannedHoursController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // Odoo 17 uses allocated_hours, 14-16 uses planned_hours. Sending both or let service handle.
    final double phours = double.tryParse(_plannedHoursController.text) ?? 0.0;

    final data = {
      'name': _nameController.text,
      'description': _descriptionController.text,
      'project_id': widget.project['id'],
      'user_id': _selectedUsers.isNotEmpty ? _selectedUsers.first['id'] : false,
      'user_ids': _selectedUsers.isNotEmpty
          ? [
              [6, 0, _selectedUsers.map((u) => u['id']).toList()],
            ]
          : false,
      'stage_id': _selectedStage?['id'],
      'priority': _priority.toString(),
      'date_deadline': _selectedDeadline != null
          ? DateFormat('yyyy-MM-dd').format(_selectedDeadline!)
          : false,
      'planned_hours': phours,
      'allocated_hours': phours,
    };

    bool success = false;
    if (widget.task == null) {
      final id = await _projectService.createTask(data);
      success = id != null;
    } else {
      success = await _projectService.updateTask(widget.task!['id'], data);
    }

    if (success && mounted) {
      Navigator.pop(context, true);
    } else if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error saving task. Check permissions or required fields.',
          ),
        ),
      );
    }
  }

  Future<void> _selectUser() async {
    final Map<String, dynamic>? user = await showSearch<Map<String, dynamic>?>(
      context: context,
      delegate: OdooSearchDelegate(
        searchFn: _projectService.searchUsers,
        title: 'Assign to...',
      ),
    );
    if (user != null) {
      setState(() {
        if (!_selectedUsers.any((u) => u['id'] == user['id'])) {
          _selectedUsers.add(user);
        }
      });
    }
  }

  void _removeUser(Map<String, dynamic> userToRemove) {
    setState(() {
      _selectedUsers.removeWhere((u) => u['id'] == userToRemove['id']);
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDeadline = picked);
    }
  }

  Future<void> _selectTag() async {
    final Map<String, dynamic>? tag = await showSearch<Map<String, dynamic>?>(
      context: context,
      delegate: OdooSearchDelegate(
        searchFn: _projectService.searchTags,
        title: 'Add tag...',
      ),
    );
    if (tag != null) {
      setState(() {
        if (!_selectedTags.any((t) => t['id'] == tag['id'])) {
          _selectedTags.add(tag);
        }
      });
    }
  }

  void _removeTag(Map<String, dynamic> tagToRemove) {
    setState(() {
      _selectedTags.removeWhere((t) => t['id'] == tagToRemove['id']);
    });
  }

  Future<void> _selectMilestone() async {
    final Map<String, dynamic>? milestone =
        await showSearch<Map<String, dynamic>?>(
          context: context,
          delegate: OdooSearchDelegate(
            searchFn: (query) =>
                _projectService.searchMilestones(query, widget.project['id']),
            title: 'Assign milestone...',
          ),
        );
    if (milestone != null) {
      setState(() => _selectedMilestone = milestone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isEditing ? "Edit Task" : "New Task",
          style: GoogleFonts.inter(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                "Save",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ),
        ],
      ),
      body: _isLoadingStages
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildSectionTitle("Task Details"),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _nameController,
                    label: "Task Title",
                    placeholder: "e.g., Review documentation",
                    validator: (v) =>
                        v == null || v.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _plannedHoursController,
                    label: "Allocated Time (Hours)",
                    placeholder: "0.00",
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle("Assignment & Status"),
                  const SizedBox(height: 16),
                  _buildMultiSelector(
                    label: "Assigned to",
                    values: _selectedUsers,
                    onTapAdd: _selectUser,
                    onRemove: _removeUser,
                    icon: Icons.person_add_alt_1_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildSelector(
                    label: "Milestone",
                    value: _selectedMilestone?['name'] ?? "Not assigned",
                    onTap: _selectMilestone,
                    icon: Icons.flag_circle_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    label: "Stage / Status",
                    value: _stages.any((s) => s['id'] == _selectedStage?['id'])
                        ? _selectedStage!['id']
                        : (_stages.isNotEmpty ? _stages.first['id'] : null),
                    items: _stages
                        .fold<List<Map<String, dynamic>>>([], (list, item) {
                          if (!list.any((x) => x['id'] == item['id'])) {
                            list.add(item);
                          }
                          return list;
                        })
                        .map<MapEntry<String, String>>(
                          (s) => MapEntry<String, String>(
                            s['id']?.toString() ?? '',
                            s['name']?.toString() ?? '',
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      final stage = _stages.firstWhere(
                        (s) => s['id'].toString() == v,
                      );
                      setState(() => _selectedStage = stage);
                    },
                    icon: Icons.flag_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildMultiSelector(
                    label: "Tags",
                    values: _selectedTags,
                    onTapAdd: _selectTag,
                    onRemove: _removeTag,
                    icon: Icons.local_offer_rounded,
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle("Priority & Date"),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSelector(
                          label: "Deadline",
                          value: _selectedDeadline != null
                              ? DateFormat(
                                  'dd/MM/yyyy',
                                ).format(_selectedDeadline!)
                              : "No date",
                          onTap: _selectDate,
                          icon: Icons.calendar_today_rounded,
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildPriorityStars(),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle("Notes"),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _descriptionController,
                    label: "Description",
                    placeholder: "Add notes or task details...",
                    maxLines: 5,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPriorityStars() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Priority",
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(3, (index) {
            return GestureDetector(
              onTap: () => setState(() => _priority = index + 1),
              child: Icon(
                index < _priority
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: index < _priority
                    ? Colors.amber[600]
                    : const Color(0xFF94A3B8),
                size: 28,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF94A3B8),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? placeholder,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelector({
    required String label,
    required String value,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF64748B)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color:
                          value.contains("Select") ||
                              value.contains("Assigned")
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFFCBD5E1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSelector({
    required String label,
    required List<Map<String, dynamic>> values,
    required VoidCallback onTapAdd,
    required Function(Map<String, dynamic>) onRemove,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
            TextButton.icon(
              onPressed: onTapAdd,
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: Text("Add", style: GoogleFonts.inter(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (values.isEmpty)
          InkWell(
            onTap: onTapAdd,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: const Color(0xFF64748B)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Not assigned",
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values
                .map(
                  (u) => Chip(
                    label: Text(
                      u['name'],
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    avatar: const Icon(
                      Icons.person,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    deleteIcon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    onDeleted: () => onRemove(u),
                    backgroundColor: const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: BorderSide.none,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required dynamic value,
    required List<MapEntry<String, String>> items,
    required void Function(String?) onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value?.toString(),
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFFCBD5E1),
              ),
              onChanged: onChanged,
              items: items.map((e) {
                return DropdownMenuItem<String>(
                  value: e.key,
                  child: Text(
                    e.value,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class OdooSearchDelegate extends SearchDelegate<Map<String, dynamic>?> {
  final Future<List<Map<String, dynamic>>> Function(String) searchFn;
  final String title;

  OdooSearchDelegate({required this.searchFn, required this.title});

  @override
  String? get searchFieldLabel => title;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.length < 2) {
      return Center(
        child: Text(
          "Escribe al menos 2 letras para buscar",
          style: GoogleFonts.inter(color: Colors.grey),
        ),
      );
    }
    return _buildList();
  }

  Widget _buildList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: searchFn(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No se encontraron resultados"));
        }
        return ListView.separated(
          itemCount: snapshot.data!.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
          itemBuilder: (context, index) {
            final item = snapshot.data![index];
            return ListTile(
              title: Text(
                item['name'] ?? '',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
              onTap: () => close(context, item),
            );
          },
        );
      },
    );
  }
}
