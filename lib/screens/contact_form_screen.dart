import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Added
import 'dart:io'; // Added
import 'dart:convert'; // Added
import '../services/odoo_service.dart';
import '../services/voip_service.dart';
import '../services/call_manager.dart'; // Added for AppCallState

class ContactFormScreen extends StatefulWidget {
  final Map<String, dynamic>? partner; // If null, create mode.

  const ContactFormScreen({super.key, this.partner});

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final OdooService _odooService = OdooService.instance;

  // Identity
  bool _isCompany = true;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _vatController = TextEditingController();

  // Address
  final _streetController = TextEditingController();
  final _street2Controller = TextEditingController(); // Calle 2...
  final _cityController = TextEditingController();
  final _stateController = TextEditingController(); // Estado
  final _zipController = TextEditingController(); // CREMAL... ? Use ZIP
  final _countryController = TextEditingController(); // Pais

  // Invoicing
  final _bankAccountController =
      TextEditingController(); // Simple string for now

  // Notes
  final _notesController = TextEditingController();

  // Person Specific
  final _birthdayController = TextEditingController();
  final _companyNameController = TextEditingController();

  // --- NEW FIELDS ---
  // Ventas
  final _sellerController = TextEditingController();
  final _salesPaymentTermsController = TextEditingController();
  final _salesPaymentMethodController = TextEditingController();
  final _deliveryMethodController = TextEditingController();

  // Compra
  final _buyerController = TextEditingController(); // Comprador
  final _purchasePaymentTermsController = TextEditingController();
  final _purchasePaymentMethodController = TextEditingController();
  bool _receiptReminder = false; // Recordatorio de recibo

  // Información Fiscal
  final _fiscalPositionController = TextEditingController(); // Situación fiscal

  // Varios
  final _companyIdController = TextEditingController(); // ID de la empresa
  final _referenceController = TextEditingController();
  final _industryController = TextEditingController();

  // Facturación (Extra)
  final _invoiceSendingController = TextEditingController();
  final _invoiceFormatController = TextEditingController();
  final _peppolController = TextEditingController();

  // Asignación de socios
  final _geoLatController = TextEditingController(text: "0.0000000");
  final _geoLongController = TextEditingController(text: "0.0000000");

  // Image State
  File? _imageFile;
  String? _base64Image; // To send to Odoo
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    if (widget.partner != null) {
      final p = widget.partner!;
      _nameController.text = p['name'] ?? '';
      _emailController.text = p['email'] is String ? p['email'] : '';
      _phoneController.text = p['phone'] is String ? p['phone'] : '';
      _streetController.text = p['street'] is String ? p['street'] : '';
      _cityController.text = p['city'] is String ? p['city'] : '';

      // Attempt to load other fields if available in map, or leave empty
      if (p['is_company'] == true) _isCompany = true;

      // Load existing image if available
      // Usually 'image_128' or 'image_1920' comes as base64 string
      if (p['image_1920'] is String && (p['image_1920'] as String).isNotEmpty) {
        _base64Image = p['image_1920'];
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _vatController.dispose();
    _streetController.dispose();
    _street2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    _bankAccountController.dispose();
    _notesController.dispose();
    _birthdayController.dispose();
    _companyNameController.dispose();
    _sellerController.dispose();
    _salesPaymentTermsController.dispose();
    _salesPaymentMethodController.dispose();
    _deliveryMethodController.dispose();
    _buyerController.dispose();
    _purchasePaymentTermsController.dispose();
    _purchasePaymentMethodController.dispose();
    _fiscalPositionController.dispose();
    _companyIdController.dispose();
    _referenceController.dispose();
    _industryController.dispose();
    _invoiceSendingController.dispose();
    _invoiceFormatController.dispose();
    _peppolController.dispose();
    _geoLatController.dispose();
    _geoLongController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, // Limit size for Odoo
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageFile = File(pickedFile.path);
          _base64Image = base64Encode(bytes);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error picking image: $e")));
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    // Prepare data
    final data = {
      'name': _nameController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
      'is_company': _isCompany,
      'street': _streetController.text,
      'street2': _street2Controller.text,
      'city': _cityController.text,
      // 'state_id': ... would require ID lookup
      // 'country_id': ... would require ID lookup
      'zip': _zipController.text,
      'vat': _vatController.text,
      'website': _websiteController.text,
      'comment': _notesController.text,
      'parent_name':
          _companyNameController.text, // Rough mapping for Company Name
      // 'function': ... Job Position if needed
    };

    // Add date only if not empty
    if (_birthdayController.text.isNotEmpty) {
      // Typically Odoo expects YYYY-MM-DD, assuming user enters correctly or we parse
      // For this MVP, we just send it if backend accepts string, otherwise might need formatting
      // data['birthdate'] = _birthdayController.text;
    }

    if (_base64Image != null) {
      data['image_1920'] = _base64Image!;
    }

    try {
      if (widget.partner == null) {
        // Create
        await _odooService.createContact(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Contact Created Successfully!")),
          );
          Navigator.pop(context, true); // Return true to refresh list
        }
      } else {
        // Update
        // Ensure we have an ID
        final id = widget.partner!['id'];
        if (id is int) {
          await _odooService.updateContact(id, data);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Contact Updated Successfully!")),
            );
            Navigator.pop(context, true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving contact: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.partner != null ? "Edit Contact" : "New Contact",
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      "Save",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.black,
            unselectedLabelColor: Color(0xFF64748B),
            indicatorColor: Colors.black,
            tabs: [
              Tab(text: "Contactos"),
              Tab(text: "Compra y venta"),
              Tab(text: "Facturación"),
              Tab(text: "Asignación de socios"),
              Tab(text: "Notas"),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _buildContactsTab(),
              _buildSalesTab(),
              _buildInvoicingTab(),
              _buildPartnerAssignTab(),
              _buildNotesTab(),
            ],
          ),
        ),
      ),
    );
  }

  // --- Header Card (Reused in all Tabs for consistency per user request) ---
  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24), // Increased padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              // Image / Logo with Picker (Centered and Larger)
              Center(
                child: InkWell(
                  onTap: _pickImage,
                  child: Container(
                    width: 120, // Larger size
                    height: 120, // Larger size
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: _buildImageWidget(),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Identity Fields (Stacked below)
              // Radio Buttons: Person vs Company (Centered)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildRadio("Persona", false),
                  const SizedBox(width: 24),
                  _buildRadio("Compañía", true),
                ],
              ),
              const SizedBox(height: 24),

              // Name Field
              TextField(
                controller: _nameController,
                textAlign: TextAlign
                    .center, // Center text for better look in this layout
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
                decoration: const InputDecoration(
                  hintText: "Nombre...",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),

              // Company Name (For Person)
              if (!_isCompany)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: _companyNameController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF64748B),
                    ),
                    decoration: const InputDecoration(
                      hintText: "Nombre de la Compañía",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              const Divider(),
            ],
          ),
          const SizedBox(height: 32),

          // Address & Contact Grid
          // Contact Info Section
          const SizedBox(height: 24),
          _buildSectionHeader("INFORMACIÓN DE CONTACTO"),
          const SizedBox(height: 16),
          // Phone & Email (Always visible)
          // Teléfono + Call Button row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _buildLabeledField(
                  "Teléfono",
                  _phoneController,
                  hint: "+1 234 567 890",
                ),
              ),
              const SizedBox(width: 12),
              // Reactive Call Button
              ListenableBuilder(
                listenable: VoipService.instance.callManager,
                builder: (context, child) {
                  final isRegistered =
                      VoipService.instance.callManager.state ==
                      AppCallState.registered;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: isRegistered
                            ? Colors.green
                            : Colors.grey[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(16),
                      ),
                      tooltip: isRegistered ? "Llamar" : "Conectando...",
                      icon: isRegistered
                          ? const Icon(Icons.phone, color: Colors.white)
                          : const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                      onPressed: isRegistered
                          ? () {
                              if (_phoneController.text.isNotEmpty) {
                                VoipService.instance.makeCall(
                                  _phoneController.text,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Llamando a ${_phoneController.text}...",
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Ingrese un número para llamar",
                                    ),
                                  ),
                                );
                              }
                            }
                          : null,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLabeledField(
            "Correo Electrónico",
            _emailController,
            hint: "ejemplo@correo.com",
          ),
          const SizedBox(height: 16),

          // Website
          _buildLabeledField(
            "Sitio web",
            _websiteController,
            hint: "https://...",
          ),
          const SizedBox(height: 16),

          // Conditional Fields
          if (_isCompany)
            _buildLabeledField(
              "Identificación Fiscal",
              _vatController,
              hint: "RUC / VAT",
            ),

          if (!_isCompany)
            _buildLabeledField(
              "Fecha de Nacimiento",
              _birthdayController,
              hint: "DD/MM/AAAA",
            ),

          const SizedBox(height: 16),
          // Etiqueta logic
          _buildLabeledField(
            "Etiquetas",
            TextEditingController(),
            hint: "B2B, VIP...",
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),

          // Address Section
          _buildSectionHeader("DIRECCIÓN"),
          const SizedBox(height: 16),
          _buildTextField("Calle...", _streetController),
          const SizedBox(height: 16),
          _buildTextField("Calle 2...", _street2Controller),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTextField("Ciudad", _cityController)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField("Estado", _stateController)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTextField("CP", _zipController)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField("País", _countryController)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadio(String label, bool value) {
    return InkWell(
      onTap: () => setState(() => _isCompany = value),
      child: Row(
        children: [
          Icon(
            _isCompany == value
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
            color: _isCompany == value ? Colors.black : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildImageWidget() {
    // If we have a local file, show it
    if (_imageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          _imageFile!,
          fit: BoxFit.cover,
          width: 80,
          height: 80,
        ),
      );
    }

    // If we have base64 image from Odoo, try to decode it safely
    if (_base64Image != null && _base64Image!.isNotEmpty) {
      try {
        final bytes = base64Decode(_base64Image!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) {
              // If image fails to load, show placeholder
              return const Icon(
                Icons.broken_image,
                size: 30,
                color: Colors.grey,
              );
            },
          ),
        );
      } catch (e) {
        debugPrint("Error decoding base64 image: $e");
        // If decoding fails, show error icon
        return const Icon(Icons.broken_image, size: 30, color: Colors.grey);
      }
    }

    // No image, show placeholder
    return const Icon(Icons.add_a_photo, size: 30, color: Colors.grey);
  }

  // --- Tab Contents ---

  Widget _buildLayout(Widget content) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // _buildHeaderCard() removed from here to show only in Contact tab
          content,
          const SizedBox(height: 80), // Footer padding
        ],
      ),
    );
  }

  Widget _buildContactsTab() {
    return _buildLayout(
      Column(
        children: [
          _buildHeaderCard(), // Header Card moved here
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Text(
                    "Agregar contacto",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTab() {
    return _buildLayout(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // VENTAS Section
          _buildSectionHeader("VENTAS"),
          const SizedBox(height: 16),
          _buildLabeledField("¿ Vendedor ?", _sellerController),
          const SizedBox(height: 12),
          _buildLabeledField(
            "Condiciones de pago",
            _salesPaymentTermsController,
          ),
          const SizedBox(height: 12),
          _buildLabeledField("Método de pago", _salesPaymentMethodController),
          const SizedBox(height: 12),
          _buildLabeledField("Método de entrega ?", _deliveryMethodController),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 32),

          // COMPRA Section
          _buildSectionHeader("COMPRA"),
          const SizedBox(height: 16),
          _buildLabeledField(
            "Solicitar cotización de grupo ?",
            TextEditingController(),
            hint: "On Order",
          ), // Mock logic
          const SizedBox(height: 12),
          _buildLabeledField("Comprador", _buyerController),
          const SizedBox(height: 12),
          _buildLabeledField(
            "Condiciones de pago",
            _purchasePaymentTermsController,
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            "Método de pago",
            _purchasePaymentMethodController,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                "¿Recordatorio de recibo ?",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Checkbox(
                value: _receiptReminder,
                onChanged: (v) => setState(() => _receiptReminder = v ?? false),
              ),
            ],
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 32),

          // INFO FISCAL Section
          _buildSectionHeader("INFORMACIÓN FISCAL"),
          const SizedBox(height: 16),
          _buildLabeledField("¿ Situación fiscal ?", _fiscalPositionController),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 32),

          // VARIOS Section
          _buildSectionHeader("VARIOS"),
          const SizedBox(height: 16),
          _buildLabeledField("¿ ID de la empresa ?", _companyIdController),
          const SizedBox(height: 12),
          _buildLabeledField("Referencia", _referenceController),
          const SizedBox(height: 12),
          _buildLabeledField("Sitio web ?", _websiteController),
          const SizedBox(height: 12),
          _buildLabeledField("Industria", _industryController),
        ],
      ),
    );
  }

  Widget _buildInvoicingTab() {
    return _buildLayout(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // _buildHeaderCard(), // Removed as per previous logic
          const SizedBox(height: 24),

          // GENERAL Section
          _buildSectionHeader("GENERAL"),
          const SizedBox(height: 16),
          _buildLabeledField(
            "bancos",
            _bankAccountController,
            hint: "Ingrese bancos...",
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 32),

          // FACTURAS DE CLIENTES Section
          _buildSectionHeader("FACTURAS DE CLIENTES"),
          const SizedBox(height: 16),
          _buildLabeledField(
            "Envío de facturas",
            _invoiceSendingController,
            hint: "Facturación electrónica...",
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            "Formato de factura electrónica",
            _invoiceFormatController,
            hint: "Formato XML",
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            "Identificación de Peppol",
            _peppolController,
            hint: "Su punto final",
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerAssignTab() {
    return _buildLayout(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("GEOLOCALIZACIÓN"),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text(
                "Ubicación geográfica",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text("Años : "),
                        Expanded(
                          child: TextField(
                            controller: _geoLatController,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    Row(
                      children: [
                        const Text("Largo: "),
                        Expanded(
                          child: TextField(
                            controller: _geoLongController,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () {
                // Mock calculation
                setState(() {
                  _geoLatController.text = "19.4326077";
                  _geoLongController.text = "-99.133208";
                });
              },
              icon: const Icon(Icons.settings, color: Colors.red, size: 16),
              label: const Text(
                "Calcular en función de la dirección",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    return _buildLayout(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "NOTAS INTERNAS",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesController,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: "Escribe cualquier nota relevante aquí...",
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Ingrese $label",
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledField(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint ?? "Ingrese $label",
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(value, style: const TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
