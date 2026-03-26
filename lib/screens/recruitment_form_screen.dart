import 'package:flutter/material.dart';
import '../models/recruitment_models.dart';
import '../services/recruitment_service.dart';
import '../services/hr_service.dart';
import '../models/hr_models.dart';

class RecruitmentFormScreen extends StatefulWidget {
  final Applicant? applicant;
  const RecruitmentFormScreen({super.key, this.applicant});

  @override
  State<RecruitmentFormScreen> createState() => _RecruitmentFormScreenState();
}

class _RecruitmentFormScreenState extends State<RecruitmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final RecruitmentService _recruitmentService = RecruitmentService();
  final HRService _hrService = HRService();

  late TextEditingController _nameController;
  late TextEditingController _candidateNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  List<JobPosition> _jobs = [];
  List<RecruitmentStage> _stages = [];
  int? _selectedJobId;
  int? _selectedStageId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _candidateNameController = TextEditingController(
      text: widget.applicant?.partnerName,
    );
    _nameController = TextEditingController(
      text: _candidateNameController.text,
    );
    _emailController = TextEditingController(text: widget.applicant?.emailFrom);
    _phoneController = TextEditingController(
      text: widget.applicant?.partnerMobile,
    );
    _selectedJobId = widget.applicant?.jobId;
    _selectedStageId = widget.applicant?.stageId;
    _fetchFormData();
  }

  Future<void> _fetchFormData() async {
    final futures = await Future.wait([
      _hrService.getJobPositions(),
      _recruitmentService.getStages(),
    ]);

    final jobs = futures[0] as List<JobPosition>;
    final stages = futures[1] as List<RecruitmentStage>;

    if (mounted) {
      setState(() {
        _jobs = jobs;
        _stages = stages;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _candidateNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final vals = {
      'partner_name': _candidateNameController.text,
      'email_from': _emailController.text,
      'partner_mobile': _phoneController.text,
      'partner_phone': _phoneController.text, // Duplicate for compatibility
      'job_id': _selectedJobId,
      if (_selectedStageId != null) 'stage_id': _selectedStageId,
    };

    try {
      if (widget.applicant == null) {
        await _recruitmentService.createApplicant(vals);
      } else {
        await _recruitmentService.updateApplicant(widget.applicant!.id, vals);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains("OdooServiceException")) {
          errorMsg = errorMsg.replaceAll("OdooServiceException: ", "");
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $errorMsg')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.applicant == null ? "New Applicant" : "Edit Applicant",
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontFamily: 'CenturyGothic',
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _save,
              child: const Text(
                "SAVE",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF007AFF), // Markdebrand Blue
                  fontFamily: 'Nexa',
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle("Application Status"),
                    const SizedBox(height: 16),
                    _buildStageField(),
                    const SizedBox(height: 32),
                    _buildSectionTitle("Vacancy Information"),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _nameController,
                      label: "Subject / Application Title",
                      icon: Icons.title_rounded,
                      validator: (v) =>
                          v == null || v.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 20),
                    _buildDropdownField(),
                    const SizedBox(height: 32),
                    _buildSectionTitle("Candidate Information"),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _candidateNameController,
                      label: "Candidate Name",
                      icon: Icons.person_outline_rounded,
                      validator: (v) =>
                          v == null || v.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _emailController,
                      label: "Email",
                      icon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _phoneController,
                      label: "Mobile",
                      icon: Icons.phone_iphone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: Color(0xFF64748B),
        letterSpacing: 1.5,
        fontFamily: 'Nexa',
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
      ),
    );
  }

  Widget _buildDropdownField() {
    return DropdownButtonFormField<int>(
      initialValue:
          _jobs.any((j) => j.id == _selectedJobId) ? _selectedJobId : null,
      validator: (v) => v == null ? "Position required" : null,
      decoration: InputDecoration(
        labelText: "Job Position",
        prefixIcon: const Icon(Icons.work_outline_rounded, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: _jobs
          .fold<List<JobPosition>>([], (list, item) {
            if (!list.any((j) => j.id == item.id)) list.add(item);
            return list;
          })
          .map((j) {
            return DropdownMenuItem(value: j.id, child: Text(j.name));
          })
          .toList(),
      onChanged: (val) => setState(() => _selectedJobId = val),
    );
  }

  Widget _buildStageField() {
    return DropdownButtonFormField<int>(
      initialValue: _stages.any((s) => s.id == _selectedStageId)
          ? _selectedStageId
          : null,
      decoration: InputDecoration(
        labelText: "Pipeline Stage",
        prefixIcon: const Icon(Icons.view_kanban_outlined, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: _stages
          .fold<List<RecruitmentStage>>([], (list, item) {
            if (!list.any((s) => s.id == item.id)) list.add(item);
            return list;
          })
          .map((s) {
            return DropdownMenuItem(value: s.id, child: Text(s.name));
          })
          .toList(),
      onChanged: (val) => setState(() => _selectedStageId = val),
    );
  }
}
