import 'package:flutter/material.dart';
import '../../screens/whatsapp_chat_screen.dart';

class OpportunityCardStitch extends StatelessWidget {
  final String partnerName;
  final String email;
  final String opportunityName;
  final double expectedRevenue;
  final Color stageColor;
  final int? partnerId;
  final String? phone;
  final String stageName;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const OpportunityCardStitch({
    super.key,
    required this.partnerName,
    this.email = "",
    required this.opportunityName,
    required this.expectedRevenue,
    this.stageColor = Colors.blue,
    required this.stageName,
    this.partnerId,
    this.phone,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Color Strip
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: stageColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon + Name
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: const Icon(
                                Icons.business,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    partnerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (email.isNotEmpty)
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Price Column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "\$${expectedRevenue.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0D59F2), // Primary
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stageName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: stageColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Tags Row (Static for visual parity with design, logic can vary)
                  Row(
                    children: [
                      _buildTag("Viable", Colors.green),
                      const SizedBox(width: 8),
                      _buildTag("High Priority", Colors.blue),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),

                  // Footer Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Avatars placeholder
                          _buildAvatar(Colors.blue[100]!),
                          Transform.translate(
                            offset: const Offset(-8, 0),
                            child: _buildAvatar(Colors.grey[300]!),
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chat, color: Colors.green),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WhatsAppChatScreen(
                                    partnerId: partnerId,
                                    partnerName: partnerName,
                                    partnerPhone: phone,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed:
                                onTap, // Bind external action to this button
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D59F2),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text("Create Quote"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color.shade500,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
