import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mvp_odoo/services/project_service.dart';
import 'package:mvp_odoo/screens/project_form_screen.dart';
import 'package:mvp_odoo/screens/project_task_list_screen.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  final ProjectService _projectService = ProjectService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'Todos';
  List<String> _availableTags = ['Todos'];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    final projects = await _projectService.getProjects();
    if (mounted) {
      // Extraer etiquetas únicas
      final Set<String> tags = {'Todos'};
      for (var project in projects) {
        if (project['tag_ids'] is List) {
          for (var tag in project['tag_ids']) {
            if (tag is List && tag.length > 1) {
              tags.add(tag[1].toString());
            } else if (tag is String) {
              tags.add(tag);
            }
          }
        }
      }

      setState(() {
        _projects = projects;
        _availableTags = tags.toList()..sort();
        // Asegurarse de que el filtro seleccionado sigue siendo válido
        if (!_availableTags.contains(_selectedFilter)) {
          _selectedFilter = 'Todos';
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openProjectForm([Map<String, dynamic>? project]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectFormScreen(project: project),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      _loadProjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/image/logo_mdb.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "Proyectos",
              style: GoogleFonts.inter(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            onPressed: _loadProjects,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openProjectForm(),
        backgroundColor: const Color(0xFF2563EB),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            )
          : _projects.isEmpty
          ? _buildEmptyState()
          : _buildProjectList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No se encontraron proyectos",
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectList() {
    List<Map<String, dynamic>> filteredProjects = _projects;

    // Filter by Search Query (Name or Tags)
    if (_searchQuery.isNotEmpty) {
      filteredProjects = filteredProjects.where((project) {
        final name = (project['name'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();

        bool matchesTags = false;
        if (project['tag_ids'] is List) {
          for (var tag in project['tag_ids']) {
            String tagName = '';
            if (tag is List && tag.length > 1) {
              tagName = tag[1].toString().toLowerCase();
            } else if (tag is String) {
              tagName = tag.toLowerCase();
            }
            if (tagName.contains(query)) {
              matchesTags = true;
              break;
            }
          }
        }

        return name.contains(query) || matchesTags;
      }).toList();
    }

    // Filter by Selected Tag
    if (_selectedFilter != 'Todos') {
      filteredProjects = filteredProjects.where((project) {
        // En Odoo los tags suelen venir en 'tag_ids'
        // pero dado que no estamos trayendo 'tag_ids' en _loadProjects()
        // necesitamos modificar project_service.dart también.
        // Asumo que agregaremos 'tag_ids' allá de inmediato.
        if (project['tag_ids'] == null || project['tag_ids'] is! List) {
          return false;
        }
        final tags = project['tag_ids'] as List;
        for (var tag in tags) {
          if (tag is List && tag.length > 1) {
            final tagName = tag[1].toString().toLowerCase().trim();
            final filterName = _selectedFilter.toLowerCase().trim();
            if (tagName == filterName) {
              return true;
            }
          } else if (tag is String) {
            // Just in case it comes as a string list directly
            if (tag.toLowerCase().trim() ==
                _selectedFilter.toLowerCase().trim()) {
              return true;
            }
          }
        }
        return false;
      }).toList();
    }

    return Column(
      children: [
        _buildSearchBar(),
        _buildFilterBar(),
        Expanded(
          child: filteredProjects.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filteredProjects.length,
                  itemBuilder: (context, index) {
                    final project = filteredProjects[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProjectTaskListScreen(project: project),
                          ),
                        ).then((_) => _loadProjects());
                      },
                      child: _buildProjectCard(project),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: "Buscar proyectos o etiquetas...",
            hintStyle: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedFilter,
            icon: const Icon(
              Icons.filter_list_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            style: GoogleFonts.inter(
              color: const Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedFilter = newValue;
                });
              }
            },
            items: _availableTags.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final name = project['name'] ?? 'Proyecto sin nombre';
    final taskCount = project['task_count'] ?? 0;
    final partnerName = project['partner_id'] is List
        ? project['partner_id'][1]
        : 'Sin cliente';
    final managerName = project['user_id'] is List
        ? project['user_id'][1]
        : 'Sin responsable';
    String dateStart = project['date_start']?.toString() ?? '';
    if (dateStart == 'false') dateStart = '';
    String dateEnd = project['date']?.toString() ?? '';
    if (dateEnd == 'false') dateEnd = '';
    final labelTasks = project['label_tasks'] ?? 'Tareas';
    final colorIndex = project['color'] is int ? project['color'] : 0;

    // Extraer la primera etiqueta (tag) para mostrarla visualmente como el "estado"
    String? displayTag;
    if (project['tag_ids'] is List && (project['tag_ids'] as List).isNotEmpty) {
      final firstTag = (project['tag_ids'] as List).first;
      if (firstTag is List && firstTag.length > 1) {
        displayTag = firstTag[1].toString();
      } else if (firstTag is String) {
        displayTag = firstTag;
      }
    }

    // Odoo colors mapping (simplified)
    final List<Color> odooColors = [
      Colors.transparent,
      const Color(0xFFF87171), // Red
      const Color(0xFFFB923C), // Orange
      const Color(0xFFFBBF24), // Yellow
      const Color(0xFF34D399), // Green
      const Color(0xFF60A5FA), // Blue
      const Color(0xFF818CF8), // Indigo
      const Color(0xFFA78BFA), // Purple
      const Color(0xFFF472B6), // Pink
      const Color(0xFF94A3B8), // Slate
    ];

    final accentColor = colorIndex > 0 && colorIndex < odooColors.length
        ? odooColors[colorIndex]
        : const Color(0xFF2563EB);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: accentColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (displayTag != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                displayTag,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "$taskCount $labelTasks",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.business_rounded,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              partnerName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              managerName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (dateStart.isNotEmpty || dateEnd.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                [
                                  if (dateStart.isNotEmpty)
                                    'Inicio: $dateStart',
                                  if (dateEnd.isNotEmpty) 'Fin: $dateEnd',
                                ].join(' - '),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFCBD5E1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
