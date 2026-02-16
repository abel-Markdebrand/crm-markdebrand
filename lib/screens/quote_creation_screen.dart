import 'package:flutter/material.dart';
import 'package:mvp_odoo/utils/odoo_utils.dart';
import '../services/quote_service.dart';
import '../services/odoo_service.dart'; // Direct access for fetching fetchables
import '../config/api_endpoints.dart';
import 'invoice_detail_screen.dart';

class QuoteCreationScreen extends StatefulWidget {
  final String partnerName;
  final int? partnerId;
  final int? opportunityId; // To link back to CRM

  const QuoteCreationScreen({
    super.key,
    required this.partnerName,
    this.partnerId,
    this.opportunityId,
  });

  @override
  State<QuoteCreationScreen> createState() => _QuoteCreationScreenState();
}

class _QuoteCreationScreenState extends State<QuoteCreationScreen> {
  final QuoteService _quoteService = QuoteService();
  final OdooService _odooService = OdooService.instance;

  // Form Controllers & State
  DateTime _expirationDate = DateTime.now().add(const Duration(days: 30));
  DateTime? _deliveryDate; // Fecha de entrega

  // Header Extra
  final _invoiceAddressController =
      TextEditingController(); // DirecciÃ³n de factura
  final _deliveryAddressController =
      TextEditingController(); // DirecciÃ³n de entrega
  final _recurringPlanController =
      TextEditingController(); // Plan recurrente (Manual text for now)

  // Tab: Other Info - Sales
  final _salesTeamController = TextEditingController();
  final _salespersonController = TextEditingController(); // Added
  // Equipo de ventas
  final _onlineSignatureController =
      TextEditingController(); // Firma online (bool logic or text)
  final _onlinePaymentController = TextEditingController(); // Pago online
  final _clientRefController =
      TextEditingController(); // Referencia del cliente
  final _fiscalPositionController = TextEditingController(); // PosiciÃ³n fiscal
  final _paymentMethodController = TextEditingController(); // MÃ©todo de pago
  final _projectController = TextEditingController(); // Proyecto

  // Tab: Other Info - Delivery
  final _weightController = TextEditingController(); // Peso transporte

  // Tab: Other Info - Tracking
  final _sourceDocumentController =
      TextEditingController(); // Documento de fuente
  final _opportunityController = TextEditingController(); // Oportunidad
  final _campaignController = TextEditingController(); // CampaÃ±a
  final _mediumController = TextEditingController(); // Medio
  final _sourceController = TextEditingController(); // Fuente
  final _nicheController = TextEditingController(); // Niche (Sync from CRM)

  // Lists for Dropdowns
  List<dynamic> _pricelists = [];
  List<dynamic> _paymentTerms = [];
  List<dynamic> _products = []; // Real products
  List<dynamic> _customers = []; // For generic creation

  // Tab: Notes
  final _termsController = TextEditingController(); // TÃ©rminos y condiciones

  // Selections (ID)
  int? _selectedPricelistId;
  int? _selectedPaymentTermId;
  int? _selectedPartnerId;

  // Track saved order to switch between create/write
  int? _savedOrderId;

  // Order Lines (Local State for MVP UI)
  List<Map<String, dynamic>> _lines = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadDependencies();
    // Default dummy data if needed or just empty
  }

  @override
  void dispose() {
    _invoiceAddressController.dispose();
    _deliveryAddressController.dispose();
    _recurringPlanController.dispose();
    _salesTeamController.dispose();
    _salespersonController.dispose(); // Added
    _onlineSignatureController.dispose();
    _onlinePaymentController.dispose();
    _clientRefController.dispose();
    _fiscalPositionController.dispose();
    _paymentMethodController.dispose();
    _projectController.dispose();
    _weightController.dispose();
    _sourceDocumentController.dispose();
    _opportunityController.dispose();
    _campaignController.dispose();
    _mediumController.dispose();
    _sourceController.dispose();
    _nicheController.dispose();
    super.dispose();
  }

  Future<void> _loadDependencies() async {
    // Fetch Pricelists
    try {
      final plResult = await _odooService.callKw(
        model: ApiRoutes.products.priceListModel,
        method: ApiRoutes.auth.searchRead,
        args: [],
        kwargs: {
          'fields': ['id', 'name'],
          'limit': 10,
        },
      );
      _pricelists = plResult as List;
    } catch (e) {
      debugPrint("Error fetching pricelists: $e");
    }

    // Fetch Payment Terms
    try {
      final ptResult = await _odooService.callKw(
        model: ApiRoutes.accounting.paymentTermModel,
        method: ApiRoutes.auth.searchRead,
        args: [],
        kwargs: {
          'fields': ['id', 'name'],
          'limit': 10,
        },
      );
      _paymentTerms = ptResult as List;
    } catch (e) {
      debugPrint("Error fetching payment terms: $e");
    }

    // Fetch Products
    try {
      final prodResult = await _odooService.callKw(
        model: ApiRoutes.products.productModel,
        method: ApiRoutes.auth.searchRead,
        args: [],
        kwargs: {
          'fields': ['id', 'name', 'list_price'],
          'domain': [
            ['sale_ok', '=', true],
          ],
          'limit': 20,
        },
      );
      _products = prodResult as List;
    } catch (e) {
      debugPrint("Error fetching products: $e");
    }

    // Fetch Customers if needed
    if (widget.partnerId == null) {
      try {
        final custResult = await _odooService.callKw(
          model: ApiRoutes.partners.model,
          method: ApiRoutes.auth.searchRead,
          args: [],
          kwargs: {
            'fields': ['id', 'name'],
            'domain': [
              ['customer_rank', '>', 0],
            ], // Simple domain
            'limit': 20,
          },
        );
        if (mounted) setState(() => _customers = custResult as List);
      } catch (e) {
        debugPrint("Error fetching customers: $e");
      }
    } else {
      // If partnerId is passed, we might need to fetch THAT specific partner to show in dropdown
      // or just trust it's there. For now, let's assume we don't need to fetch list if we have one?
      // Actually, the dropdown needs the list. So we should fetch list AND ensure our partner is in it.
      // OR we just fetch the single partner and add to list.
      try {
        final p = await _odooService.getContactDetail(widget.partnerId!);
        if (mounted) {
          setState(() {
            _customers = [p]; // Initialize list with this partner
            _selectedPartnerId = widget.partnerId;
          });
        }
      } catch (e) {
        debugPrint("Error fetching initial partner: $e");
      }
    }

    if (mounted) {
      setState(() {
        if (_pricelists.isNotEmpty) {
          _selectedPricelistId = _pricelists[0]['id'];
        }
        if (_paymentTerms.isNotEmpty) {
          _selectedPaymentTermId = _paymentTerms[0]['id'];
        }
      });
    }

    // --- SYNC OPPORTUNITY DATA ---
    if (widget.opportunityId != null) {
      try {
        final lead = await _odooService.getLeadDetail(widget.opportunityId!);
        if (mounted) {
          setState(() {
            _opportunityController.text = lead['name'] ?? "";

            // Many2one fields return [id, name]
            if (lead['campaign_id'] is List) {
              _campaignController.text = lead['campaign_id'][1];
            }
            if (lead['medium_id'] is List) {
              _mediumController.text = lead['medium_id'][1];
            }
            if (lead['source_id'] is List) {
              _sourceController.text = lead['source_id'][1];
            }
            if (lead['team_id'] is List) {
              _salesTeamController.text = lead['team_id'][1];
            }
            if (lead['user_id'] is List) {
              _salespersonController.text = lead['user_id'][1];
            }

            // Parse fields from description if available (fallback for non-native fields)
            final description = lead['description'] ?? "";
            final descLines = description.split("\n");
            for (var line in descLines) {
              final trimmed = line.trim();
              if (trimmed.startsWith("Niche:")) {
                _nicheController.text = trimmed
                    .replaceFirst("Niche:", "")
                    .trim();
              } else if (trimmed.startsWith("Campaign:")) {
                _campaignController.text = trimmed
                    .replaceFirst("Campaign:", "")
                    .trim();
              } else if (trimmed.startsWith("Medium:")) {
                _mediumController.text = trimmed
                    .replaceFirst("Medium:", "")
                    .trim();
              } else if (trimmed.startsWith("Source:")) {
                _sourceController.text = trimmed
                    .replaceFirst("Source:", "")
                    .trim();
              } else if (trimmed.startsWith("Sales Team:")) {
                _salesTeamController.text = trimmed
                    .replaceFirst("Sales Team:", "")
                    .trim();
              } else if (trimmed.startsWith("Salesperson:")) {
                _salespersonController.text = trimmed
                    .replaceFirst("Salesperson:", "")
                    .trim();
              }
            }
          });
        }
      } catch (e) {
        debugPrint("Error syncing opportunity: $e");
      }
    }
  }

  // --- Helper Methods ---

  List<Map<String, dynamic>> _sanitizeLines(List<Map<String, dynamic>> lines) {
    return lines.map((line) {
      // Create a copy without UI-only fields like 'detail'
      final sanitized = Map<String, dynamic>.from(line);
      sanitized.remove('detail');
      return sanitized;
    }).toList();
  }

  // --- Logic Implementations ---

  double get _untaxedAmount {
    return _lines.fold(
      0.0,
      (sum, line) => sum + (line['price_unit'] * line['product_uom_qty']),
    );
  }

  double get _taxAmount =>
      _untaxedAmount * 0.15; // Hardcoded 15% for visual demo as per HTML
  double get _totalAmount => _untaxedAmount + _taxAmount;

  Future<bool> _handleSaveDraft() async {
    // Validation: Pricelist is strictly required.
    // Fallback: If null, try to find ANY pricelist in the system as requested.
    if (_selectedPricelistId == null) {
      if (_pricelists.isNotEmpty) {
        _selectedPricelistId = _pricelists[0]['id'];
      } else {
        // Emergency fetch using Fail-Safe Strategy
        _selectedPricelistId = await _quoteService
            .getOrCreateDefaultPricelist();
      }

      // If key is ID 1 (manual fallback) or found, we proceed.
      // The service guarantees a return of 1 (Manual) worst case, so this check is extra safety.
      if (_selectedPricelistId == null) {
        if (!mounted) return false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Critical: Could not resolve any Pricelist."),
            ),
          );
        }
        return false;
      }
    }

    final finalPartnerId = widget.partnerId ?? _selectedPartnerId;
    if (finalPartnerId == null) {
      if (!mounted) return false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a customer")),
        );
      }
      return false;
    }

    setState(() => _isSaving = true);
    try {
      int? orderId;
      if (_savedOrderId == null) {
        // Create new quote
        orderId = await _quoteService.createQuote(
          partnerId: finalPartnerId,
          validityDate: _expirationDate,
          pricelistId: _selectedPricelistId!,
          paymentTermId: _selectedPaymentTermId,
          note: _termsController.text,
          clientOrderRef: _clientRefController.text.isNotEmpty
              ? _clientRefController.text
              : null,
          commitmentDate: _deliveryDate,
          lines: _sanitizeLines(_lines),
          opportunityId: widget.opportunityId,
        );
        if (mounted) {
          setState(() {
            _savedOrderId = orderId; // Store the new order ID
          });
        }
      } else {
        // Update existing quote
        // Strategy: Update headers. For lines, since we don't track IDs locally in this MVP list,
        // we use Command 5 (Unlink all) then Command 0 (Create) to sync the list.
        final updateVals = {
          'partner_id': widget.partnerId,
          'validity_date': _expirationDate.toIso8601String().substring(0, 10),
          'pricelist_id': _selectedPricelistId,
          'payment_term_id': _selectedPaymentTermId,
          'note': _termsController.text,
          'client_order_ref': _clientRefController.text,
          'order_line': [
            [5, 0, 0], // Remove all existing lines
            ..._sanitizeLines(
              _lines,
            ).map((l) => [0, 0, l]), // Add current lines
          ],
        };
        if (_deliveryDate != null) {
          updateVals['commitment_date'] = _deliveryDate!.toIso8601String();
        }
        if (widget.opportunityId != null) {
          updateVals['opportunity_id'] = widget.opportunityId;
        }

        await _quoteService.updateQuote(_savedOrderId!, updateVals);

        orderId = _savedOrderId;
      }

      if (!mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Draft ${orderId != null ? '(#$orderId) ' : ''}Saved!"),
        ),
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleSendToCustomer() async {
    setState(() => _isSaving = true);
    try {
      int orderId;
      if (_savedOrderId == null) {
        final success = await _handleSaveDraft(); // Save first
        if (!success) {
          // If save failed, validation checks already showed snackbars, so just return
          return;
        }
        orderId = _savedOrderId!;
      } else {
        orderId = _savedOrderId!;
      }

      // Change state to sent
      await _quoteService.markAsSent(orderId);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Quote Marked as Sent!")));
    } catch (e) {
      debugPrint("Send error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error Sending: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleConvertToInvoice() async {
    if (_selectedPricelistId == null || _selectedPaymentTermId == null) return;

    final finalPartnerId = widget.partnerId ?? _selectedPartnerId;
    if (finalPartnerId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a customer")));
      return;
    }

    setState(() => _isSaving = true);
    try {
      int orderId;
      if (_savedOrderId == null) {
        // 1. Create Order First
        orderId = await _quoteService.createQuote(
          partnerId: finalPartnerId,
          validityDate: _expirationDate,
          pricelistId: _selectedPricelistId!,
          paymentTermId: _selectedPaymentTermId!,
          lines: _sanitizeLines(_lines),
          opportunityId: widget.opportunityId,
        );
        if (mounted) setState(() => _savedOrderId = orderId);
      } else {
        // 1. Update Existing Order before converting
        try {
          await _quoteService.updateQuote(_savedOrderId!, {
            'partner_id': widget.partnerId,
            'validity_date': _expirationDate.toIso8601String().substring(0, 10),
            'pricelist_id': _selectedPricelistId,
            'payment_term_id': _selectedPaymentTermId,
            'order_line': [
              [5, 0, 0], // Remove all existing lines
              ..._sanitizeLines(
                _lines,
              ).map((l) => [0, 0, l]), // Add current lines
            ],
            'opportunity_id': widget.opportunityId,
          });
        } catch (updateError) {
          // If update fails because order is confirmed, we proceed to invoice anyway
          // This allows retrying invoice creation on a "stuck" confirmed order
          debugPrint(
            "Update failed (likely confirmed order), proceeding: $updateError",
          );
        }
        orderId = _savedOrderId!;
      }

      // 2. Transaction Script: Confirm -> Invoice
      final invoiceId = await _quoteService.convertToInvoice(orderId);

      if (!mounted) return;

      if (invoiceId != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Invoice #$invoiceId Created!")));

        // Navigate to Invoice Detail
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => InvoiceDetailScreen(invoiceId: invoiceId),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Order Confirmed but Invoice not created (Check Policy)",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Conversion error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error Converting: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "New Quote",
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [],
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Color(0xFF64748B),
            indicatorColor: Colors.black,
            tabs: [
              Tab(text: "Order Lines"),
              Tab(text: "Other Info"),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  // TAB 1: Order Lines
                  _buildOrderLinesTab(),

                  // TAB 2: Other Info
                  _buildOtherInfoTab(),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // --- Widgets Helpers ---

  Widget _buildOrderLinesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildQuoteHeaderCard(),
          const SizedBox(height: 16),
          // Order Lines List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Product",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
              // Add button header?
            ],
          ),
          const SizedBox(height: 8),
          ..._lines.map((line) => _buildOrderLineItem(line)),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showProductSelector,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text("Add product"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildTotalsCard(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildOtherInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Removed per user request

          // SALES
          _buildSectionHeader("SALES"),
          _buildTextField("Sales Team", _salesTeamController),
          const SizedBox(height: 12),
          _buildTextField("Salesperson", _salespersonController),
          const SizedBox(height: 12),
          _buildTextField("Customer Reference", _clientRefController),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChipInput("Tags"), // Mock
            ],
          ),
          const SizedBox(height: 24),

          // INVOICING
          _buildSectionHeader("INVOICING"),
          _buildTextField("Fiscal Position", _fiscalPositionController),
          const SizedBox(height: 12),
          _buildTextField("Analytic Account", _projectController),

          const SizedBox(height: 24),

          // DELIVERY
          _buildSectionHeader("DELIVERY"),
          _buildTextField(
            "Shipping Weight",
            _weightController,
            inputType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => _deliveryDate = d);
            },
            child: AbsorbPointer(
              child: _buildTextField(
                "Delivery Date",
                TextEditingController(
                  text: _deliveryDate?.toIso8601String().substring(0, 10) ?? "",
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // TRACKING
          _buildSectionHeader("TRACKING"),
          _buildTextField("Source Document", _sourceDocumentController),
          const SizedBox(height: 12),
          _buildTextField("Opportunity", _opportunityController),
          const SizedBox(height: 12),
          _buildTextField("Campaign", _campaignController),
          const SizedBox(height: 12),
          _buildTextField("Medium", _mediumController),
          const SizedBox(height: 12),
          _buildTextField("Source", _sourceController),
          const SizedBox(height: 12),
          _buildTextField("Niches", _nicheController),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildQuoteHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          // Customer Row
          _buildCustomerSelector(),
          const SizedBox(height: 16),

          // Extra Addresses
          _buildTextField("Invoice Address", _invoiceAddressController),
          const SizedBox(height: 8),
          _buildTextField("Delivery Address", _deliveryAddressController),
          const SizedBox(height: 16),

          // Terms Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel("Expiration"),
                    _buildDatePicker(),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel("Recurring Plan"),
                    SizedBox(
                      height: 48,
                      child: TextField(
                        controller: _recurringPlanController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel("Pricelist"),
                    _buildPricelistDropdown(),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel("Payment Terms"),
                    _buildPaymentTermDropdown(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType inputType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: inputType,
          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF1F5F9), // Light grey fill
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            // Remove border to make fields look bigger/cleaner as requested
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Colors.black,
                width: 1,
              ), // Minimal focus
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChipInput(String label) {
    return Chip(label: Text(label), backgroundColor: const Color(0xFFE2E8F0));
  }

  void _showProductSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Select Product",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _products.isEmpty
                    ? const Center(child: Text("No products found"))
                    : ListView.builder(
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          final name = OdooUtils.safeString(product['name']);
                          final price =
                              (product['list_price'] as num?)?.toDouble() ??
                              0.0;

                          return ListTile(
                            title: Text(name),
                            subtitle: Text("\$${price.toStringAsFixed(2)}"),
                            onTap: () {
                              setState(() {
                                _lines.add({
                                  'product_id': product['id'],
                                  'name': name,
                                  'price_unit': price,
                                  'product_uom_qty': 1.0,
                                  'price_total': price * 1.0, // Initial total
                                });
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomerSelector() {
    // If a partner is already selected (either passed in widget or selected via dropdown), show it
    final currentPartnerId = _selectedPartnerId ?? widget.partnerId;

    if (currentPartnerId != null) {
      // Find name if possible
      final p = _customers.firstWhere(
        (c) => c['id'] == currentPartnerId,
        orElse: () => {'name': 'Customer #$currentPartnerId'},
      );
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.person, color: Color(0xFF64748B)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Customer",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  Text(
                    p['name'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            // Optional: Allow changing customer?
            IconButton(
              icon: const Icon(Icons.edit, size: 16, color: Color(0xFF007AFF)),
              onPressed: () {
                setState(() {
                  _selectedPartnerId = null;
                  // If widget.partnerId was set, we can't really "unset" it easily without
                  // parent state change, but for local state we can try.
                  // However, if widget.partnerId is final, we might be stuck.
                  // For now, let's assume we can only change if it wasn't forced by parent?
                  // Or just hide this button if widget.partnerId != null.
                });
              },
            ),
          ],
        ),
      );
    }

    // Default Dropdown
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Customer",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          // Added Container for styling
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              hint: const Text("Choose a client..."),
              value: _selectedPartnerId,
              items: _customers.map<DropdownMenuItem<int>>((c) {
                return DropdownMenuItem(value: c['id'], child: Text(c['name']));
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedPartnerId = val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _expirationDate,
          firstDate: DateTime.now(),
          lastDate: DateTime(2030),
        );
        if (d != null) setState(() => _expirationDate = d);
      },
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
            Text(
              _expirationDate.toIso8601String().substring(0, 10),
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
            ),
            const Icon(Icons.calendar_month, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildPricelistDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedPricelistId,
          isExpanded: true,
          items: _pricelists
              .map<DropdownMenuItem<int>>(
                (e) => DropdownMenuItem(value: e['id'], child: Text(e['name'])),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedPricelistId = v),
        ),
      ),
    );
  }

  Widget _buildPaymentTermDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedPaymentTermId,
          isExpanded: true,
          items: _paymentTerms
              .map<DropdownMenuItem<int>>(
                (e) => DropdownMenuItem(value: e['id'], child: Text(e['name'])),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedPaymentTermId = v),
        ),
      ),
    );
  }

  Widget _buildOrderLineItem(Map<String, dynamic> line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    line['detail'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              Text(
                "\$${line['price_unit']}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D59F2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLineMetric("Qty", "${line['product_uom_qty']} Unit"),
              _buildLineMetric("Price", "\$${line['price_unit']}"),
              _buildLineMetric("Taxes", "15%"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            color: Color(0xFFCBD5E1),
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF334155),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildTotalsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Untaxed Amount",
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              Text(
                "\$${_untaxedAmount.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Taxes",
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              Text(
                "\$${_taxAmount.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Colors.white10),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "GRAND TOTAL",
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                "\$${_totalAmount.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _handleSaveDraft,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      foregroundColor: const Color(0xFF334155),
                    ),
                    child: const Text(
                      "Save Draft",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSendToCustomer,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Send to Customer",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleConvertToInvoice,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFFECFDF5), // emerald-50
                  foregroundColor: const Color(0xFF059669), // emerald-600
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFD1FAE5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        "Convert to Invoice",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
