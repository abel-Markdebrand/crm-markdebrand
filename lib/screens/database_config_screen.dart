import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/odoo_service.dart'; // Import for OdooServiceException if needed, or consistent styling

class DatabaseConfigScreen extends StatefulWidget {
  const DatabaseConfigScreen({super.key});

  @override
  State<DatabaseConfigScreen> createState() => _DatabaseConfigScreenState();
}

class _DatabaseConfigScreenState extends State<DatabaseConfigScreen> {
  final _dbController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDatabase();
  }

  Future<void> _loadDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dbController.text = prefs.getString('odoo_db') ?? '';
    });
  }

  Future<void> _saveDatabase() async {
    final dbName = _dbController.text.trim();
    if (dbName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingrese el nombre de la base de datos.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('odoo_db', dbName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Base de datos guardada correctamente.'),
          ),
        );
        // Navigate back or to login
        Navigator.of(context).pop(dbName);
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
      appBar: AppBar(title: const Text("Configurar Base de Datos")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Instrucciones",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Para conectar con su servidor Odoo, necesitamos el nombre exacto de la base de datos. Siga estos pasos para encontrarlo:",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            _buildStep(1, "Inicie sesión en su Odoo desde un navegador web."),
            _buildStep(2, "Vaya a Ajustes (Settings)."),
            _buildStep(
              3,
              "Desplácese hacia abajo y haga clic en 'Activar modo desarrollador'.",
            ),
            _buildStep(
              4,
              "Una vez activado, el nombre de la base de datos aparecerá en la parte superior derecha de la barra de navegación, o puede verlo en la URL si es `midominio.com?db=nombre_bd`.",
            ),
            const SizedBox(height: 24),
            const Text(
              "Ingrese el nombre de la base de datos:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _dbController,
              decoration: const InputDecoration(
                hintText: "Ej: markdebrand, test19, produccion",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.storage),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveDatabase,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Guardar y Continuar"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).primaryColor,
            child: Text(
              "$number",
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}
