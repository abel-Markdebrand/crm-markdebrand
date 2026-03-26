import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mvp_odoo/screens/unified_messaging_screen.dart';
import 'package:mvp_odoo/contacts_screen.dart';

import 'package:mvp_odoo/screens/leads_creation_screen.dart';
import 'package:mvp_odoo/screens/contact_form_screen.dart';
import 'package:mvp_odoo/screens/opportunity_detail_screen.dart';
import 'package:mvp_odoo/screens/whatsapp_chat_screen.dart';
import 'package:mvp_odoo/widgets/attendance_action_widget.dart';
import 'package:mvp_odoo/screens/job_position_list_screen.dart';
import 'package:mvp_odoo/screens/project_list_screen.dart';

import 'package:mvp_odoo/services/crm_service.dart';
import 'package:mvp_odoo/services/odoo_service.dart';
import 'package:mvp_odoo/services/permission_service.dart';
import 'package:mvp_odoo/models/crm_models.dart';
import 'package:mvp_odoo/widgets/stitch/opportunity_card_stitch.dart';
import 'package:mvp_odoo/widgets/stitch/bottom_nav.dart';
import 'package:mvp_odoo/screens/profile_screen.dart';
import 'package:mvp_odoo/screens/attendance_screen.dart';
import 'package:mvp_odoo/screens/no_access_screen.dart';
import 'package:mvp_odoo/sales_screen.dart';
import 'package:mvp_odoo/screens/products_screen.dart';
import 'package:mvp_odoo/utils/odoo_utils.dart';

enum AppNavigationContext { sales, rrhh, communication, operations }

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
  bool _isLoading = true;
  String _searchQuery = ""; // Added for parity
  String _drawerSearchQuery = ""; // Added for drawer search
  String? _errorMsg;
  Map<String, dynamic>? _userProfile;

  // Navigation State
  int _currentTabIndex = 0;
  bool _isLoadingPermissions = true;
  AppNavigationContext _currentContext = AppNavigationContext.sales;
  final List<StitchTab> _tabs = [];
  final PageController _pageController = PageController();

  // Animated Text State
  final ValueNotifier<String> _titleNotifier = ValueNotifier<String>("");
  final String _fullTitle = "Markdebrand";

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _startTitleAnimation();
    _initializePermissions();
  }

  Future<void> _initializePermissions() async {
    try {
      await PermissionService.instance
          .fetchPermissions(force: true)
          .timeout(const Duration(seconds: 25));
    } catch (e) {
      debugPrint("⚠️ Dashboard: Permission fetch failed or timed out: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPermissions = false;
        });
        _buildTabs();
        _loadStages();
      }
    }
  }

  void _buildTabs() {
    _tabs.clear();
    final p = PermissionService.instance;

    switch (_currentContext) {
      case AppNavigationContext.sales:
        _tabs.add(
          StitchTab(
            icon: Icons.group,
            label: "CRM",
            screen: p.hasCrmAccess
                ? _buildCrmDashboard()
                : const NoAccessScreen(moduleName: "CRM"),
            id: 'crm',
          ),
        );
        _tabs.add(
          StitchTab(
            icon: Icons.groups,
            label: "CONTACTS",
            screen: p.hasContactsAccess
                ? const ContactsScreen()
                : const NoAccessScreen(moduleName: "Contacts"),
            id: 'contacts',
          ),
        );
        _tabs.add(
          StitchTab(
            icon: Icons.shopping_cart,
            label: "SALES",
            screen: const SalesScreen(),
            id: 'sales',
          ),
        );
        _tabs.add(
          StitchTab(
            icon: Icons.inventory_2,
            label: "PRODUCTS",
            screen: const ProductsScreen(),
            id: 'products',
          ),
        );
        break;

      case AppNavigationContext.rrhh:
        _tabs.add(
          StitchTab(
            icon: Icons.person_add_alt_1,
            label: "RECRUIT.",
            screen: p.hasRecruitmentAccess
                ? const JobPositionListScreen()
                : const NoAccessScreen(moduleName: "Recruitment"),
            id: 'recruitment',
          ),
        );
        _tabs.add(
          StitchTab(
            icon: Icons.fingerprint,
            label: "ATTENDANCE",
            screen: p.hasAttendanceAccess
                ? const AttendanceScreen()
                : const NoAccessScreen(moduleName: "Attendance"),
            id: 'attendance',
          ),
        );
        break;

      case AppNavigationContext.communication:
        _tabs.add(
          StitchTab(
            icon: Icons.forum_rounded,
            label: "CHAT",
            screen: p.hasDiscussAccess
                ? const UnifiedMessagingScreen(initialIndex: 0)
                : const NoAccessScreen(moduleName: "Discuss"),
            id: 'discuss',
          ),
        );
        _tabs.add(
          StitchTab(
            icon: Icons.chat_rounded,
            label: "WHATSAPP",
            screen: p.hasDiscussAccess
                ? const UnifiedMessagingScreen(initialIndex: 1)
                : const NoAccessScreen(moduleName: "WhatsApp"),
            id: 'whatsapp',
          ),
        );
        break;

      case AppNavigationContext.operations:
        _tabs.add(
          StitchTab(
            icon: Icons.assignment_rounded,
            label: "PROJECTS",
            screen: const ProjectListScreen(),
            id: 'projects',
          ),
        );
        break;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleNotifier.dispose();
    super.dispose();
  }

  void _startTitleAnimation() {
    // Animation removed as per user request to use static module titles
    _titleNotifier.value = _fullTitle;
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await OdooService.instance.getUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {
      debugPrint("Error loading user profile in dashboard: $e");
    }
  }

  Future<void> _loadStages() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      // Parallelize RPC calls to Odoo
      final results = await Future.wait([
        _crmService.getPipelineStages(),
        _crmService.getStageCounts(),
      ]);

      final stages = results[0] as List<CrmStage>;
      final counts = results[1] as Map<int, int>;

      if (mounted) {
        setState(() {
          _stages = stages;
          _stageCounts = counts;
          if (stages.isNotEmpty && _selectedStageId == -1) {
            _selectedStageId = stages.first.id;
          }
          _isLoading = false;
        });
        // Initial build only or when strictly necessary
        if (_tabs.isEmpty) {
          _buildTabs();
        }
      }
    } catch (e, stacktrace) {
      debugPrint('ERROR IN _loadStages: $e\n$stacktrace');
      if (mounted) {
        setState(() {
          _errorMsg = OdooUtils.getFriendlyError(e);
          _isLoading = false;
        });
      }
    }
  }

  void _onTabSelected(int index) {
    setState(() => _currentTabIndex = index);
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
  }

  void _handleFabAction() {
    if (_tabs.isEmpty) return;
    final currentTabId = _tabs[_currentTabIndex].id;

    switch (currentTabId) {
      case 'crm':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LeadCreationScreen()),
        ).then((result) {
          if (result == true) _loadStages();
        });
        break;
      case 'contacts':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ContactFormScreen()),
        );
        break;
      case 'recruitment':
        // Recruitment creation logic
        break;
      case 'attendance':
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => const AttendanceActionWidget(),
        );
        break;
      default:
        // Generic add or snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Action not defined for $currentTabId")),
        );
    }
  }

  ImageProvider? _getAvatarImage() {
    if (_userProfile == null) return null;
    final imgData = _userProfile!['image_1920'];
    if (imgData != null && imgData is String && imgData.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(imgData));
      } catch (e) {
        debugPrint("Error decoding avatar image: $e");
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // background-light
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/image/logo_mdb.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: _titleNotifier,
                      builder: (context, value, _) {
                        String displayTitle = value;
                        if (_tabs.isNotEmpty &&
                            _currentTabIndex < _tabs.length) {
                          displayTitle = _tabs[_currentTabIndex].label;
                        }

                        // Logo consistent styling
                        return Text(
                          displayTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            fontFamily: 'CenturyGothic',
                          ),
                        );
                      },
                    ),
                  ],
                ),
                Text(
                  _tabs.isNotEmpty && _currentTabIndex < _tabs.length
                      ? "Markdebrand Ecosystem".toUpperCase()
                      : "Management System".toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                    fontFamily: 'Nexa',
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (PermissionService.instance.hasAttendanceAccess)
            IconButton(
              icon: const Icon(
                Icons.fingerprint_rounded,
                color: Color(0xFF64748B),
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  builder: (context) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: const AttendanceActionWidget(),
                  ),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
                _loadUserProfile();
              },
              child: _getAvatarImage() != null
                  ? CircleAvatar(backgroundImage: _getAvatarImage(), radius: 16)
                  : const CircleAvatar(
                      backgroundColor: Color(0xFFE2E8F0),
                      radius: 16,
                      child: Icon(Icons.person, size: 18, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: _tabs.isNotEmpty
          ? StitchBottomNav(
              currentIndex: _currentTabIndex,
              onTap: _onTabSelected,
              onAddPressed: _handleFabAction,
              tabs: _tabs,
              showAddButton: _currentContext == AppNavigationContext.sales,
            )
          : null,
      floatingActionButton:
          _tabs.isNotEmpty &&
              _tabs[_currentTabIndex].id == 'crm' &&
              PermissionService.instance.hasDiscussAccess
          ? FloatingActionButton(
              heroTag: "whatsapp",
              backgroundColor: const Color(0xFF25D366),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UnifiedMessagingScreen(),
                  ),
                );
              },
              child: const Icon(Icons.chat),
            )
          : null, // Hide on other tabs
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // --- CUSTOM BRANDED DRAWER HEADER ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 50,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Avatar
                _getAvatarImage() != null
                    ? Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                          image: DecorationImage(
                            image: _getAvatarImage()!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    : Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF1F5F9),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Color(0xFF64748B),
                          size: 32,
                        ),
                      ),
                const SizedBox(height: 16),
                // User Name
                Text(
                  _userProfile?['name'] is String
                      ? _userProfile!['name']
                      : "User",
                  style: const TextStyle(
                    color: Color(0xFF0F172A), // Dark Slate
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // User Email
                Text(
                  _userProfile?['email'] is String &&
                          (_userProfile!['email'] as String).isNotEmpty &&
                          _userProfile!['email'] != 'false'
                      ? _userProfile!['email']
                      : _userProfile?['login'] is String &&
                             (_userProfile!['login'] as String).isNotEmpty
                      ? _userProfile!['login']
                      : "usuario@markdebrand.com",
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13), // Slate 500
                ),
                // User Job Position
                if (_userProfile?['function'] is String &&
                    (_userProfile!['function'] as String).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _userProfile!['function'].toString().toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF475569), // Slate 600
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // --- BARRA DE BÚSQUEDA DEL DRAWER ---
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search module...",
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _drawerSearchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerCategory(
                  title: "SALES",
                  icon: Icons.monetization_on_rounded,
                  items: [
                    _DrawerItemData(
                      icon: Icons.dashboard_rounded,
                      title: 'CRM / Pipeline',
                      color: const Color(0xFF0F172A),
                      onTap: () =>
                          _switchContext(AppNavigationContext.sales, 0),
                      hasAccess: PermissionService.instance.hasCrmAccess,
                    ),
                    _DrawerItemData(
                      icon: Icons.contacts_rounded,
                      title: 'Contacts',
                      color: const Color(0xFF007AFF), // Markdebrand Blue
                      onTap: () =>
                          _switchContext(AppNavigationContext.sales, 1),
                      hasAccess: PermissionService.instance.hasContactsAccess,
                    ),
                    _DrawerItemData(
                      icon: Icons.bar_chart_rounded,
                      title: 'Sales',
                      color: const Color(0xFF007AFF),
                      onTap: () =>
                          _switchContext(AppNavigationContext.sales, 2),
                      hasAccess: true,
                    ),
                    _DrawerItemData(
                      icon: Icons.inventory_2_rounded,
                      title: 'Products',
                      color: const Color(0xFF64748B),
                      onTap: () =>
                          _switchContext(AppNavigationContext.sales, 3),
                      hasAccess: true,
                    ),
                  ],
                ),
                _buildDrawerCategory(
                  title: "HUMAN RESOURCES",
                  icon: Icons.badge_rounded,
                  items: [
                    _DrawerItemData(
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Recruitment',
                      color: const Color(0xFF007AFF), // Markdebrand Blue
                      onTap: () => _switchContext(AppNavigationContext.rrhh, 0),
                      hasAccess:
                          PermissionService.instance.hasRecruitmentAccess,
                    ),
                    _DrawerItemData(
                      icon: Icons.fingerprint,
                      title: 'Check-In / Out',
                      color: const Color(0xFF007AFF),
                      onTap: () => _switchContext(AppNavigationContext.rrhh, 1),
                      hasAccess: PermissionService.instance.hasAttendanceAccess,
                    ),
                  ],
                ),
                _buildDrawerCategory(
                  title: "OPERATIONS",
                  icon: Icons.build_circle_rounded,
                  items: [
                    _DrawerItemData(
                      icon: Icons.assignment_rounded,
                      title: 'Projects',
                      color: const Color(0xFF007AFF),
                      onTap: () =>
                          _switchContext(AppNavigationContext.operations, 0),
                      hasAccess: true,
                    ),
                  ],
                ),
                _buildDrawerCategory(
                  title: "COMMUNICATION",
                  icon: Icons.chat_bubble_rounded,
                  items: [
                    _DrawerItemData(
                      icon: Icons.forum_rounded,
                      title: 'Odoo Chat',
                      color: const Color(0xFF25D366),
                      onTap: () =>
                          _switchContext(AppNavigationContext.communication, 0),
                      hasAccess: PermissionService.instance.hasDiscussAccess,
                    ),
                    _DrawerItemData(
                      icon: Icons.chat_rounded,
                      title: 'WhatsApp',
                      color: const Color(0xFF16A34A),
                      onTap: () =>
                          _switchContext(AppNavigationContext.communication, 1),
                      hasAccess: PermissionService.instance.hasDiscussAccess,
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildDrawerFooter(),
        ],
      ),
    );
  }

  Widget _buildDrawerCategory({
    required String title,
    required IconData icon,
    required List<_DrawerItemData> items,
  }) {
    // Filtrar items según búsqueda
    final filteredItems = items.where((item) {
      return item.title.toLowerCase().contains(_drawerSearchQuery);
    }).toList();

    // Si hay búsqueda y no hay coincidencias en esta categoría, ocultarla por completo
    if (filteredItems.isEmpty && _drawerSearchQuery.isNotEmpty) {
      return const SizedBox.shrink();
    }

    // Si hay búsqueda activa y hay coincidencias, mostrar solo los items (sin expansión)
    if (_drawerSearchQuery.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: filteredItems.map((item) {
          return _buildDrawerItem(
            icon: item.icon,
            title: item.title,
            color: item.color,
            onTap: item.onTap,
          );
        }).toList(),
      );
    }

    // Si NO hay búsqueda, mostrar el comportamiento normal (ExpansionTile)
    return ExpansionTile(
      leading: Icon(icon, color: Colors.black87, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          fontFamily: 'CenturyGothic',
        ),
      ),
      initiallyExpanded: false,
      shape: const Border(),
      children: items.map((item) {
        return _buildDrawerItem(
          icon: item.icon,
          title: item.title,
          color: item.color,
          onTap: item.onTap,
        );
      }).toList(),
    );
  }

  void _switchContext(AppNavigationContext context, int tabIndex) {
    Navigator.pop(this.context);
    setState(() {
      _currentContext = context;
      _currentTabIndex = tabIndex;
      _buildTabs();
      _pageController.jumpToPage(tabIndex);
    });
  }

  Widget _buildDrawerFooter() {
    return Column(
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFooterLink("Terms of Use", "https://markdebrand.com/terms"),
              Text(" • ", style: TextStyle(color: Colors.grey[400])),
              _buildFooterLink(
                "Privacy Policy",
                "https://markdebrand.com/privacy",
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLink(String label, String url) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url)),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      hoverColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildBody() {
    if (_isLoadingPermissions) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tabs.isEmpty) {
      return const Center(
        child: Text("No modules available based on your user permissions."),
      );
    }

    // Instead of rendering static screens stored in _tabs, we dynamically
    // construct the CRM Dashboard to ensure it catches setState changes.
    List<Widget> activeScreens = _tabs.map((tab) {
      if (tab.id == 'crm') {
        return _buildCrmDashboard();
      }
      return tab.screen;
    }).toList();

    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      children: activeScreens,
      onPageChanged: (index) {
        if (_currentTabIndex != index) {
          setState(() => _currentTabIndex = index);
        }
      },
    );
  }

  Widget _buildCrmDashboard() {
    return RefreshIndicator(
      onRefresh: _loadStages,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(),

          // Bar de búsqueda
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Search by name, customer or city...",
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
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
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMsg != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 50,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Error connecting to CRM:\n$_errorMsg",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStages,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_stages.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  "No stages found. (The CRM is empty or not configured)",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            SliverFillRemaining(
              child: Column(
                children: [
                  // Pestañas Premium (Etapas)
                  SizedBox(
                    height: 84,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _stages.length,
                      itemBuilder: (context, index) {
                        final stage = _stages[index];
                        final isSelected = _selectedStageId == stage.id;
                        final count = _stageCounts[stage.id] ?? 0;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedStageId = stage.id);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 12, bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF475569)
                                  : Colors.white, // Slate 600 (Dark Gray)
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                if (!isSelected)
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                              border: Border.all(
                                color: isSelected
                                    ? Colors.black
                                    : const Color(0xFFF1F5F9),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  stage.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "$count",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black, // Forced black
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    width: 12,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: Colors
                                          .black, // Match indicator to text
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Lista de Leads de la Etapa Seleccionada
                  Expanded(
                    child: _selectedStageId == -1
                        ? const Center(child: Text("Select a stage"))
                        : SimpleOpportunityList(
                            key: ValueKey(
                              '${_selectedStageId}_$_searchQuery',
                            ), // Forza recarga al cambiar etapa o buscar
                            stageId: _selectedStageId,
                            searchQuery: _searchQuery,
                            stages: _stages,
                            onChanged:
                                _loadStages, // Recarga todo si hay cambios
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class SimpleOpportunityList extends StatefulWidget {
  final int stageId;
  final String searchQuery;
  final List<CrmStage> stages;
  final VoidCallback onChanged;

  const SimpleOpportunityList({
    super.key,
    required this.stageId,
    required this.searchQuery,
    required this.stages,
    required this.onChanged,
  });

  @override
  State<SimpleOpportunityList> createState() => _SimpleOpportunityListState();
}

class _SimpleOpportunityListState extends State<SimpleOpportunityList> {
  final CrmService _crmService = CrmService();
  List<CrmLead> _leads = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLeads();
  }

  Future<void> _fetchLeads() async {
    try {
      final leads = await _crmService.getPipeline(
        widget.stageId,
        searchQuery: widget.searchQuery,
      );
      if (mounted) {
        setState(() {
          _leads = leads;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showMoveDialog(CrmLead lead) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  "Move '${lead.name}' to:",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              ...widget.stages.where((s) => s.id != widget.stageId).map((
                stage,
              ) {
                return ListTile(
                  leading: const Icon(Icons.arrow_forward),
                  title: Text(stage.name),
                  onTap: () async {
                    Navigator.pop(context); // Cierra modal
                    // Muestra carga visual simple
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Moving lead...")),
                    );
                    try {
                      await _crmService.updateLeadStage(lead.id, stage.id);
                      widget.onChanged(); // Actualiza conteos y listas arriba
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error moving: $e")),
                        );
                      }
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          "Error loading leads: \n$_error",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_leads.isEmpty) {
      return const Center(
        child: Text(
          "No opportunities in this stage.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _leads.length,
      itemBuilder: (context, index) {
        final lead = _leads[index];
        return Stack(
          children: [
            OpportunityCardStitch(
              name: lead.name,
              partnerName: lead.partnerName ?? 'No Customer',
              expectedRevenue: lead.expectedRevenue,
              priority: lead.priority ?? '0',
              tags: lead.tags,
              phone: lead.phone, // Passing phone number
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        OpportunityDetailScreen(leadId: lead.id),
                  ),
                ).then((_) => _fetchLeads()); // Refresh when coming back
              },
              onLongPress: () => _showMoveDialog(lead),
              onMove: () => _showMoveDialog(lead),
              onWhatsApp: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WhatsAppChatScreen(
                      partnerId: lead.partnerId,
                      partnerName: lead.partnerName ?? 'Unknown',
                      partnerPhone: lead.phone,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// --- HELPER CLASSES FOR DRAWER ---
class _DrawerItemData {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final bool hasAccess;

  _DrawerItemData({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.hasAccess = true,
  });
}
