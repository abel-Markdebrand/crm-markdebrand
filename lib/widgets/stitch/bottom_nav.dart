import 'package:flutter/material.dart';

class StitchTab {
  final IconData icon;
  final String label;
  final Widget screen;
  final String
  id; // added identifier like 'crm', 'contacts' etc to know what logic to fire for FAB

  StitchTab({
    required this.icon,
    required this.label,
    required this.screen,
    required this.id,
  });
}

class StitchBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAddPressed;
  final List<StitchTab> tabs;
  final bool showAddButton;

  const StitchBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onAddPressed,
    required this.tabs,
    this.showAddButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabs.length, (index) {
              return _buildNavItem(tabs[index].icon, tabs[index].label, index);
            }),
          ),
          if (showAddButton)
            Positioned(
              top: -24,
              child: GestureDetector(
                onTap: onAddPressed,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A), // Slate 900
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = currentIndex == index;
    const kActiveColor = Color(0xFF6366F1); // Brand Indigo
    const kInactiveColor = Color(0xFF94A3B8); // Muted
    final color = isActive ? kActiveColor : kInactiveColor;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4), // Hit area
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                fontFamily: 'Nexa',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
