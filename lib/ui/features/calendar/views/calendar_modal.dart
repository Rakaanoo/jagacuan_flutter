import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../target_list/view_models/target_list_view_model.dart';
import '../../../core/formatters.dart';
import '../../../core/i18n.dart';
import '../../target_list/views/create_target_modal.dart';

class CalendarModal extends StatefulWidget {
  const CalendarModal({super.key});

  @override
  State<CalendarModal> createState() => _CalendarModalState();
}

class _CalendarModalState extends State<CalendarModal> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  String _formatMonth(DateTime date, String lang) {
    try {
      return DateFormat('MMMM yyyy', lang).format(date);
    } catch (_) {
      return DateFormat('MMMM yyyy').format(date);
    }
  }

  String _formatDateStr(DateTime date, String lang) {
    try {
      return DateFormat('d MMMM yyyy', lang).format(date);
    } catch (_) {
      return DateFormat('d MMMM yyyy').format(date);
    }
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _selectedDate = now;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TargetListViewModel>();
    final isDark = vm.isDarkMode;
    final lang = vm.language;

    final bg = isDark ? const Color(0xFF181920) : const Color(0xFFFAF6EF);
    final cardBg = isDark ? const Color(0xFF232532) : const Color(0xFFEFEADF);
    final monthPillBg = isDark ? const Color(0xFF252735) : const Color(0xFFE8E2D5);
    final selectedDayBg = const Color(0xFF7284FF);
    final cardBorder = isDark ? const Color(0xFF2E3142) : const Color(0xFFE0D5C3);
    final textColor = isDark ? Colors.white : const Color(0xFF2C2418);
    final mutedTextColor = isDark ? const Color(0xFF9A9FAE) : const Color(0xFF7A6F60);

    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7; // 0 = Sunday

    final dayTargets = vm.targets.where((t) {
      return t.endDate.year == _selectedDate.year &&
          t.endDate.month == _selectedDate.month &&
          t.endDate.day == _selectedDate.day;
    }).toList();

    final selectedDateStr = _formatDateStr(_selectedDate, lang);
    final dayNames = AppTranslations.getDayNames(lang);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cardBorder, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 30,
                offset: Offset(0, 10),
              )
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(LucideIcons.calendar, color: textColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppTranslations.tr(lang, 'calendar.title'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppTranslations.tr(lang, 'calendar.subtitle'),
                            style: TextStyle(
                              fontSize: 12,
                              color: mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(LucideIcons.x, color: mutedTextColor, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Month Selector Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: monthPillBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(LucideIcons.chevronLeft, color: textColor, size: 20),
                        onPressed: () {
                          setState(() {
                            _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                          });
                        },
                      ),
                      Text(
                        _formatMonth(_currentMonth, lang),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(LucideIcons.chevronRight, color: textColor, size: 20),
                        onPressed: () {
                          setState(() {
                            _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Days Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: dayNames
                      .map((day) => Expanded(
                            child: Text(
                              day,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: mutedTextColor,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),

                // Date Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: daysInMonth + firstWeekday,
                  itemBuilder: (context, index) {
                    if (index < firstWeekday) return const SizedBox.shrink();

                    final dayNum = index - firstWeekday + 1;
                    final date = DateTime(_currentMonth.year, _currentMonth.month, dayNum);
                    final isSelected = date.year == _selectedDate.year &&
                        date.month == _selectedDate.month &&
                        date.day == _selectedDate.day;

                    final hasDeadline = vm.targets.any((t) {
                      return t.endDate.year == date.year &&
                          t.endDate.month == date.month &&
                          t.endDate.day == date.day;
                    });

                    return InkWell(
                      onTap: () => setState(() => _selectedDate = date),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected ? selectedDayBg : cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: hasDeadline && !isSelected
                              ? Border.all(color: const Color(0xFFF59E0B), width: 1.5)
                              : null,
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.white : textColor,
                                ),
                              ),
                            ),
                            if (hasDeadline && !isSelected)
                              Positioned(
                                bottom: 4,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF59E0B),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                Divider(color: cardBorder, height: 1),
                const SizedBox(height: 16),

                // Selected Target List Header & + Tambah Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${AppTranslations.tr(lang, 'calendar.target_on')} $selectedDateStr',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => CreateTargetModal(
                            initialDeadlineDate: _selectedDate,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: cardBorder, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.plus, size: 14, color: textColor),
                            const SizedBox(width: 4),
                            Text(
                              AppTranslations.tr(lang, 'calendar.add'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Content Container / Target List or Empty State
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: dayTargets.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              AppTranslations.tr(lang, 'calendar.empty'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: mutedTextColor,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: dayTargets
                              .map((t) => Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1B1C26) : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(LucideIcons.target, color: Color(0xFFF59E0B), size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                t.title,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: textColor,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${formatRupiah(t.currentAmount, vm.currency)} / ${formatRupiah(t.targetAmount, vm.currency)}',
                                                style: TextStyle(fontSize: 12, color: mutedTextColor),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${t.progressPercentage.toStringAsFixed(0)}%',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
