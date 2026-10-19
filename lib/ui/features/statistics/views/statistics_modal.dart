import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../target_list/view_models/target_list_view_model.dart';
import '../../../../data/models/target_item.dart';
import '../../../../data/models/transaction_item.dart';
import '../../../core/formatters.dart';
import '../../../core/i18n.dart';

enum StatPeriod { week, month, year }

class StatisticsModal extends StatefulWidget {
  const StatisticsModal({super.key});

  @override
  State<StatisticsModal> createState() => _StatisticsModalState();
}

class _StatisticsModalState extends State<StatisticsModal> {
  StatPeriod _selectedPeriod = StatPeriod.week;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TargetListViewModel>();
    final isDark = vm.isDarkMode;
    final lang = vm.language;
    final currency = vm.currency;

    final bg = isDark ? const Color(0xFF16171B) : const Color(0xFFFAF7F2);
    final cardBg = isDark ? const Color(0xFF23242A) : const Color(0xFFFAF6EF);
    final innerSurface = isDark ? const Color(0xFF1C1D22) : const Color(0xFFEFEADF);
    final cardBorder = isDark ? const Color(0xFF333644) : const Color(0xFFE0D5C3);
    final textColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF2C2418);
    final mutedTextColor = isDark ? const Color(0xFFA0A5B5) : const Color(0xFF7A6F60);

    final targets = vm.targets;
    final allTransactions = targets.expand((t) => t.transactions).toList();

    final now = DateTime.now();
    final dayNames = AppTranslations.getDayNames(lang);
    final monthNames = AppTranslations.getMonthNames(lang);

    // 1. Filter transaksi sesuai periode yang dipilih
    List<TransactionItem> filteredTransactions;
    String periodRangeText = '';
    List<String> barLabels = [];
    List<int> barDepositCounts = [];
    List<double> barDepositAmounts = [];

    if (_selectedPeriod == StatPeriod.week) {
      // 7 Hari Terakhir
      final startOfWeek = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      periodRangeText =
          '${startOfWeek.day} ${monthNames[(startOfWeek.month - 1).clamp(0, 11)]} - ${now.day} ${monthNames[(now.month - 1).clamp(0, 11)]} ${now.year}';

      barLabels = [];
      barDepositCounts = List.filled(7, 0);
      barDepositAmounts = List.filled(7, 0.0);

      for (int i = 0; i < 7; i++) {
        final d = startOfWeek.add(Duration(days: i));
        // dayNames index: 0 is Sun, 1 is Mon, ..., 6 is Sat. d.weekday % 7 gives Sunday=0
        barLabels.add(dayNames[d.weekday % 7]);
      }

      filteredTransactions = allTransactions.where((tx) {
        return tx.timestamp.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
            tx.timestamp.isBefore(now.add(const Duration(days: 1)));
      }).toList();

      for (final tx in filteredTransactions) {
        if (tx.isDeposit) {
          final diffDays = DateTime(tx.timestamp.year, tx.timestamp.month, tx.timestamp.day)
              .difference(startOfWeek)
              .inDays;
          if (diffDays >= 0 && diffDays < 7) {
            barDepositCounts[diffDays]++;
            barDepositAmounts[diffDays] += tx.amount;
          }
        }
      }
    } else if (_selectedPeriod == StatPeriod.month) {
      // 1 Bulan (4-5 Minggu)
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      periodRangeText =
          '1 ${monthNames[(now.month - 1).clamp(0, 11)]} - ${endOfMonth.day} ${monthNames[(now.month - 1).clamp(0, 11)]} ${now.year}';

      final prefix = lang == 'id' ? 'M' : 'W';
      barLabels = ['$prefix 1', '$prefix 2', '$prefix 3', '$prefix 4', '$prefix 5'];
      barDepositCounts = List.filled(5, 0);
      barDepositAmounts = List.filled(5, 0.0);

      filteredTransactions = allTransactions.where((tx) {
        return tx.timestamp.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
            tx.timestamp.isBefore(endOfMonth.add(const Duration(days: 1)));
      }).toList();

      for (final tx in filteredTransactions) {
        if (tx.isDeposit) {
          final day = tx.timestamp.day;
          final weekIndex = ((day - 1) ~/ 7).clamp(0, 4);
          barDepositCounts[weekIndex]++;
          barDepositAmounts[weekIndex] += tx.amount;
        }
      }
    } else {
      // 1 Tahun (12 Bulan)
      periodRangeText = AppTranslations.tr(lang, 'stats.year_range').replaceAll('{year}', now.year.toString());
      barLabels = monthNames.map((m) {
        if (lang == 'ja' || lang == 'zh') {
          return m;
        }
        return m.isNotEmpty ? m.substring(0, 1) : m;
      }).toList();
      barDepositCounts = List.filled(12, 0);
      barDepositAmounts = List.filled(12, 0.0);

      filteredTransactions = allTransactions.where((tx) {
        return tx.timestamp.year == now.year;
      }).toList();

      for (final tx in filteredTransactions) {
        if (tx.isDeposit) {
          final monthIndex = (tx.timestamp.month - 1).clamp(0, 11);
          barDepositCounts[monthIndex]++;
          barDepositAmounts[monthIndex] += tx.amount;
        }
      }
    }

    // Hitung Metrik Batang Kedisiplinan
    final totalDeposits = filteredTransactions.where((t) => t.isDeposit).length;
    final totalDepositAmount = filteredTransactions
        .where((t) => t.isDeposit)
        .fold<double>(0, (sum, t) => sum + t.amount);

    final totalWithdrawals = filteredTransactions.where((t) => !t.isDeposit).length;
    final totalWithdrawAmount = filteredTransactions
        .where((t) => !t.isDeposit)
        .fold<double>(0, (sum, t) => sum + t.amount);

    final totalTx = totalDeposits + totalWithdrawals;

    // Titik aktif / hari disiplin
    final activeSlots = barDepositCounts.where((c) => c > 0).length;
    final totalSlots = barDepositCounts.length;
    final disciplinePct = totalSlots > 0 ? (activeSlots / totalSlots * 100).clamp(0.0, 100.0) : 0.0;
    final avgPerSlot = totalSlots > 0 ? totalDeposits / totalSlots : 0.0;
    final maxDepositCount = barDepositCounts.fold<int>(0, max);

    // AI Dynamic Insights yang tersinkron dengan bahasa & mata uang
    final aiInsights = _generateAiInsights(
      period: _selectedPeriod,
      targets: targets,
      disciplinePct: disciplinePct,
      activeSlots: activeSlots,
      totalSlots: totalSlots,
      totalDeposits: totalDeposits,
      totalWithdrawals: totalWithdrawals,
      currency: currency,
      lang: lang,
      barLabels: barLabels,
      barCounts: barDepositCounts,
    );

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Modal Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: mutedTextColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),

            // Top Header: Title & Close
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
                        border: Border.all(color: cardBorder),
                      ),
                      child: const Icon(
                        LucideIcons.barChart2,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.tr(lang, 'stats.title'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          AppTranslations.tr(lang, 'stats.subtitle_new'),
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
            const SizedBox(height: 18),

            // Period Selector (1 Minggu, 1 Bulan, 1 Tahun)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: innerSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  _buildPeriodPill(
                    label: AppTranslations.tr(lang, 'stats.period_1_week'),
                    period: StatPeriod.week,
                    active: _selectedPeriod == StatPeriod.week,
                    isDark: isDark,
                  ),
                  _buildPeriodPill(
                    label: AppTranslations.tr(lang, 'stats.period_1_month'),
                    period: StatPeriod.month,
                    active: _selectedPeriod == StatPeriod.month,
                    isDark: isDark,
                  ),
                  _buildPeriodPill(
                    label: AppTranslations.tr(lang, 'stats.period_1_year'),
                    period: StatPeriod.year,
                    active: _selectedPeriod == StatPeriod.year,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ========================================================
            // CARD 1: KEDISIPLINAN MENABUNG (BAR CHART CARD)
            // ========================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.clock,
                            color: Color(0xFF7C8BFF),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppTranslations.tr(lang, 'stats.discipline_title'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: innerSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Text(
                          _selectedPeriod == StatPeriod.week
                              ? AppTranslations.tr(lang, 'stats.badge_weekly')
                              : (_selectedPeriod == StatPeriod.month
                                  ? AppTranslations.tr(lang, 'stats.badge_monthly')
                                  : AppTranslations.tr(lang, 'stats.badge_yearly')),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: mutedTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Big Value
                  Text(
                    AppTranslations.tr(lang, 'stats.total_deposit_label'),
                    style: TextStyle(fontSize: 12, color: mutedTextColor),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$totalDeposits',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppTranslations.tr(lang, 'stats.times_deposit'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: mutedTextColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatRupiah(totalDepositAmount, currency),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    periodRangeText,
                    style: TextStyle(fontSize: 11, color: mutedTextColor.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 22),

                  // Vertical Bar Chart
                  SizedBox(
                    height: 160,
                    child: _buildBarChart(
                      labels: barLabels,
                      counts: barDepositCounts,
                      maxVal: maxDepositCount,
                      avg: avgPerSlot,
                      isDark: isDark,
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Divider
                  Divider(color: cardBorder, height: 1),
                  const SizedBox(height: 16),

                  // 3 Columns: Rutin, Rata-rata, Disiplin
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppTranslations.tr(lang, 'stats.metric_routine'),
                              style: TextStyle(fontSize: 12, color: mutedTextColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppTranslations.tr(lang, 'stats.metric_days')
                                  .replaceAll('{active}', activeSlots.toString())
                                  .replaceAll('{total}', totalSlots.toString()),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              AppTranslations.tr(lang, 'stats.metric_active_days'),
                              style: TextStyle(fontSize: 10, color: mutedTextColor),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppTranslations.tr(lang, 'stats.metric_average'),
                              style: TextStyle(fontSize: 12, color: mutedTextColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${avgPerSlot.toStringAsFixed(1)}x',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              AppTranslations.tr(lang, 'stats.metric_per_slot'),
                              style: TextStyle(fontSize: 10, color: mutedTextColor),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppTranslations.tr(lang, 'stats.metric_discipline'),
                              style: TextStyle(fontSize: 12, color: mutedTextColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${disciplinePct.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            Text(
                              AppTranslations.tr(lang, 'stats.metric_compliance'),
                              style: TextStyle(fontSize: 10, color: mutedTextColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ========================================================
            // CARD 2: AKTIVITAS TRANSAKSI (SETENGAH BOLA / GAUGE)
            // ========================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.arrowUpDown,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppTranslations.tr(lang, 'stats.activity_title'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        periodRangeText,
                        style: TextStyle(fontSize: 11, color: mutedTextColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Setengah Bola Gauge & Stats
                  Center(
                    child: SizedBox(
                      width: 220,
                      height: 125,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          CustomPaint(
                            size: const Size(220, 110),
                            painter: HalfCircleGaugePainter(
                              depositRatio: totalTx > 0 ? (totalDeposits / totalTx) : 1.0,
                              depositColor: const Color(0xFF10B981),
                              withdrawColor: const Color(0xFFEF4444),
                              trackColor: isDark
                                  ? const Color(0xFF333644)
                                  : const Color(0xFFE0D5C3),
                              strokeWidth: 20,
                            ),
                          ),
                          Positioned(
                            bottom: 6,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppTranslations.tr(lang, 'stats.total_transactions_center'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: mutedTextColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$totalTx',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Left & Right Split: Deposit vs Tarik
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Kolom Kiri: Setor (Deposit)
                      Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppTranslations.tr(lang, 'stats.deposit_legend'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: mutedTextColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppTranslations.tr(lang, 'stats.times_count')
                                .replaceAll('{count}', totalDeposits.toString()),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          Text(
                            formatRupiah(totalDepositAmount, currency),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),

                      // Divider Vertical
                      Container(
                        width: 1,
                        height: 40,
                        color: cardBorder,
                      ),

                      // Kolom Kanan: Tarik (Withdraw)
                      Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppTranslations.tr(lang, 'stats.withdraw_legend'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: mutedTextColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppTranslations.tr(lang, 'stats.times_count')
                                .replaceAll('{count}', totalWithdrawals.toString()),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          Text(
                            formatRupiah(totalWithdrawAmount, currency),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ========================================================
            // CARD 3: AI SMART FINANCIAL INSIGHTS & REMINDER
            // ========================================================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1914) : const Color(0xFFFEF7E0),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.sparkles,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppTranslations.tr(lang, 'stats.ai_title'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          AppTranslations.tr(lang, 'stats.ai_synced'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Bullet Points AI Insight
                  ...aiInsights.map((insight) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight['icon'] ?? '•',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.45,
                                    color: textColor,
                                    fontFamily: 'sans-serif',
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '${insight['title']}: ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFF59E0B),
                                      ),
                                    ),
                                    TextSpan(
                                      text: insight['desc'],
                                      style: TextStyle(
                                        color: textColor.withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodPill({
    required String label,
    required StatPeriod period,
    required bool active,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = period;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF10B981)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: active
                  ? Colors.white
                  : (isDark ? const Color(0xFFA0A5B5) : const Color(0xFF7A6F60)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart({
    required List<String> labels,
    required List<int> counts,
    required int maxVal,
    required double avg,
    required bool isDark,
    required Color textColor,
    required Color mutedTextColor,
  }) {
    final effectiveMax = max(3, maxVal);

    return LayoutBuilder(builder: (context, constraints) {
      final chartHeight = constraints.maxHeight - 24; // space for bottom labels

      return Stack(
        clipBehavior: Clip.none,
        children: [
          // Horizontal Average Line
          if (avg > 0)
            Positioned(
              left: 0,
              right: 36,
              bottom: 24 + (chartHeight * (avg / effectiveMax)).clamp(0.0, chartHeight),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: const Color(0xFF7C8BFF).withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${avg.toStringAsFixed(1)} avg',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7C8BFF),
                    ),
                  ),
                ],
              ),
            ),

          // Y Axis Ticks on the Right
          Positioned(
            right: 0,
            top: 0,
            bottom: 24,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$effectiveMax', style: TextStyle(fontSize: 10, color: mutedTextColor)),
                Text('${(effectiveMax / 2).round()}', style: TextStyle(fontSize: 10, color: mutedTextColor)),
                Text('0', style: TextStyle(fontSize: 10, color: mutedTextColor)),
              ],
            ),
          ),

          // Bars Row
          Positioned(
            left: 0,
            right: 36,
            top: 0,
            bottom: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(labels.length, (idx) {
                final count = counts[idx];
                final ratio = (count / effectiveMax).clamp(0.0, 1.0);
                final isPeak = count > 0 && count == maxVal;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // The Bar
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              width: double.infinity,
                              height: max(6.0, chartHeight * ratio),
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                gradient: isPeak
                                    ? const LinearGradient(
                                        colors: [Color(0xFF10B981), Color(0xFF7C8BFF)],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      )
                                    : count > 0
                                        ? LinearGradient(
                                            colors: [
                                              const Color(0xFF10B981).withValues(alpha: 0.5),
                                              const Color(0xFF7C8BFF).withValues(alpha: 0.6),
                                            ],
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                          )
                                        : null,
                                color: count == 0
                                    ? (isDark
                                        ? const Color(0xFF2E313D)
                                        : const Color(0xFFE2DACC))
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // X-axis label
                        Text(
                          labels[idx],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isPeak ? FontWeight.bold : FontWeight.w500,
                            color: isPeak ? const Color(0xFF10B981) : mutedTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      );
    });
  }

  List<Map<String, String>> _generateAiInsights({
    required StatPeriod period,
    required List<TargetItem> targets,
    required double disciplinePct,
    required int activeSlots,
    required int totalSlots,
    required int totalDeposits,
    required int totalWithdrawals,
    required String currency,
    required String lang,
    required List<String> barLabels,
    required List<int> barCounts,
  }) {
    final List<Map<String, String>> list = [];
    final periodName = period == StatPeriod.week
        ? AppTranslations.tr(lang, 'stats.period_1_week')
        : (period == StatPeriod.month
            ? AppTranslations.tr(lang, 'stats.period_1_month')
            : AppTranslations.tr(lang, 'stats.period_1_year'));

    // 1. Evaluasi Kedisiplinan Terhubung dengan Batang
    String peakSlot = '';
    int maxCount = 0;
    for (int i = 0; i < barCounts.length; i++) {
      if (barCounts[i] > maxCount) {
        maxCount = barCounts[i];
        peakSlot = barLabels[i];
      }
    }

    if (totalDeposits == 0) {
      list.add({
        'icon': '📊',
        'title': AppTranslations.tr(lang, 'stats.ai_discipline_title').replaceAll('{period}', periodName),
        'desc': AppTranslations.tr(lang, 'stats.ai_no_deposits'),
      });
    } else if (disciplinePct >= 70) {
      list.add({
        'icon': '🔥',
        'title': AppTranslations.tr(lang, 'stats.ai_high_discipline_title'),
        'desc': AppTranslations.tr(lang, 'stats.ai_high_discipline_desc')
            .replaceAll('{active}', activeSlots.toString())
            .replaceAll('{total}', totalSlots.toString())
            .replaceAll('{percent}', disciplinePct.toStringAsFixed(0))
            .replaceAll('{peak}', peakSlot)
            .replaceAll('{count}', maxCount.toString()),
      });
    } else {
      list.add({
        'icon': '📈',
        'title': AppTranslations.tr(lang, 'stats.ai_improve_title'),
        'desc': AppTranslations.tr(lang, 'stats.ai_improve_desc')
            .replaceAll('{active}', activeSlots.toString())
            .replaceAll('{total}', totalSlots.toString())
            .replaceAll('{percent}', disciplinePct.toStringAsFixed(0))
            .replaceAll('{empty}', (totalSlots - activeSlots).toString()),
      });
    }

    // 2. Rekomendasi Target Prioritas
    if (targets.isEmpty) {
      list.add({
        'icon': '🎯',
        'title': AppTranslations.tr(lang, 'stats.ai_empty_title'),
        'desc': AppTranslations.tr(lang, 'stats.ai_empty_desc'),
      });
    } else {
      final activeList = targets.where((t) => !t.isCompleted).toList();
      if (activeList.isNotEmpty) {
        activeList.sort((a, b) =>
            (b.targetAmount - b.currentAmount).compareTo(a.targetAmount - a.currentAmount));
        final top = activeList.first;
        final sisa = max(0.0, top.targetAmount - top.currentAmount);
        final dailyPacing = (sisa / 30).ceilToDouble();

        list.add({
          'icon': '🎯',
          'title': AppTranslations.tr(lang, 'stats.ai_priority_title').replaceAll('{title}', top.title),
          'desc': AppTranslations.tr(lang, 'stats.ai_priority_desc')
              .replaceAll('{remaining}', formatRupiah(sisa, currency))
              .replaceAll('{daily}', formatRupiah(dailyPacing, currency)),
        });
      } else {
        list.add({
          'icon': '🏆',
          'title': AppTranslations.tr(lang, 'stats.ai_all_done_title'),
          'desc': AppTranslations.tr(lang, 'stats.ai_all_done_desc'),
        });
      }
    }

    // 3. Evaluasi Rasio Setor vs Tarik
    if (totalWithdrawals > 0) {
      final withdrawRatio = (totalWithdrawals / (totalDeposits + totalWithdrawals) * 100).toStringAsFixed(0);
      list.add({
        'icon': '⚠️',
        'title': AppTranslations.tr(lang, 'stats.ai_withdraw_title'),
        'desc': AppTranslations.tr(lang, 'stats.ai_withdraw_desc')
            .replaceAll('{count}', totalWithdrawals.toString())
            .replaceAll('{percent}', withdrawRatio),
      });
    } else if (totalDeposits > 0) {
      list.add({
        'icon': '✨',
        'title': AppTranslations.tr(lang, 'stats.ai_intact_title'),
        'desc': AppTranslations.tr(lang, 'stats.ai_intact_desc'),
      });
    }

    return list;
  }
}

class HalfCircleGaugePainter extends CustomPainter {
  final double depositRatio; // 0.0 to 1.0
  final Color depositColor;
  final Color withdrawColor;
  final Color trackColor;
  final double strokeWidth;

  HalfCircleGaugePainter({
    required this.depositRatio,
    required this.depositColor,
    required this.withdrawColor,
    required this.trackColor,
    this.strokeWidth = 20.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - strokeWidth / 2;

    // Background track arc (180° to 360°)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      trackPaint,
    );

    if (depositRatio > 0) {
      final depositPaint = Paint()
        ..color = depositColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweep = pi * depositRatio.clamp(0.02, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        pi,
        sweep,
        false,
        depositPaint,
      );
    }

    if (depositRatio < 1.0 && depositRatio >= 0) {
      final withdrawPaint = Paint()
        ..color = withdrawColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final start = pi + (pi * depositRatio);
      final sweep = pi * (1.0 - depositRatio).clamp(0.02, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        withdrawPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HalfCircleGaugePainter oldDelegate) {
    return oldDelegate.depositRatio != depositRatio ||
        oldDelegate.depositColor != depositColor ||
        oldDelegate.withdrawColor != withdrawColor ||
        oldDelegate.trackColor != trackColor;
  }
}
