import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../data/models/target_item.dart';
import '../../target_list/view_models/target_list_view_model.dart';
import '../../../core/formatters.dart';
import '../../../core/i18n.dart';

class TargetDetailView extends StatefulWidget {
  final String targetId;
  const TargetDetailView({super.key, required this.targetId});

  @override
  State<TargetDetailView> createState() => _TargetDetailViewState();
}

class _TargetDetailViewState extends State<TargetDetailView> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  bool _alarmEnabled = false;
  bool _isEditingAlarm = false;
  int _selectedHour = 12;
  int _selectedMinute = 0;
  bool _isPm = true;
  String _clockMode = 'hour'; // 'hour' or 'minute'
  String _alarmDayKey = 'alarm.day_sunday';

  final List<String> _daysKeys = [
    'alarm.day_everyday',
    'alarm.day_monday',
    'alarm.day_tuesday',
    'alarm.day_wednesday',
    'alarm.day_thursday',
    'alarm.day_friday',
    'alarm.day_saturday',
    'alarm.day_sunday',
  ];

  Widget _buildCoverImage(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(url, fit: BoxFit.cover);
    } else {
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
      return Image.network(url, fit: BoxFit.cover);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _showTransactionModal(BuildContext context, bool isDeposit) {
    final vm = context.read<TargetListViewModel>();
    final curSymbol = currencySymbolMap[vm.currency] ?? 'Rp ';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDeposit
                  ? AppTranslations.tr(vm.language, 'detail.record_deposit')
                  : AppTranslations.tr(vm.language, 'detail.record_withdraw'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '${AppTranslations.tr(vm.language, 'detail.amount_nominal')} ($curSymbol)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: AppTranslations.tr(vm.language, 'detail.note_optional'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final amtStr = _amountController.text.replaceAll(RegExp(r'\D'), '');
                  final amt = double.tryParse(amtStr) ?? 0;
                  if (amt <= 0) return;

                  final baseAmt = toBaseIDR(amt, vm.currency);

                  await vm.addQuickSetor(widget.targetId, isDeposit ? baseAmt : -baseAmt);

                  _amountController.clear();
                  _noteController.clear();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDeposit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  isDeposit
                      ? AppTranslations.tr(vm.language, 'detail.save_deposit')
                      : AppTranslations.tr(vm.language, 'detail.save_withdraw'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularClockPicker(bool isDark, Color cardBg, Color cardBorder, Color subText, Color textCol, String lang) {
    final hoursList = [12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
    final minsList = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];
    final activeList = _clockMode == 'hour' ? hoursList : minsList;

    final selectedVal = _clockMode == 'hour' ? _selectedHour : _selectedMinute;
    final selectedIdx = activeList.indexOf(selectedVal);
    final rotationDeg = selectedIdx >= 0 ? selectedIdx * 30 : 0;

    final accentColor = isDark ? const Color(0xFF7C8BFF) : const Color(0xFF2C2418);

    return Column(
      children: [
        // Digital display & AM/PM
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2028) : const Color(0xFFFAF6EF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _clockMode = 'hour'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _clockMode == 'hour' ? accentColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _selectedHour.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _clockMode == 'hour' ? Colors.white : textCol,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                  Text(' : ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textCol)),
                  GestureDetector(
                    onTap: () => setState(() => _clockMode = 'minute'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _clockMode == 'minute' ? accentColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _selectedMinute.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _clockMode == 'minute' ? Colors.white : textCol,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Column(
              children: [
                InkWell(
                  onTap: () => setState(() => _isPm = false),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: !_isPm ? accentColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: _isPm ? Border.all(color: cardBorder) : null,
                    ),
                    child: Text('AM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: !_isPm ? Colors.white : subText)),
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => setState(() => _isPm = true),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isPm ? accentColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: !_isPm ? Border.all(color: cardBorder) : null,
                    ),
                    child: Text('PM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isPm ? Colors.white : subText)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _clockMode == 'hour'
              ? AppTranslations.tr(lang, 'alarm.rotate_hint_hour')
              : AppTranslations.tr(lang, 'alarm.rotate_hint_minute'),
          style: TextStyle(fontSize: 12, color: subText, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),

        // Analog Circular Clock Face
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1E2028) : const Color(0xFFFAF6EF),
                  border: Border.all(color: cardBorder, width: 2),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                ),
              ),
              Positioned(
                top: 28,
                left: 99,
                child: Transform.rotate(
                  angle: rotationDeg * (math.pi / 180),
                  alignment: Alignment.bottomCenter,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 2,
                        height: 72,
                        color: accentColor,
                      ),
                      Positioned(
                        top: -15,
                        left: -15,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (int i = 0; i < activeList.length; i++) ...[
                Builder(builder: (context) {
                  final numVal = activeList[i];
                  final angleRad = (i * 30 - 90) * (math.pi / 180);
                  const radius = 72.0;
                  final x = radius * math.cos(angleRad);
                  final y = radius * math.sin(angleRad);
                  final isSelected = _clockMode == 'hour' ? _selectedHour == numVal : _selectedMinute == numVal;

                  return Transform.translate(
                    offset: Offset(x, y),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_clockMode == 'hour') {
                            _selectedHour = numVal;
                            _clockMode = 'minute';
                          } else {
                            _selectedMinute = numVal;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? accentColor : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(
                            _clockMode == 'hour' ? '$numVal' : numVal.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : textCol,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TargetListViewModel>();
    final target = vm.targets.firstWhere((t) => t.id == widget.targetId,
        orElse: () => TargetItem(
              id: '',
              title: 'Not Found',
              targetAmount: 0,
              startDate: DateTime.now(),
              endDate: DateTime.now(),
            ));

    if (target.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(AppTranslations.tr(vm.language, 'detail.title'))),
        body: Center(child: Text(AppTranslations.tr(vm.language, 'detail.not_found'))),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF23242A) : const Color(0xFFFAF6EF);
    final cardBorder = isDark ? const Color(0xFF333644) : const Color(0xFFE0D5C3);
    final subText = isDark ? const Color(0xFFA0A5B5) : const Color(0xFF7A6F60);
    final textCol = isDark ? Colors.white : const Color(0xFF2C2418);
    final dividerBg = isDark ? const Color(0xFF32343E) : const Color(0xFFE0D5C3);

    final remaining = (target.targetAmount - target.currentAmount).clamp(0, double.infinity);
    final progressPct = target.progressPercentage.toStringAsFixed(0);
    final daysDiff = target.remainingDays;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(target.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.pencil, size: 20),
            onPressed: () {
              // Edit target modal or functionality
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 20, color: Colors.redAccent),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(AppTranslations.tr(vm.language, 'detail.delete_confirm_title')),
                  content: Text(AppTranslations.tr(vm.language, 'detail.delete_confirm_desc')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppTranslations.tr(vm.language, 'common.cancel'))),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: Text(AppTranslations.tr(vm.language, 'common.delete'), style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await vm.deleteTarget(target.id);
                if (!context.mounted) return;
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card 1: Cover Image or Concentric Target Circle
                Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: target.coverUrl != null && target.coverUrl!.isNotEmpty
                      ? _buildCoverImage(target.coverUrl!)
                      : Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: subText.withValues(alpha: 0.4), width: 3),
                            ),
                            child: Center(
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: subText.withValues(alpha: 0.4), width: 3),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: subText.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                // Card 2: Target Amount, Rate per Day & Date Details
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatRupiah(target.targetAmount, vm.currency),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: textCol,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${formatRupiah(daysDiff > 0 ? ((target.targetAmount - target.currentAmount).clamp(0.0, double.infinity) / daysDiff) : 0, vm.currency)} /${AppTranslations.tr(vm.language, 'detail.per_day')}',
                                style: TextStyle(fontSize: 13, color: subText),
                              ),
                            ],
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: cardBorder, width: 2.5),
                            ),
                            child: Center(
                              child: Text(
                                '$progressPct%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: subText,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(color: dividerBg, height: 1),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppTranslations.tr(vm.language, 'detail.created_date'),
                                style: TextStyle(fontSize: 12, color: subText),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${target.startDate.day.toString().padLeft(2, '0')} Sep ${target.startDate.year}',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textCol),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                AppTranslations.tr(vm.language, 'detail.estimate'),
                                style: TextStyle(fontSize: 12, color: subText),
                              ),
                              const SizedBox(height: 2),
                              Text('-', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textCol)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Card 3: Reminder Notification Card (Interactive Alarm Switch & Circular Clock)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isEditingAlarm = !_isEditingAlarm),
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark ? const Color(0xFF2D2F38) : const Color(0xFFEFEADF),
                                    ),
                                    child: Icon(
                                      LucideIcons.bell,
                                      size: 18,
                                      color: _alarmEnabled ? (isDark ? const Color(0xFF7C8BFF) : const Color(0xFF2C2418)) : subText,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')}',
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                                color: textCol,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(LucideIcons.clock, size: 14, color: subText),
                                          ],
                                        ),
                                        Text(
                                          '${AppTranslations.tr(vm.language, _alarmDayKey)} • ${AppTranslations.tr(vm.language, 'detail.alarm_hint')}',
                                          style: TextStyle(fontSize: 12, color: subText),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Switch(
                            value: _alarmEnabled,
                            onChanged: (val) {
                              setState(() {
                                _alarmEnabled = val;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    val
                                        ? '${AppTranslations.tr(vm.language, 'alarm.enabled')}! (${AppTranslations.tr(vm.language, _alarmDayKey)}) ${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')}'
                                        : AppTranslations.tr(vm.language, 'alarm.disabled'),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            activeTrackColor: const Color(0xFF7C8BFF),
                          ),
                        ],
                      ),
                      if (_isEditingAlarm) ...[
                        const SizedBox(height: 14),
                        Divider(color: dividerBg, height: 1),
                        const SizedBox(height: 16),
                        _buildCircularClockPicker(isDark, cardBg, cardBorder, subText, textCol, vm.language),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppTranslations.tr(vm.language, 'alarm.header'),
                            style: TextStyle(fontSize: 12, color: subText, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _daysKeys.map((dayKey) {
                            final isSel = _alarmDayKey == dayKey;
                            return InkWell(
                              onTap: () => setState(() => _alarmDayKey = dayKey),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? (isDark ? const Color(0xFF7C8BFF) : const Color(0xFF2C2418))
                                      : (isDark ? const Color(0xFF191A23) : const Color(0xFFFAF6EF)),
                                  borderRadius: BorderRadius.circular(999),
                                  border: isSel ? null : Border.all(color: cardBorder),
                                ),
                                child: Text(
                                  AppTranslations.tr(vm.language, dayKey),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                    color: isSel ? Colors.white : subText,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() => _isEditingAlarm = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${AppTranslations.tr(vm.language, 'alarm.saved')}! ${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')} (${AppTranslations.tr(vm.language, _alarmDayKey)})',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(LucideIcons.check, size: 16),
                            label: Text(
                              AppTranslations.tr(vm.language, 'alarm.save_button'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF7C8BFF) : const Color(0xFF2C2418),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Card 4: Terkumpul, Kekurangan & History List
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(AppTranslations.tr(vm.language, 'detail.collected'), style: TextStyle(fontSize: 12, color: subText)),
                                const SizedBox(height: 4),
                                Text(
                                  formatRupiah(target.currentAmount, vm.currency),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 36, color: dividerBg),
                          Expanded(
                            child: Column(
                              children: [
                                Text(AppTranslations.tr(vm.language, 'detail.shortage'), style: TextStyle(fontSize: 12, color: subText)),
                                const SizedBox(height: 4),
                                Text(
                                  formatRupiah(remaining, vm.currency),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(color: dividerBg, height: 1),
                      const SizedBox(height: 24),
                      if (target.transactions.isEmpty)
                        Center(
                          child: Text(
                            AppTranslations.tr(vm.language, 'detail.no_transactions'),
                            style: TextStyle(fontSize: 13, color: subText),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: target.transactions.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final tx = target.transactions[i];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1F25) : const Color(0xFFEFEADF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.isDeposit
                                            ? AppTranslations.tr(vm.language, 'detail.deposit_label')
                                            : AppTranslations.tr(vm.language, 'detail.withdraw_label'),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      if (tx.note.isNotEmpty)
                                        Text(tx.note, style: TextStyle(fontSize: 11, color: subText)),
                                    ],
                                  ),
                                  Text(
                                    '${tx.isDeposit ? '+' : '-'}${formatRupiah(tx.amount, vm.currency)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: tx.isDeposit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Floating Blue Pencil Action Button
          Positioned(
            bottom: 24,
            right: 24,
            child: SizedBox(
              width: 52,
              height: 52,
              child: FloatingActionButton(
                onPressed: () => _showTransactionModal(context, true),
                backgroundColor: const Color(0xFF7C8BFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Icon(LucideIcons.pencil, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


