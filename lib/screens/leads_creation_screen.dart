import 'package:flutter/material.dart';
import '../services/odoo_service.dart';

class LeadCreationScreen extends StatefulWidget {
  const LeadCreationScreen({super.key});

  @override
  State<LeadCreationScreen> createState() => _LeadCreationScreenState();
}

class _LeadCreationScreenState extends State<LeadCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final OdooService _odoo = OdooService.instance;

  // Page Controller for Wizard
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // --- CONTROLLERS ---

  // 1. OPPORTUNITY
  final _nameController = TextEditingController(); // Opportunity Name
  final _revenueController = TextEditingController(text: "0.00");
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  int _priority = 0; // 0: Low, 1: Medium, 2: High, 3: Very High
  // Tags managed via list

  // 2. COMPANY INFO
  final _companyNameController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();
  final _countryController = TextEditingController(); // Just text for now
  final _languageController = TextEditingController();

  // 3. CONTACT INFO
  final _contactNameController = TextEditingController();
  final _jobPositionController = TextEditingController();
  final _websiteController = TextEditingController();

  // 4. MARKETING
  final _campaignController = TextEditingController();
  final _mediumController = TextEditingController();
  final _sourceController = TextEditingController();
  final _referredByController = TextEditingController();

  // 5. PROPERTY (Sales/Tracking)
  final _teamController = TextEditingController();
  final _salespersonController = TextEditingController();

  // 6. NOTES (Step 2)
  final _notesController = TextEditingController();

  // Unused but kept to match Odoo fields physically if needed later
  final _paymentTermsController = TextEditingController();
  final _priceListController = TextEditingController();

  // --- SELECTION OPTIONS ---
  static const List<String> _opportunityNames = [
    "Desarrollo Módulos Odoo",
    "Desarrollo OnePage",
    "Desarrollo Agente IA",
    "Desarrollo de APK",
    "Desarrollo E-Commerce",
    "Desarrollo Website",
    "Desarrollo LMS",
    "Desarrollo Landing Page",
    "Desarrollo de Marca",
    "Seo on Page y Mantenimiento Seo",
    "Community Manager",
    "Funcionalidades Avanzadas",
    "Tarea Menor",
    "No Aplica",
  ];

  static const List<String> _campaignOptions = ["InBound", "OutBound"];

  static const List<String> _mediumOptions = [
    "Email",
    "Facebook",
    "Phone",
    "Whatsapp",
    "LinkedIn",
    "Instagram Msn",
  ];

  static const List<String> _sourceOptions = [
    "WIX MDB InBound",
    "WIX MDB OutBound",
    "WIX Prisma InBound",
    "WIX Prisma OutBound",
    "Cliente",
    "Facebook Campana",
    "Facebook Grupo",
    "Facebook Post",
    "Facebook InBound",
    "Instagram InBound",
    "Instagram OutBound",
    "LinkedIn",
    "Website MDB",
    "Website Prisma",
  ];

  static const List<String> _nicheOptions = [
    "Undefined",
    "Estudiantes",
    "Error Solicitud",
    "Restaurant",
    "Real State",
    "Supermarkets",
    "Legal Services",
    "technology",
    "Hotel",
    "Travel Agency",
    "Mechanics Workshops",
    "Health Wellness",
    "Sports",
    "Administrative and Financial Services",
    "Education Services",
    "Tourism",
    "Fashion",
    "Manufacture",
    "Retail",
    "Marketing & Advertising",
    "Music",
    "Insurance",
    "Architecture & Planning",
    "Wholesale",
    "Medical Devices",
    "Media Production",
    "Telecomunications",
    "Logistics & Supply Chain",
    "Construction",
    "Hospitality",
    "Renewable Energy",
    "Entertaiment",
  ];

  // Tags Logic (Hardcoded as per request)
  final List<Map<String, dynamic>> _tagOptions = [
    {'id': -1, 'name': 'Viable'},
    {'id': -2, 'name': 'No Viable'},
  ];
  List<dynamic> _selectedTags = [];
  String? _selectedNiche = "Undefined";

  @override
  void initState() {
    super.initState();
    _teamController.text = "Sales";
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final profile = await _odoo.getUserProfile();
      if (mounted) {
        setState(() {
          _salespersonController.text = profile['name'] ?? "";
        });
      }
    } catch (e) {
      debugPrint("Error loading user profile: $e");
    }
    // We override Odoo tags with requested ones if desired,
    // but we can also load them to see if they match.
    // For now we use the requested hardcoded ones.
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _revenueController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _companyNameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    _languageController.dispose();
    _contactNameController.dispose();
    _jobPositionController.dispose();
    _websiteController.dispose();
    _campaignController.dispose();
    _mediumController.dispose();
    _sourceController.dispose();
    _referredByController.dispose();
    _teamController.dispose();
    _salespersonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showTagSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select Tags",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tagOptions.map((tag) {
                      final isSelected = _selectedTags.any(
                        (t) => t['name'] == tag['name'],
                      );
                      return FilterChip(
                        label: Text(tag['name']),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          setModalState(() {
                            if (selected) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.removeWhere(
                                (t) => t['name'] == tag['name'],
                              );
                            }
                          });
                          setState(() {});
                        },
                        selectedColor: const Color(0xFF0D59F2).withOpacity(0.2),
                        checkmarkColor: const Color(0xFF0D59F2),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSingleSelectionSelector({
    required String title,
    required List<String> options,
    required String? currentValue,
    required Function(String) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final isSelected = option == currentValue;
                      return ListTile(
                        title: Text(
                          option,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF0D59F2)
                                : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Color(0xFF0D59F2))
                            : null,
                        onTap: () {
                          onSelected(option);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    // If we are on step 2, we assume step 1 was validated before entering.
    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text,
        'partner_name': _companyNameController.text,
        'contact_name': _contactNameController.text,
        'function': _jobPositionController.text,
        'website': _websiteController.text,
        'email_from': _emailController.text,
        'phone': _phoneController.text,

        'street': _streetController.text,
        'city': _cityController.text,
        'zip': _zipController.text,

        // Financials
        'expected_revenue': double.tryParse(_revenueController.text) ?? 0.0,
        'priority': _priority.toString(),

        // Manual "Description" construction including all the fields that aren't native or need lookup
        'description':
            '${_notesController.text}\n\n' // Internal Notes first
            '--- Auto-Generated Details ---\n'
            'Niche: ${_selectedNiche ?? "Undefined"}\n'
            'Tags: ${_selectedTags.map((t) => t['name']).join(", ")}\n'
            'Language: ${_languageController.text}\n'
            'Campaign: ${_campaignController.text}\n'
            'Medium: ${_mediumController.text}\n'
            'Source: ${_sourceController.text}\n'
            'Referred By: ${_referredByController.text}\n'
            'Sales Team: ${_teamController.text}\n'
            'Salesperson: ${_salespersonController.text}',

        'type': 'opportunity',
      };

      await _odoo.createLead(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Opportunity Created Successfully!")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validate Form 1
      if (!_formKey.currentState!.validate()) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = 1);
    }
  }

  void _prevStep() {
    if (_currentStep == 1) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = 0);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [_buildFormStep(), _buildNotesStep()],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _prevStep,
            child: Row(
              children: [
                const Icon(
                  Icons.arrow_back_ios,
                  size: 20,
                  color: Color(0xFF0D59F2),
                ),
                Text(
                  _currentStep == 0 ? "Back" : "Details",
                  style: const TextStyle(
                    color: Color(0xFF0D59F2),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _currentStep == 0 ? "New Opportunity" : "Internal Notes",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          // Action Button (Next or Create)
          TextButton(
            onPressed: _currentStep == 0 ? _nextStep : _submit,
            child: Text(
              _currentStep == 0 ? "Next" : "Create",
              style: const TextStyle(
                color: Color(0xFF0D59F2),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 1: Main Form ---
  Widget _buildFormStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("OPPORTUNITY"),
            _buildCard(
              children: [
                _buildSelectionField(
                  "Opportunity Name",
                  _nameController.text.isEmpty
                      ? "Select Option"
                      : _nameController.text,
                  required: true,
                  onTap: () {
                    _showSingleSelectionSelector(
                      title: "Opportunity Name",
                      options: _opportunityNames,
                      currentValue: _nameController.text,
                      onSelected: (val) {
                        setState(() => _nameController.text = val);
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildStitchTextField(
                  "Expected Revenue",
                  _revenueController,
                  inputType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildStitchTextField(
                  "Email",
                  _emailController,
                  inputType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildStitchTextField(
                  "Phone",
                  _phoneController,
                  inputType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildTagsSelector(),
              ],
            ),
            const SizedBox(height: 24),

            // 2. COMPANY INFO
            _buildSectionTitle("COMPANY INFO"),
            _buildCard(
              children: [
                _buildStitchTextField("Company Name", _companyNameController),
                const SizedBox(height: 16),

                // Address nested
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildStitchTextField("Street", _streetController),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStitchTextField(
                              "City",
                              _cityController,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStitchTextField("Zip", _zipController),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildStitchTextField("Country", _countryController),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildStitchTextField("Language", _languageController),
              ],
            ),
            const SizedBox(height: 24),

            // 3. CONTACT INFO
            _buildSectionTitle("CONTACT INFO"),
            _buildCard(
              children: [
                _buildStitchTextField("Contact Name", _contactNameController),
                const SizedBox(height: 16),
                _buildStitchTextField("Job Position", _jobPositionController),
                const SizedBox(height: 16),
                _buildStitchTextField("Website", _websiteController),
              ],
            ),
            const SizedBox(height: 24),

            // 4. MARKETING
            _buildSectionTitle("MARKETING"),
            _buildCard(
              children: [
                _buildSelectionField(
                  "Campaign",
                  _campaignController.text.isEmpty
                      ? "Select Option"
                      : _campaignController.text,
                  onTap: () {
                    _showSingleSelectionSelector(
                      title: "Campaign",
                      options: _campaignOptions,
                      currentValue: _campaignController.text,
                      onSelected: (val) {
                        setState(() => _campaignController.text = val);
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildSelectionField(
                  "Medium",
                  _mediumController.text.isEmpty
                      ? "Select Option"
                      : _mediumController.text,
                  onTap: () {
                    _showSingleSelectionSelector(
                      title: "Medium",
                      options: _mediumOptions,
                      currentValue: _mediumController.text,
                      onSelected: (val) {
                        setState(() => _mediumController.text = val);
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildSelectionField(
                  "Source",
                  _sourceController.text.isEmpty
                      ? "Select Option"
                      : _sourceController.text,
                  onTap: () {
                    _showSingleSelectionSelector(
                      title: "Source",
                      options: _sourceOptions,
                      currentValue: _sourceController.text,
                      onSelected: (val) {
                        setState(() => _sourceController.text = val);
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildSelectionField(
                  "Niches",
                  _selectedNiche ?? "Undefined",
                  onTap: () {
                    _showSingleSelectionSelector(
                      title: "Niches",
                      options: _nicheOptions,
                      currentValue: _selectedNiche,
                      onSelected: (val) {
                        setState(() => _selectedNiche = val);
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildStitchTextField("Referred By", _referredByController),
              ],
            ),
            const SizedBox(height: 24),

            // 5. PROPERTY
            _buildSectionTitle("PROPERTY"),
            _buildCard(
              children: [
                _buildStitchTextField("Sales Team", _teamController),
                const SizedBox(height: 16),
                _buildStitchTextField("Salesperson", _salespersonController),
              ],
            ),
            const SizedBox(height: 24),

            // DATES & TERMS
            _buildSectionTitle("DATES & TERMS"),
            _buildCard(
              children: [
                _buildStitchTextField("Payment Terms", _paymentTermsController),
                const SizedBox(height: 16),
                _buildStitchTextField("Price List", _priceListController),
              ],
            ),

            const SizedBox(height: 48), // Bottom padding
          ],
        ),
      ),
    );
  }

  // --- STEP 2: Notes ---
  Widget _buildNotesStep() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Add Internal Notes",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _notesController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: "Type any additional details or notes here...",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                ),
                style: const TextStyle(fontSize: 16, color: Color(0xFF1E293B)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D59F2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: const Text(
                "Create Opportunity",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // --- Helpers ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildStitchTextField(
    String label,
    TextEditingController controller, {
    bool required = false,
    TextInputType inputType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
            if (required)
              const Text(
                " *",
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: inputType,
            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: false,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            validator: required
                ? (val) => val == null || val.isEmpty ? "Required" : null
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionField(
    String label,
    String value, {
    bool required = false,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
            if (required)
              const Text(
                " *",
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
          ],
        ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: value == "Select Option"
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xFF64748B),
      ),
    );
  }

  Widget _buildTagsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel("Tags"),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _showTagSelector,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_selectedTags.isEmpty)
                  const Text(
                    "Select tags...",
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ..._selectedTags.map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (tag['color'] != null && tag['color'] != 0)
                          ? Colors.blue.withOpacity(0.1)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tag['name'],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.close,
                          size: 14,
                          color: Color(0xFF1E40AF),
                        ),
                      ],
                    ),
                  ),
                ),
                const Icon(
                  Icons.add_circle,
                  color: Color(0xFF0D59F2),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
