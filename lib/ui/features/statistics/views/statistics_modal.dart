import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../target_list/view_models/target_list_view_model.dart';
import '../../../../data/models/target_item.dart';
import '../../../../data/models/transaction_item.dart';
import '../../../core/formatters.dart';

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

    final bg = isDark ? const Color(0xFF16171B) : const Color(0xFFFAF7F2);
    final cardBg = isDark ? const Color(0xFF23242A) : const Color(0xFFFAF6EF);
    final innerSurface = isDark ? const Color(0xFF1C1D22) : const Color(0xFFEFEADF);
    final cardBorder = isDark ? const Color(0xFF333644) : const Color(0xFFE0D5C3);
    final textColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF2C2418);
    final mutedTextColor = isDark ? const Color(0xFFA0A5B5) : const Color(0xFF7A6F60);

    final targets = vm.targets;
    final allTransactions = targets.expand((t) => t.transactions).toList();

    final now = DateTime.now();

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
          '${startOfWeek.day} ${_monthName(startOfWeek.month)} - ${now.day} ${_monthName(now.month)} ${now.year}';

      barLabels = [];
      barDepositCounts = List.filled(7, 0);
      barDepositAmounts = List.filled(7, 0.0);

      for (int i = 0; i < 7; i++) {
        final d = startOfWeek.add(Duration(days: i));
        barLabels.add(_shortDayName(d.weekday));
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
      // 1 Bulan (4 Minggu)
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      periodRangeText =
          '1 ${_monthName(now.month)} - ${endOfMonth.day} ${_monthName(now.month)} ${now.year}';

      barLabels = ['M1', 'M2', 'M3', 'M4', 'M5'];
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
      periodRangeText = 'Januari - Desember ${now.year}';
      barLabels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
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

    // AI Dynamic Insights yang tersinkron dengan batang
    final aiInsights = _generateAiInsights(
      period: _selectedPeriod,
      targets: targets,
      disciplinePct: disciplinePct,
      activeSlots: activeSlots,
      totalSlots: totalSlots,
      totalDeposits: totalDeposits,
      totalWithdrawals: totalWithdrawals,
      currency: vm.currency,
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
                          'Statistik & Insight',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Ringkasan kedisiplinan & transaksi tabunganmu',
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
                    label: '1 Minggu',
                    period: StatPeriod.week,
                    active: _selectedPeriod == StatPeriod.week,
                    isDark: isDark,
                  ),
                  _buildPeriodPill(
                    label: '1 Bulan',
                    period: StatPeriod.month,
                    active: _selectedPeriod == StatPeriod.month,
                    isDark: isDark,
                  ),
                  _buildPeriodPill(
                    label: '1 Tahun',
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
                            'Kedisiplinan Menabung',
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
                              ? 'Mingguan'
                              : (_selectedPeriod == StatPeriod.month ? 'Bulanan' : 'Tahunan'),
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
                    'Total Setoran',
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
                        'kali setor',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: mutedTextColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatRupiah(totalDepositAmount, vm.currency),
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

                  // 3 Columns: Rutin, Rata-rata, Disiplin (Sesuai foto kedua)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rutin',
                              style: TextStyle(fontSize: 12, color: mutedTextColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$activeSlots/$totalSlots Hari',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'Hari aktif',
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
                              'Rata-rata',
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
                              'Per slot waktu',
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
                              'Disiplin',
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
                              'Tingkat patuh',
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
                            'Aktivitas Transaksi',
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
                                  'Total Transaksi',
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

                  // Left & Right Split: Deposit vs Tarik (Sesuai foto kedua)
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
                                'Setor (Deposit)',
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
                            '$totalDeposits kali',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          Text(
                            formatRupiah(totalDepositAmount, vm.currency),
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
                                'Tarik (Withdraw)',
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
                            '$totalWithdrawals kali',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          Text(
                            formatRupiah(totalWithdrawAmount, vm.currency),
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
                      const Text(
                        'AI Smart Financial Reminder',
                        style: TextStyle(
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
                        child: const Text(
                          'Tersinkron',
                          style: TextStyle(
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
                                        color: textColor.withValues(alpha: 0.9),
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
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
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
    final effectiveMax = max(maxVal, 3);
    final avgRatio = (avg / effectiveMax).clamp(0.0, 1.0);

    return LayoutBuilder(builder: (ctx, constraints) {
      final chartHeight = constraints.maxHeight - 24; // room for x labels

      return Stack(
        children: [
          // Average Horizontal Line
          if (avg > 0)
            Positioned(
              left: 0,
              right: 32,
              bottom: 24 + (chartHeight * avgRatio),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: const Color(0xFF7C8BFF).withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${avg.toStringAsFixed(1)} avg',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
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
    required List<String> barLabels,
    required List<int> barCounts,
  }) {
    final List<Map<String, String>> list = [];
    final periodName = period == StatPeriod.week
        ? '1 Minggu'
        : (period == StatPeriod.month ? '1 Bulan' : '1 Tahun');

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
        'title': 'Kedisiplinan Periode $periodName',
        'desc': 'Belum ada transaksi setoran yang tercatat pada periode ini. Mulai setor nominal kecil hari ini untuk membentuk grafik kedisiplinanmu!',
      });
    } else if (disciplinePct >= 70) {
      list.add({
        'icon': '🔥',
        'title': 'Konsistensi Sangat Baik',
        'desc': 'Kamu disiplin menabung di $activeSlots dari $totalSlots titik waktu ($disciplinePct%). Paling aktif pada slot "$peakSlot" dengan $maxCount setoran.',
      });
    } else {
      list.add({
        'icon': '📈',
        'title': 'Tingkatkan Frekuensi',
        'desc': 'Tercatat $activeSlots dari $totalSlots titik waktu terisi setoran ($disciplinePct%). Terdapat ${totalSlots - activeSlots} slot kosong. Cobalah aktifkan alarm pengingat harian!',
      });
    }

    // 2. Rekomendasi Target Prioritas
    if (targets.isEmpty) {
      list.add({
        'icon': '🎯',
        'title': 'Buat Target Impian',
        'desc': 'Belum ada target celengan aktif. Buat target impian pertamamu dengan menekan tombol (+) di halaman utama.',
      });
    } else {
      final activeList = targets.where((t) => !t.isCompleted).toList();
      if (activeList.isNotEmpty) {
        activeList.sort((a, b) =>
            (b.targetAmount - b.currentAmount).compareTo(a.targetAmount - a.currentAmount));
        final top = activeList.first;
        final sisa = top.targetAmount - top.currentAmount;
        final dailyPacing = (sisa / 30).ceilToDouble();

        list.add({
          'icon': '🎯',
          'title': 'Target Prioritas "${top.title}"',
          'desc': 'Sisa target ${formatRupiah(sisa, currency)}. Cukup sisihkan ${formatRupiah(dailyPacing, currency)} per hari agar target ini tercapai dalam 30 hari ke depan.',
        });
      } else {
        list.add({
          'icon': '🏆',
          'title': 'Semua Target Tercapai',
          'desc': 'Hebat! Seluruh celengan kamu sudah 100% tuntas. Kamu bisa mengarsipkan celengan ini dan membuat target baru.',
        });
      }
    }

    // 3. Evaluasi Rasio Setor vs Tarik
    if (totalWithdrawals > 0) {
      final withdrawRatio = (totalWithdrawals / (totalDeposits + totalWithdrawals) * 100).toStringAsFixed(0);
      list.add({
        'icon': '⚠️',
        'title': 'Pengendalian Penarikan',
        'desc': 'Terdapat $totalWithdrawals kali penarikan ($withdrawRatio% dari seluruh transaksi). Tahan keinginan menarik uang celengan agar targetmu tidak tertunda.',
      });
    } else if (totalDeposits > 0) {
      list.add({
        'icon': '✨',
        'title': 'Tabungan Utuh 100%',
        'desc': 'Nol penarikan tercatat di periode ini! Seluruh uang tabunganmu terkumpul aman tanpa ada kebocoran dana.',
      });
    }

    return list;
  }

  String _monthName(int month) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return m[(month - 1).clamp(0, 11)];
  }

  String _shortDayName(int weekday) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return days[(weekday - 1).clamp(0, 6)];
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
