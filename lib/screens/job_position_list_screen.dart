import 'package:flutter/material.dart';

import '../models/hr_models.dart';
import '../services/hr_service.dart';
import 'job_position_form_screen.dart';
import 'recruitment_list_screen.dart';

class JobPositionListScreen extends StatefulWidget {
  const JobPositionListScreen({super.key});

  @override
  State<JobPositionListScreen> createState() => _JobPositionListScreenState();
}

class _JobPositionListScreenState extends State<JobPositionListScreen> {
  final HRService _hrService = HRService();
  List<JobPosition> _jobPositions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchJobPositions();
  }

  Future<void> _fetchJobPositions() async {
    setState(() => _isLoading = true);
    final positions = await _hrService.getJobPositions();
    if (mounted) {
      setState(() {
        _jobPositions = positions;
        _isLoading = false;
      });
    }
  }

  void _createNewJobPosition() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const JobPositionFormScreen()),
    );
    if (result == true) {
      _fetchJobPositions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      appBar: AppBar(
        title: const Text(
          "Puestos de Trabajo",
          style: TextStyle(
            color: Color(0xFF0F172A), // Slate 900
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'CenturyGothic',
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: _createNewJobPosition,
              icon: const Icon(Icons.add, size: 20),
              label: const Text("Nuevo"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _jobPositions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.work_off_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No se encontraron puestos de trabajo",
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _fetchJobPositions,
                    child: const Text("Reintentar"),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchJobPositions,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _jobPositions.length,
                itemBuilder: (context, index) {
                  final job = _jobPositions[index];
                  return _buildJobCard(job);
                },
              ),
            ),
    );
  }

  Widget _buildJobCard(JobPosition job) {
    return GestureDetector(
      onTap: () {
        // Navegar a los Detalles/Configuración del Puesto (Wizard)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobPositionFormScreen(jobPosition: job),
          ),
        ).then((value) {
          if (value == true) _fetchJobPositions();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section (Title & Recruiter)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            fontFamily: 'CenturyGothic',
                          ),
                        ),
                        if (job.userName != null && job.userName!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  child: Text(
                                    job.userName![0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF475569),
                                      fontFamily: 'Nexa',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    job.userName!,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Nexa',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Metrics Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetric(
                    label: "Para reclutar",
                    value: "${job.noOfRecruitment ?? 0}",
                    color: const Color(0xFF64748B),
                  ),
                  _buildMetric(
                    label: "Nuevas aplic.",
                    value: "${job.newApplicationCount ?? 0}",
                    color: const Color(0xFF3B82F6), // Blue to highlight new
                  ),

                  // Botón interactivo para ir al Pipeline
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RecruitmentListScreen(jobPosition: job),
                        ),
                      ).then((value) {
                        // Refresh in case applicants changed state
                        _fetchJobPositions();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4), // Light Green
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            "${job.applicationCount ?? 0} en curso",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF16A34A), // Green 600
                              fontFamily: 'Nexa',
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: Color(0xFF16A34A),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            fontFamily: 'CenturyGothic',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
            fontFamily: 'Nexa',
          ),
        ),
      ],
    );
  }
}
