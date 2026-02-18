import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login_screen.dart'; // To navigate to LoginScreen

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _urlController = TextEditingController();
  final _dbController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    _dbController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    final url = _urlController.text.trim();
    final dbName = _dbController.text.trim();

    if (url.isEmpty || dbName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor complete todos los campos.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('odoo_url', url);
      await prefs.setString('odoo_db', dbName);
      // Mark setup as complete
      await prefs.setBool('is_setup_completed', true);

      if (mounted) {
        // Navigate to Login and remove Setup from stack
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              const Text(
                "Configuración Inicial",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                "Antes de comenzar, necesitamos conectar con tu servidor Odoo.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),

              _buildLabel("URL del Servidor"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: "https://midominio.com",
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              _buildLabel("Base de Datos"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dbController,
                decoration: const InputDecoration(
                  hintText: "Ej: produccion",
                  prefixIcon: Icon(Icons.storage),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),
              _buildHelpBox(),

              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveConfig,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Guardar y Continuar",
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildHelpBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "¿Cómo encontrar el nombre de la DB?",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          SizedBox(height: 8),
          Text(
            "1. Ve a Ajustes en tu Odoo.\n"
            "2. Activa el 'Modo Desarrollador'.\n"
            "3. El nombre aparecerá en la barra superior.",
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
