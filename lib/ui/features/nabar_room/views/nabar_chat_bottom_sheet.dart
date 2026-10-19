import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../data/repositories/supabase_nabar_repository.dart';
import '../../../../data/models/nabar_room.dart';
import '../../../core/formatters.dart';
import '../../../core/i18n.dart';
import '../../../core/theme.dart';
import '../../target_list/view_models/target_list_view_model.dart';

class NabarChatBottomSheet extends StatefulWidget {
  final NabarRoom room;

  const NabarChatBottomSheet({super.key, required this.room});

  static Future<void> show(BuildContext context, NabarRoom room) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NabarChatBottomSheet(room: room),
    );
  }

  @override
  State<NabarChatBottomSheet> createState() => _NabarChatBottomSheetState();
}

class _NabarChatBottomSheetState extends State<NabarChatBottomSheet> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isSendLocked = false;
  DateTime _lastSendTime = DateTime.fromMillisecondsSinceEpoch(0);
  late Stream<List<NabarMessage>> _messagesStream;

  @override
  void initState() {
    super.initState();
    final repo = context.read<SupabaseNabarRepository>();
    _messagesStream = repo.streamRoomMessages(widget.room.id);
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSend({
    String? customMessage,
    String messageType = 'text',
  }) async {
    final now = DateTime.now();
    // Anti double-send & debounce: drop repeated dispatches within 800ms
    if (now.difference(_lastSendTime).inMilliseconds < 800) return;
    if (_isSendLocked || _isSending) return;

    final text = (customMessage ?? _msgController.text).trim();
    if (text.isEmpty) return;

    // Immediate synchronous lock
    _isSendLocked = true;
    _lastSendTime = now;
    setState(() => _isSending = true);

    if (customMessage == null) {
      _msgController.clear();
    }

    try {
      final repo = context.read<SupabaseNabarRepository>();
      await repo.sendRoomMessage(
        roomId: widget.room.id,
        message: text,
        messageType: messageType,
      );
      Future.delayed(const Duration(milliseconds: 150), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        final lang = context.read<TargetListViewModel>().language;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppTranslations.tr(lang, 'chat.send_failed')}: $e',
            ),
          ),
        );
      }
    } finally {
      _isSendLocked = false;
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _confirmDeleteMessage(NabarMessage message) async {
    final repo = context.read<SupabaseNabarRepository>();
    final currentUserId = repo.currentUser?.id;
    final isHost = widget.room.ownerId == currentUserId;
    final isAuthor = message.userId == currentUserId;

    if (!isAuthor && !isHost) return;

    final lang = context.read<TargetListViewModel>().language;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppTranslations.tr(lang, 'chat.delete_title')),
        content: Text(
          isHost && !isAuthor
              ? AppTranslations.tr(lang, 'chat.delete_host_desc')
              : AppTranslations.tr(lang, 'chat.delete_author_desc'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppTranslations.tr(lang, 'common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: Text(AppTranslations.tr(lang, 'common.delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await repo.deleteRoomMessage(message.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${AppTranslations.tr(lang, 'chat.delete_failed')}: $e',
              ),
            ),
          );
        }
      }
    }
  }

  String _formatSystemMessage(String rawMsg, String lang) {
    final match = RegExp(
      r"""^(?:¡)?(.*?)(?:\s+(?:baru saja menyetor|just deposited|ha appena depositato|ha appena|hat gerade gespart|vient d[’']effectuer|acaba de realizar|ने अभी-अभी|เพิ่งฝากเงิน)[\s\S]*|さんが貯金[\s\S]*|刚刚存入[\s\S]*)""",
      caseSensitive: false,
    ).firstMatch(rawMsg.trim());

    if (match != null &&
        match.group(1) != null &&
        match.group(1)!.trim().isNotEmpty) {
      final name = match.group(1)!.trim();
      return AppTranslations.tr(
        lang,
        'chat.system_deposited',
      ).replaceAll('{name}', name);
    }
    return rawMsg;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final repo = context.watch<SupabaseNabarRepository>();
    final currentUserId = repo.currentUser?.id;
    final isHost = widget.room.ownerId == currentUserId;
    final vm = context.watch<TargetListViewModel>();
    final lang = vm.language;

    final quickCheers = [
      AppTranslations.tr(lang, 'chat.cheer_spirit'),
      AppTranslations.tr(lang, 'chat.cheer_deposited'),
      AppTranslations.tr(lang, 'chat.cheer_almost'),
      AppTranslations.tr(lang, 'chat.cheer_great'),
      AppTranslations.tr(lang, 'chat.cheer_cool'),
    ];

    final bg = context.appBg;
    final cardBg = context.appCard;
    final cardBorder = context.appBorder;
    final textColor = context.appTextPrimary;
    final mutedText = context.appTextMuted;
    final accentCol = context.appAccent;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: mutedText.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.messageSquare,
                    size: 18,
                    color: accentCol,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.tr(lang, 'chat.room_title'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '${widget.room.name} • ${AppTranslations.tr(lang, 'chat.member_count').replaceAll('{count}', '${widget.room.members.length}')}',
                        style: TextStyle(fontSize: 12, color: mutedText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(LucideIcons.x, size: 20, color: mutedText),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(color: cardBorder, height: 20),

          // Message Stream List
          Expanded(
            child: StreamBuilder<List<NabarMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        '${AppTranslations.tr(lang, 'chat.load_error')}: ${snapshot.error}',
                        style: TextStyle(fontSize: 12, color: mutedText),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  );
                }

                final rawMessages = snapshot.data ?? [];
                final seenIds = <String>{};
                final messages = <NabarMessage>[];
                for (final m in rawMessages) {
                  if (seenIds.add(m.id)) {
                    messages.add(m);
                  }
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.appSurface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.messagesSquare,
                              size: 36,
                              color: accentCol,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            AppTranslations.tr(lang, 'chat.empty_title'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppTranslations.tr(lang, 'chat.empty_desc'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: mutedText,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, idx) {
                    final msg = messages[idx];
                    final isMe = msg.userId == currentUserId;
                    final isSystem = msg.messageType == 'system';
                    final isCheer = msg.messageType == 'cheer';

                    if (isSystem) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: context.appSurface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: cardBorder, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.sparkles,
                                  size: 13,
                                  color: isDark
                                      ? const Color(0xFF93C5FD)
                                      : const Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _formatSystemMessage(msg.message, lang),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFFE2E8F0)
                                          : const Color(0xFF334155),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatTimeAgo(msg.createdAt, lang),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onLongPress: () {
                          if (isMe || isHost) {
                            _confirmDeleteMessage(msg);
                          }
                        },
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) ...[
                              CircleAvatar(
                                radius: 14,
                                backgroundImage:
                                    msg.avatarUrl != null &&
                                        msg.avatarUrl!.isNotEmpty
                                    ? NetworkImage(msg.avatarUrl!)
                                    : null,
                                child:
                                    (msg.avatarUrl == null ||
                                        msg.avatarUrl!.isEmpty)
                                    ? Text(
                                        msg.userName.isNotEmpty
                                            ? msg.userName[0].toUpperCase()
                                            : 'M',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 4,
                                        bottom: 4,
                                      ),
                                      child: Text(
                                        msg.userName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: mutedText,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isCheer ? 14 : 14,
                                      vertical: isCheer ? 10 : 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? accentCol
                                          : (isCheer
                                                ? context.appSurface
                                                : cardBg),
                                      border: isMe
                                          ? null
                                          : Border.all(
                                              color: cardBorder,
                                              width: 1,
                                            ),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: Radius.circular(
                                          isMe ? 16 : 4,
                                        ),
                                        bottomRight: Radius.circular(
                                          isMe ? 4 : 16,
                                        ),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.04,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          msg.message,
                                          style: TextStyle(
                                            fontSize: isCheer ? 14 : 13.5,
                                            fontWeight: isCheer
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isMe
                                                ? Colors.white
                                                : textColor,
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          formatTimeAgo(msg.createdAt, lang),
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            color: isMe
                                                ? Colors.white.withValues(
                                                    alpha: 0.75,
                                                  )
                                                : mutedText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Quick Cheer Chips Bar
          Container(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            decoration: BoxDecoration(
              color: context.appCard,
              border: Border(top: BorderSide(color: cardBorder, width: 0.8)),
            ),
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: quickCheers.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final cheer = quickCheers[idx];
                  return InkWell(
                    onTap: _isSending
                        ? null
                        : () => _handleSend(
                            customMessage: cheer,
                            messageType: 'cheer',
                          ),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.appSurface,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: cardBorder, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          cheer,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom Input Bar with Safe Keyboard Insets
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(color: context.appCard),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.appSurface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: cardBorder, width: 1.2),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _msgController,
                      style: TextStyle(fontSize: 14, color: textColor),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      decoration: InputDecoration(
                        hintText: AppTranslations.tr(
                          lang,
                          'chat.input_placeholder',
                        ),
                        hintStyle: TextStyle(fontSize: 13, color: mutedText),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _isSending ? null : () => _handleSend(),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentCol,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentCol.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isSending
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : const Icon(
                            LucideIcons.send,
                            size: 18,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
