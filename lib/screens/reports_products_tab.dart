import 'package:flutter/material.dart';
import '../../services/odoo_service.dart';
import '../../utils/odoo_utils.dart';
import '../../widgets/stitch/kpi_card.dart';

class ReportsProductsTab extends StatefulWidget {
  const ReportsProductsTab({super.key});

  @override
  State<ReportsProductsTab> createState() => _ReportsProductsTabState();
}

class _ReportsProductsTabState extends State<ReportsProductsTab> {
  bool _isLoading = true;
  List<dynamic> _products = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final products = await OdooService.instance.getProductStats();
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI ROW (Mocked for Products context)
          Row(
            children: [
              Expanded(
                child: KpiCard(
                  title: "Top Seller",
                  value: "Desk Pad",
                  trend: "+15 Sold",
                  isPositive: true,
                  icon: Icons.star,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KpiCard(
                  title: "Low Stock",
                  value: "3 Items",
                  trend: "Restock",
                  isPositive: false,
                  icon: Icons.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // TOP PRODUCTS LIST
          Text(
            "Top Selling Products",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[900],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: _products.map((p) => _buildProductRow(p)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(Map<String, dynamic> product) {
    // Determine rank (could be passed via index if using mapIndexed)
    // For now simple row
    final name = OdooUtils.safeString(product['name']);
    final price = (product['list_price'] as num?)?.toDouble() ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  "\$${price.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}
