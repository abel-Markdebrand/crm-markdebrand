import 'package:flutter/material.dart';
import '../services/crm_service.dart';
import '../models/crm_models.dart';

class EditOpportunityScreen extends StatefulWidget {
  final CrmLead lead;

  const EditOpportunityScreen({super.key, required this.lead});

  @override
  State<EditOpportunityScreen> createState() => _EditOpportunityScreenState();
}

class _EditOpportunityScreenState extends State<EditOpportunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final CrmService _crmService = CrmService();

  late TextEditingController _nameController;
  late TextEditingController _revenueController;
  late TextEditingController _probController;
  late TextEditingController _descriptionController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.lead.name);
    _revenueController = TextEditingController(
      text: widget.lead.expectedRevenue.toString(),
    );
    _probController = TextEditingController(
      text: widget.lead.probability.toString(),
    );
    _descriptionController = TextEditingController(
      text: widget.lead.description ?? '',
    );
    _emailController = TextEditingController(text: widget.lead.email ?? '');
    _phoneController = TextEditingController(text: widget.lead.phone ?? '');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final vals = {
        'name': _nameController.text,
        'expected_revenue': double.tryParse(_revenueController.text) ?? 0.0,
        'probability': double.tryParse(_probController.text) ?? 0.0,
        'description': _descriptionController.text,
        'email_from': _emailController.text,
        'phone': _phoneController.text,
      };

      await _crmService.updateLead(widget.lead.id, vals);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oportunidad actualizada')),
        );
        Navigator.pop(context, true); // Return true to indicate refresh needed
      }
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
      appBar: AppBar(title: const Text('Editar Oportunidad')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _revenueController,
                      decoration: const InputDecoration(
                        labelText: 'Ingreso Esperado',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _probController,
                      decoration: const InputDecoration(
                        labelText: 'Probabilidad (%)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción / Notas',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('GUARDAR CAMBIOS'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
