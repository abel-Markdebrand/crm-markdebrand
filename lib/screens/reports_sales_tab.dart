import 'package:flutter/material.dart';
import '../../services/odoo_service.dart';
import '../../widgets/stitch/kpi_card.dart';

class ReportsSalesTab extends StatefulWidget {
  const ReportsSalesTab({super.key});

  @override
  State<ReportsSalesTab> createState() => _ReportsSalesTabState();
}

class _ReportsSalesTabState extends State<ReportsSalesTab> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await OdooService.instance.getSalesStats();
      if (mounted) {
        setState(() {
          _stats = stats;
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

    final totalRevenue = _stats['total_revenue'] ?? 0.0;
    final avgDealSize = _stats['avg_deal_size'] ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI ROW
          Row(
            children: [
              Expanded(
                child: KpiCard(
                  title: "Total Revenue",
                  value: "\$${totalRevenue.toStringAsFixed(2)}",
                  trend: "+12.5%",
                  isPositive: true,
                  icon: Icons.trending_up,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KpiCard(
                  title: "Avg Deal Size",
                  value: "\$${avgDealSize.toStringAsFixed(2)}",
                  trend: "+3.2%",
                  isPositive: true,
                  icon: Icons.trending_up,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // EXPECTED VS ACTUAL CHART
          Text(
            "Expected vs Actual",
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
              children: [
                SizedBox(
                  height: 150,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildBarPair("W1", 0.7, 0.5),
                      _buildBarPair("W2", 0.8, 0.9),
                      _buildBarPair("W3", 0.6, 0.4),
                      _buildBarPair("W4", 0.9, 1.0),
                      _buildBarPair("W5", 0.75, 0.65),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem(Colors.grey[200]!, "Expected"),
                    const SizedBox(width: 24),
                    _buildLegendItem(const Color(0xFF0D59F2), "Actual"),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // LEADS BY SOURCE (Simple representation)
          Text(
            "Leads by Source",
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
              children: [
                _buildSourceRow("LinkedIn", 45, const Color(0xFF0D59F2)),
                const SizedBox(height: 16),
                _buildSourceRow("Referral", 25, Colors.teal),
                const SizedBox(height: 16),
                _buildSourceRow("Ads", 30, Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarPair(String label, double expectedPct, double actualPct) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 12,
              height: 100 * expectedPct,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 12,
              height: 100 * actualPct,
              decoration: BoxDecoration(
                color: const Color(0xFF0D59F2),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSourceRow(String source, int percentage, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            source,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          "$percentage%",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
