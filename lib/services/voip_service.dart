import 'package:flutter/material.dart';
import 'call_manager.dart';
import 'odoo_service.dart';

/// Service that acts as a wrapper/bridge for the VoIP Module Logic.
/// This services creates the instance of the VoIP logic and exposes simple methods.
class VoipService {
  static final VoipService instance = VoipService._internal();

  factory VoipService() {
    return instance;
  }

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  VoipService._internal();

  final CallManager _callManager = CallManager.instance;
  CallManager get callManager => _callManager;
  bool _isInitialized = false;

  /// Initializes the VoIP engine using credentials from OdooService.
  /// This mimics the initialization logic of the Odoo 'voip' module.
  Future<void> initialize() async {
    if (_isInitialized) return;
    debugPrint("🚀 VOIP SERVICE: Initializing...");

    try {
      final config = await OdooService.instance.fetchVoipConfig();
      if (config == null || !config.isValid) {
        debugPrint(
          "⚠️ VOIP SERVICE: Config missing or invalid. Skipping initialization.",
        );
        return;
      }

      debugPrint("✅ VOIP SERVICE: Config Validated -> $config");
      await _callManager.init(config: config);
      _isInitialized = true;
    } catch (e) {
      debugPrint("❌ VOIP SERVICE: Internal Logic Error: $e");
    }
  }

  /// Initiates a call to the specified number.
  /// Uses the integrated logic to ensure compatibility with the Odoo backend.
  Future<void> makeCall(String number) async {
    debugPrint("VoipModuleService: Calling $number...");
    try {
      await _callManager.call(number);
    } catch (e) {
      debugPrint("⛔ VOIP ERROR: $e");

      // Show Snackbar to user
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString().replaceAll('Exception: ', '')}"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Ends the current call.
  void hangup() {
    debugPrint("VoipModuleService: Hanging up...");
    _callManager.hangup();
  }

  /// Manually retry connection
  Future<void> retryConnection() async {
    debugPrint("VoipService: Retrying connection...");
    try {
      await _callManager.retryConnection();
    } catch (e) {
      debugPrint("❌ VOIP RETRY ERROR: $e");
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            "Retry failed: ${e.toString().replaceAll('Exception: ', '')}",
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
