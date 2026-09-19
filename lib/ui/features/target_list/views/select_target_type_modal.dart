import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../data/models/target_item.dart';
import '../../../../data/repositories/supabase_nabar_repository.dart';
import '../../nabar_room/views/connect_google_modal.dart';
import '../../nabar_room/views/nabar_room_view.dart';
import '../../target_list/view_models/target_list_view_model.dart';
import '../../../core/i18n.dart';

class SelectTargetTypeModal extends StatelessWidget {
  final Function(TargetType) onSelectType;

  const SelectTargetTypeModal({super.key, required this.onSelectType});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TargetListViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF1B1C23) : const Color(0xFFFAF6EF);
    final cardBg = isDark ? const Color(0xFF22242F) : const Color(0xFFEFEADF);
    final cardBorder = isDark ? const Color(0xFF333746) : const Color(0xFFDDD5C7);
    final iconBg = isDark ? const Color(0xFF2D303D) : const Color(0xFFEAE1D1);
    final titleColor = isDark ? Colors.white : const Color(0xFF2C2418);
    final subColor = isDark ? const Color(0xFF9DA2B3) : const Color(0xFF7A6F60);
    final iconColor = isDark ? const Color(0xFF8B9BFF) : const Color(0xFF2C2418);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Title
          Text(
            AppTranslations.tr(vm.language, 'select_type.title'),
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 18),

          // Option 1: Tabungan Target
          _buildOptionCard(
            context,
            icon: LucideIcons.flag,
            title: AppTranslations.tr(vm.language, 'select_type.nabung'),
            subtitle: AppTranslations.tr(vm.language, 'select_type.nabung_desc'),
            cardBg: cardBg,
            cardBorder: cardBorder,
            iconBg: iconBg,
            iconColor: iconColor,
            titleColor: titleColor,
            subColor: subColor,
            onTap: () => onSelectType(TargetType.target),
          ),
          const SizedBox(height: 12),

          // Option 2: Tabungan Berkala
          _buildOptionCard(
            context,
            icon: LucideIcons.trophy,
            title: AppTranslations.tr(vm.language, 'select_type.berkala'),
            subtitle: AppTranslations.tr(vm.language, 'select_type.berkala_desc'),
            cardBg: cardBg,
            cardBorder: cardBorder,
            iconBg: iconBg,
            iconColor: iconColor,
            titleColor: titleColor,
            subColor: subColor,
            onTap: () => onSelectType(TargetType.berkala),
          ),
          const SizedBox(height: 12),

          // Option 3: Nabung Bareng (Buat Room Baru)
          _buildOptionCard(
            context,
            icon: LucideIcons.users,
            title: AppTranslations.tr(vm.language, 'select_type.nabar'),
            subtitle: AppTranslations.tr(vm.language, 'select_type.nabar_desc'),
            cardBg: cardBg,
            cardBorder: cardBorder,
            iconBg: iconBg,
            iconColor: iconColor,
            titleColor: titleColor,
            subColor: subColor,
            onTap: () {
              final supabaseRepo = context.read<SupabaseNabarRepository>();
              if (supabaseRepo.currentUser == null) {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => const ConnectGoogleModal(),
                );
              } else {
                onSelectType(TargetType.nabar);
              }
            },
          ),
          const SizedBox(height: 12),

          // Option 4: Gabung Room Nabar (Kode 6 Digit)
          _buildOptionCard(
            context,
            icon: LucideIcons.keyRound,
            title: 'Gabung Room Nabar',
            subtitle: 'Masukkan 6 digit kode room dari teman untuk bergabung',
            cardBg: cardBg,
            cardBorder: cardBorder,
            iconBg: iconBg,
            iconColor: const Color(0xFF10B981),
            titleColor: titleColor,
            subColor: subColor,
            onTap: () {
              final supabaseRepo = context.read<SupabaseNabarRepository>();
              if (supabaseRepo.currentUser == null) {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => const ConnectGoogleModal(),
                );
              } else {
                Navigator.pop(context);
                _showJoinRoomDialog(context);
              }
            },
          ),
          const SizedBox(height: 20),

          // Right-aligned Cancel Button (Batal)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E202A) : cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF353949) : cardBorder, width: 1.2),
                  ),
                  child: Text(
                    AppTranslations.tr(vm.language, 'common.cancel'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color cardBg,
    required Color cardBorder,
    required Color iconBg,
    required Color iconColor,
    required Color titleColor,
    required Color subColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorder, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: subColor,
                      height: 1.3,
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

  void _showJoinRoomDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gabung Room Nabar', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Masukkan 6 digit angka kode room:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 3.0),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '123456',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final codeInput = controller.text.trim();
              if (codeInput.isEmpty) return;

              Navigator.pop(ctx);
              try {
                final repo = context.read<SupabaseNabarRepository>();
                final room = await repo.joinRoomByInviteCode(codeInput);
                if (room != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Permintaan bergabung ke "${room.name}" telah dikirim! Menunggu verifikasi Host.'),
                    ),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NabarRoomView(roomId: room.id)),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal bergabung: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Minta Bergabung'),
          ),
        ],
      ),
    );
  }
}
