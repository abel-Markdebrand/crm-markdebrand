import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mvp_odoo/services/project_service.dart';
import 'package:mvp_odoo/screens/project_form_screen.dart';
import 'package:mvp_odoo/screens/task_form_screen.dart';
import 'package:intl/intl.dart';

class ProjectTaskListScreen extends StatefulWidget {
  final Map<String, dynamic> project;

  const ProjectTaskListScreen({super.key, required this.project});

  @override
  State<ProjectTaskListScreen> createState() => _ProjectTaskListScreenState();
}

class _ProjectTaskListScreenState extends State<ProjectTaskListScreen> {
  final ProjectService _projectService = ProjectService();
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _stages = [];
  bool _isLoading = true;
  int? _selectedStageId; // null = Todas

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _projectService.getTasks(widget.project['id']),
        _projectService.getProjectStages(widget.project['id']),
      ]);

      if (mounted) {
        setState(() {
          _tasks = results[0];
          _stages = results[1];
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint("Error in _loadData: $e\n$stackTrace");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openTaskForm([Map<String, dynamic>? task]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TaskFormScreen(project: widget.project, task: task),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _editProject() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectFormScreen(project: widget.project),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.project['name'] ?? "Tasks",
              style: GoogleFonts.inter(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              "List by Stages",
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB)),
            onPressed: _editProject,
            tooltip: "Edit Project",
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            onPressed: _loadData,
          ),
        ],
        bottom: _isLoading || (_tasks.isEmpty && _stages.isEmpty)
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: _buildStageTabs(),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskForm(
          _selectedStageId != null && _selectedStageId != 0
              ? {
                  'stage_id': [
                    _selectedStageId,
                    _stages.firstWhere(
                      (s) => s['id'] == _selectedStageId,
                      orElse: () => {'name': 'Stage'},
                    )['name'],
                  ],
                }
              : null,
        ),
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add_task_rounded, color: Colors.white),
        label: Text(
          "Task",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _tasks.isEmpty && _stages.isEmpty
                  ? _buildEmptyState()
                  : _buildTaskTabView(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            "No tasks found",
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text("Retry Load"),
          ),
        ],
      ),
    );
  }

  Widget _buildStageTabs() {
    final Set<int> taskStageIds = _tasks
        .map((e) => e['stage_id'] is List ? e['stage_id'][0] : 0)
        .toSet()
        .cast<int>();
    final List<Map<String, dynamic>> allAvailableStages = List.from(_stages);
    for (var sid in taskStageIds) {
      if (!allAvailableStages.any((s) => s['id'] == sid)) {
        final taskWithStage = _tasks.firstWhere(
          (t) => (t['stage_id'] is List ? t['stage_id'][0] : 0) == sid,
          orElse: () => {},
        );
        if (taskWithStage.isNotEmpty) {
          allAvailableStages.add({
            'id': sid,
            'name': taskWithStage['stage_id'] is List
                ? taskWithStage['stage_id'][1]
                : 'No Stage',
          });
        }
      }
    }
    allAvailableStages.sort(
      (a, b) => (a['sequence'] ?? 0).compareTo(b['sequence'] ?? 0),
    );

    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildTabChip(null, "All"),
          ...allAvailableStages.map((s) => _buildTabChip(s['id'], s['name'])),
        ],
      ),
    );
  }

  Widget _buildTabChip(int? id, String name) {
    bool isSelected = _selectedStageId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          name,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedStageId = id);
        },
        selectedColor: const Color(0xFF2563EB),
        backgroundColor: const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildTaskTabView() {
    List<Map<String, dynamic>> filteredTasks = _tasks;
    if (_selectedStageId != null) {
      filteredTasks = _tasks.where((t) {
        final sid = t['stage_id'] is List ? t['stage_id'][0] : 0;
        return sid == _selectedStageId;
      }).toList();
    }

    if (filteredTasks.isEmpty) {
      return Center(
        child: Text(
          "No tasks in this stage",
          style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        mainAxisExtent: 170, // Fixed height specifically for grid layout
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) => _buildTaskCard(filteredTasks[index]),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final String name = task['name'] is String
        ? task['name']
        : 'Unnamed Task';
    final List<String> assigneeNames = task['assignee_names'] is List
        ? List<String>.from(task['assignee_names'])
        : [];

    final String? assignedTo = assigneeNames.isNotEmpty
        ? assigneeNames.join(", ")
        : null;
    final String? deadline = task['date_deadline'] is String
        ? task['date_deadline']
        : null;
    final int priority = (task['priority'] is String || task['priority'] is int)
        ? int.tryParse(task['priority'].toString()) ?? 0
        : 0;

    final double planned = (task['planned_hours'] is num)
        ? (task['planned_hours'] as num).toDouble()
        : (task['allocated_hours'] is num)
        ? (task['allocated_hours'] as num).toDouble()
        : 0.0;

    final double effective = (task['effective_hours'] is num)
        ? (task['effective_hours'] as num).toDouble()
        : 0.0;

    final List<dynamic> tags = task['tag_ids'] is List ? task['tag_ids'] : [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openTaskForm(task),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildPriorityStars(priority),
                        ],
                      ),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: tags
                                .take(2)
                                .map(
                                  (t) => Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "Tag #$t",
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (assignedTo != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 12,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 80),
                          child: Text(
                            assignedTo,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (planned > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 12,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${effective.toStringAsFixed(1)}/${planned.toStringAsFixed(1)}h",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: effective > planned
                                ? Colors.orange[700]
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  if (deadline != null && _isValidDate(deadline))
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd MMM').format(DateTime.parse(deadline)),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _isOverdue(deadline)
                                ? Colors.red[400]
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.bottomRight,
                child: _buildKanbanStateIndicator(task['kanban_state']),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityStars(int priority) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Icon(
          index < priority ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 18,
          color: index < priority ? Colors.amber[600] : const Color(0xFFCBD5E1),
        );
      }),
    );
  }

  bool _isValidDate(String deadline) {
    try {
      DateTime.parse(deadline);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isOverdue(String deadline) {
    try {
      final date = DateTime.parse(deadline);
      return date.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  Widget _buildKanbanStateIndicator(String? state) {
    Color color;
    switch (state) {
      case 'done':
        color = const Color(0xFF10B981);
        break;
      case 'blocked':
        color = const Color(0xFFEF4444);
        break;
      default:
        color = const Color(0xFFCBD5E1);
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
