import 'package:flutter/material.dart';
import '../services/crm_service.dart';
import '../services/product_service.dart';
import '../widgets/product_search_dialog.dart';
import '../sales_form_screen.dart';

class CartScreen extends StatefulWidget {
  final int partnerId;
  final int? opportunityId;

  const CartScreen({super.key, required this.partnerId, this.opportunityId});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CrmService _crmService = CrmService();
  final ProductService _productService = ProductService();

  List<Map<String, dynamic>> _selectedProducts = [];
  bool _isProcessing = false;

  void _addProduct() async {
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          ProductSearchDialog(productService: _productService),
    );

    if (selected != null) {
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

  Future<void> _processSale() async {
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
        partnerId: widget.partnerId,
        opportunityId: widget.opportunityId,
      );

      // 2. Agregar Líneas
      for (var prod in _selectedProducts) {
        await _crmService.addOrderLine(
          orderId,
          prod['id'],
          (prod['qty'] as num).toDouble(),
        );
      }

      if (!mounted) return;

      // 3. Navegar a Confirmación (SalesFormScreen)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SalesFormScreen(orderId: orderId),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al procesar venta: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Productos a Facturar')),
      body: Column(
        children: [
          Expanded(
            child: _selectedProducts.isEmpty
                ? Center(
                    child: Text(
                      'Agregue productos con el botón (+)',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : ListView.builder(
                    itemCount: _selectedProducts.length,
                    itemBuilder: (context, index) {
                      final item = _selectedProducts[index];
                      return ListTile(
                        title: Text(item['name']),
                        subtitle: Text("Cantidad: ${item['qty']}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeProduct(index),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
                onPressed: _isProcessing ? null : _processSale,
                icon: const Icon(Icons.check_circle),
                label: Text(
                  _isProcessing ? "PROCESANDO..." : "CONFIRMAR Y FACTURAR",
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProduct,
        child: const Icon(Icons.add),
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
