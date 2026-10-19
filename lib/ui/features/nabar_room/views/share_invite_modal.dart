import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/nabar_room.dart';
import '../../../core/i18n.dart';
import '../../../core/theme.dart';
import '../../target_list/view_models/target_list_view_model.dart';

class ShareInviteModal extends StatelessWidget {
  final NabarRoom room;

  const ShareInviteModal({super.key, required this.room});

  static Future<void> show(BuildContext context, NabarRoom room) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareInviteModal(room: room),
    );
  }

  String _buildFullShareMessage([String lang = 'id']) {
    final link = 'https://jagacuan-app.vercel.app/room/${room.id}';
    final inviteText = AppTranslations.tr(lang, 'share.invite_message');
    return '$inviteText\n$link';
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<TargetListViewModel>().language;

    final bg = context.appCard;
    final cardBg = context.appSurface;
    final cardBorder = context.appBorder;
    final textColor = context.appTextPrimary;
    final mutedTextColor = context.appTextMuted;

    final fullMessage = _buildFullShareMessage(lang);
    final rawLink = 'https://jagacuan-app.vercel.app/room/${room.id}';

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
          // Drag handle
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

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C8BFF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.share2,
                      size: 18,
                      color: Color(0xFF7C8BFF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppTranslations.tr(lang, 'share.title'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
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

          // Message Preview Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cardBorder, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.messageSquare,
                      size: 14,
                      color: mutedTextColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppTranslations.tr(lang, 'share.invite_text_label'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: mutedTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  fullMessage,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Raw Link Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.link,
                  size: 16,
                  color: Color(0xFF7C8BFF),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rawLink,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7C8BFF),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: fullMessage));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppTranslations.tr(lang, 'share.link_copied'),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      AppTranslations.tr(lang, 'share.copy'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Main Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: fullMessage));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppTranslations.tr(
                            lang,
                            'share.link_copied_clipboard',
                          ),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.copy, size: 16),
                  label: Text(
                    AppTranslations.tr(lang, 'share.copy_link'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: cardBorder, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: fullMessage));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppTranslations.tr(lang, 'share.message_copied'),
                        ),
                        backgroundColor: const Color(0xFF10B981),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.send, size: 18),
                  label: Text(
                    AppTranslations.tr(lang, 'share.copy_message'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
