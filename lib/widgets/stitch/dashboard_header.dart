import 'package:flutter/material.dart';
import '../../models/crm_models.dart';

class DashboardHeader extends StatelessWidget {
  final List<CrmStage> stages;
  final int selectedStageId;
  final Function(int) onStageSelected;
  final Map<int, int> stageCounts;

  const DashboardHeader({
    super.key,
    required this.stages,
    required this.selectedStageId,
    required this.onStageSelected,
    this.stageCounts = const {},
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: stages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final stage = stages[index];
          final isSelected = stage.id == selectedStageId;

          return ActionChip(
            onPressed: () => onStageSelected(stage.id),
            backgroundColor: isSelected
                ? const Color(0xFF0D59F2)
                : Colors.white,
            side: BorderSide(
              color: isSelected ? Colors.transparent : Colors.grey[300]!,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stage.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${stageCounts[stage.id] ?? 0}",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : Colors.grey[500],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
