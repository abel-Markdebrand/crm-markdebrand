import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../models/hr_models.dart';
import '../services/hr_service.dart';

class EmployeeFormScreen extends StatefulWidget {
  final Employee? employee;
  const EmployeeFormScreen({super.key, this.employee});

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final HRService _hrService = HRService();
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  String? _base64Image;

  // Design Colors from Mockups
  static const _primaryColor = Color(0xFF0090FF);
  static const _bgLight = Colors.white;
  static const _slate100 = Color(0xFFF1F5F9);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _slate300 = Color(0xFFCBD5E1);
  static const _slate400 = Color(0xFF94A3B8);
  static const _slate500 = Color(0xFF64748B);
  static const _slate600 = Color(0xFF475569);
  static const _slate900 = Color(0xFF0F172A);

  // Tab 1: Trabajo
  late TextEditingController _nameController;
  late TextEditingController _jobController;
  int? _selectedDepartmentId;
  int? _selectedManagerId;
  int? _selectedCoachId;
  String? _selectedGender;

  // Tab 2: Personal
  late TextEditingController _idNumberController;
  late TextEditingController _nationalityController;
  late TextEditingController _placeOfBirthController;
  late TextEditingController _birthdayController;
  String? _selectedMarital;
  late TextEditingController _studyFieldController;
  String? _selectedCertificate;
  int _childrenCount = 0;
  late TextEditingController _privateEmailController;
  late TextEditingController _privatePhoneController;
  late TextEditingController _bankAccountController;
  // Note: distanceController removed

  late TextEditingController _emergencyContactController;
  late TextEditingController _emergencyPhoneController;

  // Contacto Trabajo
  late TextEditingController _workEmailController;
  late TextEditingController _mobilePhoneController;
  late TextEditingController _workPhoneController;

  List<Department> _departments = [];
  List<Employee> _allEmployees = [];
  List<Map<String, dynamic>> _contractTypes = [];
  List<Map<String, dynamic>> _structureTypes = [];
  List<Map<String, dynamic>> _workingHoursList = [];

  bool _isLoading = false;
  bool _isSavingContract = false;

  // Contract data
  final _wageController = TextEditingController();
  final _contractDateStartController = TextEditingController();
  final _contractDateEndController = TextEditingController();
  int? _selectedContractTypeId;
  int? _selectedStructureTypeId;
  int? _selectedWorkingHoursId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _nameController = TextEditingController(text: widget.employee?.name);
    _jobController = TextEditingController(text: widget.employee?.jobTitle);
    _selectedDepartmentId = widget.employee?.departmentId;
    _selectedManagerId = widget.employee?.parentId;
    _selectedCoachId = widget.employee?.coachId;
    _selectedGender = widget.employee?.gender;

    _idNumberController = TextEditingController(
      text: widget.employee?.identificationId,
    );
    _nationalityController = TextEditingController(
      text: widget.employee?.nationality ?? 'Española',
    );
    _placeOfBirthController = TextEditingController(
      text: widget.employee?.placeOfBirth,
    );
    _birthdayController = TextEditingController(
      text: widget.employee?.birthday,
    );
    _selectedMarital =
        widget.employee?.marital ?? (widget.employee == null ? 'single' : null);

    _studyFieldController = TextEditingController(
      text: widget.employee?.studyField,
    );
    _selectedCertificate = widget.employee?.certificate;
    _childrenCount = widget.employee?.children ?? 0;

    _privateEmailController = TextEditingController(
      text: widget.employee?.privateEmail,
    );
    _privatePhoneController = TextEditingController(
      text: widget.employee?.privatePhone,
    );
    _bankAccountController = TextEditingController(
      text: widget.employee?.bankAccount,
    );

    _emergencyContactController = TextEditingController(
      text: widget.employee?.emergencyContact,
    );
    _emergencyPhoneController = TextEditingController(
      text: widget.employee?.emergencyPhone,
    );

    _workEmailController = TextEditingController(
      text: widget.employee?.workEmail,
    );
    _mobilePhoneController = TextEditingController(
      text: widget.employee?.mobilePhone,
    );
    _workPhoneController = TextEditingController(
      text: widget.employee?.workPhone,
    );

    _base64Image = widget.employee?.image1920;

    _fetchFormData();
    if (widget.employee != null) {
      _loadContract();
    }
  }

  Future<void> _fetchFormData() async {
    try {
      final depts = await _hrService.getDepartments();
      final emps = await _hrService.getEmployees();
      final cTypes = await _hrService.getContractTypes();
      final sTypes = await _hrService.getStructureTypes();
      final wHours = await _hrService.getWorkingHours();

      if (mounted) {
        setState(() {
          _departments = depts;
          _allEmployees = emps;
          _contractTypes = cTypes;
          _structureTypes = sTypes;
          _workingHoursList = wHours;
        });
      }
    } catch (e) {
      debugPrint("Error fetching form data: $e");
    }
  }

  Future<void> _loadContract() async {
    if (widget.employee == null) return;
    try {
      final contract = await _hrService.getContract(widget.employee!.id);
      if (contract != null && mounted) {
        setState(() {
          _wageController.text = contract.wage > 0
              ? contract.wage.toString()
              : _wageController.text;
          if (_contractDateStartController.text.isEmpty) {
            _contractDateStartController.text = contract.dateStart ?? '';
          }
          if (_contractDateEndController.text.isEmpty) {
            _contractDateEndController.text = contract.dateEnd ?? '';
          }
          _selectedContractTypeId ??= contract.contractTypeId;
          _selectedStructureTypeId ??= contract.payCategoryId;
          _selectedWorkingHoursId ??= contract.workingHoursId;
        });
      }
    } catch (e) {
      debugPrint("Error loading contract: $e");
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final File file = File(pickedFile.path);
        final bytes = await file.readAsBytes();
        setState(() {
          _base64Image = base64Encode(bytes);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _jobController.dispose();
    _idNumberController.dispose();
    _nationalityController.dispose();
    _placeOfBirthController.dispose();
    _birthdayController.dispose();
    _studyFieldController.dispose();
    _privateEmailController.dispose();
    _privatePhoneController.dispose();
    _bankAccountController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _workEmailController.dispose();
    _mobilePhoneController.dispose();
    _workPhoneController.dispose();
    _wageController.dispose();
    _contractDateStartController.dispose();
    _contractDateEndController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final vals = {
      'name': _nameController.text,
      'job_title': _jobController.text,
      'department_id': _selectedDepartmentId,
      'parent_id': _selectedManagerId,
      'coach_id': _selectedCoachId,
      'gender': _selectedGender,
      'identification_id': _idNumberController.text,
      'place_of_birth': _placeOfBirthController.text,
      'birthday': _birthdayController.text,
      'study_field': _studyFieldController.text,
      'marital': _selectedMarital,
      'certificate': _selectedCertificate,
      'children': _childrenCount,
      'private_email': _privateEmailController.text,
      'private_phone': _privatePhoneController.text,
      'emergency_contact': _emergencyContactController.text,
      'emergency_phone': _emergencyPhoneController.text,
      'work_email': _workEmailController.text,
      'mobile_phone': _mobilePhoneController.text,
      'work_phone': _workPhoneController.text,
      'image_1920': _base64Image,
    };

    try {
      if (widget.employee == null) {
        final newId = await _hrService.createEmployee(vals);
        if (newId != null && mounted) {
          Navigator.pop(context, true);
        }
      } else {
        await _hrService.updateEmployee(widget.employee!.id, vals);
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: Text(
          widget.employee == null ? "Nuevo Empleado" : "Perfil del Empleado",
          style: GoogleFonts.inter(
            color: _slate900,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _slate900),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _slate200, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: _primaryColor,
              unselectedLabelColor: _slate500,
              indicatorColor: _primaryColor,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: "Trabajo"),
                Tab(text: "Personal"),
                Tab(text: "Contrato"),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildWorkTab(),
                  _buildPersonalTab(),
                  _buildContractTab(),
                ],
              ),
            ),
      bottomNavigationBar: _isLoading ? null : _buildStickyFooter(),
    );
  }

  Widget _buildStickyFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xE6FFFFFF),
        border: Border(top: BorderSide(color: _slate200)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton(
            onPressed: () {
              if (_tabController.index < 2) {
                _tabController.animateTo(_tabController.index + 1);
              } else {
                _save();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: const Color(0x4D0090FF),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _tabController.index < 2 ? "Continuar" : "Guardar Empleado",
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- TRABAJO TAB ---
  Widget _buildWorkTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileImageHeader(),
          const SizedBox(height: 32),
          _buildSectionHeader("Información del Puesto"),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _nameController,
            label: "Nombre Completo",
            hint: "Introduce nombre completo",
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _jobController,
            label: "Título del Puesto",
            hint: "Ej. Especialista en Marketing",
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField<String>(
                  label: "Género",
                  value: _selectedGender,
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Masculino')),
                    DropdownMenuItem(value: 'female', child: Text('Femenino')),
                    DropdownMenuItem(value: 'other', child: Text('Otro')),
                  ],
                  onChanged: (v) => setState(() => _selectedGender = v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField<int>(
                  label: "Departamento",
                  value: _departments.any((d) => d.id == _selectedDepartmentId)
                      ? _selectedDepartmentId
                      : null,
                  items: _departments
                      .map(
                        (d) =>
                            DropdownMenuItem(value: d.id, child: Text(d.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedDepartmentId = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField<int>(
                  label: "Gerente / Responsable",
                  value: _allEmployees.any((e) => e.id == _selectedManagerId)
                      ? _selectedManagerId
                      : null,
                  items: _allEmployees
                      .map(
                        (e) =>
                            DropdownMenuItem(value: e.id, child: Text(e.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedManagerId = v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField<int>(
                  label: "Entrenador / Coach",
                  value: _allEmployees.any((e) => e.id == _selectedCoachId)
                      ? _selectedCoachId
                      : null,
                  items: _allEmployees
                      .map(
                        (e) =>
                            DropdownMenuItem(value: e.id, child: Text(e.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCoachId = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          _buildSectionHeader("Contacto de Trabajo"),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _workEmailController,
            label: "Email de Trabajo",
            prefixIcon: Icons.mail_outline,
            hint: "ejemplo@empresa.com",
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _mobilePhoneController,
                  label: "Teléfono Móvil",
                  prefixIcon: Icons.smartphone,
                  hint: "+34 600 000 000",
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _workPhoneController,
                  label: "Teléfono Fijo",
                  prefixIcon: Icons.call,
                  hint: "+34 910 000 000",
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- PERSONAL TAB ---
  Widget _buildPersonalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            "Información Personal",
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 24),
          _buildDropdownField<String>(
            label: "Estado Civil",
            value: _selectedMarital,
            items: const [
              DropdownMenuItem(value: 'single', child: Text('Soltero/a')),
              DropdownMenuItem(value: 'married', child: Text('Casado/a')),
              DropdownMenuItem(value: 'divorced', child: Text('Divorciado/a')),
              DropdownMenuItem(
                value: 'cohabitant',
                child: Text('Pareja de hecho'),
              ),
              DropdownMenuItem(value: 'widower', child: Text('Viudo/a')),
            ],
            onChanged: (v) => setState(() => _selectedMarital = v),
          ),
          const SizedBox(height: 16),
          _buildChildrenCounter(),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _placeOfBirthController,
            label: "Lugar de Nacimiento",
            hint: "Ej: Madrid, España",
          ),
          const SizedBox(height: 16),
          _buildDateField(
            controller: _birthdayController,
            label: "Fecha de Nacimiento",
          ),
          const SizedBox(height: 40),
          _buildSectionHeader(
            "Ciudadanía e Identificación",
            icon: Icons.public,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _nationalityController,
            label: "Nacionalidad",
            readOnly: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _idNumberController,
            label: "NIF / NIE / Pasaporte",
            hint: "00000000X",
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 40),
          _buildSectionHeader("Educación", icon: Icons.school_outlined),
          const SizedBox(height: 24),
          _buildDropdownField<String>(
            label: "Nivel de Estudios",
            value: _selectedCertificate,
            items: const [
              DropdownMenuItem(
                value: 'graduate',
                child: Text('Grado Universitario'),
              ),
              DropdownMenuItem(
                value: 'master',
                child: Text('Máster / Postgrado'),
              ),
              DropdownMenuItem(value: 'bachelor', child: Text('Bachillerato')),
              DropdownMenuItem(value: 'doctor', child: Text('Doctorado')),
              DropdownMenuItem(value: 'other', child: Text('Otro')),
            ],
            onChanged: (v) => setState(() => _selectedCertificate = v),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _studyFieldController,
            label: "Campo de Estudio / Carrera",
            hint: "Ej: Ingeniería de Software",
          ),
          const SizedBox(height: 40),
          _buildSectionHeader(
            "Contacto Privado",
            icon: Icons.contact_mail_outlined,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _privateEmailController,
            label: "Email Privado",
            hint: "nombre@personal.com",
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _privatePhoneController,
            label: "Teléfono Privado",
            hint: "+34 600 000 000",
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _bankAccountController,
            label: "Nº Cuenta Bancaria (IBAN)",
            readOnly: true,
          ),
          const SizedBox(height: 40),
          _buildSectionHeader(
            "Contacto de Emergencia",
            icon: Icons.emergency_outlined,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _emergencyContactController,
            label: "Nombre del Contacto",
            hint: "Nombre completo",
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emergencyPhoneController,
            label: "Teléfono de Emergencia",
            hint: "+34 600 000 000",
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  // --- CONTRATO TAB ---
  Widget _buildContractTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            "Datos del Contrato",
            icon: Icons.description_outlined,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _wageController,
            label: "Salario Mensual Bruto",
            hint: "0.00",
            prefixIcon: Icons.payments_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField<int>(
                  label: "Tipo de Contrato",
                  value:
                      _contractTypes.any(
                        (t) => t['id'] == _selectedContractTypeId,
                      )
                      ? _selectedContractTypeId
                      : null,
                  items: _contractTypes
                      .map(
                        (t) => DropdownMenuItem<int>(
                          value: t['id'] as int,
                          child: Text(t['name'] ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedContractTypeId = v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField<int>(
                  label: "Categoría de Nómina",
                  value:
                      _structureTypes.any(
                        (s) => s['id'] == _selectedStructureTypeId,
                      )
                      ? _selectedStructureTypeId
                      : null,
                  items: _structureTypes
                      .map(
                        (s) => DropdownMenuItem<int>(
                          value: s['id'] as int,
                          child: Text(s['name'] ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedStructureTypeId = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          _buildSectionHeader(
            "Vigencia del Contrato",
            icon: Icons.calendar_today_outlined,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  controller: _contractDateStartController,
                  label: "Fecha de Inicio",
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDateField(
                  controller: _contractDateEndController,
                  label: "Fecha de Fin",
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          _buildSectionHeader(
            "Horario de Trabajo",
            icon: Icons.schedule_outlined,
          ),
          const SizedBox(height: 24),
          _buildDropdownField<int>(
            label: "Jornada / Horario",
            value:
                _workingHoursList.any((w) => w['id'] == _selectedWorkingHoursId)
                ? _selectedWorkingHoursId
                : null,
            items: _workingHoursList
                .map(
                  (w) => DropdownMenuItem<int>(
                    value: w['id'] as int,
                    child: Text(w['name'] ?? ''),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedWorkingHoursId = v),
          ),
          const SizedBox(height: 40),
          _buildContractSaveButton(),
        ],
      ),
    );
  }

  Widget _buildContractSaveButton() {
    if (widget.employee == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0x19FF9800),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x4DFF9800)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Guarda el empleado primero para poder gestionar el contrato.",
                style: GoogleFonts.inter(
                  color: Colors.orange.shade900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isSavingContract ? null : _saveContractData,
        icon: _isSavingContract
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save),
        label: Text(
          _isSavingContract ? "Guardando..." : "GUARDAR CONTRATO",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _slate900,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> _saveContractData() async {
    setState(() => _isSavingContract = true);
    final vals = <String, dynamic>{
      'employee_id': widget.employee!.id,
      'name': "Contrato ${widget.employee!.name}",
      'wage': double.tryParse(_wageController.text) ?? 0.0,
    };
    if (_selectedContractTypeId != null) {
      vals['contract_type_id'] = _selectedContractTypeId;
    }
    if (_selectedStructureTypeId != null) {
      vals['structure_type_id'] = _selectedStructureTypeId;
    }
    if (_selectedWorkingHoursId != null) {
      vals['resource_calendar_id'] = _selectedWorkingHoursId;
    }
    if (_contractDateStartController.text.isNotEmpty) {
      vals['date_start'] = _contractDateStartController.text;
    }
    if (_contractDateEndController.text.isNotEmpty) {
      vals['date_end'] = _contractDateEndController.text;
    }

    try {
      await _hrService.upsertContract(widget.employee!.id, vals);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contrato guardado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        _loadContract();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar contrato: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingContract = false);
    }
  }

  // --- HELPER WIDGETS ---

  Widget _buildProfileImageHeader() {
    return Center(
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_primaryColor, Color(0xFF80C8FF)],
              ),
            ),
            child: CircleAvatar(
              radius: 56,
              backgroundColor: Colors.white,
              backgroundImage: _base64Image != null
                  ? MemoryImage(base64Decode(_base64Image!))
                  : null,
              child: _base64Image == null
                  ? const Icon(Icons.person, size: 56, color: _slate300)
                  : null,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 20,
                  color: _primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: _primaryColor, size: 24),
          const SizedBox(width: 8),
        ] else ...[
          Container(
            width: 6,
            height: 24,
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _slate900,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? prefixIcon,
    bool isRequired = false,
    bool readOnly = false,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: RichText(
            text: TextSpan(
              text: label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _slate600,
              ),
              children: [
                if (isRequired)
                  const TextSpan(
                    text: " *",
                    style: TextStyle(color: _primaryColor),
                  ),
              ],
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: GoogleFonts.inter(fontSize: 16, color: _slate900),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: _slate400),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: _slate400)
                : null,
            filled: true,
            fillColor: readOnly ? _slate100 : _slate100,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _slate200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _primaryColor, width: 2),
            ),
          ),
          validator: isRequired
              ? (v) => v == null || v.isEmpty ? "Este campo es requerido" : null
              : null,
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _slate600,
            ),
          ),
        ),
        DropdownButtonFormField<T>(
          initialValue: items.any((i) => i.value == value) ? value : null,
          items: items,
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down, color: _primaryColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: _slate100,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _slate200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _primaryColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
  }) {
    return _buildTextField(
      controller: controller,
      label: label,
      readOnly: true,
      hint: "AAAA-MM-DD",
      prefixIcon: Icons.calendar_today,
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: _primaryColor,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: _slate900,
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          setState(() => controller.text = date.toString().split(' ')[0]);
        }
      },
    );
  }

  Widget _buildChildrenCounter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _slate100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slate200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Número de Hijos",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _slate900,
                ),
              ),
              Text(
                "Dependientes a cargo",
                style: GoogleFonts.inter(fontSize: 12, color: _slate500),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _slate100),
            ),
            child: Row(
              children: [
                _buildCircleIconButton(Icons.remove, () {
                  if (_childrenCount > 0) setState(() => _childrenCount--);
                }),
                SizedBox(
                  width: 40,
                  child: Center(
                    child: Text(
                      "$_childrenCount",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                _buildCircleIconButton(
                  Icons.add,
                  () => setState(() => _childrenCount++),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0x1A0090FF),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: _primaryColor),
      ),
    );
  }
}
