import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/odoo_service.dart';
import 'services/voip_service.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'screens/crm_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // CONFIGURACIÓN INTERNA: AJUSTA ESTOS VALORES EN EL CÓDIGO
  final TextEditingController _urlController = TextEditingController(
    text: 'https://app.prismahexagon.com',
  );
  final TextEditingController _dbController = TextEditingController(
    text: 'test19',
  );
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _urlController.text =
            prefs.getString('odoo_url') ?? 'https://app.prismahexagon.com';
        _dbController.text = prefs.getString('odoo_db') ?? 'test19';

        if (prefs.containsKey('odoo_user')) {
          _userController.text = prefs.getString('odoo_user')!;
        }
        if (prefs.containsKey('odoo_pass')) {
          _passwordController.text = prefs.getString('odoo_pass')!;
        }
      });
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('odoo_url', _urlController.text);
    await prefs.setString('odoo_db', _dbController.text);
    await prefs.setString('odoo_user', _userController.text);
    await prefs.setString('odoo_pass', _passwordController.text);
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);

    try {
      // Guardar credenciales para futuro uso
      await _saveCredentials();

      // Inicializamos el cliente
      final url = _urlController.text.trim();
      OdooService.instance.init(url);

      // Autenticación robusta
      final db = _dbController.text.trim();
      final user = _userController.text.trim();
      final pass = _passwordController.text.trim();

      debugPrint("LOGIN ATTEMPT: URL=$url, DB=$db, User=$user");

      await OdooService.instance.authenticate(db, user, pass);

      // Start services
      if (!OdooService.instance.isPrismaMode) {
        try {
          await OdooService.instance.initWhatsAppClient();
        } catch (_) {}
      }

      try {
        await VoipService.instance.initialize();
      } catch (_) {}

      await NotificationService.instance.initialize();
      NotificationService.instance.startPolling();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const CrmDashboardScreen()),
        );
      }
    } on OdooServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textMuted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // LOGO
                      Hero(
                        tag: 'logo',
                        child: Container(
                          width: 100,
                          height: 100,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/image/logo_mdb.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, _, __) =>
                                const Icon(Icons.rocket_launch, size: 40),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // WELCOME
                      const Text(
                        "Welcome back",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Enter your credentials to continue",
                        style: TextStyle(color: textMuted, fontSize: 16),
                      ),
                      const SizedBox(height: 40),

                      const SizedBox(height: 32),

                      // FORM
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_showAdvanced) ...[
                            _buildLabel("Server URL"),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _urlController,
                              decoration: const InputDecoration(
                                hintText: "https://odoo.example.com",
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildLabel("Database"),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _dbController,
                              decoration: const InputDecoration(
                                hintText: "my_database",
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          _buildLabel("Email / Username"),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _userController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: "user@example.com",
                              prefixIcon: Icon(Icons.person_outline, size: 20),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildLabel("Password"),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              hintText: "••••••••",
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Log In",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ADVANCED TOGGLE
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _showAdvanced = !_showAdvanced),
                        icon: Icon(
                          _showAdvanced
                              ? Icons.settings
                              : Icons.settings_outlined,
                          size: 16,
                        ),
                        label: Text(
                          _showAdvanced
                              ? "Hide Advanced Settings"
                              : "Advanced Settings",
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // LEGAL LINKS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFooterLink(
                            "Terms of Use",
                            "https://markdebrand.com/terms",
                          ),
                          Text(
                            " • ",
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          _buildFooterLink(
                            "Privacy Policy",
                            "https://markdebrand.com/privacy",
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            // FOOTER COPYRIGHT
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0, left: 24, right: 24),
              child: GestureDetector(
                onTap: () => UpdateService.instance.showUpdateDialog(context),
                child: Text(
                  "© 2024 Markdebrand Agency • v2.4.0",
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
