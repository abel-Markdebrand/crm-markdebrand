import 'package:flutter/material.dart';
import 'package:mvp_odoo/services/crm_service.dart';
import '../models/crm_models.dart';
import 'package:mvp_odoo/screens/leads_creation_screen.dart';
import 'package:mvp_odoo/screens/quote_creation_screen.dart';
import '../services/voip_service.dart';
import '../services/call_manager.dart';

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
      appBar: AppBar(
        title: const Text('Detalle de Oportunidad'),
        actions: [
          FutureBuilder<CrmLead?>(
            future: _leadFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final lead = snapshot.data!;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editLead(lead),
                    ),
                  ],
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
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER CARD ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
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
                                color: const Color(
                                  0xFF0D59F2,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.star,
                                color: Color(0xFF0D59F2),
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
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.business,
                                        size: 16,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          lead.partnerName ?? 'Sin Cliente',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (lead.function != null &&
                                      lead.function!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        lead.function!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Priority Badge
                            if (lead.priority != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      size: 12,
                                      color: Colors.amber,
                                    ),
                                    Text(
                                      " ${lead.priority}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatItem(
                              "Revenue",
                              "\$${lead.expectedRevenue.toStringAsFixed(2)}",
                              Icons.attach_money,
                              Colors.green,
                            ),
                            _buildStatItem(
                              "Probability",
                              "${lead.probability}%",
                              Icons.donut_large,
                              Colors.orange,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- CONTACT INFO ---
                  const Text(
                    "INFORMACIÓN DE CONTACTO",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          Icons.email_outlined,
                          "Email",
                          lead.email ?? "N/A",
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          Icons.phone_outlined,
                          "Teléfono",
                          lead.phone ?? "N/A",
                          suffix: _buildCallButton(
                            lead.phone,
                            isProminent: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          Icons.language,
                          "Website",
                          lead.website ?? "N/A",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- ADDRESS INFO ---
                  const Text(
                    "DIRECCIÓN",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          Icons.location_on_outlined,
                          "Calle",
                          lead.street ?? "N/A",
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailRow(
                                Icons.location_city,
                                "Ciudad",
                                lead.city ?? "N/A",
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDetailRow(
                                Icons.numbers,
                                "C. Postal",
                                lead.zip ?? "N/A",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          Icons.flag_outlined,
                          "País",
                          lead.countryName ?? "N/A",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- NOTES SECTION ---
                  const Text(
                    "NOTAS INTERNAS",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: _buildDetailRow(
                      Icons.notes,
                      "Descripción",
                      _stripHtml(lead.description),
                      isMultiLine: true,
                    ),
                  ),

                  const Divider(height: 32),

                  // --- ACTIONS ---
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D59F2), Color(0xFF0A46C2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0D59F2,
                            ).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
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
                        icon: const Icon(Icons.receipt_long, size: 24),
                        label: const Text(
                          "COTIZACIÓN",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // ADD PADDING TO AVOID BOTTOM OVERFLOW
                  const SizedBox(height: 50),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _stripHtml(String? htmlString) {
    if (htmlString == null || htmlString.isEmpty) return "Sin descripción";
    final document = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    var parsed = htmlString.replaceAll(document, '');
    return parsed.trim().isEmpty ? "Sin descripción" : parsed.trim();
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
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
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
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (suffix != null) suffix,
      ],
    );
  }

  Widget _buildCallButton(String? phone, {bool isProminent = false}) {
    if (phone == null || phone.isEmpty) return const SizedBox();

    return ListenableBuilder(
      listenable: VoipService.instance.callManager,
      builder: (context, _) {
        final state = VoipService.instance.callManager.state;
        final isRegistered = state == AppCallState.registered;

        if (isProminent) {
          return InkWell(
            onTap: isRegistered
                ? () {
                    VoipService.instance.makeCall(phone);
                  }
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("VoIP no registrado")),
                    );
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isRegistered
                    ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isRegistered ? const Color(0xFF22C55E) : Colors.grey,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.phone,
                    color: isRegistered ? const Color(0xFF15803D) : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "LLAMAR",
                    style: TextStyle(
                      color: isRegistered
                          ? const Color(0xFF15803D)
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return IconButton(
          onPressed: isRegistered
              ? () {
                  VoipService.instance.makeCall(phone);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Llamando a $phone..."),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              : null,
          icon: Icon(
            Icons.phone_forwarded,
            color: isRegistered ? Colors.green : Colors.grey,
          ),
          tooltip: isRegistered ? "Llamar" : "VoIP no disponible",
        );
      },
    );
  }
}
