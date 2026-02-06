import 'package:flutter/material.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/odoo_service.dart';
import 'services/voip_service.dart';
import 'screens/crm_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // CONFIGURACIÓN INTERNA: AJUSTA ESTOS VALORES EN EL CÓDIGO
  final _urlController = TextEditingController(
    text: 'http://147.93.40.102:8071',
  );
  final _dbController = TextEditingController(text: 'testmdb');
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        if (prefs.containsKey('odoo_url')) {
          _urlController.text = prefs.getString('odoo_url')!;
        }
        if (prefs.containsKey('odoo_db')) {
          _dbController.text = prefs.getString('odoo_db')!;
        }
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

      // Inicializamos el cliente (LEGACY)
      OdooService.instance.init(_urlController.text);

      // Intentamos autenticar usando el servicio legacy
      await OdooService.instance.authenticate(
        _dbController.text,
        _userController.text,
        _passwordController.text,
      );

      // VOIP INITIALIZATION (Added check)
      try {
        await VoipService.instance.initialize();
      } catch (e) {
        debugPrint("VoIP Init Warning: $e");
        // Don't block login if VoIP fails, but log it
      }

      // Si pasa, vamos a la pantalla principal
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const CrmDashboardScreen()),
        );
      }
    } on OdooException catch (e) {
      // Manejo básico de errores
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión: ${e.message}')),
        );
      }
      debugPrint('Login Error: $e');
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error de Formato: Revise la URL del servidor.'),
          ),
        );
      }
      debugPrint('Format Error (Posible URL incorrecta): $e');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stitch Design Implementation
    final primaryColor = Theme.of(context).primaryColor;
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
                      // LOGO SECTION
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/image/logo_mdb.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback si no existe el logo
                              return Container(
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.rocket_launch,
                                  color: Colors.white,
                                  size: 60,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Markdebrand",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        "CRM & SALES PORTAL",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          color: textMuted,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // WELCOME TEXT
                      const Text(
                        "Welcome back",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Please enter your credentials",
                        style: TextStyle(fontSize: 15, color: textMuted),
                      ),

                      const SizedBox(height: 32),

                      // FORM SECTION
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Email / Username"),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _userController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: "name@company.com",
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildLabel("Password"),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: "••••••••",
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // BUTTON
                      ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("Log In"),
                      ),

                      const SizedBox(height: 24),

                      // FOOTER LINKS & BIOMETRICS
                      TextButton(
                        onPressed: () {}, // Forgot password placeholder
                        child: Text(
                          "Forgot your password?",
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            // FOOTER COPYRIGHT
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                "© 2024 Markdebrand Agency • v2.4.0",
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ),
          ],
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
