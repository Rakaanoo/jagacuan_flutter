import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../data/repositories/supabase_nabar_repository.dart';
import '../../../../data/models/nabar_room.dart';
import '../../target_list/view_models/target_list_view_model.dart';
import '../../../core/formatters.dart';
import '../../../core/i18n.dart';

class NabarRoomView extends StatefulWidget {
  final String roomId;
  const NabarRoomView({super.key, required this.roomId});

  @override
  State<NabarRoomView> createState() => _NabarRoomViewState();
}

class _NabarRoomViewState extends State<NabarRoomView> {
  NabarRoom? _room;
  bool _isLoading = true;
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRoom();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchRoom() async {
    final repo = context.read<SupabaseNabarRepository>();
    final room = await repo.getRoomById(widget.roomId);
    if (mounted) {
      setState(() {
        _room = room;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleQuickSetor() async {
    final amountStr = _amountController.text.replaceAll(RegExp(r'\D'), '');
    final amount = double.tryParse(amountStr) ?? 0;
    if (amount <= 0 || _room == null) return;

    final lang = context.read<TargetListViewModel>().language;

    try {
      final repo = context.read<SupabaseNabarRepository>();
      final status = await repo.addRoomTransaction(
        roomId: _room!.id,
        amount: amount,
        isDeposit: true,
        note: AppTranslations.tr(lang, 'nabar.note_deposit'),
      );

      _amountController.clear();
      if (mounted) Navigator.pop(context);

      final msg = status == 'approved'
          ? AppTranslations.tr(lang, 'nabar.deposit_success')
          : AppTranslations.tr(lang, 'nabar.deposit_pending_msg');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      await _fetchRoom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _approveTx(String txId) async {
    final repo = context.read<SupabaseNabarRepository>();
    final lang = context.read<TargetListViewModel>().language;
    await repo.approveRoomTransaction(txId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.tr(lang, 'nabar.approved_msg'))),
      );
    }
    await _fetchRoom();
  }

  Future<void> _rejectTx(String txId) async {
    final repo = context.read<SupabaseNabarRepository>();
    final lang = context.read<TargetListViewModel>().language;
    await repo.rejectRoomTransaction(txId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.tr(lang, 'nabar.rejected_msg'))),
      );
    }
    await _fetchRoom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final vm = context.watch<TargetListViewModel>();
    final lang = vm.language;
    final currency = vm.currency;
    final repo = context.watch<SupabaseNabarRepository>();
    final currentUser = repo.currentUser;

    if (currentUser == null) {
      final bg = isDark ? const Color(0xFF131418) : const Color(0xFFFAF6EF);
      final cardBg = isDark ? const Color(0xFF222432) : const Color(0xFFEFEADF);
      final cardBorder = isDark ? const Color(0xFF333748) : const Color(0xFFDDD5C7);
      final textColor = isDark ? Colors.white : const Color(0xFF2C2418);
      final mutedTextColor = isDark ? const Color(0xFFA0A5B5) : const Color(0xFF7A6F60);

      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: Text(AppTranslations.tr(lang, 'nabar.room_title'), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder, width: 1.2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2F40) : const Color(0xFFE5DDD0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.user,
                      size: 24,
                      color: isDark ? const Color(0xFFA0A5B5) : const Color(0xFF7A6F60),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppTranslations.tr(lang, 'sidebar.google_not_connected'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppTranslations.tr(lang, 'sidebar.google_not_connected_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: mutedTextColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await repo.signInWithGoogle();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Google Sign-In: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(LucideIcons.logIn, size: 18),
                      label: Text(AppTranslations.tr(lang, 'connect_google.button')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF808CFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_room == null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppTranslations.tr(lang, 'nabar.room_title'))),
        body: Center(child: Text(AppTranslations.tr(lang, 'nabar.room_not_found'))),
      );
    }

    final room = _room!;
    final isOwner = room.userStatus == 'owner';

    return Scaffold(
      appBar: AppBar(
        title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.share2),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${AppTranslations.tr(lang, 'nabar.share_link')}: https://jagacuan-app.vercel.app/room/${room.id}')),
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${AppTranslations.tr(lang, 'detail.collected')}:', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                        Text('${room.progressPercentage.toStringAsFixed(0)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatRupiah(room.currentAmount, currency),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                    ),
                    Text('${AppTranslations.tr(lang, 'detail.target')}: ${formatRupiah(room.targetAmount, currency)}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: room.progressPercentage / 100,
                        minHeight: 10,
                        backgroundColor: isDark ? Colors.white12 : const Color(0xFFEFEADF),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF7C8BFF)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Setor Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _showQuickSetorModal(context, lang, currency),
                icon: const Icon(LucideIcons.plusCircle),
                label: Text(AppTranslations.tr(lang, 'nabar.record_deposit'), style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Pending Host Verification Section (HOST ONLY)
            if (isOwner && room.pendingActivities.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF23242A) : const Color(0xFFFAF6EF),
                  border: Border.all(color: const Color(0xFFD97706)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.clock, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${AppTranslations.tr(lang, 'nabar.pending_host')} (${room.pendingActivities.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...room.pendingActivities.map((act) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1C1D22) : const Color(0xFFEFEADF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: act.avatarUrl != null ? NetworkImage(act.avatarUrl!) : null,
                                child: act.avatarUrl == null ? Text(act.name[0]) : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${act.name} - +${formatRupiah(act.amount, currency)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('${formatTimeAgo(act.timestamp)} • ${AppTranslations.tr(lang, 'nabar.pending_host_badge')}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(LucideIcons.check, color: Color(0xFF16A34A)),
                                    onPressed: () => _approveTx(act.id),
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.x, color: Color(0xFFDC2626)),
                                    onPressed: () => _rejectTx(act.id),
                                  ),
                                ],
                              )
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Recent Activities
            Text(AppTranslations.tr(lang, 'nabar.recent_activities'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            if (room.activities.isEmpty)
              Text(AppTranslations.tr(lang, 'nabar.no_activities'))
            else
              ...room.activities.map((act) => ListTile(
                    leading: CircleAvatar(
                      backgroundImage: act.avatarUrl != null ? NetworkImage(act.avatarUrl!) : null,
                      child: act.avatarUrl == null ? Text(act.name[0]) : null,
                    ),
                    title: Text(act.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(formatTimeAgo(act.timestamp)),
                    trailing: Text('+${formatRupiah(act.amount, currency)}',
                        style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                  )),
          ],
        ),
      ),
    );
  }

  void _showQuickSetorModal(BuildContext context, String lang, String currency) {
    final symbol = currencySymbolMap[currency] ?? 'Rp';
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
            Text(AppTranslations.tr(lang, 'nabar.setor_to_room'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '${AppTranslations.tr(lang, 'detail.amount_nominal')} ($symbol)',
                hintText: '50.000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _handleQuickSetor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(AppTranslations.tr(lang, 'nabar.send_deposit'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

