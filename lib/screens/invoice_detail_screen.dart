import 'package:flutter/material.dart';
import '../services/odoo_service.dart';
import '../utils/odoo_utils.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final int invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final OdooService _odoo = OdooService.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _invoice;
  List<dynamic> _lines = [];

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    try {
      final res = await _odoo.callKw(
        model: 'account.move',
        method: 'read',
        args: [
          [widget.invoiceId],
          [
            'name',
            'partner_id',
            'invoice_date',
            'invoice_date_due', // Added for design
            'invoice_origin', // Added for design ("Source Order")
            'amount_total',
            'state',
            'invoice_line_ids',
            'amount_untaxed',
            'amount_tax',
            'currency_id', // To show currency symbol if needed (simplified to $)
          ],
        ],
      );

      if (res != null && (res as List).isNotEmpty) {
        final data = res[0] as Map<String, dynamic>;

        // Fetch lines details
        final lineIds = data['invoice_line_ids'] as List;
        if (lineIds.isNotEmpty) {
          final linesRes = await _odoo.callKw(
            model: 'account.move.line',
            method: 'read',
            args: [
              lineIds,
              ['name', 'quantity', 'price_unit', 'price_total', 'product_id'],
            ],
          );
          _lines = linesRes as List;
        }

        if (mounted) {
          setState(() {
            _invoice = data;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading invoice: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmInvoice() async {
    setState(() => _isLoading = true);
    try {
      await _odoo.callKw(
        model: 'account.move',
        method: 'action_post',
        args: [
          [widget.invoiceId],
        ],
      );
      await _loadInvoice(); // Refresh to update state
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Invoice Confirmed!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _registerPayment() async {
    setState(() => _isLoading = true);
    try {
      await _odoo.registerFullPayment(widget.invoiceId);
      await _loadInvoice();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Payment Registered! Generating PDF..."),
          ),
        );
        // Automatically generate and view PDF
        await _viewInvoicePdf();
      }
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains("nothing left to pay") ||
          errorMsg.contains("finances under control")) {
        // This means it's already paid. Treat as success.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Already paid! Generating PDF...")),
          );
          await _viewInvoicePdf();
        }
        setState(() => _isLoading = false);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error paying: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _viewInvoicePdf() async {
    // Feature disabled by removal of http package
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("PDF viewing is disabled in this version.")),
    );
  }

  Future<void> _sendInvoice() async {
    // Feature disabled by removal of http package
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("PDF sending is disabled in this version.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF2F2F7), // background-light
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_invoice == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF2F2F7),
        body: Center(child: Text("Invoice not found")),
      );
    }

    final state = OdooUtils.safeString(_invoice!['state']);
    final bool isDraft = state == 'draft';
    final stateColor = state == 'posted'
        ? const Color(0xFF34C759)
        : const Color(0xFFFF9500); // ios-green : ios-orange
    final stateLabel = state == 'posted' ? 'Posted' : 'Draft';

    final partnerName = OdooUtils.safeString(_invoice!['partner_id'][1]);
    final sourceDoc = OdooUtils.safeString(_invoice!['invoice_origin']);
    final invoiceName = OdooUtils.safeString(_invoice!['name']);
    final invoiceDate = OdooUtils.safeString(_invoice!['invoice_date']);
    final dueDate = OdooUtils.safeString(_invoice!['invoice_date_due']);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      // Custom Header mimicking the design (Sticky top)
      appBar: AppBar(
        backgroundColor: const Color(0xCCFFFFFF), // bg-white/80
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors
                  .transparent, // active:bg-slate-100 logic not easy here without InkWell
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF007AFF),
              size: 20,
            ),
          ),
        ),
        title: Column(
          children: [
            Text(
              invoiceName.isEmpty ? 'New Invoice' : invoiceName,
              style: const TextStyle(
                color: Color(0xFF0F172A), // text-slate-900
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              isDraft ? "INVOICE DRAFT" : "INVOICE",
              style: const TextStyle(
                color: Color(0xFF64748B), // text-slate-500
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: stateColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: stateColor.withOpacity(0.2)),
            ),
            child: Text(
              stateLabel.toUpperCase(),
              style: TextStyle(
                color: stateColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFE2E8F0), // border-slate-200
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120), // Padding for footer
        child: Column(
          children: [
            // Section: Source Order
            if (sourceDoc.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12), // rounded-xl
                    border: Border.all(
                      color: const Color(0xFFF1F5F9),
                    ), // border-slate-100
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF007AFF,
                          ).withOpacity(0.1), // bg-primary/10
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.description,
                          color: Color(0xFF007AFF),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "SOURCE ORDER",
                            style: TextStyle(
                              color: Color(0xFF94A3B8), // text-slate-400
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                sourceDoc,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                " • Generated from Quote",
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
                    ],
                  ),
                ),
              ),

            // Section: Info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16), // rounded-2xl
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Customer Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "CUSTOMER INFORMATION",
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  partnerName,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                // Placeholder specific address if we fetched it, for now just name
                              ],
                            ),
                          ),
                          Text(
                            "Edit",
                            style: TextStyle(
                              color: const Color(0xFF007AFF),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF8FAFC)),
                    // Dates Grid
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "ISSUE DATE",
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      invoiceDate.isEmpty ? '-' : invoiceDate,
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "DUE DATE",
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.event,
                                      size: 14,
                                      color: Color(0xFF007AFF),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      dueDate.isEmpty ? '-' : dueDate,
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Section: Itemized Lines
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "ITEMIZED LINES",
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (isDraft)
                    Row(
                      children: const [
                        Icon(
                          Icons.add_circle,
                          color: Color(0xFF007AFF),
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "Add Line",
                          style: TextStyle(
                            color: Color(0xFF007AFF),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // List of Lines
            Container(
              decoration: const BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(color: Color(0xFFF1F5F9)),
                ),
              ),
              child: Column(
                children: _lines.map((l) {
                  final name = OdooUtils.safeString(l['name']);
                  final qty = l['quantity'] ?? 0;
                  final price = l['price_unit'] ?? 0;
                  final total = l['price_total'] ?? 0;

                  return Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    margin: const EdgeInsets.only(bottom: 1), // Divider effect
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),

                              // Description placeholder if distinct from name, usually assumed same in MVP
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "$qty x \$${price.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "\$${total.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "VAT Excl.", // Simplified tax label
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // Totals Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Column(
                  children: [
                    _buildTotalRow("Subtotal", _invoice!['amount_untaxed']),
                    const SizedBox(height: 12),
                    _buildTotalRow("Taxes", _invoice!['amount_tax']),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          "Total Amount",
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "\$${(_invoice!['amount_total'] as num).toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Color(0xFF007AFF),
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              "USD CURRENCY",
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Fixed Footer
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: const Color(0xE6FFFFFF), // bg-white/90
          border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Primary Actions Row
            Row(
              children: [
                if (isDraft)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmInvoice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 4,
                        shadowColor: const Color(0xFF007AFF).withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check_circle_outline, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Validate & Issue",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _registerPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF34C759), // ios-green
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 4,
                        shadowColor: const Color(0xFF34C759).withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.payments_outlined, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Register Payment",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Secondary Actions Row
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      Icons.save_outlined,
                      "Save",
                      () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSecondaryButton(
                      Icons.send_outlined,
                      "Send",
                      _sendInvoice,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.more_horiz,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, dynamic amount) {
    final val = (amount as num?)?.toDouble() ?? 0.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        Text(
          "\$${val.toStringAsFixed(2)}",
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryButton(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9), // bg-slate-100
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF0F172A)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
