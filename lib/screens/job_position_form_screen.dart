import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hr_models.dart';
import '../services/hr_service.dart';

class JobPositionFormScreen extends StatefulWidget {
  final JobPosition? jobPosition;
  const JobPositionFormScreen({super.key, this.jobPosition});

  @override
  State<JobPositionFormScreen> createState() => _JobPositionFormScreenState();
}

class _JobPositionFormScreenState extends State<JobPositionFormScreen> {
  late PageController _pageController;
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  final HRService _hrService = HRService();
  bool _isLoading = false;
  int _currentStep = 0;

  // Step 1 Fields
  late TextEditingController _nameController;
  late TextEditingController _aliasController;

  // Step 2 Fields
  int? _selectedRecruiterId;
  late TextEditingController _targetEmployeesController;
  int? _selectedDepartmentId;
  bool _isPublished = false;
  late TextEditingController _locationController;
  late TextEditingController _interviewersController;
  late TextEditingController _employmentTypeController;
  late TextEditingController _degreeController;
  late TextEditingController _skillsController;
  late TextEditingController _summaryController;

  List<Employee> _employees = [];
  List<Department> _departments = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.jobPosition?.name);
    _aliasController = TextEditingController(
      text: widget.jobPosition?.aliasName,
    );
    _locationController = TextEditingController(
      text: widget.jobPosition?.addressName,
    );

    // For Interviewers we'll use a mocked text input for now or show count if exists
    _interviewersController = TextEditingController(
      text: widget.jobPosition?.interviewerIds.isNotEmpty == true
          ? '${widget.jobPosition!.interviewerIds.length} Entrevistador(es)'
          : '',
    );

    _targetEmployeesController = TextEditingController(
      text: widget.jobPosition?.expectedEmployees?.toString() ?? '1',
    );
    _selectedRecruiterId = widget.jobPosition?.userId;
    _selectedDepartmentId = widget.jobPosition?.departmentId;
    _isPublished = widget.jobPosition?.isPublished ?? false;

    _employmentTypeController = TextEditingController(
      text: widget.jobPosition?.employmentTypeName,
    );
    _degreeController = TextEditingController(
      text: widget.jobPosition?.degreeName,
    );
    _skillsController =
        TextEditingController(); // Skills often m2m tags, or text in desc
    _summaryController = TextEditingController(
      text: widget.jobPosition?.description,
    );

    if (widget.jobPosition != null) {
      _currentStep = 1;
      _fetchStep2Data();
    }
    _pageController = PageController(initialPage: _currentStep);
  }

  Future<void> _fetchStep2Data() async {
    setState(() => _isLoading = true);
    final futures = await Future.wait([
      _hrService.getEmployees(),
      _hrService.getDepartments(),
    ]);
    if (mounted) {
      setState(() {
        _employees = futures[0] as List<Employee>;
        _departments = futures[1] as List<Department>;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _aliasController.dispose();
    _targetEmployeesController.dispose();
    _locationController.dispose();
    _interviewersController.dispose();
    _employmentTypeController.dispose();
    _degreeController.dispose();
    _skillsController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_formKeyStep1.currentState!.validate()) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        setState(() => _currentStep = 1);
        if (_employees.isEmpty) {
          _fetchStep2Data();
        }
      }
    }
  }

  void _prevStep() {
    if (_currentStep == 1 && widget.jobPosition == null) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = 0);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    if (!_formKeyStep2.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final vals = {
      'name': _nameController.text,
      'alias_name': _aliasController.text.isNotEmpty
          ? _aliasController.text
          : false,
      'expected_employees': int.tryParse(_targetEmployeesController.text) ?? 1,
      if (_selectedRecruiterId != null) 'user_id': _selectedRecruiterId,
      if (_selectedDepartmentId != null) 'department_id': _selectedDepartmentId,
      'is_published': _isPublished,
      'description': _summaryController.text,
      // For now, we don't have a multi-select for interviewers, but we can preserve existing ones
      // or implement a basic logic if needed.
    };

    try {
      if (widget.jobPosition == null) {
        await _hrService.createJobPosition(vals);
      } else {
        await _hrService.updateJobPosition(widget.jobPosition!.id, vals);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      appBar: AppBar(
        title: Text(
          widget.jobPosition == null
              ? "Crear Puesto de Trabajo"
              : "Configurar Puesto",
          style: GoogleFonts.inter(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _prevStep,
        ),
        actions: [
          if (_currentStep == 1 && !_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6), // Teal
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  "Guardar",
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [_buildStep1(), _buildStep2()],
      ),
    );
  }

  Widget _buildStep1() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKeyStep1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.work_outline,
                        color: Color(0xFF14B8A6),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "Puesto Inicial",
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.inter(fontSize: 16),
                  decoration: _inputDecoration(
                    "Nombre del Puesto",
                    hint: "p. ej. Gerente de ventas",
                  ),
                  validator: (v) => v == null || v.isEmpty ? "Requerido" : null,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _aliasController,
                  style: GoogleFonts.inter(fontSize: 16),
                  decoration: _inputDecoration(
                    "¿Correo electrónico de solicitud?",
                    hint: "p. ej. empleos",
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Los correos entrantes generan solicitudes automáticamente al alias @miempresa.com",
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6), // Teal
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Continuar Configuración",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep2() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKeyStep2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera Principal
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF59E0B),
                        size: 36,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _nameController.text.isNotEmpty
                              ? _nameController.text
                              : "Nuevo Puesto",
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.jobPosition != null && _isPublished) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (widget.jobPosition?.websiteUrl != null &&
                              widget.jobPosition!.websiteUrl!.isNotEmpty) {
                            final url = Uri.parse(
                              widget.jobPosition!.websiteUrl!.startsWith('http')
                                  ? widget.jobPosition!.websiteUrl!
                                  : 'https://odoo-markdebrand.informatiquecr.com${widget.jobPosition!.websiteUrl!}',
                            );
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("No se pudo abrir la URL"),
                                  ),
                                );
                              }
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Este puesto no tiene una URL pública configurada",
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.open_in_browser_rounded,
                          color: Color(0xFF14B8A6),
                        ),
                        label: Text(
                          "Página del empleo",
                          style: GoogleFonts.inter(
                            color: const Color(0xFF14B8A6),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF14B8A6)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Hiring Process Card
            _buildCardSection(
              title: "Proceso de Contratación",
              icon: Icons.people_alt_outlined,
              children: [
                DropdownButtonFormField<int>(
                  initialValue:
                      _employees.any((e) => e.id == _selectedRecruiterId)
                      ? _selectedRecruiterId
                      : null,
                  decoration: _inputDecoration("¿Contratador?"),
                  items: _employees
                      .fold<List<Employee>>([], (list, item) {
                        if (!list.any((x) => x.id == item.id)) list.add(item);
                        return list;
                      })
                      .map((e) {
                        return DropdownMenuItem(
                          value: e.id,
                          child: Text(e.name, style: GoogleFonts.inter()),
                        );
                      })
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _selectedRecruiterId = val),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _interviewersController,
                  decoration: _inputDecoration("¿Entrevistadores?"),
                  style: GoogleFonts.inter(),
                  readOnly: false, // In a real app this opens a multi-select
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _aliasController,
                  decoration: _inputDecoration("¿Alias de correo electrónico?"),
                  style: GoogleFonts.inter(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Job Publication Card
            _buildCardSection(
              title: "Publicación de Empleo",
              icon: Icons.campaign_outlined,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "¿Publicado en Sitio Web?",
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                      Switch(
                        value: _isPublished,
                        onChanged: (val) => setState(() => _isPublished = val),
                        activeThumbColor: const Color(0xFF14B8A6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _targetEmployeesController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration("Objetivo (Nuevos empleados)"),
                  style: GoogleFonts.inter(),
                  validator: (v) => v == null || v.isEmpty ? "Requerido" : null,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Work Location Card
            _buildCardSection(
              title: "Trabajo y Ubicación",
              icon: Icons.business_center_outlined,
              children: [
                DropdownButtonFormField<int>(
                  initialValue:
                      _departments.any((d) => d.id == _selectedDepartmentId)
                      ? _selectedDepartmentId
                      : null,
                  decoration: _inputDecoration("Departamento"),
                  items: _departments
                      .fold<List<Department>>([], (list, item) {
                        if (!list.any((x) => x.id == item.id)) list.add(item);
                        return list;
                      })
                      .map((d) {
                        return DropdownMenuItem(
                          value: d.id,
                          child: Text(d.name, style: GoogleFonts.inter()),
                        );
                      })
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _selectedDepartmentId = val),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  decoration: _inputDecoration("¿Ubicación del trabajo?"),
                  style: GoogleFonts.inter(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Technical Details Card
            _buildCardSection(
              title: "Detalles del Perfil",
              icon: Icons.list_alt_rounded,
              children: [
                TextFormField(
                  controller: _employmentTypeController,
                  decoration: _inputDecoration(
                    "Tipo de empleo",
                    hint: "p. ej. Tiempo completo, Medio tiempo",
                  ),
                  style: GoogleFonts.inter(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _degreeController,
                  decoration: _inputDecoration(
                    "Grado esperado",
                    hint: "p. ej. Maestría, Licenciatura",
                  ),
                  style: GoogleFonts.inter(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _skillsController,
                  decoration: _inputDecoration(
                    "Habilidades esperadas",
                    hint: "p. ej. Ventas, Marketing, Liderazgo",
                  ),
                  style: GoogleFonts.inter(),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _summaryController,
                  decoration: _inputDecoration("Resumen / Descripción"),
                  style: GoogleFonts.inter(),
                  maxLines: 3,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF64748B), size: 20),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF475569),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF1F5F9), // Lighter gray for inputs
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 1.5),
      ),
    );
  }
}
