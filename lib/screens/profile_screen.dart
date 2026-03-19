import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/odoo_service.dart';
import '../utils/odoo_utils.dart';

const kBrandIndigo = Color(0xFF6366F1);
const kBrandTeal = Color(0xFF14B8A6);
const kTextMain = Color(0xFF0F172A);
const kTextMuted = Color(0xFF64748B);
const kTextLight = Color(0xFF94A3B8);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _userData = {};
  String? _errorMessage;

  // Editable states
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _mobileController;
  late TextEditingController _signatureController;
  late TextEditingController _pinController;
  String? _selectedLang;
  String? _selectedNotification;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _mobileController = TextEditingController();
    _signatureController = TextEditingController();
    _pinController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _mobileController.dispose();
    _signatureController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await OdooService.instance.getUserProfile();
      if (mounted) {
        setState(() {
          _userData = data;
          _isLoading = false;

          // Initialize controllers
          _nameController.text = OdooUtils.safeString(data['name']);
          _phoneController.text = OdooUtils.safeString(data['phone']);
          _mobileController.text = OdooUtils.safeString(data['mobile']);
          _signatureController.text = _parseSignature(data['signature']);
          _pinController.text = OdooUtils.safeString(data['attendance_pin']);

          _selectedLang = data['lang'];
          _selectedNotification = data['notification_type'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final odoo = OdooService.instance;

      // Update User Preferences (res.users)
      final userSuccess = await odoo.updateUserPreferences({
        'lang': _selectedLang,
        'notification_type': _selectedNotification,
        'attendance_pin': _pinController.text,
        'signature': _signatureController.text.isNotEmpty
            ? '<span>${_signatureController.text}</span>'
            : '',
      });

      // Update Partner Preferences (res.partner)
      final partnerSuccess = await odoo.updatePartnerPreferences({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'mobile': _mobileController.text,
      });

      if (mounted) {
        if (userSuccess && partnerSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ajustes guardados correctamente")),
          );
          _loadProfile(); // Refresh
        } else {
          throw Exception("Error parcial al guardar");
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 1024,
    );

    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);

      final success = await OdooService.instance.updateUserProfileImage(
        base64String,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Foto de perfil actualizada")),
          );
          _loadProfile(); // Refresh
        }
      } else {
        throw Exception("Error al actualizar la foto");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Configuración de Perfil",
          style: TextStyle(
            color: kTextMain,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            fontFamily: 'CenturyGothic',
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: TextButton.styleFrom(foregroundColor: kBrandIndigo),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kBrandIndigo,
                        ),
                      )
                    : Text(
                        "GUARDAR",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          fontFamily: 'Nexa',
                        ),
                      ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // --- PREMIUM GRADIENT HEADER ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0F172A),
                          const Color(0xFF1E293B),
                          kBrandIndigo.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: _pickAndUploadImage,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kBrandIndigo.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _buildAvatarImage(
                                    _userData['image_1920'],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: _pickAndUploadImage,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    color: kTextMain,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          OdooUtils.safeString(_userData['name']),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontFamily: 'CenturyGothic',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            OdooUtils.safeString(
                              _userData['function'] ?? "Empleado",
                            ).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: kBrandTeal,
                              letterSpacing: 1.5,
                              fontFamily: 'Nexa',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Account Details Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "DETALLES DE LA CUENTA",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: kTextMuted,
                                  letterSpacing: 1.0,
                                  fontFamily: 'CenturyGothic',
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildEditableDetailRow(
                                Icons.email_outlined,
                                "Correo Electrónico",
                                _userData['login'] ?? "",
                                readOnly: true,
                              ),
                              const Divider(
                                height: 32,
                                color: Color(0xFFF1F5F9),
                              ),
                              _buildEditableDetailRow(
                                Icons.phone_outlined,
                                "Teléfono",
                                "",
                                controller: _phoneController,
                              ),
                              const Divider(
                                height: 32,
                                color: Color(0xFFF1F5F9),
                              ),
                              _buildEditableDetailRow(
                                Icons.smartphone,
                                "Móvil",
                                "",
                                controller: _mobileController,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // System Settings Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "PREFERENCIAS",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: kTextMuted,
                                  letterSpacing: 1.0,
                                  fontFamily: 'CenturyGothic',
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildLabelValueRow(
                                "Idioma",
                                _selectedLang == 'es_ES'
                                    ? 'Español (España)'
                                    : (_selectedLang == 'es_MX'
                                          ? 'Español (México)'
                                          : 'Inglés (EE. UU.)'),
                                onEdit: () => _showPicker(
                                  "Idioma",
                                  {
                                    'en_US': 'Inglés (EE. UU.)',
                                    'es_ES': 'Español (España)',
                                    'es_MX': 'Español (México)',
                                  },
                                  _selectedLang,
                                  (v) => setState(() => _selectedLang = v),
                                ),
                              ),
                              const Divider(
                                height: 24,
                                color: Color(0xFFF1F5F9),
                              ),
                              _buildLabelValueRow(
                                "Notificaciones",
                                _selectedNotification == 'email'
                                    ? 'Por Correo'
                                    : 'En Odoo',
                                onEdit: () => _showPicker(
                                  "Notificaciones",
                                  {'email': 'Por Correo', 'manual': 'En Odoo'},
                                  _selectedNotification,
                                  (v) =>
                                      setState(() => _selectedNotification = v),
                                ),
                              ),
                              const Divider(
                                height: 24,
                                color: Color(0xFFF1F5F9),
                              ),
                              _buildEditableDetailRow(
                                Icons.password,
                                "PIN de Asistencia",
                                "",
                                controller: _pinController,
                                isPassword: true,
                              ),
                              const Divider(
                                height: 32,
                                color: Color(0xFFF1F5F9),
                              ),
                              _buildEditableDetailRow(
                                Icons.edit_note,
                                "Firma de Correo",
                                "",
                                controller: _signatureController,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Legal Information Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "INFORMACIÓN LEGAL",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: kTextMuted,
                                  letterSpacing: 1.0,
                                  fontFamily: 'CenturyGothic',
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildLegalRow(
                                context,
                                Icons.description_outlined,
                                "Términos y Condiciones",
                                "https://mardebran.com/terms",
                              ),
                              const Divider(
                                height: 32,
                                color: Color(0xFFF1F5F9),
                              ),
                              _buildLegalRow(
                                context,
                                Icons.privacy_tip_outlined,
                                "Política de Privacidad",
                                "https://mardebran.com/privacy",
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Logout Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _handleLogout(context),
                            icon: const Icon(Icons.logout),
                            label: const Text("Cerrar Sesión"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444), // Red
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cerrar Sesión"),
        content: const Text("¿Estás seguro de que deseas cerrar sesión?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text("Cerrar Sesión"),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      // Clear session data
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('odoo_pass'); // Clear password for security

        // Optionally clear all credentials
        // await prefs.clear();

        // Navigate to login screen and clear navigation stack
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } catch (e) {
        debugPrint("Error during logout: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Error al cerrar sesión"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildAvatarImage(dynamic base64String) {
    if (base64String is String && base64String.isNotEmpty) {
      try {
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: const Icon(Icons.person, size: 48, color: Colors.white),
            );
          },
        );
      } catch (e) {
        return Container(
          color: Colors.grey[300],
          child: const Icon(Icons.person, size: 48, color: Colors.white),
        );
      }
    }
    return Container(
      color: Colors.grey[300],
      child: const Icon(Icons.person, size: 48, color: Colors.white),
    );
  }

  Widget _buildEditableDetailRow(
    IconData icon,
    String label,
    String value, {
    TextEditingController? controller,
    bool readOnly = false,
    bool isPassword = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kBrandIndigo.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: kBrandIndigo, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Nexa',
                  fontWeight: FontWeight.w700,
                  color: kTextLight,
                ),
              ),
              const SizedBox(height: 2),
              controller != null
                  ? TextField(
                      controller: controller,
                      obscureText: isPassword,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                  : Text(
                      value.isEmpty ? "No establecido" : value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Nexa',
                        color: readOnly
                            ? const Color(0xFF64748B)
                            : const Color(0xFF0F172A),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabelValueRow(
    String label,
    String value, {
    required VoidCallback onEdit,
  }) {
    return InkWell(
      onTap: onEdit,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0F172A),
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 15, color: Color(0xFF64748B)),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPicker(
    String title,
    Map<String, String> options,
    String? current,
    Function(String) onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const Divider(),
          ...options.entries.map(
            (e) => ListTile(
              title: Text(e.value),
              trailing: current == e.key
                  ? const Icon(Icons.check, color: kBrandIndigo)
                  : null,
              onTap: () {
                onSelect(e.key);
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _parseSignature(dynamic signatureField) {
    if (signatureField is String && signatureField.isNotEmpty) {
      // Simple HTML tag removal
      return signatureField
          .replaceAll(
            RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true),
            '',
          )
          .trim();
    }
    return "";
  }

  Widget _buildLegalRow(
    BuildContext context,
    IconData icon,
    String label,
    String url,
  ) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kBrandIndigo.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: kBrandIndigo, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: kTextMain,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 20),
        ],
      ),
    );
  }
}
