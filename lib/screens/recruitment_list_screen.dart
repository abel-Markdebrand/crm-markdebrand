import 'package:flutter/material.dart';

import '../models/recruitment_models.dart';
import '../services/recruitment_service.dart';
import 'recruitment_form_screen.dart';

import '../models/hr_models.dart';

class RecruitmentListScreen extends StatefulWidget {
  final JobPosition? jobPosition;
  const RecruitmentListScreen({super.key, this.jobPosition});

  @override
  State<RecruitmentListScreen> createState() => _RecruitmentListScreenState();
}

class _RecruitmentListScreenState extends State<RecruitmentListScreen> {
  final RecruitmentService _recruitmentService = RecruitmentService();
  bool _isLoading = true;
  List<RecruitmentStage> _stages = [];
  Map<int, List<Applicant>> _applicantsByStage = {};
  String? _error;

  final PageController _pageController = PageController(viewportFraction: 0.88);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final domain = widget.jobPosition != null
          ? [
              ['job_id', '=', widget.jobPosition!.id],
            ]
          : null;

      final futures = await Future.wait([
        _recruitmentService.getStages(jobId: widget.jobPosition?.id),
        _recruitmentService.getApplicants(domain: domain),
      ]);

      final stages = futures[0] as List<RecruitmentStage>;
      final applicants = futures[1] as List<Applicant>;

      debugPrint('Stages fetched: ${stages.length}');
      debugPrint('Applicants fetched: ${applicants.length}');

      // Group applicants by stage
      Map<int, List<Applicant>> byStage = {};

      // Initialize with fetched stages
      for (var s in stages) {
        byStage[s.id] = [];
      }

      List<Applicant> withoutStage = [];
      for (var applicant in applicants) {
        final sid = applicant.stageId;
        if (sid != null) {
          // ensure the stage exists in our grouping map
          if (!byStage.containsKey(sid)) {
            byStage[sid] = [];
          }
          byStage[sid]!.add(applicant);
        } else {
          withoutStage.add(applicant);
        }
      }

      // Build full stage list: Start with Odoo stages, then add dynamic ones
      List<RecruitmentStage> allStages = List.from(stages);

      // Add dynamic stages from applicants that weren't in the global stage list
      for (var applicant in applicants) {
        final sid = applicant.stageId;
        if (sid != null && !allStages.any((s) => s.id == sid)) {
          allStages.add(
            RecruitmentStage(
              id: sid,
              name: applicant.stageName ?? 'Etapa $sid',
            ),
          );
        }
      }

      // Add a fallback bucket for applicants with no stage
      const noStageId = -1;
      if (withoutStage.isNotEmpty) {
        if (!allStages.any((s) => s.id == noStageId)) {
          allStages.add(RecruitmentStage(id: noStageId, name: 'Sin Etapa'));
        }
        byStage[noStageId] = withoutStage;
      }

      debugPrint('Final grouped stages count: ${allStages.length}');

      if (mounted) {
        setState(() {
          _stages = allStages;
          _applicantsByStage = byStage;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Error al cargar datos: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      appBar: AppBar(
        title: Text(
          widget.jobPosition?.name ?? "Reclutamiento",
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontFamily: 'CenturyGothic',
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: _fetchData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontFamily: 'Nexa',
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _fetchData,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _stages.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.view_kanban_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No hay etapas configuradas en Odoo",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontFamily: 'Nexa',
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _buildStageIndicators(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _stages.length,
                    itemBuilder: (context, index) {
                      return _buildStageColumn(_stages[index]);
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF007AFF), // Markdebrand Blue
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RecruitmentFormScreen(),
            ),
          ).then((value) {
            if (value == true) _fetchData();
          });
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStageIndicators() {
    return Container(
      height: 40,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _stages.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final isSelected = _currentPage == index;
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE2E8F0) // Slate 200 (Light Gray)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _stages[index].name,
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12,
                    fontFamily: 'Nexa',
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStageColumn(RecruitmentStage stage) {
    final applicants = _applicantsByStage[stage.id] ?? [];

    return Container(
      margin: const EdgeInsets.only(right: 16, top: 16, bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    stage.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      fontFamily: 'CenturyGothic',
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${applicants.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                      fontFamily: 'Nexa',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List of applicants
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: applicants.length,
                itemBuilder: (context, index) {
                  return _buildApplicantCard(applicants[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorFromInt(int? colorIndex) {
    if (colorIndex == null || colorIndex == 0) return Colors.transparent;
    // Odoo standard colors map roughly to this list (1-11)
    const List<Color> odooColors = [
      Colors.transparent, // 0
      Color(0xFFEF4444), // 1: Red
      Color(0xFFF97316), // 2: Orange
      Color(0xFFEAB308), // 3: Yellow
      Color(0xFF007AFF), // 4: Markdebrand Blue
      Color(0xFF991B1B), // 5: Dark Red
      Color(0xFF10B981), // 6: Green
      Color(0xFF0F766E), // 7: Teal
      Color(0xFF06B6D4), // 8: Cyan
      Color(0xFF8B5CF6), // 9: Purple
      Color(0xFFEC4899), // 10: Pink
      Color(0xFF14B8A6), // 11: Light Teal
    ];
    if (colorIndex > 0 && colorIndex < odooColors.length) {
      return odooColors[colorIndex];
    }
    return Colors.grey.shade400; // Default
  }

  Widget _buildApplicantCard(Applicant applicant) {
    final hasColor = applicant.color != null && applicant.color! > 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecruitmentFormScreen(applicant: applicant),
          ),
        ).then((value) {
          if (value == true) _fetchData();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: hasColor
              ? Border(
                  left: BorderSide(
                    color: _getColorFromInt(applicant.color),
                    width: 4,
                  ),
                )
              : Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Candidate Name
              Text(
                applicant.partnerName != null &&
                        applicant.partnerName!.isNotEmpty
                    ? applicant.partnerName!
                    : applicant.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  fontSize: 15,
                  fontFamily: 'CenturyGothic',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Subject/Job
              if (applicant.name.toLowerCase() !=
                  (applicant.partnerName?.toLowerCase() ?? ''))
                Text(
                  applicant.name,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontFamily: 'Nexa',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (applicant.jobName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    applicant.jobName!,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Nexa',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              const SizedBox(height: 12),

              // Footer tags (Priority, Attachments)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Priority Stars
                      if (applicant.priority != null &&
                          applicant.priority != '0')
                        Row(
                          children: List.generate(
                            int.tryParse(applicant.priority!) ?? 0,
                            (index) => const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        )
                      else
                        const Icon(
                          Icons.star_border_rounded,
                          size: 14,
                          color: Color(0xFFCBD5E1),
                        ),

                      const SizedBox(width: 8),

                      // Activity Scheduler (Clock Menu)
                      Theme(
                        data: Theme.of(context).copyWith(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                        child: PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.access_time_filled_rounded,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                          padding: EdgeInsets.zero,
                          tooltip: "Planificar Actividad",
                          onSelected: (val) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Agendar: $val")),
                            );
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: Colors.white,
                          elevation: 4,
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'Llamada',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.phone_outlined,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Llamada",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Nexa',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'Correo',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.email_outlined,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Correo",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Nexa',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'Reunión',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.group_outlined,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Reunión",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Nexa',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'Por hacer',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Por hacer",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Nexa',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Attachments indicator
                  if (applicant.attachmentNumber > 0)
                    Row(
                      children: [
                        const Icon(
                          Icons.attach_file_rounded,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${applicant.attachmentNumber}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Nexa',
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
