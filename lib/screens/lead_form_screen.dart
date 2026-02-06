import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/crm_service.dart';
import '../services/odoo_service.dart';
import '../models/crm_models.dart';
import 'cart_screen.dart';

class LeadFormScreen extends StatefulWidget {
  final CrmLead? lead;
  final int? stageId;

  const LeadFormScreen({super.key, this.lead, this.stageId});

  @override
  State<LeadFormScreen> createState() => _LeadFormScreenState();
}

class _LeadFormScreenState extends State<LeadFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final CrmService _crmService = CrmService();

  // Controladores
  late TextEditingController _titleController;
  late TextEditingController _revenueController;
  late TextEditingController _contactNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _notesController;

  // Estado
  double _probability = 0.0;
  DateTime? _closingDate;
  int? _selectedStageId;
  Map<String, dynamic>? _selectedPartner;

  List<CrmStage> _stages = [];
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadStages();
  }

  void _initControllers() {
    final l = widget.lead;

    _titleController = TextEditingController(text: l?.name ?? "");
    _revenueController = TextEditingController(
      text: l?.expectedRevenue.toString() ?? "",
    );
    _contactNameController = TextEditingController(text: l?.partnerName ?? "");
    _emailController = TextEditingController(text: l?.email ?? "");
    _phoneController = TextEditingController(text: l?.phone ?? "");
    _notesController = TextEditingController(text: l?.description ?? "");

    _probability = l?.probability ?? 0.0;
    _selectedStageId = widget.stageId;

    if (l?.partnerId != null) {
      // Partner exists, we'll show it
    }
  }

  Future<void> _loadStages() async {
    setState(() => _isLoading = true);
    try {
      final stages = await _crmService.getPipelineStages();
      if (mounted) {
        setState(() {
          _stages = stages;
          if (_selectedStageId == null && stages.isNotEmpty) {
            _selectedStageId = stages.first.id;
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading stages: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _revenueController.dispose();
    _contactNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // --- Actions ---

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _closingDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _closingDate = picked);
    }
  }

  Future<void> _launchPhone() async {
    final phone = _phoneController.text;
    if (phone.isEmpty) return;
    final uri = Uri.parse("tel:$phone");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo abrir el marcador")),
      );
    }
  }

  Future<void> _selectPartner() async {
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _PartnerSearchDialog(),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedPartner = selected;
        if (_contactNameController.text.isEmpty) {
          _contactNameController.text = selected['name'];
        }
        if (_emailController.text.isEmpty && selected['email'] != false) {
          _emailController.text = selected['email'];
        }
        if (_phoneController.text.isEmpty && selected['phone'] != false) {
          _phoneController.text = selected['phone'];
        }
      });
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final vals = {
        'name': _titleController.text,
        'type': 'opportunity',
        'expected_revenue': double.tryParse(_revenueController.text) ?? 0.0,
        'probability': _probability,
        'email_from': _emailController.text,
        'phone': _phoneController.text,
        'description': _notesController.text,
        'priority': '1',

        if (_selectedStageId != null) 'stage_id': _selectedStageId,
        if (_selectedPartner != null) 'partner_id': _selectedPartner!['id'],
        if (_closingDate != null)
          'date_deadline': _closingDate!.toIso8601String().split('T')[0],
      };

      if (widget.lead == null) {
        await _crmService.createLead(vals);
      } else {
        await _crmService.updateLead(widget.lead!.id, vals);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Guardado exitosamente")));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al guardar: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- UI Builders ---

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType? inputType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Nexa',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: inputType,
          validator: validator,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
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
              borderSide: const BorderSide(color: Color(0xFF0D59F2), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            'Oportunidad *',
            _titleController,
            validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Ingreso Esperado',
            _revenueController,
            inputType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          Text(
            "Probabilidad",
            style: const TextStyle(
              fontFamily: 'Nexa',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Probabilidad de cierre",
                      style: TextStyle(
                        fontFamily: 'Nexa',
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      "${_probability.toStringAsFixed(0)}%",
                      style: const TextStyle(
                        fontFamily: 'Nexa',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D59F2),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _probability,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  activeColor: const Color(0xFF0D59F2),
                  onChanged: (val) => setState(() => _probability = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Fecha de Cierre',
            TextEditingController(
              text: _closingDate == null
                  ? ""
                  : "${_closingDate!.day}/${_closingDate!.month}/${_closingDate!.year}",
            ),
            readOnly: true,
            onTap: _selectDate,
            suffixIcon: const Icon(
              Icons.calendar_today,
              color: Color(0xFF0D59F2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Etapa",
            style: const TextStyle(
              fontFamily: 'Nexa',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonFormField<int>(
              value: _selectedStageId,
              decoration: const InputDecoration(border: InputBorder.none),
              items: _stages
                  .map(
                    (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedStageId = val),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildContactInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Cliente (Partner)",
            style: const TextStyle(
              fontFamily: 'Nexa',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _selectPartner,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedPartner != null
                          ? "${_selectedPartner!['name']}"
                          : "Seleccionar Cliente...",
                      style: TextStyle(
                        fontFamily: 'Nexa',
                        color: _selectedPartner != null
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Icon(Icons.search, color: Color(0xFF0D59F2)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField('Nombre Contacto', _contactNameController),
          const SizedBox(height: 16),
          _buildTextField(
            'Email',
            _emailController,
            inputType: TextInputType.emailAddress,
            validator: (v) {
              if (v != null && v.isNotEmpty && !v.contains('@'))
                return 'Email inválido';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Teléfono / Móvil',
            _phoneController,
            inputType: TextInputType.phone,
            suffixIcon: IconButton(
              icon: const Icon(Icons.call, color: Color(0xFF10B981)),
              onPressed: _launchPhone,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "NOTAS INTERNAS",
            style: const TextStyle(
              fontFamily: 'Nexa',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesController,
            maxLines: 10,
            decoration: InputDecoration(
              hintText:
                  "Escribe aquí los detalles de la reunión, requerimientos del cliente, etc.",
              hintStyle: const TextStyle(
                fontFamily: 'Nexa',
                color: Color(0xFF94A3B8),
              ),
              filled: true,
              fillColor: Colors.white,
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
                borderSide: const BorderSide(
                  color: Color(0xFF0D59F2),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (widget.lead != null)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_selectedPartner == null &&
                        widget.lead?.partnerId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Asigne un Cliente primero"),
                        ),
                      );
                      return;
                    }

                    final partnerId = _selectedPartner != null
                        ? _selectedPartner!['id']
                        : widget.lead!.partnerId!;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CartScreen(
                          partnerId: partnerId,
                          opportunityId: widget.lead!.id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long),
                  label: const Text("FACTURAR"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (widget.lead != null) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveForm,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? "GUARDANDO..." : "GUARDAR"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D59F2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF0D59F2)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.lead == null ? "Nueva Oportunidad" : "Editar Oportunidad",
            style: const TextStyle(
              fontFamily: 'CenturyGothic',
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: const TabBar(
            labelColor: Color(0xFF0D59F2),
            unselectedLabelColor: Color(0xFF64748B),
            indicatorColor: Color(0xFF0D59F2),
            tabs: [
              Tab(text: "Negocio"),
              Tab(text: "Contacto"),
              Tab(text: "Notas"),
            ],
          ),
        ),
        body: Form(
          key: _formKey,
          child: TabBarView(
            children: [
              _buildBusinessInfoTab(),
              _buildContactInfoTab(),
              _buildNotesTab(),
            ],
          ),
        ),
        bottomSheet: _buildFooter(),
      ),
    );
  }
}

// Dialogo Simple de Búsqueda de Partners
class _PartnerSearchDialog extends StatefulWidget {
  const _PartnerSearchDialog();

  @override
  State<_PartnerSearchDialog> createState() => _PartnerSearchDialogState();
}

class _PartnerSearchDialogState extends State<_PartnerSearchDialog> {
  final _searchController = TextEditingController();
  final OdooService _odooService = OdooService.instance;
  List<dynamic> _results = [];
  bool _loading = false;

  void _search() async {
    setState(() => _loading = true);
    try {
      final res = await _odooService.callKw(
        model: 'res.partner',
        method: 'search_read',
        args: [],
        kwargs: {
          'domain': [
            ['name', 'ilike', _searchController.text],
          ],
          'fields': ['id', 'name', 'email', 'phone'],
          'limit': 20,
        },
      );
      if (mounted) setState(() => _results = res as List);
    } catch (e) {
      debugPrint("Search error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Buscar cliente...",
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
                  borderSide: const BorderSide(
                    color: Color(0xFF0D59F2),
                    width: 2,
                  ),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Color(0xFF0D59F2)),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final p = _results[index];
                        return ListTile(
                          title: Text(
                            p['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          subtitle: Text(
                            p['email']?.toString() ??
                                p['phone']?.toString() ??
                                '',
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                          onTap: () => Navigator.pop(context, p),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancelar",
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
