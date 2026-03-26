import 'package:flutter/material.dart';
import '../services/product_service.dart';
import '../services/odoo_service.dart';
import '../widgets/stitch/product_card_stitch.dart';
import '../widgets/stitch/category_chips.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ProductService _productService = ProductService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _products = [];
  bool _isLoading = false;
  String _selectedCategory = "All";
  final Map<int, int> _cart = {}; // productId -> quantity
  final Map<int, Map<String, dynamic>> _cartProductData =
      {}; // productId -> product data

  // Selection state for Direct Sale
  int? _selectedPartnerId;
  String? _selectedPartnerName;

  // Categorías dummy para paridad visual
  final List<String> _categories = [
    "All",
    "Branding",
    "Diseño Web",
    "Marketing",
    "SEO",
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts([String query = '']) async {
    setState(() => _isLoading = true);
    try {
      final results = await _productService.searchProducts(query);
      if (mounted) {
        setState(() {
          _products = results;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading products: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onCategorySelected(String category) {
    setState(() => _selectedCategory = category);
    if (category == "All") {
      _loadProducts();
    } else {
      _loadProducts(category);
    }
  }

  void _showPartnerSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PartnerPickerSheet(
        onPartnerSelected: (id, name) {
          setState(() {
            _selectedPartnerId = id;
            _selectedPartnerName = name;
          });
        },
      ),
    );
  }

  void _addToCart(Map<String, dynamic> product) {
    final int id = product['id'];
    setState(() {
      _cart[id] = (_cart[id] ?? 0) + 1;
      _cartProductData[id] = product;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Added ${product['name']} to cart"),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _removeFromCart(int productId) {
    setState(() {
      if (_cart.containsKey(productId)) {
        if (_cart[productId]! > 1) {
          _cart[productId] = _cart[productId]! - 1;
        } else {
          _cart.remove(productId);
          _cartProductData.remove(productId);
        }
      }
    });
  }

  Future<void> _handleCartCheckout() async {
    if (_selectedPartnerId == null) {
      _showPartnerSelector();
      return;
    }

    if (_cart.isEmpty) return;

    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final List<Map<String, dynamic>> items = _cart.entries.map((e) {
        return {'id': e.key, 'quantity': e.value};
      }).toList();

      final success = await OdooService.instance.createSaleWithCart(
        partnerId: _selectedPartnerId!,
        items: items,
      );

      if (mounted) Navigator.pop(context); // Close loading

      if (mounted) {
        if (success) {
          setState(() {
            _cart.clear();
            _cartProductData.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Sale and Invoice generated successfully"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Error processing cart sale"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCartReview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "TOTAL",
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Nexa',
                        ),
                      ),
                      Text(
                        "${_cart.length} products", // Changed "items" to "productos"
                        style: const TextStyle(
                          color: Color(
                            0xFF94A3B8,
                          ), // Changed color from Colors.grey
                          fontFamily: 'Nexa', // Added font family
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final id = _cart.keys.elementAt(index);
                      final product = _cartProductData[id]!;
                      final qty = _cart[id]!;
                      return ListTile(
                        title: Text(
                          product['name'] ?? 'Supplies',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          "\$${((product['list_price'] ?? 0) * qty).toStringAsFixed(2)}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                _removeFromCart(id);
                                setModalState(() {});
                                setState(() {});
                                if (_cart.isEmpty) Navigator.pop(context);
                              },
                            ),
                            Text(
                              "$qty",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Color(0xFF007AFF), // Markdebrand Blue
                              ),
                              onPressed: () {
                                _addToCart(product);
                                setModalState(() {});
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleCartCheckout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF), // Markdebrand Blue
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "CONFIRM SALE AND BILL",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // background-light
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Expanded(child: SizedBox.shrink()),
                  // Removing bag icon from here
                ],
              ),
            ),

            // Partner Selector Bar (Sticky)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2), // Very Light Red
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)), // Light Red border
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_pin_rounded,
                    color: Color(0xFF007AFF),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "SELECTED CLIENT",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                        Text(
                          _selectedPartnerName ?? "Not selected",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _selectedPartnerName != null
                                ? const Color(0xFF991B1B) // Dark Red
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _showPartnerSelector,
                    child: Text(
                      _selectedPartnerName != null ? "Change" : "Select",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: "Search products or services",
                    hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                    prefixIcon: Icon(Icons.search, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onSubmitted: _loadProducts,
                ),
              ),
            ),

            // Category Chips
            CategoryChips(
              categories: _categories,
              selectedCategory: _selectedCategory,
              onSelect: _onCategorySelected,
            ),

            // Product List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "No products found",
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        bottom: 100,
                      ), // Space for FAB
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return ProductCardStitch(
                          name: product['name'] ?? 'Unknown Item',
                          description: "", // Removed confusing placeholder
                          price:
                              (product['list_price'] as num?)?.toDouble() ??
                              0.0,
                          imageUrl:
                              null, // Odoo images require auth tokens usually
                          quantityInCart: _cart[product['id']] ?? 0,
                          onAdd: () => _addToCart(product),
                          onDirectSale: () => _handleDirectSale(product),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _cart.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showCartReview,
              label: Text("Review Sale (${_cart.length})"),
              icon: const Icon(Icons.shopping_cart_checkout),
              backgroundColor: const Color(0xFF0D59F2),
            )
          : null,
    );
  }

  Future<void> _handleDirectSale(Map<String, dynamic> product) async {
    _addToCart(product);
    _showCartReview();
  }
}

class _PartnerPickerSheet extends StatefulWidget {
  final Function(int id, String name) onPartnerSelected;

  const _PartnerPickerSheet({required this.onPartnerSelected});

  @override
  State<_PartnerPickerSheet> createState() => _PartnerPickerSheetState();
}

class _PartnerPickerSheetState extends State<_PartnerPickerSheet> {
  final OdooService _odooService = OdooService.instance;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _partners = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  Future<void> _loadPartners([String query = '']) async {
    setState(() => _isLoading = true);
    try {
      final List<dynamic> domain = [
        ['customer_rank', '>', 0],
      ];
      if (query.isNotEmpty) {
        domain.add(['name', 'ilike', query]);
      }

      final results = await _odooService.callKw(
        model: 'res.partner',
        method: 'search_read',
        args: [],
        kwargs: {
          'domain': domain,
          'fields': ['id', 'name', 'email', 'phone'],
          'limit': 15,
        },
      );

      if (mounted) {
        setState(() {
          _partners = results as List<dynamic>;
        });
      }
    } catch (e) {
      debugPrint("Error loading partners: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Select Client",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search client...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) => _loadPartners(val),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _partners.isEmpty
                ? const Center(child: Text("No se encontraron clientes"))
                : ListView.builder(
                    itemCount: _partners.length,
                    itemBuilder: (context, index) {
                      final p = _partners[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(p['name'] ?? 'Unnamed'),
                        subtitle: Text(p['email'] ?? p['phone'] ?? ''),
                        onTap: () {
                          widget.onPartnerSelected(p['id'], p['name']);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
