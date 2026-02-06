import 'package:flutter/material.dart';
import '../services/crm_service.dart';

class CreateLeadScreen extends StatefulWidget {
  const CreateLeadScreen({super.key});

  @override
  State<CreateLeadScreen> createState() => _CreateLeadScreenState();
}

class _CreateLeadScreenState extends State<CreateLeadScreen> {
  final _formKey = GlobalKey<FormState>();
  final CrmService _crmService = CrmService();

  // Controllers
  final _nameController = TextEditingController(); // Opportunity Name
  final _partnerNameController =
      TextEditingController(); // Customer Name (New or Existing)
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _revenueController = TextEditingController(text: '0.0');
  final _descriptionController = TextEditingController();

  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final vals = {
        'name': _nameController.text,
        'contact_name': _partnerNameController
            .text, // Odoo handles creation often or links if found
        'email_from': _emailController.text,
        'phone': _phoneController.text,
        'expected_revenue': double.tryParse(_revenueController.text) ?? 0.0,
        'description': _descriptionController.text,
        'type': 'opportunity', // Force as opportunity
        // 'user_id': OdooService.instance.currentUserId, // Assign to self handled by default usually, but good to ensure
      };

      await _crmService.createLead(vals);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oportunidad creada con éxito')),
        );
        Navigator.pop(context);
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
      appBar: AppBar(title: const Text('Nueva Oportunidad')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Título de Oportunidad *',
                ),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _partnerNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Cliente / Contacto',
                ),
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
                controller: _revenueController,
                decoration: const InputDecoration(
                  labelText: 'Ingreso Esperado (\$)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Notas / Descripción',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('CREAR OPORTUNIDAD'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
