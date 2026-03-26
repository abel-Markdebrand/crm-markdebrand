import 'package:flutter/material.dart';
import 'pdf_viewer_screen.dart';
import '../services/odoo_service.dart';
import '../services/pdf_service.dart';
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
            'invoice_date_due',
            'invoice_origin',
            'amount_total',
            'state',
            'invoice_line_ids',
            'amount_untaxed',
            'amount_tax',
            'currency_id',
            'narration', // Added for Quote Notes
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
    if (_invoice == null) return;

    setState(() => _isLoading = true);

    try {
      // 1. Fetch Partner Address (Simplified)
      final partnerData = _invoice!['partner_id'];
      final partnerId = partnerData is List ? partnerData[0] : partnerData;
      if (partnerId == null || partnerId == false) return;

      final partner = await _odoo.getContactDetail(partnerId);
      final countryName = OdooUtils.safeM2OName(partner['country_id']);
      final address =
          "${OdooUtils.safeString(partner['street'])}\n${OdooUtils.safeString(partner['city'])}, $countryName";

      // 2. Map Lines
      final List<Map<String, dynamic>> pdfLines = _lines.map((l) {
        return {
          'name': l['name'],
          'quantity': l['quantity'],
          'price_unit': l['price_unit'],
          'amount': l['price_total'],
          'tax': 5.0, // Matching the user's 5% request
        };
      }).toList();

      // 3. Generate local PDF via PdfService
      final pdfPath = await PdfService.instance.generateInvoicePdf(
        invoiceName: _invoice!['name'],
        partnerName: _invoice!['partner_id'][1],
        partnerAddress: address,
        date: _invoice!['invoice_date'] ?? '',
        dueDate: _invoice!['invoice_date_due'] ?? '',
        origin: _invoice!['invoice_origin'] ?? '',
        notes: _invoice!['narration'] ?? '',
        lines: pdfLines,
        subtotal: (_invoice!['amount_untaxed'] as num).toDouble(),
        taxes: (_invoice!['amount_tax'] as num).toDouble(),
        total: (_invoice!['amount_total'] as num).toDouble(),
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(
              path: pdfPath,
              title: _invoice?['name'] ?? "Invoice",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error generating custom Invoice PDF: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error generating PDF: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/image/logo_mdb.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Markdebrand",
                  style: const TextStyle(
                    color: Color(0xFF0F172A), // text-slate-900
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  isDraft ? "INVOICE DRAFT" : "INVOICE: $invoiceName",
                  style: const TextStyle(
                    color: Color(0xFF64748B), // text-slate-500
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: stateColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: stateColor.withValues(alpha: 0.2)),
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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
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
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
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
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.description,
                                color: Color(0xFF007AFF),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              // Added Expanded to prevent overflow
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "SOURCE ORDER",
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
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
                                      Flexible(
                                        // Added Flexible to allow truncation
                                        child: Text(
                                          " • Generated from Quote",
                                          overflow: TextOverflow
                                              .ellipsis, // Ensure ellipsis on overflow
                                          style: TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Removed Spacer() to let Expanded take available space
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFFCBD5E1),
                            ),
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
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Company Header (Logo + Name)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      'assets/image/logo_mdb.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Markdebrand",
                                      style: TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    Text(
                                      isDraft ? "Draft Invoice" : "Invoice",
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),

                          // Customer Header
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            invoiceDate.isEmpty
                                                ? '-'
                                                : invoiceDate,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                          margin: const EdgeInsets.only(bottom: 1),
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
                                    "VAT Excl.",
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

                  // Section: Notes/Narration (Project Plan)
                  if (_invoice!['narration'] != null &&
                      (_invoice!['narration'] as String).trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "PROJECT PLAN / NOTES",
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFF1F5F9),
                              ),
                            ),
                            child: Text(
                              OdooUtils.stripHtml(_invoice!['narration']),
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
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
                          _buildTotalRow(
                            "Subtotal",
                            _invoice!['amount_untaxed'],
                          ),
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
                                      color: Color(0xFFC8102E),
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
          ),

          // Footer
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: const Color(0xE6FFFFFF),
              border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (isDraft)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _confirmInvoice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC8102E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 4,
                            shadowColor: const Color(
                              0xFFC8102E,
                            ).withValues(alpha: 0.2),
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
                            backgroundColor: const Color(0xFF34C759),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 4,
                            shadowColor: const Color(
                              0xFF34C759,
                            ).withValues(alpha: 0.2),
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
                          Icons.picture_as_pdf,
                          "PDF",
                          _viewInvoicePdf,
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
        ],
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
