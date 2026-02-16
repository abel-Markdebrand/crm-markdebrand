import 'package:flutter/material.dart';
import '../models/crm_models.dart';
import '../services/crm_service.dart';
import '../services/product_service.dart';
import '../sales_form_screen.dart';
import '../widgets/product_search_dialog.dart';

class OpportunityQuoteScreen extends StatefulWidget {
  final CrmLead lead;

  const OpportunityQuoteScreen({super.key, required this.lead});

  @override
  State<OpportunityQuoteScreen> createState() => _OpportunityQuoteScreenState();
}

class _OpportunityQuoteScreenState extends State<OpportunityQuoteScreen> {
  final CrmService _crmService = CrmService();
  final ProductService _productService = ProductService();

  bool _isProcessing = false;
  List<Map<String, dynamic>> _selectedProducts = [];

  // --- Start Hot Sale (Instant Sale) ---
  Future<void> _startHotSale() async {
    if (widget.lead.partnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este lead no tiene cliente asignado.')),
      );
      return;
    }

    // Validar productos
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione al menos un producto.')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      // 1. Crear Pedido (Draft)
      final orderId = await _crmService.createSaleOrder(
        partnerId: widget.lead.partnerId!,
        opportunityId: widget.lead.id,
      );

      // 2. Agregar Líneas seleccionadas
      for (var prod in _selectedProducts) {
        await _crmService.addOrderLine(
          orderId,
          prod['id'],
          (prod['qty'] as num).toDouble(),
        );
      }

      if (!mounted) return;

      // 3. Navegar a Confirmación (SalesFormScreen)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SalesFormScreen(orderId: orderId),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al crear venta: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _addProduct() async {
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          ProductSearchDialog(productService: _productService),
    );

    if (selected != null) {
      // Pedir cantidad (Simple dialog)
      final qtyStr = await showDialog<String>(
        context: context,
        builder: (ctx) => _QtyDialog(),
      );

      if (qtyStr != null) {
        final qty = double.tryParse(qtyStr) ?? 1.0;
        setState(() {
          final p = Map<String, dynamic>.from(selected);
          p['qty'] = qty;
          _selectedProducts.add(p);
        });
      }
    }
  }

  void _removeProduct(int index) {
    setState(() {
      _selectedProducts.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Cotización')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header Info
            ListTile(
              title: Text(
                widget.lead.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(widget.lead.partnerName ?? 'Desconocido'),
              leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
            ),
            const Divider(),

            // Product Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Productos a Facturar",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _addProduct,
                  icon: const Icon(Icons.add),
                  label: const Text("AGREGAR"),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            // Product List
            Expanded(
              child: _selectedProducts.isEmpty
                  ? Center(
                      child: Text(
                        "Agregue productos para cotizar",
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _selectedProducts.length,
                      itemBuilder: (context, index) {
                        final item = _selectedProducts[index];
                        return Card(
                          elevation: 0,
                          color: Colors.grey[50],
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            dense: true,
                            title: Text(item['name'], maxLines: 1),
                            subtitle: Text(
                              "Cant: ${item['qty']} - \$${item['list_price']}",
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _removeProduct(index),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Action Button
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D59F2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                onPressed: _isProcessing ? null : _startHotSale,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  _isProcessing ? "Procesando..." : "CONFIRMAR COTIZACIÓN",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyDialog extends StatefulWidget {
  @override
  State<_QtyDialog> createState() => _QtyDialogState();
}

class _QtyDialogState extends State<_QtyDialog> {
  final _controller = TextEditingController(text: "1");
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Cantidad"),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(suffixText: "Und"),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text("OK"),
        ),
      ],
    );
  }
}
