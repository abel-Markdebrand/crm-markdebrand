import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart'; // Added
import 'dart:io'; // Added
import 'dart:convert'; // Added
import '../services/odoo_service.dart';

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


  bool _isSaving = false;

  int _currentStep = 1;

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
      _street2Controller.text = p['street2'] is String ? p['street2'] : '';
      _cityController.text = p['city'] is String ? p['city'] : '';
      _stateController.text = p['state_id'] is List ? p['state_id'][1].toString() : '';
      _zipController.text = p['zip'] is String ? p['zip'] : '';
      _countryController.text = p['country_id'] is List ? p['country_id'][1].toString() : '';
      _bankAccountController.text = p['bank_ids'] is List && (p['bank_ids'] as List).isNotEmpty ? 'Linked Account' : '';
      _notesController.text = p['comment'] is String ? p['comment'] : '';
      _isCompany = p['is_company'] == true;

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
        maxWidth: 800,
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error picking image: $e")));
    }
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Por favor ingrese un nombre")));
      return;
    }

    setState(() => _isSaving = true);

    final data = {
      'name': _nameController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
      'is_company': _isCompany,
      'street': _streetController.text,
      'street2': _street2Controller.text,
      'city': _cityController.text,
      'zip': _zipController.text,
      'vat': _vatController.text,
      'website': _websiteController.text,
      'comment': _notesController.text,
    };

    if (_base64Image != null) {
      data['image_1920'] = _base64Image!;
    }

    try {
      if (widget.partner == null) {
        await _odooService.createContact(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Contacto creado exitosamente!")));
          Navigator.pop(context, true);
        }
      } else {
        final id = widget.partner!['id'];
        if (id is int) {
          await _odooService.updateContact(id, data);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Contacto actualizado exitosamente!")));
            Navigator.pop(context, true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al guardar: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _save();
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: _buildStepContent(),
              ),
            ),
            _buildNavigationFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title = "Contact Details";
    if (_currentStep == 2) title = "Location";
    if (_currentStep == 3) title = "Additional Info";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: _prevStep,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 48), // Balancing for back button
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          final step = index + 1;
          final isActive = step == _currentStep;
          final isCompleted = step < _currentStep;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 6,
            width: isActive ? 24 : 6,
            decoration: BoxDecoration(
              color: isActive || isCompleted ? Colors.black : Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1() {
    return Column(
      children: [
        const SizedBox(height: 16),
        // Image Picker Card
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: _imageFile != null || _base64Image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _imageFile != null
                        ? Image.file(_imageFile!, fit: BoxFit.cover)
                        : Image.memory(base64Decode(_base64Image!), fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, size: 32, color: Colors.black),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Add Image",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 32),
        // Name Input
        TextField(
          controller: _nameController,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: "Name...",
            hintStyle: TextStyle(color: Colors.grey[300]),
            border: InputBorder.none,
          ),
        ),
        Text(
          "sip:[new.contact@sip.linphone.org]",
          style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12),
        ),
        const SizedBox(height: 32),
        // Info Card
        _buildInfoCard([
          _buildStep1RadioFields(),
          _buildPremiumField(Icons.phone_forwarded, "Phone", _phoneController, hint: "+1 234 567 890", icon: Icons.call),
          _buildPremiumField(null, "Email", _emailController, hint: "example@mail.com", icon: Icons.mail),
          _buildPremiumField(null, "Date of Birth", _birthdayController, hint: "DD/MM/YYYY...", icon: Icons.calendar_today),
          _buildPremiumField(null, "Tags", TextEditingController(), hint: "B2B, VIP...", icon: Icons.label),
        ]),
      ],
    );
  }

  Widget _buildStep1RadioFields() {
    return Row(
      children: [
        const Icon(Icons.person, color: Colors.grey, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "TYPE",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildMiniRadio("Persona", !_isCompany, () => setState(() => _isCompany = false)),
                  const SizedBox(width: 16),
                  _buildMiniRadio("Company", _isCompany, () => setState(() => _isCompany = true)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniRadio(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: active ? Colors.black : Colors.grey[300]!, width: active ? 5 : 1),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        _buildInfoCard([
          _buildPremiumField(null, "Street", _streetController, hint: "Street address...", icon: Icons.home),
          _buildPremiumField(null, "Street 2", _street2Controller, hint: "Apartment, suite, unit...", icon: Icons.domain),
          _buildPremiumField(null, "City", _cityController, hint: "City...", icon: Icons.location_city),
          Row(
            children: [
              Expanded(child: _buildPremiumField(null, "State", _stateController, hint: "State...", icon: Icons.map)),
              const SizedBox(width: 16),
              Expanded(child: _buildPremiumField(null, "Zip Code", _zipController, hint: "ZIP...", icon: Icons.location_on)),
            ],
          ),
          _buildPremiumField(null, "Country", _countryController, hint: "Country...", icon: Icons.public),
        ]),
        const SizedBox(height: 32),
        // Map Preview
        Container(
          height: 140,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            image: const DecorationImage(
              image: NetworkImage("https://lh3.googleusercontent.com/aida-public/AB6AXuDLVyeuzrS7gdPPM7FFQC-tUHij_lb1WOfGBgOoZmHeUSKVf226LfzbZIMe2quLdqp7u1AZa8c8cVT4cRRBOw0AL3igmeVDSO4kAuMD7icVh7sxP36SCi56DbYozuYXpzYwBpJFl015-FcjASl83DXuGA_gNWdPhgREzB0EhAnqb__xkmAl-Vv1-1XfLrTVs_MZ-X-UN1LNMdmeBGod6bxZQouCqzjfTkylcqCU2b3MTY65I58KG2twe6G0oMAmwqwKHovxrsw5kxk"),
              fit: BoxFit.cover,
              opacity: 0.2,
            ),
            color: Colors.grey[100],
          ),
          child: const Center(
            child: Icon(Icons.my_location, size: 40, color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Other Details",
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        _buildInfoCard([
          _buildPremiumFieldAlt("Sales - Payment Terms", _salesPaymentTermsController, hint: "Terms...", icon: Icons.calendar_today),
          _buildPremiumFieldAlt("Purchase - Payment Terms", _purchasePaymentTermsController, hint: "Terms...", icon: Icons.calendar_month),
          _buildPremiumFieldAlt("Bank Account", _bankAccountController, hint: "Bank...", icon: Icons.account_balance),
          _buildPremiumFieldAlt("Internal Notes", _notesController, hint: "Add any private information...", icon: Icons.edit_note, isMultiline: true),
        ]),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: children.expand((w) => [w, const SizedBox(height: 24)]).toList()..removeLast(),
      ),
    );
  }

  Widget _buildPremiumField(IconData? suffix, String label, TextEditingController controller, {required String hint, required IconData icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Icon(icon, color: Colors.grey[300], size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: TextStyle(color: Colors.grey[300], fontWeight: FontWeight.normal),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                  ),
                  if (suffix != null) Icon(suffix, color: Colors.black, size: 20),
                ],
              ),
              const Divider(height: 1, thickness: 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumFieldAlt(String label, TextEditingController controller, {required String hint, required IconData icon, bool isMultiline = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1.0),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            maxLines: isMultiline ? 4 : 1,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey, size: 20),
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.normal),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0), Colors.white],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_currentStep == 3)
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text("SAVE CONTACT", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 10,
                shadowColor: Colors.black.withValues(alpha: 0.3),
              ),
            ),
          if (_currentStep < 3)
            ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 10,
                shadowColor: Colors.black.withValues(alpha: 0.3),
              ),
              child: const Text("Next", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          if (_currentStep > 1)
            TextButton(
              onPressed: _prevStep,
              child: const Text(
                "Back to previous step",
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
