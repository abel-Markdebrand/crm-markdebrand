import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necesario para PlatformException
import 'package:local_auth/local_auth.dart';

import 'dart:ui';

class BiometricAuthModal extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const BiometricAuthModal({super.key, required this.onAuthenticated});

  @override
  State<BiometricAuthModal> createState() => _BiometricAuthModalState();
}

class _BiometricAuthModalState extends State<BiometricAuthModal>
    with SingleTickerProviderStateMixin {
  final LocalAuthentication auth = LocalAuthentication();
  late AnimationController _controller;
  bool _isAuthenticating = false;
  String _statusMessage = "Confirm your identity to access CRM.";
  bool _showRetryButton =
      false; // Nuevo estado para controlar el botón de reintentar

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    // CORRECCIÓN 1: Esperar al primer frame antes de autenticar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    bool authenticated = false;

    // Reseteamos estados
    setState(() {
      _isAuthenticating = true;
      _showRetryButton = false;
      _statusMessage = "Scanning...";
    });

    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        if (!mounted) return;
        setState(() {
          _statusMessage = "Biometrics not supported on this device.";
          _isAuthenticating = false;
        });
        return;
      }

      // CORRECCIÓN 2: Autenticación biométrica
      authenticated = await auth.authenticate(
        localizedReason: 'Scan your face or fingerprint to authenticate',
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _showRetryButton = true;

        // Handle specific error codes
        if (e.code == 'NotAvailable') {
          _statusMessage = "Biometrics not available on this device.";
        } else if (e.code == 'NotEnrolled') {
          _statusMessage = "No biometrics enrolled on this device.";
        } else if (e.code == 'noCredentialsSet' || e.code == 'PasscodeNotSet') {
          _statusMessage =
              "Device not secured. Please set up a PIN, Pattern, or Face ID in your device settings.";
        } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
          _statusMessage = "Too many failed attempts. Try again later.";
        } else {
          // Fallback for other platform exceptions
          _statusMessage =
              "Authentication failed: ${e.message ?? 'Unknown error'}";
        }
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _showRetryButton = true;
        _statusMessage = "Unexpected error occurred.";
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      _isAuthenticating = false;
    });

    if (authenticated) {
      widget.onAuthenticated();
    } else {
      setState(() {
        _statusMessage = "Authentication failed.";
        _showRetryButton = true; // Mostrar botón para intentar de nuevo
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... El resto de tu código UI (BackdropFilter, Container, etc) sigue igual hasta el contenido ...

    // Solo cambiaremos la parte de los textos y botones dentro del Column:
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(color: Colors.black.withOpacity(0.1)),
          ),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // AQUÍ VA TU WIDGET DEL ESCÁNER (SizedBox con el Stack) QUE HICISTE
                // (Lo omito para no alargar la respuesta, pero pégalo igual)
                _buildScannerAnimation(), // Extraje tu widget a un método para limpiar

                const SizedBox(height: 24),

                Text(
                  _isAuthenticating
                      ? "Authenticating..."
                      : "Authentication Required",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        Colors.grey[600], // Un poco más oscuro para legibilidad
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 32),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Lógica de botones
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    // CORRECCIÓN 3: Botón de reintentar
                    if (_showRetryButton)
                      TextButton(
                        onPressed: _authenticate,
                        child: const Text(
                          "Retry",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D59F2),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tu método helper para el escáner (sin cambios, solo movido para orden)
  Widget _buildScannerAnimation() {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                width: 80 + (_controller.value * 10),
                height: 80 + (_controller.value * 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF0D59F2).withOpacity(0.2),
                    width: 2,
                  ),
                ),
              );
            },
          ),
          const Icon(Icons.face, size: 64, color: Color(0xFF0D59F2)),
          Positioned(top: 0, left: 0, child: _buildCorner(true, true)),
          Positioned(top: 0, right: 0, child: _buildCorner(true, false)),
          Positioned(bottom: 0, left: 0, child: _buildCorner(false, true)),
          Positioned(bottom: 0, right: 0, child: _buildCorner(false, false)),
        ],
      ),
    );
  }

  Widget _buildCorner(bool isTop, bool isLeft) {
    // ... Tu código original de _buildCorner ...
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? const BorderSide(color: Color(0xFF0D59F2), width: 2)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: Color(0xFF0D59F2), width: 2)
              : BorderSide.none,
          left: isLeft
              ? const BorderSide(color: Color(0xFF0D59F2), width: 2)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: Color(0xFF0D59F2), width: 2)
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: isTop && isLeft ? const Radius.circular(8) : Radius.zero,
          topRight: isTop && !isLeft ? const Radius.circular(8) : Radius.zero,
          bottomLeft: !isTop && isLeft ? const Radius.circular(8) : Radius.zero,
          bottomRight: !isTop && !isLeft
              ? const Radius.circular(8)
              : Radius.zero,
        ),
      ),
    );
  }
}
