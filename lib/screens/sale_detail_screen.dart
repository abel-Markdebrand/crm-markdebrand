import 'package:flutter/material.dart';
import '../services/odoo_service.dart';
import '../models/sale.dart';
import 'package:intl/intl.dart';
import 'invoice_detail_screen.dart'; // Import added for navigation
import '../services/pdf_service.dart';
import 'pdf_viewer_screen.dart';

class SaleDetailScreen extends StatefulWidget {
  final int saleId;

  const SaleDetailScreen({super.key, required this.saleId});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  final OdooService _odoo = OdooService.instance;
  bool _isLoading = true;
  Sale? _sale;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSale();
  }

  Future<void> _loadSale() async {
    try {
      final saleData = await _odoo.getSaleWithLines(widget.saleId);
      if (mounted) {
        setState(() {
          _sale = saleData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmAndInvoiceSale() async {
    setState(() => _isLoading = true);
    try {
      await _odoo.confirmSale(widget.saleId);
      final invoiceId = await _odoo.createInvoiceFromSale(widget.saleId);
      await _loadSale(); // Refresh to update state
      if (mounted) {
        if (invoiceId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Venta confirmada y Factura creada")),
          );
          _navigateToInvoice(invoiceId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Venta confirmada pero no se pudo abrir la factura.",
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createInvoice() async {
    setState(() => _isLoading = true);
    try {
      final invoiceId = await _odoo.createInvoiceFromSale(widget.saleId);
      await _loadSale(); // Refresh to update state
      if (mounted) {
        if (invoiceId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Factura creada exitosamente")),
          );
          _navigateToInvoice(invoiceId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No se pudo crear la factura.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _navigateToInvoice(int invoiceId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceDetailScreen(invoiceId: invoiceId),
      ),
    ).then((_) {
      // Refresh sale details when coming back from invoice screen
      if (mounted) {
        setState(() => _isLoading = true);
        _loadSale();
      }
    });
  }

  Future<void> _viewSalePdf() async {
    if (_sale == null) return;

    setState(() => _isLoading = true);

    try {
      // 1. Fetch Partner Address
      final partner = await _odoo.getContactDetail(_sale!.partnerId);
      final address =
          "${partner['street'] ?? ''}\n${partner['city'] ?? ''}, ${partner['country_id']?[1] ?? ''}";

      // 2. Map Lines
      final List<Map<String, dynamic>> pdfLines = _sale!.lines.map((l) {
        return {
          'name': l.name,
          'quantity': l.qty,
          'price_unit': l.priceUnit,
          'amount': l.priceTotal,
          'tax': 5.0, // Default 5% as per user request
        };
      }).toList();

      // 3. Generate local PDF via PdfService
      final pdfPath = await PdfService.instance.generateQuotePdf(
        orderName: _sale!.name,
        partnerName: _sale!.partnerName,
        partnerAddress: address,
        date: _sale!.dateOrder,
        expirationDate: _sale!.validityDate,
        salesperson: _sale!.salespersonName,
        notes: _sale!.note,
        lines: pdfLines,
        subtotal: _sale!.amountUntaxed,
        taxes: _sale!.amountTax,
        total: _sale!.amountTotal,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PdfViewerScreen(path: pdfPath, title: _sale!.name),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error generating custom Sale PDF: $e");
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
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        body: Center(child: Text("Error: $_errorMessage")),
      );
    }
    if (_sale == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF2F2F7),
        body: Center(child: Text("Sale not found")),
      );
    }

    final currencyFormatter = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );

    final state = _sale!.state.toLowerCase();
    final bool isDraft = state == 'draft';
    final stateColor = state == 'sale' || state == 'done'
        ? const Color(0xFF34C759)
        : const Color(0xFFFF9500); // ios-green : ios-orange
    final stateLabel = state == 'sale' || state == 'done'
        ? 'Confirmed'
        : 'Draft';

    final partnerName = _sale!.partnerName;
    final invoiceName = _sale!.name;
    final invoiceDate = _sale!.dateOrder;
    final dueDate = _sale!.validityDate;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xCCFFFFFF),
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
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
              width: 24,
              height: 24,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  invoiceName.isEmpty ? 'New Sale' : invoiceName,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  isDraft ? "QUOTATION" : "SALE ORDER",
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF9B3232)),
            onPressed: _viewSalePdf,
            tooltip: "Ver PDF",
          ),
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
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
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
                        children: [
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
                                const Text(
                                  "Edit",
                                  style: TextStyle(
                                    color: Color(0xFF007AFF),
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
                                        "ORDER DATE",
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
                                                : invoiceDate.split(
                                                    ' ',
                                                  )[0], // only keep date if datetime
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
                                        "EXPIRATION",
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
                                            dueDate.isEmpty
                                                ? '-'
                                                : dueDate.split(' ')[0],
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
                      children: _sale!.lines.isEmpty
                          ? [
                              Container(
                                color: Colors.white,
                                padding: const EdgeInsets.all(20),
                                alignment: Alignment.center,
                                child: const Text(
                                  "No hay líneas en este pedido",
                                ),
                              ),
                            ]
                          : _sale!.lines.map((l) {
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l.name,
                                            style: const TextStyle(
                                              color: Color(0xFF0F172A),
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              "${l.qty} x ${currencyFormatter.format(l.priceUnit)}",
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          currencyFormatter.format(
                                            l.priceTotal,
                                          ),
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
                            _sale!.amountUntaxed,
                            currencyFormatter,
                          ),
                          const SizedBox(height: 12),
                          _buildTotalRow(
                            "Taxes",
                            _sale!.amountTax,
                            currencyFormatter,
                          ),
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
                                    currencyFormatter.format(
                                      _sale!.amountTotal,
                                    ),
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
          ),

          // Footer
          if (isDraft)
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: const BoxDecoration(
                color: Color(0xE6FFFFFF),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _confirmAndInvoiceSale,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 4,
                            shadowColor: const Color(
                              0xFF007AFF,
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
                                "Confirmar y Facturar",
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
                ],
              ),
            )
          else if (_sale!.invoiceIds.isEmpty)
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: const BoxDecoration(
                color: Color(0xE6FFFFFF),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _createInvoice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 4,
                            shadowColor: const Color(
                              0xFF007AFF,
                            ).withValues(alpha: 0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_card, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "Crear Factura",
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
                ],
              ),
            )
          else
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: const BoxDecoration(
                color: Color(0xE6FFFFFF),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              _navigateToInvoice(_sale!.invoiceIds.last),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF34C759,
                            ), // Green like the success container that was there
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
                              Icon(Icons.receipt_long, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "Ver Factura",
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
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, NumberFormat formatter) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          formatter.format(amount),
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
