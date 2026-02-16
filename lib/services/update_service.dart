import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static final UpdateService instance = UpdateService._internal();

  UpdateService._internal();

  // TODO: Replace with actual URLs provided by the user
  final String _androidUrl =
      "https://play.google.com/store/apps/details?id=com.markdebrand.crm";
  final String _iOSUrl = "https://apps.apple.com/app/id123456789";

  Future<void> checkForUpdate(BuildContext context) async {
    // In a real app, you would fetch the latest version from an API here.
    // For now, we'll assume an update is always available for testing or
    // provide a manual "Update App" button action.

    // Check platform and launch appropriate URL
    await _launchUpdateUrl(context);
  }

  Future<void> _launchUpdateUrl(BuildContext context) async {
    String url = "";

    if (Platform.isAndroid) {
      url = _androidUrl;
    } else if (Platform.isIOS) {
      url = _iOSUrl;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Updates are only supported on Android and iOS."),
        ),
      );
      return;
    }

    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not launch update URL: $url")),
        );
      }
    }
  }

  // Method to show an update dialog (can be called from LoginScreen)
  void showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force user to choose
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Update Available"),
          content: const Text(
            "A new version of the app is available. Please update to continue using the app.",
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Later"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text("Update Now"),
              onPressed: () {
                Navigator.of(context).pop();
                _launchUpdateUrl(context);
              },
            ),
          ],
        );
      },
    );
  }
}
