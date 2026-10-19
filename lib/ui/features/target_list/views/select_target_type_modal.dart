import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../data/models/target_item.dart';
import '../../../../data/repositories/supabase_nabar_repository.dart';
import '../../nabar_room/views/connect_google_modal.dart';
import '../../nabar_room/views/nabar_room_view.dart';
import '../../nabar_room/views/room_preview_modal.dart';
import '../../target_list/view_models/target_list_view_model.dart';
import '../../../core/i18n.dart';
import '../../../core/theme.dart';

class SelectTargetTypeModal extends StatelessWidget {
  final Function(TargetType) onSelectType;

  const SelectTargetTypeModal({super.key, required this.onSelectType});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TargetListViewModel>();
    final isDark = context.isDarkMode;

    final bg = context.appCard;
    final cardBg = context.appSurface;
    final cardBorder = context.appBorder;
    final iconBg = isDark ? context.appBg : const Color(0xFFEAE1D1);
    final titleColor = context.appTextPrimary;
    final subColor = context.appTextMuted;
    final iconColor = isDark ? context.appAccent : context.appTextPrimary;

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
          const SizedBox(height: 4),
          Text(
            AppTranslations.tr(vm.language, 'select_type.subtitle'),
            style: TextStyle(fontSize: 13, color: subColor),
          ),
          const SizedBox(height: 18),

          // Option 1: Tabungan Pribadi (Target Impian)
          _buildOptionCard(
            context,
            icon: LucideIcons.flag,
            title: AppTranslations.tr(vm.language, 'select_type.nabung'),
            subtitle: AppTranslations.tr(
              vm.language,
              'select_type.nabung_desc',
            ),
            cardBg: cardBg,
            cardBorder: cardBorder,
            iconBg: iconBg,
            iconColor: iconColor,
            titleColor: titleColor,
            subColor: subColor,
            onTap: () => onSelectType(TargetType.target),
          ),
          const SizedBox(height: 14),

          // Option 2: Nabung Bareng (Nabar)
          _buildOptionCard(
            context,
            icon: LucideIcons.users,
            title: AppTranslations.tr(vm.language, 'select_type.nabar'),
            subtitle: AppTranslations.tr(vm.language, 'select_type.nabar_desc'),
            cardBg: cardBg,
            cardBorder: cardBorder,
            iconBg: iconBg,
            iconColor: context.appAccent,
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
                _showNabarActionSheet(context, vm.language);
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder, width: 1.2),
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

  static Widget _buildOptionCard(
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

  void _showNabarActionSheet(BuildContext context, String lang) {
    final bg = context.appCard;
    final cardBg = context.appSurface;
    final cardBorder = context.appBorder;
    final titleColor = context.appTextPrimary;
    final subColor = context.appTextMuted;
    final isDark = context.isDarkMode;
    final iconBg = isDark ? context.appBg : const Color(0xFFEAE1D1);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppTranslations.tr(lang, 'select_type.nabar'),
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(sheetCtx),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cardBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.x, size: 18, color: subColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              AppTranslations.tr(lang, 'select_type.nabar_choice_subtitle'),
              style: TextStyle(fontSize: 13, color: subColor),
            ),
            const SizedBox(height: 18),

            // Sub-Option A: Buat Room Baru
            _buildOptionCard(
              context,
              icon: LucideIcons.circlePlus,
              title: AppTranslations.tr(lang, 'select_type.nabar_create_new'),
              subtitle: AppTranslations.tr(
                lang,
                'select_type.nabar_create_new_desc',
              ),
              cardBg: cardBg,
              cardBorder: cardBorder,
              iconBg: iconBg,
              iconColor: context.appAccent,
              titleColor: titleColor,
              subColor: subColor,
              onTap: () {
                Navigator.pop(sheetCtx);
                onSelectType(TargetType.nabar);
              },
            ),
            const SizedBox(height: 12),

            // Sub-Option B: Gabung via Kode / Link
            _buildOptionCard(
              context,
              icon: LucideIcons.link,
              title: AppTranslations.tr(lang, 'select_type.join_room'),
              subtitle: AppTranslations.tr(lang, 'select_type.join_room_desc'),
              cardBg: cardBg,
              cardBorder: cardBorder,
              iconBg: iconBg,
              iconColor: const Color(0xFF10B981),
              titleColor: titleColor,
              subColor: subColor,
              onTap: () {
                Navigator.pop(sheetCtx);
                _showJoinRoomDialog(context, lang);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showJoinRoomDialog(BuildContext context, String lang) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          AppTranslations.tr(lang, 'select_type.join_dialog_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppTranslations.tr(lang, 'select_type.join_dialog_prompt')),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              decoration: InputDecoration(
                hintText: AppTranslations.tr(
                  lang,
                  'select_type.join_dialog_hint',
                ),
                hintStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppTranslations.tr(lang, 'common.cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final codeInput = controller.text.trim();
              if (codeInput.isEmpty) return;

              Navigator.pop(ctx);
              try {
                final repo = context.read<SupabaseNabarRepository>();
                // Fetch preview first
                final preview = await repo.getRoomPreview(codeInput);
                if (preview != null && context.mounted) {
                  RoomPreviewModal.show(context, preview);
                } else {
                  // Direct join fallback if preview wasn't available
                  final room = await repo.joinRoomByInviteCode(codeInput);
                  if (room != null && context.mounted) {
                    try {
                      final vm = context.read<TargetListViewModel>();
                      final existing = vm.targets.any(
                        (t) => t.roomId == room.id || t.id == room.id,
                      );
                      if (!existing) {
                        final target = TargetItem(
                          id: room.id,
                          title: room.name,
                          targetAmount: room.targetAmount,
                          currentAmount: room.currentAmount,
                          startDate: DateTime.now(),
                          endDate: room.targetDate,
                          note: room.note,
                          coverUrl: room.coverUrl,
                          type: TargetType.nabar,
                          roomId: room.id,
                        );
                        await vm.addTarget(target);
                      }
                    } catch (_) {}

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppTranslations.tr(
                            lang,
                            'select_type.join_request_sent',
                          ).replaceAll('{name}', room.name),
                        ),
                      ),
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NabarRoomView(roomId: room.id),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${AppTranslations.tr(lang, 'select_type.join_error')}: $e',
                      ),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: Text(
              AppTranslations.tr(lang, 'select_type.join_dialog_submit'),
            ),
          ),
        ],
      ),
    );
  }
}
