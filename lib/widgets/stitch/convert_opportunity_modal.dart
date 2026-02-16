import 'package:flutter/material.dart';
import '../../services/crm_service.dart';
import '../../services/odoo_service.dart';
import '../../config/api_endpoints.dart';
import '../../utils/odoo_utils.dart';

enum CustomerAction { createNew, linkExisting }

class ConvertOpportunityModal extends StatefulWidget {
  final VoidCallback? onConversionComplete;
  final int? stageId; // Optional stage ID to drop the opportunity into

  const ConvertOpportunityModal({
    super.key,
    this.onConversionComplete,
    this.stageId,
  });

  @override
  State<ConvertOpportunityModal> createState() =>
      _ConvertOpportunityModalState();
}

class _ConvertOpportunityModalState extends State<ConvertOpportunityModal> {
  final _formKey = GlobalKey<FormState>();
  CustomerAction _action = CustomerAction.createNew;
  final CrmService _crmService = CrmService();
  final OdooService _odooService = OdooService.instance;

  // Controllers
  final _nameController = TextEditingController(
    text: "Branding Project - Markdebrand",
  );
  final _revenueController = TextEditingController(text: "");
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _searchController = TextEditingController();

  // State
  bool _isLoading = false;
  List<dynamic> _searchResults = [];
  int? _selectedPartnerId;
  String? _selectedPartnerName;
  bool _isSearching = false;

  @override
  void dispose() {
    _nameController.dispose();
    _revenueController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _descController.dispose();
    _contactNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPartners(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final res = await _odooService.callKw(
        model: ApiRoutes.partners.model,
        method: ApiRoutes.auth.searchRead,
        args: [],
        kwargs: {
          'domain': [
            ['name', 'ilike', query],
          ],
          'fields': ['id', 'name', 'email', 'phone'],
          'limit': 5,
        },
      );
      if (mounted) {
        setState(() {
          _searchResults = res as List? ?? [];
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _confirmConversion() async {
    if (!_formKey.currentState!.validate()) return;

    if (_action == CustomerAction.linkExisting && _selectedPartnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a customer to link.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> vals = {
        'name': _nameController.text,
        'expected_revenue': double.tryParse(_revenueController.text) ?? 0.0,
        'type': 'opportunity', // Essential for pipeline visibility
        'priority': '1', // Default high priority
        // Missing fields added:
        'email_from': _emailController.text,
        'phone': _phoneController.text,
        'description': _descController.text,
        'contact_name': _contactNameController.text.isNotEmpty
            ? _contactNameController.text
            : (_selectedPartnerName ??
                  ''), // Use partner name if contact name empty
      };

      if (_action == CustomerAction.linkExisting) {
        vals['partner_id'] = _selectedPartnerId;
      }

      if (widget.stageId != null) {
        vals['stage_id'] = widget.stageId;
      }

      await _crmService.createLead(vals);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Converted to Opportunity successfully!"),
          ),
        );
        Navigator.pop(context); // Close modal
        widget.onConversionComplete?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colors from design
    const kPrimaryColor = Color(0xFF0d59f2);
    const kBgLight = Color(0xFFf5f6f8);
    const kTextDark = Color(0xFF0d121c);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFced7e8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Convert to Opportunity",
                  style: TextStyle(
                    color: kTextDark,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Confirm conversion and link this lead to a customer profile.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Radio Toggles
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          _buildRadioTile(
                            title: "Create new customer",
                            value: CustomerAction.createNew,
                            groupValue: _action,
                            onChanged: (v) => setState(() => _action = v!),
                          ),
                          const SizedBox(width: 12),
                          _buildRadioTile(
                            title: "Link existing",
                            value: CustomerAction.linkExisting,
                            groupValue: _action,
                            onChanged: (v) => setState(() => _action = v!),
                          ),
                        ],
                      ),
                    ),

                    // Select Customer Dropdown (Conditional)
                    if (_action == CustomerAction.linkExisting) ...[
                      const Text(
                        "Select Existing Customer",
                        style: TextStyle(
                          color: kTextDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildCustomerSearch(),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFf1f5f9)),
                      const SizedBox(height: 16),
                    ],

                    // Opportunity Name
                    const Text(
                      "Opportunity Name",
                      style: TextStyle(
                        color: kTextDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: _inputDecoration(
                        hint: "e.g. Branding Project",
                      ),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 16),

                    // Expected Revenue
                    const Text(
                      "Expected Revenue",
                      style: TextStyle(
                        color: kTextDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _revenueController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        hint: "0.00",
                        prefixIcon: const Icon(Icons.attach_money, size: 18),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // NEW FIELDS: Contact Details (Email, Phone, Contact Name)
                    const Text(
                      "Contact Details",
                      style: TextStyle(
                        color: kTextDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration(
                              hint: "Email",
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: _inputDecoration(
                              hint: "Phone",
                              prefixIcon: const Icon(
                                Icons.phone_outlined,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactNameController,
                      decoration: _inputDecoration(
                        hint: "Contact Name (e.g. John Doe)",
                        prefixIcon: const Icon(Icons.person_outline, size: 18),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    const Text(
                      "Internal Notes / Description",
                      style: TextStyle(
                        color: kTextDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        hint: "Add details about the opportunity...",
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: kBgLight,
              border: Border(top: BorderSide(color: Color(0xFFced7e8))),
            ),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _confirmConversion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    shadowColor: kPrimaryColor.withValues(alpha: 0.2),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check_circle_outline, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Confirm Conversion",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: kTextDark,
                    side: const BorderSide(color: Color(0xFFced7e8)),
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedPartnerId != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFced7e8)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF0d59f2)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    OdooUtils.safeString(_selectedPartnerName),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _selectedPartnerId = null;
                      _selectedPartnerName = null;
                      // Clear fields if unlinked? Or keep them? Keeping is safer.
                    });
                  },
                ),
              ],
            ),
          ),
        ] else ...[
          // Search Input
          TextField(
            controller: _searchController,
            decoration: _inputDecoration(
              hint: "Search customers...",
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search, color: Colors.grey),
            ),
            onChanged: (val) {
              if (val.length > 2) _searchPartners(val);
            },
          ),
          // Results Dropdown
          if (_searchResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFced7e8)),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (ctx, i) {
                  final p = _searchResults[i];
                  return ListTile(
                    dense: true,
                    title: Text(OdooUtils.safeString(p['name'])),
                    subtitle: Text(
                      OdooUtils.safeString(p['email']),
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedPartnerId = p['id'];
                        _selectedPartnerName = p['name'];
                        _searchResults = [];
                        _searchController.clear();

                        // AUTO-FILL Logic
                        if (_emailController.text.isEmpty) {
                          _emailController.text = OdooUtils.safeString(
                            p['email'],
                          );
                        }
                        if (_phoneController.text.isEmpty) {
                          _phoneController.text = OdooUtils.safeString(
                            p['phone'],
                          );
                        }
                        if (_contactNameController.text.isEmpty) {
                          _contactNameController.text = OdooUtils.safeString(
                            p['name'],
                          );
                        }
                      });
                    },
                  );
                },
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildRadioTile({
    required String title,
    required CustomerAction value,
    required CustomerAction groupValue,
    required ValueChanged<CustomerAction?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0d59f2).withValues(alpha: 0.05)
                : Colors.white,
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0d59f2)
                  : const Color(0xFFced7e8),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? const Color(0xFF0d121c) : Colors.grey[700],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFced7e8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF0d59f2), width: 2),
      ),
    );
  }
}
