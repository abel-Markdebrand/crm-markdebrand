import 'package:flutter/material.dart';
import 'reports_sales_tab.dart';
import 'reports_invoicing_tab.dart';
import 'reports_products_tab.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Reports Dashboard",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0D59F2),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0D59F2),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.show_chart), text: "Sales"),
            Tab(icon: Icon(Icons.receipt_long), text: "Invoicing"),
            Tab(icon: Icon(Icons.inventory_2), text: "Products"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ReportsSalesTab(),
          ReportsInvoicingTab(),
          ReportsProductsTab(),
        ],
      ),
    );
  }
}
