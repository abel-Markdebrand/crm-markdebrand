import 'package:flutter/material.dart';
import '../services/product_service.dart';

class ProductSearchDialog extends StatefulWidget {
  final ProductService productService;
  const ProductSearchDialog({super.key, required this.productService});

  @override
  State<ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<ProductSearchDialog> {
  final _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _loading = false;

  void _search() async {
    setState(() => _loading = true);
    try {
      final res = await widget.productService.searchProducts(
        _searchController.text,
      );
      if (mounted) setState(() => _results = res);
    } catch (e) {
      debugPrint("Search error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _search(); // Load initial products
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Buscar producto...",
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            onPressed: _search,
          ),
        ),
        onSubmitted: (_) => _search(),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _results.isEmpty
            ? const Center(child: Text("No se encontraron productos"))
            : ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final prod = _results[index];
                  return ListTile(
                    title: Text(prod['name']),
                    subtitle: Text(
                      "Ref: ${prod['default_code'] ?? 'N/A'} - \$${prod['list_price']}",
                    ),
                    onTap: () => Navigator.pop(context, prod),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
      ],
    );
  }
}
