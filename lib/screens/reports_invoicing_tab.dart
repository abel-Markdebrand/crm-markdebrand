import 'package:flutter/material.dart';
import '../../services/odoo_service.dart';
import '../../widgets/stitch/kpi_card.dart';

class ReportsInvoicingTab extends StatefulWidget {
  const ReportsInvoicingTab({super.key});

  @override
  State<ReportsInvoicingTab> createState() => _ReportsInvoicingTabState();
}

class _ReportsInvoicingTabState extends State<ReportsInvoicingTab> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _handlePayAndShare(int invoiceId, String invoiceName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final odoo = OdooService.instance;
      // 1. Pay Invoice
      await odoo.registerFullPayment(invoiceId);

      // Feature disabled by removal of http package
      if (mounted) {
        Navigator.pop(context); // Hide loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Payment registered. PDF sharing disabled."),
          ),
        );
        _loadStats();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Hide loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await OdooService.instance.getInvoiceStats();
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

    final totalReceivables = _stats['total_receivables'] ?? 0.0;
    final overdueCount = _stats['overdue_count'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BANK SYNC CARD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[50], // Emerald 50
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.sync, color: Colors.green[600]),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bank Sync Active",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "Last synced: 5 mins ago",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: true,
                  onChanged: (_) {},
                  activeColor: Colors.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // KPI CARDS
          SizedBox(
            height: 180,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                SizedBox(
                  width: 160,
                  child: KpiCard(
                    title: "Total Receivables",
                    value: "\$${totalReceivables.toStringAsFixed(2)}",
                    trend: "+12.4%",
                    isPositive: true,
                    icon: Icons.trending_up,
                    iconColor: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: KpiCard(
                    title: "Overdue",
                    value:
                        "\$${(overdueCount * 1250).toStringAsFixed(0)}", // Mock amount based on count
                    trend: "$overdueCount Critical",
                    isPositive: false,
                    icon: Icons.error,
                    iconColor: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // CASH FLOW CHART (Placeholder)
          // UNPAID INVOICES (Actionable)
          Text(
            "Facturas Pendientes (Unpaid)",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[900],
            ),
          ),
          const SizedBox(height: 16),
          if (_stats['unpaid_invoices'] != null &&
              (_stats['unpaid_invoices'] as List).isNotEmpty)
            ...(_stats['unpaid_invoices'] as List).map((inv) {
              final id = inv['id'];
              final name = inv['name'] ?? "Invoice #$id";
              final partner = inv['partner_id'] is List
                  ? inv['partner_id'][1]
                  : "Cliente";
              final amount = inv['amount_residual'] ?? 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[100]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            partner,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            "\$${(amount as num).toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _handlePayAndShare(id, name),
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text("Pay & Send"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            })
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text("All invoices paid! Great job.")),
            ),

          const SizedBox(height: 24),

          // RECENT PAYMENTS
          Text(
            "Recent Payments",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[900],
            ),
          ),
          const SizedBox(height: 12),
          if (_stats['recent_payments'] != null &&
              (_stats['recent_payments'] as List).isNotEmpty)
            ...(_stats['recent_payments'] as List).map((payment) {
              final partner = payment['partner_id'] is List
                  ? payment['partner_id'][1]
                  : "Unknown Client";
              final date = payment['date'] ?? "";
              final amount = payment['amount'] ?? 0.0;
              // Simple currency formatting -> assuming standard for now or could use currency_id symbol
              final formattedAmount =
                  "+\$${(amount as num).toStringAsFixed(2)}";

              return _buildPaymentItem(
                partner.toString(),
                date.toString(),
                formattedAmount,
              );
            })
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  "No recent payments found.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(String title, String date, String amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[50],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add_circle, color: Colors.green[600], size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  date,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }
}
