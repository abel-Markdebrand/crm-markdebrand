import 'package:flutter/material.dart';
import 'package:mvp_odoo/screens/products_screen.dart';
import 'package:mvp_odoo/screens/whatsapp_list_screen.dart';
import 'package:mvp_odoo/services/notification_service.dart';
import 'package:mvp_odoo/contacts_screen.dart';
import 'package:mvp_odoo/sales_screen.dart';

import 'package:mvp_odoo/screens/leads_creation_screen.dart';
import 'package:mvp_odoo/screens/contact_form_screen.dart';
import 'package:mvp_odoo/screens/opportunity_detail_screen.dart';

import 'package:mvp_odoo/services/crm_service.dart';
import 'package:mvp_odoo/services/odoo_service.dart';
import 'package:mvp_odoo/models/crm_models.dart';
import 'package:mvp_odoo/widgets/stitch/opportunity_card_stitch.dart';
import 'package:mvp_odoo/widgets/stitch/dashboard_header.dart';
import 'package:mvp_odoo/widgets/stitch/bottom_nav.dart';
import 'package:mvp_odoo/screens/profile_screen.dart';
import 'package:mvp_odoo/screens/dialpad_screen.dart';
import 'package:mvp_odoo/screens/reports_screen.dart';

class CrmDashboardScreen extends StatefulWidget {
  const CrmDashboardScreen({super.key});

  @override
  State<CrmDashboardScreen> createState() => _CrmDashboardScreenState();
}

class _CrmDashboardScreenState extends State<CrmDashboardScreen> {
  final CrmService _crmService = CrmService();
  List<CrmStage> _stages = [];
  Map<int, int> _stageCounts = {};
  int _selectedStageId = -1;
  String _searchQuery = "";
  bool _isLoading = true;

  // Navigation State
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadStages();
  }

  Future<void> _loadStages() async {
    setState(() => _isLoading = true);

    // DEBUG: Probe installed modules for 'phone' or 'voip'
    _probeInstalledModules();

    try {
      final stages = await _crmService.getPipelineStages();
      final counts = await _crmService.getStageCounts();

      if (mounted) {
        setState(() {
          _stages = stages;
          _stageCounts = counts;
          if (stages.isNotEmpty && _selectedStageId == -1) {
            _selectedStageId = stages.first.id;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Temporary Probe Logic
  Future<void> _probeInstalledModules() async {
    try {
      debugPrint("PROBE: Searching for 'phone' or 'voip' modules...");
      final res = await OdooService.instance.callKw(
        model: 'ir.module.module',
        method: 'search_read',
        args: [],
        kwargs: {
          'domain': [
            ['state', '=', 'installed'],
            '|',
            ['shortdesc', 'ilike', 'phone'],
            ['name', 'ilike', 'phone'],
          ],
          'fields': ['name', 'shortdesc', 'summary'],
          'limit': 10,
        },
      );
      debugPrint("PROBE RESULTS (PHONE): $res");

      final resVoip = await OdooService.instance.callKw(
        model: 'ir.module.module',
        method: 'search_read',
        args: [],
        kwargs: {
          'domain': [
            ['state', '=', 'installed'],
            ['name', 'ilike', 'voip'],
          ],
          'fields': ['name', 'shortdesc'],
        },
      );
      debugPrint("PROBE RESULTS (VOIP): $resVoip");
    } catch (e) {
      debugPrint("PROBE ERROR: $e");
    }
  }

  Future<void> _refreshCounts() async {
    final counts = await _crmService.getStageCounts();
    if (mounted) setState(() => _stageCounts = counts);
  }

  void _onStageSelected(int id) {
    setState(() => _selectedStageId = id);
  }

  void _onTabSelected(int index) {
    setState(() => _currentTabIndex = index);
  }

  void _handleFabAction() {
    if (_currentTabIndex == 0) {
      // CRM Tab -> New Opportunity
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LeadCreationScreen()),
      ).then((result) {
        if (result == true) {
          _loadStages();
        }
      });
    } else if (_currentTabIndex == 2) {
      // Contacts Tab -> New Contact
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ContactFormScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // background-light
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: StitchBottomNav(
        currentIndex: _currentTabIndex,
        onTap: _onTabSelected,
        onAddPressed: _handleFabAction,
      ),
      floatingActionButton:
          _currentTabIndex ==
              0 // Only show this floating buttons on CRM tab
          ? Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: "whatsapp",
                  mini: true,
                  backgroundColor: const Color(0xFF25D366),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WhatsAppListScreen(),
                      ),
                    );
                  },
                  child: const Icon(Icons.chat),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: "call",
                  mini: true,
                  backgroundColor: const Color(0xFF0D59F2),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DialpadScreen()),
                    );
                  },
                  child: const Icon(Icons.call),
                ),
              ],
            )
          : null, // Hide on other tabs
    );
  }

  Widget _buildBody() {
    switch (_currentTabIndex) {
      case 0:
        return _buildCrmDashboard();
      case 1:
        return const ProductsScreen();
      case 2:
        return const ContactsScreen();
      case 3:
        return const SalesScreen(); // Sales Module
      default:
        return const Center(child: Text("Coming Soon"));
    }
  }

  Widget _buildCrmDashboard() {
    return Column(
      children: [
        // CUSTOM APP BAR
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/image/logo_mdb.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Markdebrand CRM",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    "SALES MANAGEMENT",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Notification Badge
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none_outlined,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WhatsAppListScreen(),
                        ),
                      );
                    },
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: NotificationService.instance.unreadCount,
                    builder: (context, count, child) {
                      if (count == 0) return const SizedBox.shrink();
                      return Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              PopupMenuButton<String>(
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'profile') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  } else if (value == 'reports') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReportsScreen(),
                      ),
                    );
                  }
                  // Other actions can be handled here
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings, color: Colors.grey),
                        SizedBox(width: 8),
                        Text("Settings"),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'notifications',
                    child: Row(
                      children: [
                        Icon(Icons.notifications, color: Colors.grey),
                        SizedBox(width: 8),
                        Text("Notifications"),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'reports',
                    child: Row(
                      children: [
                        Icon(Icons.bar_chart, color: Colors.grey),
                        SizedBox(width: 8),
                        Text("Reports"),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Color(0xFF0D59F2)),
                        SizedBox(width: 8),
                        Text(
                          "My Profile",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
                child: const CircleAvatar(
                  backgroundImage: NetworkImage(
                    "https://i.pravatar.cc/150?img=11",
                  ),
                  radius: 18,
                ),
              ),
            ],
          ),
        ),

        // STAGE FILTERS
        if (_isLoading)
          const LinearProgressIndicator()
        else
          DashboardHeader(
            stages: _stages,
            selectedStageId: _selectedStageId,
            onStageSelected: _onStageSelected,
            stageCounts: _stageCounts,
          ),

        const SizedBox(height: 12),

        // SEARCH BAR
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Search opportunities...",
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                prefixIcon: Icon(
                  Icons.search,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Sub-header (Filters)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.filter_list, size: 16, color: Colors.black54),
                    SizedBox(width: 4),
                    Text(
                      "My Team",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.calendar_month, color: Colors.black54),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // OPPORTUNITY LIST (KANBAN COLUMN)
        Expanded(
          child: _selectedStageId == -1
              ? const SizedBox()
              : OpportunityList(
                  stageId: _selectedStageId,
                  searchQuery: _searchQuery,
                  stages: _stages,
                  onStageChanged: _onStageSelected,
                  onPipelineChanged: _refreshCounts,
                ),
        ),
      ],
    );
  }
}

class OpportunityList extends StatefulWidget {
  final int stageId;
  final String searchQuery;
  final List<CrmStage> stages;
  final Function(int) onStageChanged;
  final VoidCallback? onPipelineChanged;

  const OpportunityList({
    super.key,
    required this.stageId,
    required this.searchQuery,
    required this.stages,
    required this.onStageChanged,
    this.onPipelineChanged,
  });

  @override
  State<OpportunityList> createState() => _OpportunityListState();
}

class _OpportunityListState extends State<OpportunityList> {
  Future<List<CrmLead>>? _leadsFuture;

  @override
  void initState() {
    super.initState();
    _loadLeads();
  }

  @override
  void didUpdateWidget(covariant OpportunityList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stageId != widget.stageId ||
        oldWidget.searchQuery != widget.searchQuery) {
      _loadLeads();
    }
  }

  void _loadLeads() {
    setState(() {
      _leadsFuture = CrmService().getPipeline(
        widget.stageId,
        searchQuery: widget.searchQuery,
      );
    });
  }

  Color _getStageColor(int id) {
    const colors = [Colors.purple, Colors.teal, Colors.amber, Colors.green];
    return colors[id % colors.length];
  }

  void _showMoveStageModal(BuildContext context, CrmLead lead) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Text(
                  "Move '${lead.name}' to...",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
              ...widget.stages
                  .where((s) => s.id != widget.stageId) // Exclude current stage
                  .map(
                    (stage) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStageColor(
                          stage.id,
                        ).withValues(alpha: 0.2),
                        child: Icon(
                          Icons.arrow_forward,
                          color: _getStageColor(stage.id),
                        ),
                      ),
                      title: Text(stage.name),
                      onTap: () async {
                        Navigator.pop(context);
                        await _moveLead(lead, stage.id);
                      },
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _moveLead(CrmLead lead, int newStageId) async {
    // Optimistic UI update or Show Loading?
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Moving opportunity...")));

    try {
      await CrmService().updateLeadStage(lead.id, newStageId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Opportunity moved successfully!")),
        );
        _loadLeads(); // Refresh current list (item should disappear)
        widget.onPipelineChanged?.call(); // Refresh counts in parent
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error moving opportunity: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CrmLead>>(
      future: _leadsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  "No deals here",
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        final leads = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: leads.length,
          itemBuilder: (context, index) {
            final lead = leads[index];
            return OpportunityCardStitch(
              partnerName: lead.partnerName ?? 'Unknown Client',
              opportunityName: lead.name,
              expectedRevenue: lead.expectedRevenue,
              stageName: "Stage ${widget.stageId}",
              stageColor: _getStageColor(widget.stageId),
              partnerId: lead.partnerId,
              phone: lead.phone,
              onLongPress: () => _showMoveStageModal(context, lead),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        OpportunityDetailScreen(leadId: lead.id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
