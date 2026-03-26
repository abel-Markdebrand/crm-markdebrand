import 'package:flutter/material.dart';
import 'services/crm_service.dart';
import 'screens/invoice_detail_screen.dart';

class SalesFormScreen extends StatefulWidget {
  final int? orderId; // ID del pedido creado

  const SalesFormScreen({super.key, this.orderId});

  @override
  State<SalesFormScreen> createState() => _SalesFormScreenState();
}

class _SalesFormScreenState extends State<SalesFormScreen> {
  final CrmService _crmService = CrmService();

  List<dynamic> _orderLines = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshLines();
  }

  Future<void> _refreshLines() async {
    if (widget.orderId == null) return;
    try {
      final lines = await _crmService.getOrderLines(widget.orderId!);
      if (mounted) setState(() => _orderLines = lines);
    } catch (e) {
      debugPrint("Error loading lines: $e");
    }
  }

  Future<void> _confirmAndInvoice() async {
    if (widget.orderId == null) return;
    try {
      setState(() => _isLoading = true);

      // 1. Confirmar
      try {
        await _crmService.confirmSale(widget.orderId!);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Sale Confirmed')));
        }
      } catch (e) {
        final errorString = e.toString().toLowerCase();
        if (errorString.contains("state requiring confirmation") ||
            errorString.contains("already confirmed")) {
          // Ignore
        } else {
          rethrow;
        }
      }

      // 2. Facturar
      await _crmService.setAllLinesDelivered(widget.orderId!);

      final invoiceId = await _crmService.generateInvoice(widget.orderId!);
      if (invoiceId == null) {
        throw Exception(
          "No invoice generated (Check invoicing policy)",
        );
      }

      // 3. Publicar
      await _crmService.postInvoice(invoiceId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invoice Posted')));
      }

      // 4. Pago
      await _crmService.registerPayment(invoiceId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment Registered')));

        // RUTEO A LA FACTURA FINAL EN LUGAR DE SALIR
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => InvoiceDetailScreen(invoiceId: invoiceId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Workflow error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Confirm Sale #${widget.orderId ?? "N/A"}'),
      ),
      body: Column(
        children: [
          // Header Informativo
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            width: double.infinity,
            child: const Text("Review items and confirm the invoice."),
          ),

          const Divider(height: 1),

          // LISTA DE PRODUCTOS
          Expanded(
            child: _orderLines.isEmpty
                ? const Center(child: Text('Loading products...'))
                : ListView.builder(
                    itemCount: _orderLines.length,
                    itemBuilder: (context, index) {
                      final line = _orderLines[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text("${index + 1}")),
                        title: Text(line['name'] ?? 'Product'),
                        subtitle: Text(
                          "Qty: ${line['product_uom_qty']} x \$${line['price_unit']} = \$${line['price_subtotal']}",
                        ),
                      );
                    },
                  ),
          ),

          // BOTONERA INFERIOR
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isLoading ? null : _confirmAndInvoice,
                icon: const Icon(Icons.check_circle),
                label: Text(
                  _isLoading ? "Processing..." : "CONFIRM AND INVOICE",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
