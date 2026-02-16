import 'package:flutter/material.dart';

class LeadDetailScreen extends StatelessWidget {
  final Map<String, dynamic> lead;

  const LeadDetailScreen({super.key, required this.lead});

  @override
  Widget build(BuildContext context) {
    // Stitch Design Colors (from HTML)
    const primaryColor = Color(0xFF0D59F2);
    const backgroundLight = Color(0xFFF5F6F8);
    final textMain = const Color(0xFF0D121C);
    final textMuted = const Color(0xFF49659C);

    return Scaffold(
      backgroundColor: backgroundLight,
      body: CustomScrollView(
        slivers: [
          // Sticky App Bar
          SliverAppBar(
            pinned: true,
            backgroundColor: backgroundLight.withValues(alpha: 0.9),
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: textMain, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              "Lead Details",
              style: TextStyle(
                color: textMain,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(Icons.more_horiz, color: textMain),
                onPressed: () {},
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HERO SECTION
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image Placeholder
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                image: const DecorationImage(
                                  image: NetworkImage(
                                    "https://lh3.googleusercontent.com/aida-public/AB6AXuDnSgqtFL1Qm9mWMlMWQaIoZORBqxEfgk55V_eYTiP4eMpHUocUtBD2KoHiAJIatP9ZdhB3wnPQsf2KYYzlAHvzvoitR_kZVWD7EkMMpYmh91SG04wQN4J-1OkH68FCzLVDjsMmI9cIaqY69jpUOhK1BfFt1fG5uxJwO8brax9QWRF3-NCNuaYK4t33tmajzBtiSOAssplnet-pr8OriC2dJ18MGSbiFfsZTnwtGVv4EzJ6f5zMMTlgRzhB1Yiv6tCclTajKkIwqBPx",
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "NEW LEAD",
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    lead['name'] is String
                                        ? lead['name']
                                        : "Unknown Name",
                                    style: TextStyle(
                                      color: textMain,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    lead['parent_name'] is String
                                        ? "Company: ${lead['parent_name']}"
                                        : (lead['company_name'] is String
                                              ? lead['company_name']
                                              : ""), // If applicable
                                    style: TextStyle(
                                      color: textMuted,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Metadata
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 16, color: textMuted),
                            const SizedBox(width: 6),
                            Text(
                              lead['create_date'] is String
                                  ? "Created: ${lead['create_date']}"
                                  : "Recently",
                              style: TextStyle(color: textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Main Action
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Claim Lead",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // CONTACT INFORMATION
                  const SizedBox(height: 24),
                  Text(
                    "Contact Information",
                    style: TextStyle(
                      color: textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        // Name
                        _buildContactRow(
                          iconOrAvatar: Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: NetworkImage(
                                  "https://lh3.googleusercontent.com/aida-public/AB6AXuDgqs8c4Q4XOB3NGoalikN4SqEaV6UhvJ8gZwZWEGTex_4JYOHvcHUqXzM-eL92wFm5Mr0fVOyIBfO0Zr_mchOhMP1cITtIlGZL6ywPx04xVH8lDSazyQHjYpp6wQUmIyrbsMpwqNdYD3ciTXiyeq-fyIGbX16-Kh9v6SxtJ5lMTGO_W_RALYwOBt8WKEolBz4Uvn14TPHulEkXPaQscXsF0vzQkT1ZjZUP46f4uQznvI1bSQ0tw0XSmSF3Yv3ra4BXACTPWQnZNqel",
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          title: lead['contact_name'] is String
                              ? lead['contact_name']
                              : "Unknown",
                          subtitle: lead['function'] is String
                              ? lead['function']
                              : "No Job Position", // Job Position
                          trailing: Icon(Icons.person, color: primaryColor),
                        ),
                        Divider(height: 1, color: Colors.grey[100]),
                        // Phone
                        _buildContactRow(
                          iconOrAvatar: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.phone, color: primaryColor),
                          ),
                          title: lead['phone'] is String
                              ? lead['phone']
                              : "No Phone",
                          subtitle: "Mobile",
                          trailing: Icon(
                            Icons.copy,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                        ),
                        Divider(height: 1, color: Colors.grey[100]),
                        // Email
                        _buildContactRow(
                          iconOrAvatar: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.mail, color: primaryColor),
                          ),
                          title: lead['email_from'] is String
                              ? lead['email_from']
                              : "No Email",
                          subtitle: "Work Email",
                          trailing: Icon(
                            Icons.copy,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // INQUIRY DETAILS
                  const SizedBox(height: 24),
                  Text(
                    "Inquiry Details",
                    style: TextStyle(
                      color: textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.language,
                                  size: 18,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Source: Contact Directory",
                                  style: TextStyle(
                                    color: textMuted,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "INQUIRY #${lead['id']}",
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          lead['comment'] is String
                              ? lead['comment']
                              : "No additional notes available for this contact.",
                          style: TextStyle(
                            color: textMain,
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100), // Bottom spacer
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: FloatingActionButton.extended(
                heroTag: "whatsapp",
                onPressed: () {},
                backgroundColor: const Color(0xFF25D366),
                elevation: 4,
                icon: const Icon(Icons.chat_bubble, color: Colors.white),
                label: const Text(
                  "WhatsApp",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FloatingActionButton.extended(
                heroTag: "call",
                onPressed: () {},
                backgroundColor: primaryColor,
                elevation: 4,
                icon: const Icon(Icons.call, color: Colors.white),
                label: const Text(
                  "VoIP Call",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildContactRow({
    required Widget iconOrAvatar,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    // Stitch Design Colors
    final textMain = const Color(0xFF0D121C);
    final textMuted = const Color(0xFF49659C);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          iconOrAvatar,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
