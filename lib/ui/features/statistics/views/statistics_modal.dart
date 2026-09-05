import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../target_list/view_models/target_list_view_model.dart';
import '../../../../data/models/target_item.dart';
import '../../../core/formatters.dart';
import '../../../core/i18n.dart';

class StatisticsModal extends StatelessWidget {
  const StatisticsModal({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TargetListViewModel>();
    final isDark = vm.isDarkMode;
    final lang = vm.language;

    final bg = isDark ? const Color(0xFF1C1D22) : const Color(0xFFFAF6EF);
    final cardBg = isDark ? const Color(0xFF262832) : const Color(0xFFEFEADF);
    final metricBg = isDark ? const Color(0xFF232530) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF353846) : const Color(0xFFE0D5C3);
    final textColor = isDark ? Colors.white : const Color(0xFF2C2418);
    final mutedTextColor = isDark ? const Color(0xFFA0A5B5) : const Color(0xFF7A6F60);
    final bannerBg = isDark ? const Color(0xFF282A34) : const Color(0xFF2C2418);

    final targets = vm.targets;
    final totalSaved = targets.fold<double>(0, (sum, t) => sum + t.currentAmount);
    final totalGoal = targets.fold<double>(0, (sum, t) => sum + t.targetAmount);
    final completedCount = targets.where((t) => t.isCompleted).length;
    final activeCount = targets.where((t) => !t.isCompleted).length;
    final overallProgress = totalGoal > 0 ? (totalSaved / totalGoal * 100).clamp(0.0, 100.0) : 0.0;

    String getSmartInsight() {
      if (targets.isEmpty) {
        return AppTranslations.tr(lang, 'stats.smart_empty');
      }
      final sorted = List<TargetItem>.from(targets)
        ..sort((a, b) => (b.targetAmount - b.currentAmount).compareTo(a.targetAmount - a.currentAmount));
      final highest = sorted.isNotEmpty ? sorted.first : null;
      if (highest != null && highest.targetAmount > highest.currentAmount) {
        final remaining = highest.targetAmount - highest.currentAmount;
        final dailyTarget = 20000.0;
        final daysLeft = (remaining / dailyTarget).ceil();
        final formattedDaily = formatRupiah(dailyTarget, vm.currency);
        return '${AppTranslations.tr(lang, 'stats.smart_routine_1')} $formattedDaily ${AppTranslations.tr(lang, 'stats.smart_routine_2')} "${highest.title}" ${AppTranslations.tr(lang, 'stats.smart_routine_3')} $daysLeft ${AppTranslations.tr(lang, 'stats.days_left')}';
      }
      return AppTranslations.tr(lang, 'stats.smart_all_done');
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.pieChart, color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.tr(lang, 'stats.title'),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        Text(
                          AppTranslations.tr(lang, 'stats.subtitle'),
                          style: TextStyle(fontSize: 12, color: mutedTextColor),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(LucideIcons.x, color: textColor, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Big Total Saved Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bannerBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTranslations.tr(lang, 'stats.total_saved'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatRupiah(totalSaved, vm.currency),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppTranslations.tr(lang, 'stats.of_total_target')} ${formatRupiah(totalGoal, vm.currency)} (${overallProgress.toStringAsFixed(0)}%)',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: overallProgress / 100,
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3 Grid Metric Cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: metricBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.target, color: Color(0xFF7C8BFF), size: 20),
                        const SizedBox(height: 8),
                        Text('$activeCount', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                        Text(AppTranslations.tr(lang, 'stats.active_targets'), style: TextStyle(fontSize: 11, color: mutedTextColor)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: metricBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.checkCircle2, color: Color(0xFF10B981), size: 20),
                        const SizedBox(height: 8),
                        Text('$completedCount', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                        Text(AppTranslations.tr(lang, 'stats.completed'), style: TextStyle(fontSize: 11, color: mutedTextColor)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: metricBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.sparkles, color: Color(0xFFF59E0B), size: 20),
                        const SizedBox(height: 8),
                        Text('${targets.length}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                        Text(AppTranslations.tr(lang, 'stats.total_targets'), style: TextStyle(fontSize: 11, color: mutedTextColor)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // AI Smart Insight Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF232534) : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.sparkles, color: Color(0xFFF59E0B), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.tr(lang, 'stats.smart_insight_title'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF59E0B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          getSmartInsight(),
                          style: TextStyle(fontSize: 12, height: 1.4, color: textColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
