import 'package:flutter/material.dart';
import '../services/crm_service.dart';
import '../models/crm_models.dart';
import '../screens/leads_creation_screen.dart';
import '../screens/quote_creation_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/odoo_utils.dart';

class OpportunityDetailScreen extends StatefulWidget {
  final int leadId;

  const OpportunityDetailScreen({super.key, required this.leadId});

  @override
  State<OpportunityDetailScreen> createState() =>
      _OpportunityDetailScreenState();
}

class _OpportunityDetailScreenState extends State<OpportunityDetailScreen> {
  final CrmService _crmService = CrmService();

  late Future<CrmLead?> _leadFuture;
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

  // Navigation to Edit
  void _editLead(CrmLead lead) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LeadCreationScreen(lead: lead)),
    );
    if (result == true) {
      _loadLead(); // Refresh data
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/image/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Opportunity Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          FutureBuilder<CrmLead?>(
            future: _leadFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final lead = snapshot.data!;
                return IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editLead(lead),
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<CrmLead?>(
        future: _leadFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();
          final lead = snapshot.data!;
          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuoteCreationScreen(
                    partnerName: lead.partnerName ?? 'Unknown',
                    partnerId: lead.partnerId,
                    opportunityId: lead.id,
                  ),
                ),
              );
            },
            backgroundColor: const Color(0xFFC8102E),
            foregroundColor: Colors.white,
            label: const Text(
              "QUOTE",
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            icon: const Icon(Icons.receipt_long),
          );
        },
      ),
      body: FutureBuilder<CrmLead?>(
        future: _leadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  OdooUtils.getFriendlyError(snapshot.error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Opportunity not found.'));
          }

          final lead = snapshot.data!;
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER CARD ---
                  _buildHeaderCard(lead),
                  const SizedBox(height: 24),

                  // --- MARKETING SECTION ---
                  if (lead.campaignName != null ||
                      lead.mediumName != null ||
                      lead.sourceName != null) ...[
                    _buildSectionHeader("MARKETING"),
                    const SizedBox(height: 12),
                    _buildInfoCard([
                      if (lead.campaignName != null)
                        _buildDetailRow(
                          Icons.campaign,
                          "Campaign",
                          lead.campaignName,
                        ),
                      if (lead.mediumName != null)
                        _buildDetailRow(
                          Icons.broadcast_on_home,
                          "Medium",
                          lead.mediumName,
                        ),
                      if (lead.sourceName != null)
                        _buildDetailRow(
                          Icons.source,
                          "Source",
                          lead.sourceName,
                        ),
                    ]),
                    const SizedBox(height: 24),
                  ],

                  // --- CONTACT SECTION ---
                  _buildSectionHeader("CONTACT INFORMATION"),
                  const SizedBox(height: 12),
                  _buildInfoCard([
                    _buildDetailRow(Icons.email_outlined, "Email", lead.email),
                    _buildDetailRow(
                      Icons.phone_outlined,
                      "Phone",
                      lead.phone,
                      suffix: _buildCallButton(lead.phone, isProminent: true),
                    ),
                    _buildDetailRow(Icons.language, "Website", lead.website),
                  ]),
                  const SizedBox(height: 24),

                  // --- ADDRESS SECTION ---
                  _buildSectionHeader("ADDRESS"),
                  const SizedBox(height: 12),
                  _buildInfoCard([
                    _buildDetailRow(
                      Icons.location_on_outlined,
                      "Calle",
                      lead.street,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailRow(
                            Icons.location_city,
                            "Ciudad",
                            lead.city,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDetailRow(
                            Icons.numbers,
                            "C. Postal",
                            lead.zip,
                          ),
                        ),
                      ],
                    ),
                    _buildDetailRow(
                      Icons.flag_outlined,
                      "País",
                      lead.countryName,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // --- DESCRIPTION SECTION ---
                  _buildSectionHeader("INTERNAL NOTES"),
                  const SizedBox(height: 12),
                  _buildInfoCard([
                    _buildDetailRow(
                      Icons.description_outlined,
                      "Descripción",
                      _stripHtml(lead.description),
                      isMultiLine: true,
                    ),
                  ]),
                  const SizedBox(height: 100), // Space for FAB
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeaderCard(CrmLead lead) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC8102E).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFC8102E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.business_center_outlined,
                  color: Color(0xFFC8102E),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lead.partnerName ?? 'No Customer',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (lead.priority != null) _buildPriorityBadge(lead.priority!),
            ],
          ),
          if (lead.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: lead.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (lead.niche != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D59F2).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFF0D59F2).withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  lead.niche!,
                  style: const TextStyle(
                    color: Color(0xFF0D59F2),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
          const Divider(height: 40, thickness: 1, color: Color(0xFFF1F5F9)),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  "Revenue",
                  "\$${lead.expectedRevenue.toStringAsFixed(2)}",
                  Icons.attach_money_rounded,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  "Probability",
                  "${lead.probability.toInt()}%",
                  Icons.analytics_outlined,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Color(0xFF94A3B8),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    // Filter out null or empty rows if any
    final validChildren = children.where((w) => w is! SizedBox).toList();

    // Add spacing between rows
    List<Widget> spacedChildren = [];
    for (int i = 0; i < validChildren.length; i++) {
      spacedChildren.add(validChildren[i]);
      if (i < validChildren.length - 1) {
        spacedChildren.add(const SizedBox(height: 16));
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(children: spacedChildren),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    int stars = int.tryParse(priority) ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Icon(
          index < stars ? Icons.star : Icons.star_border,
          size: 18,
          color: index < stars ? Colors.amber : Colors.grey.shade300,
        );
      }),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String? value, {
    bool isMultiLine = false,
    Widget? suffix,
  }) {
    final displayValue = (value == null || value.trim().isEmpty) ? "—" : value;

    return Row(
      crossAxisAlignment: isMultiLine
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF64748B), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayValue,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1E293B),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        // ignore: use_null_aware_elements
        if (suffix != null) suffix,
      ],
    );
  }

  Widget _buildCallButton(String? phone, {bool isProminent = false}) {
    if (phone == null || phone.isEmpty) return const SizedBox();

    return IconButton(
      onPressed: () async {
        final Uri url = Uri.parse('tel:$phone');
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Could not start the call")),
            );
          }
        }
      },
      icon: const Icon(Icons.phone_outlined, color: Colors.green),
      style: IconButton.styleFrom(
        backgroundColor: Colors.green.withValues(alpha: 0.1),
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  String _stripHtml(String? htmlString) {
    if (htmlString == null || htmlString.isEmpty) return "No description";
    final document = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    var parsed = htmlString.replaceAll(document, '');
    return parsed.trim().isEmpty ? "No description" : parsed.trim();
  }
}
