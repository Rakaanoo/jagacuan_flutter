import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../data/models/target_item.dart';
import '../../target_list/view_models/target_list_view_model.dart';
import '../../../core/formatters.dart';
import '../../../core/i18n.dart';
import '../../../core/theme.dart';

import '../../../core/notification_permission_dialog.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../data/repositories/supabase_nabar_repository.dart';

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
  bool _isAlarmInitialized = false;
  String _pacingMode = 'daily'; // 'daily', 'weekly', 'monthly'

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
    String resolvedUrl = url.trim();
    if (!resolvedUrl.startsWith('http://') &&
        !resolvedUrl.startsWith('https://') &&
        !resolvedUrl.startsWith('/')) {
      resolvedUrl =
          'https://cddmksbflgzxmavrddrp.supabase.co/storage/v1/object/public/room-covers/$resolvedUrl';
    }

    if (resolvedUrl.startsWith('http://') ||
        resolvedUrl.startsWith('https://')) {
      return Image.network(
        resolvedUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(LucideIcons.image, size: 36, color: Colors.grey),
        ),
      );
    } else {
      final file = File(resolvedUrl);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
      return const Center(
        child: Icon(LucideIcons.image, size: 36, color: Colors.grey),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final numeric = val.replaceAll(RegExp(r'\D'), '');
    if (numeric.isEmpty) {
      _amountController.text = '';
      return;
    }
    final number = double.tryParse(numeric) ?? 0;
    final formatted = formatAmountOnly(number);
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _saveAlarmSettings(
    bool enabled,
    int hour,
    int minute,
    String dayKey,
  ) async {
    final vm = context.read<TargetListViewModel>();
    await vm.updateTargetAlarm(
      widget.targetId,
      alarmEnabled: enabled,
      alarmHour: hour,
      alarmMinute: minute,
      alarmDayKey: dayKey,
    );
  }

  Future<void> _handleAlarmToggle(bool enabled) async {
    if (enabled) {
      final isGranted = await checkAndShowNotificationPermissionDialog(context);
      if (!isGranted) {
        if (!mounted) return;
        setState(() {
          _alarmEnabled = false;
        });
        await _saveAlarmSettings(
          false,
          _selectedHour,
          _selectedMinute,
          _alarmDayKey,
        );
        return;
      }

      if (!mounted) return;
      final vm = context.read<TargetListViewModel>();
      final target = vm.targets.cast<TargetItem?>().firstWhere(
        (t) => t?.id == widget.targetId,
        orElse: () => null,
      );

      if (target != null) {
        final remaining = (target.targetAmount - target.currentAmount).clamp(
          0.0,
          double.infinity,
        );
        await NotificationService().scheduleTargetReminder(
          targetIdHash: target.id.hashCode,
          targetTitle: target.title,
          hour: _selectedHour,
          minute: _selectedMinute,
          remainingAmount: remaining,
        );
      }
    } else {
      await NotificationService().cancelReminder(widget.targetId.hashCode);
    }

    setState(() {
      _alarmEnabled = enabled;
    });
    await _saveAlarmSettings(
      enabled,
      _selectedHour,
      _selectedMinute,
      _alarmDayKey,
    );

    if (!mounted) return;
    final vm = context.read<TargetListViewModel>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? '${AppTranslations.tr(vm.language, 'alarm.enabled')}! (${AppTranslations.tr(vm.language, _alarmDayKey)}) ${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')}'
              : AppTranslations.tr(vm.language, 'alarm.disabled'),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showTransactionModal(
    BuildContext context,
    bool initialIsDeposit, {
    double? initialAmount,
  }) {
    final vm = context.read<TargetListViewModel>();
    const curSymbol = 'Rp';
    bool isDeposit = initialIsDeposit;

    if (initialAmount != null && initialAmount > 0) {
      final formatted = formatAmountOnly(
        initialAmount.ceilToDouble(),
      );
      _amountController.text = formatted;
    } else {
      _amountController.clear();
    }
    _noteController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final target = vm.targets.cast<TargetItem?>().firstWhere(
            (t) => t?.id == widget.targetId,
            orElse: () => null,
          );
          final currentAmount = target?.currentAmount ?? 0.0;

          return Padding(
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
                // Segmented Toggle Setor (+) & Tarik (-)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setModalState(() => isDeposit = true),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isDeposit
                                ? const Color(0xFF16A34A)
                                      .withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDeposit
                                  ? const Color(0xFF16A34A)
                                  : Colors.grey.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.arrowDownLeft,
                                  size: 16,
                                  color: isDeposit
                                      ? const Color(0xFF16A34A)
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  AppTranslations.tr(
                                    vm.language,
                                    'detail.save_deposit',
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDeposit
                                        ? const Color(0xFF16A34A)
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => setModalState(() => isDeposit = false),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isDeposit
                                ? const Color(0xFFDC2626)
                                      .withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !isDeposit
                                  ? const Color(0xFFDC2626)
                                  : Colors.grey.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.arrowUpRight,
                                  size: 16,
                                  color: !isDeposit
                                      ? const Color(0xFFDC2626)
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  AppTranslations.tr(
                                    vm.language,
                                    'detail.save_withdraw',
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: !isDeposit
                                        ? const Color(0xFFDC2626)
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Available Balance badge when in Withdrawal mode
                if (!isDeposit) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.wallet,
                          size: 16,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppTranslations.tr(
                              vm.language,
                              'detail.available_balance',
                            ).replaceAll(
                              '{amount}',
                              formatRupiah(currentAmount),
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  onChanged: _onAmountChanged,
                  decoration: InputDecoration(
                    labelText:
                        '${AppTranslations.tr(vm.language, 'detail.amount_nominal')} ($curSymbol)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: AppTranslations.tr(
                      vm.language,
                      'detail.note_optional',
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amtStr = _amountController.text.replaceAll(
                        RegExp(r'\D'),
                        '',
                      );
                      final amt = double.tryParse(amtStr) ?? 0;
                      if (amt <= 0) return;

                      final baseAmt = amt;

                      if (!isDeposit && baseAmt > currentAmount) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppTranslations.tr(
                                vm.language,
                                'detail.withdraw_exceeds_balance',
                              ),
                            ),
                            backgroundColor: const Color(0xFFDC2626),
                          ),
                        );
                        return;
                      }

                      await vm.addTransaction(
                        widget.targetId,
                        baseAmt,
                        isDeposit: isDeposit,
                        note: _noteController.text.trim().isNotEmpty
                            ? _noteController.text.trim()
                            : null,
                      );

                      _amountController.clear();
                      _noteController.clear();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDeposit
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      isDeposit
                          ? AppTranslations.tr(
                              vm.language,
                              'detail.save_deposit',
                            )
                          : AppTranslations.tr(
                              vm.language,
                              'detail.save_withdraw',
                            ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildCircularClockPicker(
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color subText,
    Color textCol,
    String lang,
  ) {
    final hoursList = [12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
    final minsList = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];
    final activeList = _clockMode == 'hour' ? hoursList : minsList;

    final selectedVal = _clockMode == 'hour' ? _selectedHour : _selectedMinute;
    final selectedIdx = activeList.indexOf(selectedVal);
    final rotationDeg = selectedIdx >= 0 ? selectedIdx * 30 : 0;

    final accentColor = isDark
        ? const Color(0xFF7C8BFF)
        : const Color(0xFF2C2418);

    return Column(
      children: [
        // Digital display & AM/PM
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _clockMode = 'hour'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _clockMode == 'hour'
                            ? accentColor
                            : Colors.transparent,
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
                  Text(
                    ' : ',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textCol,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _clockMode = 'minute'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _clockMode == 'minute'
                            ? accentColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _selectedMinute.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _clockMode == 'minute'
                              ? Colors.white
                              : textCol,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: !_isPm ? accentColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: _isPm ? Border.all(color: cardBorder) : null,
                    ),
                    child: Text(
                      'AM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: !_isPm ? Colors.white : subText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => setState(() => _isPm = true),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isPm ? accentColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: !_isPm ? Border.all(color: cardBorder) : null,
                    ),
                    child: Text(
                      'PM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isPm ? Colors.white : subText,
                      ),
                    ),
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
          style: TextStyle(
            fontSize: 12,
            color: subText,
            fontWeight: FontWeight.w600,
          ),
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
                  color: cardBg,
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
                      Container(width: 2, height: 72, color: accentColor),
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
                Builder(
                  builder: (context) {
                    final numVal = activeList[i];
                    final angleRad = (i * 30 - 90) * (math.pi / 180);
                    const radius = 72.0;
                    final x = radius * math.cos(angleRad);
                    final y = radius * math.sin(angleRad);
                    final isSelected = _clockMode == 'hour'
                        ? _selectedHour == numVal
                        : _selectedMinute == numVal;

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
                            color: isSelected
                                ? accentColor
                                : Colors.transparent,
                          ),
                          child: Center(
                            child: Text(
                              _clockMode == 'hour'
                                  ? '$numVal'
                                  : numVal.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: isSelected ? Colors.white : textCol,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showCelebrationDialog(BuildContext context, TargetItem target) {
    HapticFeedback.heavyImpact();
    final vm = context.read<TargetListViewModel>();
    final daysElapsed = DateTime.now().difference(target.startDate).inDays + 1;
    final totalDepositTx = target.transactions.where((t) => t.isDeposit).length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.trophy,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  LucideIcons.partyPopper,
                  color: Color(0xFFF59E0B),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  AppTranslations.tr(vm.language, 'detail.celebrate_title'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.appTextPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppTranslations.tr(vm.language, 'detail.celebrate_desc'),
              style: TextStyle(fontSize: 13, color: context.appTextMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.appBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppTranslations.tr(vm.language, 'detail.collected'),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextMuted,
                        ),
                      ),
                      Text(
                        formatRupiah(target.currentAmount),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppTranslations.tr(vm.language, 'detail.target'),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextMuted,
                        ),
                      ),
                      Text(
                        formatRupiah(target.targetAmount),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppTranslations.tr(vm.language, 'detail.total_time'),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextMuted,
                        ),
                      ),
                      Text(
                        AppTranslations.tr(vm.language, 'detail.days_count')
                            .replaceAll('{count}', daysElapsed.toString()),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppTranslations.tr(vm.language, 'detail.deposit_count'),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextMuted,
                        ),
                      ),
                      Text(
                        AppTranslations.tr(vm.language, 'detail.times_count')
                            .replaceAll('{count}', totalDepositTx.toString()),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await vm.toggleArchiveTarget(target.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          target.isArchived
                              ? AppTranslations.tr(
                                  vm.language,
                                  'detail.unarchive_btn',
                                )
                              : AppTranslations.tr(
                                  vm.language,
                                  'detail.celebrate_smashed',
                                ),
                        ),
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                    );
                  }
                },
                icon: Icon(
                  target.isArchived
                      ? LucideIcons.rotateCcw
                      : LucideIcons.hammer,
                ),
                label: Text(
                  target.isArchived
                      ? AppTranslations.tr(vm.language, 'detail.unarchive_btn')
                      : AppTranslations.tr(vm.language, 'detail.archive_btn'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartPacingCard(
    BuildContext context,
    TargetItem target,
    TargetListViewModel vm,
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color subText,
    Color textCol,
    int daysDiff,
  ) {
    final remaining = (target.targetAmount - target.currentAmount).clamp(
      0.0,
      double.infinity,
    );
    final safeDays = daysDiff > 0 ? daysDiff : 1;

    double pacingAmount;
    String periodLabel;
    String hintText;

    if (_pacingMode == 'daily') {
      pacingAmount = (remaining / safeDays).ceilToDouble();
      periodLabel = '/ ${AppTranslations.tr(vm.language, 'detail.per_day')}';
      hintText = AppTranslations.tr(vm.language, 'detail.pacing_daily_hint');
    } else if (_pacingMode == 'weekly') {
      pacingAmount = (remaining / safeDays * 7)
          .clamp(0.0, remaining)
          .ceilToDouble();
      periodLabel = '/ ${AppTranslations.tr(vm.language, 'detail.per_week')}';
      hintText = AppTranslations.tr(vm.language, 'detail.pacing_weekly_hint');
    } else {
      final paydaysLeft = (safeDays / 30).ceil().clamp(1, 120);
      pacingAmount = (remaining / paydaysLeft).ceilToDouble();
      periodLabel = '/ ${AppTranslations.tr(vm.language, 'detail.per_payday')}';
      hintText = AppTranslations.tr(
        vm.language,
        'detail.pacing_payday_hint',
      ).replaceAll('{count}', paydaysLeft.toString());
    }

    final accentColor = isDark
        ? const Color(0xFF7C8BFF)
        : const Color(0xFF2C2418);

    return Container(
      padding: const EdgeInsets.all(18),
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
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.calculator,
                      color: Color(0xFF10B981),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppTranslations.tr(vm.language, 'detail.pacing_title'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textCol,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pacing Mode Switcher Tabs
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildPacingTab(
                  'daily',
                  AppTranslations.tr(vm.language, 'detail.pacing_daily'),
                  accentColor,
                  textCol,
                ),
                _buildPacingTab(
                  'weekly',
                  AppTranslations.tr(vm.language, 'detail.pacing_weekly'),
                  accentColor,
                  textCol,
                ),
                _buildPacingTab(
                  'monthly',
                  AppTranslations.tr(vm.language, 'detail.pacing_monthly'),
                  accentColor,
                  textCol,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Pacing Amount & Hint
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatRupiah(pacingAmount),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 6),
              Text(periodLabel, style: TextStyle(fontSize: 12, color: subText)),
            ],
          ),
          const SizedBox(height: 4),
          Text(hintText, style: TextStyle(fontSize: 12, color: subText)),
          const SizedBox(height: 14),

          // Shortcut Quick Setor Pacing
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: () => _showTransactionModal(
                context,
                true,
                initialAmount: pacingAmount,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                AppTranslations.tr(
                  vm.language,
                  'detail.pacing_quick_btn',
                ).replaceAll(
                  '{amount}',
                  formatRupiah(pacingAmount),
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPacingTab(
    String mode,
    String label,
    Color accentColor,
    Color textCol,
  ) {
    final isSelected = _pacingMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _pacingMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : textCol,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TargetListViewModel>();
    final target = vm.targets.firstWhere(
      (t) => t.id == widget.targetId,
      orElse: () => TargetItem(
        id: '',
        title: 'Not Found',
        targetAmount: 0,
        startDate: DateTime.now(),
        endDate: DateTime.now(),
      ),
    );

    if (target.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppTranslations.tr(vm.language, 'detail.title')),
        ),
        body: Center(
          child: Text(AppTranslations.tr(vm.language, 'detail.not_found')),
        ),
      );
    }

    if (!_isAlarmInitialized) {
      _alarmEnabled = target.alarmEnabled;
      _selectedHour = target.alarmHour;
      _selectedMinute = target.alarmMinute;
      _alarmDayKey = target.alarmDayKey;
      _isAlarmInitialized = true;
    }

    final isDark = context.isDarkMode;
    final cardBg = context.appCard;
    final cardBorder = context.appBorder;
    final subText = context.appTextMuted;
    final textCol = context.appTextPrimary;
    final dividerBg = context.appBorder;

    final remaining = (target.targetAmount - target.currentAmount).clamp(
      0,
      double.infinity,
    );
    final progressPct = target.progressPercentage.toStringAsFixed(0);
    final daysDiff = target.remainingDays;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          target.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              target.isArchived
                  ? LucideIcons.archiveRestore
                  : LucideIcons.archive,
              size: 20,
              color: target.isArchived
                  ? const Color(0xFFF59E0B)
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            tooltip: target.isArchived ? 'Batal Arsipkan' : 'Arsipkan Target',
            onPressed: () async {
              final isArchiving = !target.isArchived;
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cardBorder),
                  ),
                  title: Row(
                    children: [
                      Icon(
                        isArchiving
                            ? LucideIcons.archive
                            : LucideIcons.archiveRestore,
                        color: const Color(0xFFF59E0B),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isArchiving ? 'Arsipkan Celengan?' : 'Batalkan Arsip?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textCol,
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    isArchiving
                        ? 'Celengan ini akan dipindahkan ke tab "Selesai" (arsip prestasi).'
                        : 'Celengan ini akan dikembalikan ke tab "Berjalan".',
                    style: TextStyle(fontSize: 13, color: subText),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        AppTranslations.tr(vm.language, 'common.cancel'),
                        style: TextStyle(color: subText),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        isArchiving ? 'Arsipkan' : 'Kembalikan',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await vm.toggleArchiveTarget(target.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isArchiving
                            ? 'Target berhasil diarsipkan ke tab Selesai.'
                            : 'Target dikembalikan ke tab Berjalan.',
                      ),
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.pencil, size: 20),
            onPressed: () {
              // Edit target modal or functionality
            },
          ),
          IconButton(
            icon: const Icon(
              LucideIcons.trash2,
              size: 20,
              color: Colors.redAccent,
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(
                    AppTranslations.tr(
                      vm.language,
                      'detail.delete_confirm_title',
                    ),
                  ),
                  content: Text(
                    AppTranslations.tr(
                      vm.language,
                      'detail.delete_confirm_desc',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        AppTranslations.tr(vm.language, 'common.cancel'),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: Text(
                        AppTranslations.tr(vm.language, 'common.delete'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                final supabaseRepo = context.read<SupabaseNabarRepository>();
                await vm.deleteTarget(target.id, supabaseRepo: supabaseRepo);
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
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 90,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Celebration Banner if Target is Completed (100%)
                if (target.isCompleted)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF382A11), const Color(0xFF231C0E)]
                            : [
                                const Color(0xFFFEF3C7),
                                const Color(0xFFFDE68A),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFF59E0B),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              LucideIcons.trophy,
                              color: Color(0xFFF59E0B),
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    target.isArchived
                                        ? LucideIcons.trophy
                                        : LucideIcons.partyPopper,
                                    size: 15,
                                    color: isDark
                                        ? const Color(0xFFFDE68A)
                                        : const Color(0xFF92400E),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      target.isArchived
                                          ? 'Celengan Dipecahkan'
                                          : AppTranslations.tr(
                                              vm.language,
                                              'detail.celebrate_title',
                                            ),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? const Color(0xFFFDE68A)
                                            : const Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                target.isArchived
                                    ? AppTranslations.tr(
                                        vm.language,
                                        'detail.celebrate_smashed',
                                      )
                                    : AppTranslations.tr(
                                        vm.language,
                                        'detail.celebrate_desc',
                                      ),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? const Color(0xFFE2D6C0)
                                      : const Color(0xFF78350F),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () =>
                              _showCelebrationDialog(context, target),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!target.isArchived) ...[
                                const Icon(
                                  LucideIcons.hammer,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                target.isArchived
                                    ? 'Detail'
                                    : AppTranslations.tr(
                                        vm.language,
                                        'detail.smash_piggy',
                                      ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

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
                              border: Border.all(
                                color: subText.withValues(alpha: 0.4),
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: subText.withValues(alpha: 0.4),
                                    width: 3,
                                  ),
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
                                formatRupiah(target.targetAmount),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: textCol,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${formatRupiah(daysDiff > 0 ? ((target.targetAmount - target.currentAmount).clamp(0.0, double.infinity) / daysDiff) : 0)} /${AppTranslations.tr(vm.language, 'detail.per_day')}',
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
                                AppTranslations.tr(
                                  vm.language,
                                  'detail.created_date',
                                ),
                                style: TextStyle(fontSize: 12, color: subText),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${target.startDate.day.toString().padLeft(2, '0')}/${target.startDate.month.toString().padLeft(2, '0')}/${target.startDate.year}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textCol,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                AppTranslations.tr(
                                  vm.language,
                                  'detail.estimate',
                                ),
                                style: TextStyle(fontSize: 12, color: subText),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    target.isCompleted
                                        ? AppTranslations.tr(
                                            vm.language,
                                            'detail.estimate_reached',
                                          )
                                        : daysDiff <= 0
                                        ? AppTranslations.tr(
                                            vm.language,
                                            'detail.estimate_due_today',
                                          )
                                        : '${target.endDate.day}/${target.endDate.month}/${target.endDate.year} (${AppTranslations.tr(vm.language, 'detail.days_left').replaceAll('{days}', daysDiff.toString())})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: target.isCompleted
                                          ? const Color(0xFF16A34A)
                                          : textCol,
                                    ),
                                  ),
                                  if (target.isCompleted) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      LucideIcons.partyPopper,
                                      size: 13,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!target.isCompleted) ...[
                  const SizedBox(height: 16),
                  _buildSmartPacingCard(
                    context,
                    target,
                    vm,
                    isDark,
                    cardBg,
                    cardBorder,
                    subText,
                    textCol,
                    daysDiff,
                  ),
                ],
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
                              onTap: () => setState(
                                () => _isEditingAlarm = !_isEditingAlarm,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: context.appSurface,
                                    ),
                                    child: Icon(
                                      LucideIcons.bell,
                                      size: 18,
                                      color: _alarmEnabled
                                          ? (isDark
                                                ? const Color(0xFF7C8BFF)
                                                : const Color(0xFF2C2418))
                                          : subText,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            Icon(
                                              LucideIcons.clock,
                                              size: 14,
                                              color: subText,
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${AppTranslations.tr(vm.language, _alarmDayKey)} • ${AppTranslations.tr(vm.language, 'detail.alarm_hint')}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: subText,
                                          ),
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
                            onChanged: (val) => _handleAlarmToggle(val),
                            activeTrackColor: const Color(0xFF7C8BFF),
                          ),
                        ],
                      ),
                      if (_isEditingAlarm) ...[
                        const SizedBox(height: 14),
                        Divider(color: dividerBg, height: 1),
                        const SizedBox(height: 16),
                        _buildCircularClockPicker(
                          isDark,
                          cardBg,
                          cardBorder,
                          subText,
                          textCol,
                          vm.language,
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppTranslations.tr(vm.language, 'alarm.header'),
                            style: TextStyle(
                              fontSize: 12,
                              color: subText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _daysKeys.map((dayKey) {
                            final isSel = _alarmDayKey == dayKey;
                            return InkWell(
                              onTap: () async {
                                setState(() => _alarmDayKey = dayKey);
                                await _saveAlarmSettings(
                                  _alarmEnabled,
                                  _selectedHour,
                                  _selectedMinute,
                                  dayKey,
                                );
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? (isDark
                                            ? const Color(0xFF7C8BFF)
                                            : const Color(0xFF2C2418))
                                      : context.appSurface,
                                  borderRadius: BorderRadius.circular(999),
                                  border: isSel
                                      ? null
                                      : Border.all(color: cardBorder),
                                ),
                                child: Text(
                                  AppTranslations.tr(vm.language, dayKey),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel
                                        ? FontWeight.bold
                                        : FontWeight.w500,
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
                            onPressed: () async {
                              if (_alarmEnabled) {
                                final isGranted =
                                    await checkAndShowNotificationPermissionDialog(
                                      context,
                                    );
                                if (!isGranted) {
                                  if (!mounted) return;
                                  setState(() {
                                    _alarmEnabled = false;
                                  });
                                  await _saveAlarmSettings(
                                    false,
                                    _selectedHour,
                                    _selectedMinute,
                                    _alarmDayKey,
                                  );
                                  return;
                                }
                              }
                              setState(() => _isEditingAlarm = false);
                              await _saveAlarmSettings(
                                _alarmEnabled,
                                _selectedHour,
                                _selectedMinute,
                                _alarmDayKey,
                              );
                              if (!mounted || !context.mounted) return;
                              final vm = context.read<TargetListViewModel>();
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
                              AppTranslations.tr(
                                vm.language,
                                'alarm.save_button',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? const Color(0xFF7C8BFF)
                                  : const Color(0xFF2C2418),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
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
                                Text(
                                  AppTranslations.tr(
                                    vm.language,
                                    'detail.collected',
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatRupiah(target.currentAmount),
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
                                Text(
                                  AppTranslations.tr(
                                    vm.language,
                                    'detail.shortage',
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatRupiah(remaining),
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
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _showTransactionModal(context, true),
                                icon: const Icon(
                                  LucideIcons.plusCircle,
                                  size: 18,
                                ),
                                label: Text(
                                  AppTranslations.tr(
                                    vm.language,
                                    'nabar.add_deposit',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _showTransactionModal(context, false),
                                icon: const Icon(
                                  LucideIcons.arrowUpRight,
                                  size: 18,
                                  color: Color(0xFFDC2626),
                                ),
                                label: Text(
                                  AppTranslations.tr(
                                    vm.language,
                                    'nabar.withdraw_btn',
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFDC2626),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (target.transactions.isEmpty)
                        Center(
                          child: Text(
                            AppTranslations.tr(
                              vm.language,
                              'detail.no_transactions',
                            ),
                            style: TextStyle(fontSize: 13, color: subText),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: target.transactions.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final tx = target.transactions[i];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.appSurface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.isDeposit
                                            ? AppTranslations.tr(
                                                vm.language,
                                                'detail.deposit_label',
                                              )
                                            : AppTranslations.tr(
                                                vm.language,
                                                'detail.withdraw_label',
                                              ),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (tx.note.isNotEmpty)
                                        Text(
                                          tx.note,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: subText,
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    '${tx.isDeposit ? '+' : '-'}${formatRupiah(tx.amount)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: tx.isDeposit
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFDC2626),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  LucideIcons.pencil,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
