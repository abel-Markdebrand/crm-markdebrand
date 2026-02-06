import 'package:flutter/material.dart';
import 'services/crm_service.dart';

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
          ).showSnackBar(const SnackBar(content: Text('Venta Confirmada')));
        }
      } catch (e) {
        final errorString = e.toString().toLowerCase();
        if (errorString.contains("state requiring confirmation") ||
            errorString.contains("ya confirmado")) {
          // Ignore
        } else {
          rethrow;
        }
      }

      // 2. Facturar
      await _crmService.setAllLinesDelivered(widget.orderId!);

      final invoiceId = await _crmService.generateInvoice(widget.orderId!);
      if (invoiceId == null)
        throw Exception(
          "No se generó factura (Verifique política de facturación)",
        );

      // 3. Publicar
      await _crmService.postInvoice(invoiceId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Factura Publicada')));
      }

      // 4. Pago
      await _crmService.registerPayment(invoiceId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pago Registrado')));
        Navigator.pop(context); // Salir
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error en flujo: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Confirmar Venta #${widget.orderId ?? "N/A"}'),
      ),
      body: Column(
        children: [
          // Header Informativo
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            width: double.infinity,
            child: const Text("Revise los ítems y confirme la factura."),
          ),

          const Divider(height: 1),

          // LISTA DE PRODUCTOS
          Expanded(
            child: _orderLines.isEmpty
                ? const Center(child: Text('Cargando productos...'))
                : ListView.builder(
                    itemCount: _orderLines.length,
                    itemBuilder: (context, index) {
                      final line = _orderLines[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text("${index + 1}")),
                        title: Text(line['name'] ?? 'Producto'),
                        subtitle: Text(
                          "Cant: ${line['product_uom_qty']} x \$${line['price_unit']} = \$${line['price_subtotal']}",
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
                  _isLoading ? "Procesando..." : "CONFIRMAR Y FACTURAR",
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
