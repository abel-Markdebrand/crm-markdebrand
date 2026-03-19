import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mvp_odoo/screens/discussion_list_screen.dart';
import 'package:mvp_odoo/screens/whatsapp_list_screen.dart';

class UnifiedMessagingScreen extends StatelessWidget {
  final int initialIndex;
  const UnifiedMessagingScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "Centro de Mensajes",
            style: GoogleFonts.inter(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: const Color(0xFF2563EB),
            indicatorWeight: 3,
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: const Color(0xFF64748B),
            isScrollable: false,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: "Discusión", icon: Icon(Icons.forum_rounded, size: 20)),
              Tab(text: "WhatsApp", icon: Icon(Icons.chat_rounded, size: 20)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DiscussionListScreen(showAppBar: false),
            WhatsAppListScreen(showAppBar: false),
          ],
        ),
      ),
    );
  }
}
