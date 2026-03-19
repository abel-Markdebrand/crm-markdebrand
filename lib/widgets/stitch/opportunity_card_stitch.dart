import 'package:flutter/material.dart';

class OpportunityCardStitch extends StatelessWidget {
  final String name;
  final String partnerName;
  final double expectedRevenue;
  final String priority;
  final List<String> tags; // Added tags
  final String? phone; // Added phone number
  final VoidCallback onTap;
  final VoidCallback onMove;
  final VoidCallback? onLongPress; // Added for legacy parity
  final VoidCallback? onWhatsApp; // Added WhatsApp callback

  const OpportunityCardStitch({
    super.key,
    required this.name,
    required this.partnerName,
    required this.expectedRevenue,
    required this.priority,
    this.tags = const [],
    this.phone,
    required this.onTap,
    required this.onMove,
    this.onLongPress,
    this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Light Gray requested by user
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                          fontFamily: 'CenturyGothic',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildPriorityStars(priority),
                  ],
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: tags
                        .take(3)
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      partnerName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Nexa',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "INGRESO ESTIMADO",
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Color(0xFF94A3B8),
                            fontFamily: 'Nexa',
                          ),
                        ),
                        Text(
                          "\$${expectedRevenue.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Nexa',
                            // Verde si es > 0, Rojo si es <= 0
                            color: expectedRevenue > 0
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (phone != null &&
                            phone!.isNotEmpty &&
                            onWhatsApp != null) ...[
                          _buildActionButton(
                            icon: Icons
                                .chat_bubble_outline_rounded, // WhatsApp icon representation
                            onPressed: onWhatsApp!,
                            color: const Color(
                              0xFF22C55E,
                            ).withValues(alpha: 0.1),
                            iconColor: const Color(0xFF22C55E),
                          ),
                          const SizedBox(width: 8),
                        ],
                        _buildActionButton(
                          icon: Icons.drive_file_move_outline,
                          onPressed: onMove,
                          color: const Color(0xFFE2E8F0), // Light Gray
                          iconColor: const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          icon: Icons.arrow_forward_rounded,
                          onPressed: onTap,
                          color: const Color(
                            0xFF0D59F2,
                          ), // Mantenemos azul para acción principal
                          iconColor: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityStars(String priority) {
    int stars = int.tryParse(priority) ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Icon(
          index < stars ? Icons.star : Icons.star_border,
          size: 14,
          color: index < stars ? Colors.amber : Colors.grey.shade400,
        );
      }),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    required Color iconColor,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: iconColor),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
