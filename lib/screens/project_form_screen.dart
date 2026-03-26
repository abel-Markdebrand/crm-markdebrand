import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mvp_odoo/services/project_service.dart';

class ProjectFormScreen extends StatefulWidget {
  final Map<String, dynamic>? project;

  const ProjectFormScreen({super.key, this.project});

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProjectService _projectService = ProjectService();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  Map<String, dynamic>? _selectedPartner;
  Map<String, dynamic>? _selectedUser;

  bool _isSaving = false;

  String _stripHtmlTags(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').replaceAll('&nbsp;', ' ').trim();
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.project?['name'] ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.project?['description'] != null
          ? _stripHtmlTags(widget.project!['description'])
          : '',
    );

    if (widget.project?['partner_id'] is List) {
      _selectedPartner = {
        'id': widget.project!['partner_id'][0],
        'name': widget.project!['partner_id'][1],
      };
    }

    if (widget.project?['user_id'] is List) {
      _selectedUser = {
        'id': widget.project!['user_id'][0],
        'name': widget.project!['user_id'][1],
      };
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final data = {
      'name': _nameController.text,
      'description': _descriptionController.text,
      'partner_id': _selectedPartner?['id'],
      'user_id': _selectedUser?['id'],
    };

    bool success = false;
    if (widget.project == null) {
      final id = await _projectService.createProject(data);
      success = id != null;
    } else {
      success = await _projectService.updateProject(
        widget.project!['id'],
        data,
      );
    }

    if (success && mounted) {
      Navigator.pop(context, true);
    } else if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving project')),
      );
    }
  }

  Future<void> _selectPartner() async {
    final Map<String, dynamic>? partner =
        await showSearch<Map<String, dynamic>?>(
          context: context,
          delegate: OdooSearchDelegate(
            searchFn: _projectService.searchPartners,
            title: 'Select Client',
          ),
        );
    if (partner != null) {
      setState(() => _selectedPartner = partner);
    }
  }

  Future<void> _selectUser() async {
    final Map<String, dynamic>? user = await showSearch<Map<String, dynamic>?>(
      context: context,
      delegate: OdooSearchDelegate(
        searchFn: _projectService.searchUsers,
        title: 'Select Responsible',
      ),
    );
    if (user != null) {
      setState(() => _selectedUser = user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.project != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isEditing ? "Edit Project" : "New Project",
          style: GoogleFonts.inter(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                "Save",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSectionTitle("General Information"),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nameController,
              label: "Project Name",
              placeholder: "e.g., Mobile App Development",
              validator: (v) => v == null || v.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle("Assignment"),
            const SizedBox(height: 16),
            _buildSelector(
              label: "Client",
              value: _selectedPartner?['name'] ?? "Select client",
              onTap: _selectPartner,
              icon: Icons.business_rounded,
            ),
            const SizedBox(height: 16),
            _buildSelector(
              label: "Responsible",
              value: _selectedUser?['name'] ?? "Select responsible",
              onTap: _selectUser,
              icon: Icons.person_rounded,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle("Description"),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descriptionController,
              label: "Notes or description",
              placeholder: "Additional project details...",
              maxLines: 5,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF94A3B8),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? placeholder,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelector({
    required String label,
    required String value,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF64748B)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: value.contains("Select")
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFFCBD5E1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class OdooSearchDelegate extends SearchDelegate<Map<String, dynamic>?> {
  final Future<List<Map<String, dynamic>>> Function(String) searchFn;
  final String title;

  OdooSearchDelegate({required this.searchFn, required this.title});

  @override
  String? get searchFieldLabel => title;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.length < 2) {
      return Center(
        child: Text(
          "Type at least 2 letters to search",
          style: GoogleFonts.inter(color: Colors.grey),
        ),
      );
    }
    return _buildList();
  }

  Widget _buildList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: searchFn(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No results found"));
        }
        return ListView.separated(
          itemCount: snapshot.data!.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
          itemBuilder: (context, index) {
            final item = snapshot.data![index];
            return ListTile(
              title: Text(
                item['name'] ?? '',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
              onTap: () => close(context, item),
            );
          },
        );
      },
    );
  }
}
