import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../data/models/nabar_room.dart';
import '../../../../data/models/target_item.dart';
import '../../../../data/repositories/supabase_nabar_repository.dart';
import '../../target_list/view_models/target_list_view_model.dart';
import '../../../core/formatters.dart';
import '../../../core/i18n.dart';
import '../../../core/theme.dart';
import 'nabar_room_view.dart';

class RoomPreviewModal extends StatefulWidget {
  final NabarRoomPreview preview;

  const RoomPreviewModal({super.key, required this.preview});

  static Future<void> show(BuildContext context, NabarRoomPreview preview) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomPreviewModal(preview: preview),
    );
  }

  @override
  State<RoomPreviewModal> createState() => _RoomPreviewModalState();
}

class _RoomPreviewModalState extends State<RoomPreviewModal> {
  bool _isSubmitting = false;

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
          child: Icon(LucideIcons.image, size: 24, color: Colors.grey),
        ),
      );
    } else {
      final file = File(resolvedUrl);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
      return const Center(
        child: Icon(LucideIcons.image, size: 24, color: Colors.grey),
      );
    }
  }

  Future<void> _handleJoin() async {
    final preview = widget.preview;
    final repo = context.read<SupabaseNabarRepository>();
    final lang = context.read<TargetListViewModel>().language;

    // If user is already owner or approved, just open the room
    if (preview.userStatus == 'owner' ||
        preview.userStatus == 'approved_member' ||
        preview.userStatus == 'pending_member') {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NabarRoomView(roomId: preview.id)),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final room = await repo.joinRoomByInviteCode(preview.id);
      if (!mounted) return;
      Navigator.pop(context);

      if (room != null) {
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

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppTranslations.tr(
                lang,
                'select_type.join_request_sent',
              ).replaceAll('{name}', room.name),
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NabarRoomView(roomId: room.id)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppTranslations.tr(lang, 'select_type.join_error')}: $e',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final vm = context.watch<TargetListViewModel>();
    final currency = vm.currency;
    final lang = vm.language;

    final bg = context.appCard;
    final cardBg = context.appSurface;
    final cardBorder = context.appBorder;
    final textColor = context.appTextPrimary;
    final mutedTextColor = context.appTextMuted;

    final isAlreadyMember =
        preview.userStatus == 'owner' ||
        preview.userStatus == 'approved_member';
    final isPending = preview.userStatus == 'pending_member';

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle bar
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: context.appBorder,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Modal Title & Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppTranslations.tr(lang, 'preview.title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(LucideIcons.x, size: 20, color: mutedTextColor),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Room Card Overview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder, width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image or icon
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C8BFF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child:
                      preview.coverUrl != null && preview.coverUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _buildCoverImage(preview.coverUrl!),
                        )
                      : const Center(
                          child: Icon(
                            LucideIcons.users,
                            size: 28,
                            color: Color(0xFF7C8BFF),
                          ),
                        ),
                ),
                const SizedBox(width: 14),

                // Name & Host Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.user,
                            size: 14,
                            color: mutedTextColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Host: ${preview.ownerName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: mutedTextColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Target Amount & Deadline Grid
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.tr(lang, 'preview.joint_target'),
                        style: TextStyle(fontSize: 11, color: mutedTextColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatRupiah(preview.targetAmount, currency),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.tr(lang, 'preview.deadline'),
                        style: TextStyle(fontSize: 11, color: mutedTextColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatDateIndo(preview.targetDate, lang),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Note if present
          if (preview.note != null && preview.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.fileText, size: 16, color: mutedTextColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      preview.note!.trim(),
                      style: TextStyle(fontSize: 12, color: textColor),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Existing Membership Note
          if (isAlreadyMember || isPending) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isAlreadyMember
                    ? context.appBadgeSuccessBg
                    : context.appBadgeWarningBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isAlreadyMember
                      ? context.appBadgeSuccessBorder
                      : context.appBadgeWarningBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isAlreadyMember
                        ? LucideIcons.checkCircle
                        : LucideIcons.clock,
                    size: 16,
                    color: isAlreadyMember
                        ? const Color(0xFF10B981)
                        : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      preview.userStatus == 'owner'
                          ? AppTranslations.tr(lang, 'preview.status_host')
                          : (isAlreadyMember
                                ? AppTranslations.tr(
                                    lang,
                                    'preview.status_member',
                                  )
                                : AppTranslations.tr(
                                    lang,
                                    'preview.status_pending',
                                  )),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isAlreadyMember
                            ? context.appBadgeSuccessText
                            : context.appBadgeWarningText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: cardBorder, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    AppTranslations.tr(lang, 'common.cancel'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _handleJoin,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          isAlreadyMember
                              ? LucideIcons.externalLink
                              : LucideIcons.userPlus,
                          size: 18,
                        ),
                  label: Text(
                    isAlreadyMember
                        ? AppTranslations.tr(lang, 'preview.open_room')
                        : (isPending
                              ? AppTranslations.tr(lang, 'preview.view_status')
                              : AppTranslations.tr(
                                  lang,
                                  'preview.request_join',
                                )),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C8BFF),
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
        ],
      ),
    );
  }
}
