import 'package:flutter/material.dart';
import '../models/crm_models.dart';
import '../services/crm_service.dart';
import '../services/product_service.dart';
import '../sales_form_screen.dart';
import 'package:mvp_odoo/screens/lead_form_screen.dart';
import '../widgets/product_search_dialog.dart';

class OpportunityDetailScreen extends StatefulWidget {
  final int leadId;

  const OpportunityDetailScreen({super.key, required this.leadId});

  @override
  State<OpportunityDetailScreen> createState() =>
      _OpportunityDetailScreenState();
}

class _OpportunityDetailScreenState extends State<OpportunityDetailScreen> {
  final CrmService _crmService = CrmService();
  final ProductService _productService = ProductService();

  late Future<CrmLead?> _leadFuture;
  bool _isProcessing = false;

  // HOT SALE STATE
  List<Map<String, dynamic>> _selectedProducts = [];

  @override
  void initState() {
    super.initState();
    _loadLead();
  }

  void _loadLead() {
    setState(() {
      _leadFuture = _crmService.getLeadById(widget.leadId);
    });
  }

  // --- Start Hot Sale (Instant Sale) ---
  Future<void> _startHotSale(CrmLead lead) async {
    if (lead.partnerId == null) {
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
        partnerId: lead.partnerId!,
        opportunityId: lead.id,
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

      // Limpiar selección al volver? (Opcional)
      // setState(() => _selectedProducts.clear());
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

  // Navigation to Edit
  void _editLead(CrmLead lead) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LeadFormScreen(lead: lead)),
    );
    if (result == true) {
      _loadLead(); // Refresh data
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Oportunidad'),
        actions: [
          FutureBuilder<CrmLead?>(
            future: _leadFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editLead(snapshot.data!),
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
      body: FutureBuilder<CrmLead?>(
        future: _leadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('No se encontró la oportunidad.'));
          }

          final lead = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  lead.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  lead.partnerName ?? 'Sin Cliente',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),

                // Lead Info
                _buildInfoRow(
                  Icons.monetization_on,
                  "Ingreso Esperado",
                  "\$${lead.expectedRevenue.toStringAsFixed(2)}",
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.message,
                  "Descripción",
                  lead.description ?? "Sin descripción",
                ),

                const Divider(height: 32),

                // --- SECCIÓN PRODUCTOS (HOT SALE CART) ---
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

                Expanded(
                  child: _selectedProducts.isEmpty
                      ? Center(
                          child: Text(
                            "Agregue productos para venta inmediata",
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

                // Action Button (HOT SALE)
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.green[700], // Green for Money/Sale
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    onPressed: _isProcessing ? null : () => _startHotSale(lead),
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.flash_on),
                    label: Text(
                      _isProcessing ? "Procesando..." : "FACTURAR AHORA",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueGrey, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text("$label: $value", style: const TextStyle(fontSize: 14)),
        ),
      ],
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
