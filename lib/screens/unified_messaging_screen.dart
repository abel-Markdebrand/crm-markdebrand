import 'package:flutter/material.dart';
import 'package:mvp_odoo/screens/discussion_list_screen.dart';

class UnifiedMessagingScreen extends StatelessWidget {
  final int initialIndex;
  const UnifiedMessagingScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    // Simplified to only show DiscussionListScreen as WhatsApp is not ready.
    return const Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: DiscussionListScreen(showAppBar: true),
    );
  }
}
