import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../data/repositories/supabase_nabar_repository.dart';
import '../../../../data/models/nabar_room.dart';
import '../../target_list/view_models/target_list_view_model.dart';
import '../../target_list/views/create_target_modal.dart';
import '../../../../data/models/target_item.dart';
import '../../../core/formatters.dart';
import '../../../core/i18n.dart';
import '../../../core/theme.dart';
import 'share_invite_modal.dart';
import 'nabar_chat_bottom_sheet.dart';

class NabarRoomView extends StatefulWidget {
  final String roomId;
  const NabarRoomView({super.key, required this.roomId});

  @override
  State<NabarRoomView> createState() => _NabarRoomViewState();
}

class _NabarRoomViewState extends State<NabarRoomView> {
  NabarRoom? _room;
  bool _isLoading = true;
  String _pacingMode = 'daily';
  final _amountController = TextEditingController();

  StreamSubscription<List<NabarMessage>>? _msgSubscription;
  NabarMessage? _latestSneakPeekMessage;
  bool _showSneakPeek = false;
  Timer? _sneakPeekTimer;

  @override
  void initState() {
    super.initState();
    _fetchRoom();
  }

  @override
  void dispose() {
    _msgSubscription?.cancel();
    _sneakPeekTimer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  void _onDepositAmountChanged(String val) {
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

  Future<void> _fetchRoom() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final repo = context.read<SupabaseNabarRepository>();
      NabarRoom? room;

      if (widget.roomId != 'demo_room' && widget.roomId.isNotEmpty) {
        room = await repo
            .getRoomById(widget.roomId)
            .timeout(const Duration(seconds: 4), onTimeout: () => null);
      }

      if (room == null && repo.currentUser != null) {
        final userRooms = await repo.getUserRooms().timeout(
          const Duration(seconds: 4),
          onTimeout: () => [],
        );
        if (userRooms.isNotEmpty) {
          room = userRooms.first;
        }
      }

      // Auto-sync cover to Supabase if coverUrl is missing or local path, but host has local file
      if (room != null &&
          (room.userStatus == 'owner' ||
              room.ownerId == repo.currentUser?.id)) {
        try {
          if (mounted) {
            final vm = context.read<TargetListViewModel>();
            final localTarget = vm.targets.cast<TargetItem?>().firstWhere(
              (t) => t?.id == widget.roomId || t?.roomId == widget.roomId,
              orElse: () => null,
            );

            final currentCover = room.coverUrl;
            final isNotRemoteUrl =
                currentCover == null ||
                currentCover.isEmpty ||
                !currentCover.startsWith('http');

            if (isNotRemoteUrl) {
              String? localCandidatePath;
              if (currentCover != null && currentCover.startsWith('/')) {
                localCandidatePath = currentCover;
              } else if (localTarget?.coverUrl != null &&
                  localTarget!.coverUrl!.isNotEmpty &&
                  localTarget.coverUrl!.startsWith('/')) {
                localCandidatePath = localTarget.coverUrl;
              }

              if (localCandidatePath != null) {
                final file = File(localCandidatePath);
                if (file.existsSync()) {
                  room = room.copyWith(coverUrl: localCandidatePath);
                  final targetRoomId = room.id;
                  unawaited(
                    repo
                        .uploadRoomCover(file, roomId: targetRoomId)
                        .then((uploadedUrl) {
                          if (uploadedUrl != null && mounted) {
                            repo.updateRoomCover(targetRoomId, uploadedUrl);
                            setState(() {
                              _room = _room?.copyWith(coverUrl: uploadedUrl);
                            });
                            if (localTarget != null) {
                              vm.updateTarget(
                                localTarget.copyWith(coverUrl: uploadedUrl),
                              );
                            }
                          }
                        })
                        .catchError((_) {}),
                  );
                }
              } else if (localTarget?.coverUrl != null &&
                  localTarget!.coverUrl!.isNotEmpty) {
                room = room.copyWith(coverUrl: localTarget.coverUrl);
              }
            }
          }
        } catch (e) {
          debugPrint('Error syncing local cover: $e');
        }
      }

      if (room == null) {
        try {
          if (!mounted) return;
          final vm = context.read<TargetListViewModel>();
          TargetItem? localTarget;

          if (widget.roomId != 'demo_room' && widget.roomId.isNotEmpty) {
            localTarget = vm.targets.cast<TargetItem?>().firstWhere(
              (t) => t?.id == widget.roomId || t?.roomId == widget.roomId,
              orElse: () => null,
            );
          }

          localTarget ??= vm.targets.cast<TargetItem?>().firstWhere(
            (t) => t?.type == TargetType.nabar,
            orElse: () => null,
          );

          if (localTarget != null) {
            room = NabarRoom(
              id: localTarget.roomId ?? localTarget.id,
              name: localTarget.title,
              targetAmount: localTarget.targetAmount,
              currentAmount: localTarget.currentAmount,
              targetDate: localTarget.endDate,
              ownerId: repo.currentUser?.id ?? 'owner',
              coverUrl: localTarget.coverUrl,
              note: localTarget.note,
              inviteCode: localTarget.roomId ?? localTarget.id,
              userStatus: 'owner',
              members: [
                NabarMember(
                  id: '1',
                  userId: repo.currentUser?.id ?? 'owner',
                  name: repo.currentUser?.userMetadata?['full_name'] ?? 'Saya',
                  avatarUrl: repo.currentUser?.userMetadata?['avatar_url'],
                  status: 'approved',
                  role: 'owner',
                  avatarBg: '#7C8BFF',
                ),
              ],
              pendingMembers: [],
              activities: [],
              pendingActivities: [],
            );
          }
        } catch (e) {
          debugPrint('Error loading local target fallback: $e');
        }
      }

      if (mounted) {
        setState(() {
          _room = room;
        });
        if (room != null) {
          _listenToMessages(room.id);
          try {
            final vm = context.read<TargetListViewModel>();
            final currentRoom = room;
            final localTarget = vm.targets.cast<TargetItem?>().firstWhere(
              (t) => t?.id == currentRoom.id || t?.roomId == currentRoom.id,
              orElse: () => null,
            );
            if (localTarget != null) {
              final updated = localTarget.copyWith(
                currentAmount: room.currentAmount,
                targetAmount: room.targetAmount,
                title: room.name,
                coverUrl: room.coverUrl ?? localTarget.coverUrl,
              );
              if (updated.currentAmount != localTarget.currentAmount ||
                  updated.targetAmount != localTarget.targetAmount ||
                  updated.title != localTarget.title ||
                  updated.coverUrl != localTarget.coverUrl) {
                vm.updateTarget(updated);
              }
            }
          } catch (e) {
            debugPrint('Error syncing local target in NabarRoomView: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching Nabar room: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _listenToMessages(String roomId) {
    _msgSubscription?.cancel();
    final repo = context.read<SupabaseNabarRepository>();
    _msgSubscription = repo.streamRoomMessages(roomId).listen((messages) {
      if (!mounted || messages.isEmpty) return;
      final latest = messages.last;
      final currentUserId = repo.currentUser?.id;
      // Show sneak peek only if the message is from someone else and not a system event
      if (latest.userId != currentUserId && latest.messageType != 'system') {
        _sneakPeekTimer?.cancel();
        setState(() {
          _latestSneakPeekMessage = latest;
          _showSneakPeek = true;
        });
        _sneakPeekTimer = Timer(const Duration(milliseconds: 3500), () {
          if (mounted) {
            setState(() {
              _showSneakPeek = false;
            });
          }
        });
      }
    });
  }

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
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(LucideIcons.image, size: 36, color: Colors.grey),
          );
        },
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

  Future<void> _handleTransaction(bool isDeposit, double myNetEquity) async {
    final amountStr = _amountController.text.replaceAll(RegExp(r'\D'), '');
    final amount = double.tryParse(amountStr) ?? 0;
    if (amount <= 0 || _room == null) return;

    final vm = context.read<TargetListViewModel>();
    final lang = vm.language;
    final baseAmount = amount;

    if (!isDeposit && baseAmount > myNetEquity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppTranslations.tr(
              lang,
              'nabar.withdraw_limit_exceeded',
            ).replaceAll('{amount}', formatRupiah(myNetEquity)),
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    try {
      final repo = context.read<SupabaseNabarRepository>();
      final status = await repo.addRoomTransaction(
        roomId: _room!.id,
        amount: baseAmount,
        isDeposit: isDeposit,
        note: isDeposit ? 'Setoran tabungan' : 'Penarikan tabungan',
      );

      _amountController.clear();
      if (mounted) Navigator.pop(context);

      final msg = isDeposit
          ? (status == 'approved'
                ? AppTranslations.tr(lang, 'nabar.deposit_success')
                : AppTranslations.tr(lang, 'nabar.deposit_pending_host'))
          : (status == 'approved'
                ? AppTranslations.tr(lang, 'nabar.withdraw_success')
                : AppTranslations.tr(lang, 'nabar.withdraw_pending_host'));

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }

      if (status == 'approved' && _room != null) {
        final name = repo.currentUser?.userMetadata?['full_name'] ?? 'Anggota';
        final actionText = isDeposit
            ? AppTranslations.tr(
                lang,
                'chat.system_deposited',
              ).replaceAll('{name}', name)
            : '$name menarik dana ${formatRupiah(baseAmount)}';
        repo.sendSystemMessage(roomId: _room!.id, message: actionText);
      }

      await _fetchRoom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _approveTx(String txId) async {
    final lang = context.read<TargetListViewModel>().language;
    final repo = context.read<SupabaseNabarRepository>();
    final pendingAct = _room?.pendingActivities.firstWhere(
      (a) => a.id == txId,
      orElse: () => NabarActivity(
        id: '',
        userId: '',
        name: 'Anggota',
        amount: 0,
        isDeposit: true,
        note: '',
        timestamp: DateTime.now(),
        status: 'approved',
      ),
    );

    await repo.approveRoomTransaction(txId);

    if (_room != null && pendingAct != null && pendingAct.name.isNotEmpty) {
      repo.sendSystemMessage(
        roomId: _room!.id,
        message: AppTranslations.tr(
          lang,
          'chat.system_deposited',
        ).replaceAll('{name}', pendingAct.name),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppTranslations.tr(lang, 'nabar.deposit_approved')),
        ),
      );
    }
    await _fetchRoom();
  }

  Future<void> _rejectTx(String txId) async {
    final lang = context.read<TargetListViewModel>().language;
    final repo = context.read<SupabaseNabarRepository>();
    await repo.rejectRoomTransaction(txId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppTranslations.tr(lang, 'nabar.deposit_rejected')),
        ),
      );
    }
    await _fetchRoom();
  }

  Future<void> _approveMember(String memberUserId, String name) async {
    final lang = context.read<TargetListViewModel>().language;
    final repo = context.read<SupabaseNabarRepository>();
    await repo.approveMember(_room!.id, memberUserId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppTranslations.tr(
              lang,
              'nabar.member_approved',
            ).replaceAll('{name}', name),
          ),
        ),
      );
    }
    await _fetchRoom();
  }

  Future<void> _rejectMember(String memberUserId, String name) async {
    final lang = context.read<TargetListViewModel>().language;
    final repo = context.read<SupabaseNabarRepository>();
    await repo.rejectMember(_room!.id, memberUserId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppTranslations.tr(
              lang,
              'nabar.member_rejected',
            ).replaceAll('{name}', name),
          ),
        ),
      );
    }
    await _fetchRoom();
  }

  Future<void> _handleLeaveRoom() async {
    final lang = context.read<TargetListViewModel>().language;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppTranslations.tr(lang, 'nabar.leave_room_confirm_title')),
        content: Text(
          AppTranslations.tr(lang, 'nabar.leave_room_confirm_desc'),
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
            ),
            child: Text(
              AppTranslations.tr(lang, 'nabar.leave_room'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final repo = context.read<SupabaseNabarRepository>();
      final vm = context.read<TargetListViewModel>();
      await repo.leaveRoom(_room!.id);

      // Remove from local targets if user had saved it
      final localTarget = vm.targets.cast<TargetItem?>().firstWhere(
        (t) => t?.roomId == _room!.id || t?.id == _room!.id,
        orElse: () => null,
      );
      if (localTarget != null) {
        await vm.deleteTarget(localTarget.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.tr(lang, 'nabar.room_left'))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _handleDeleteRoom() async {
    final lang = context.read<TargetListViewModel>().language;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          AppTranslations.tr(lang, 'nabar.delete_room_confirm_title'),
        ),
        content: Text(
          AppTranslations.tr(lang, 'nabar.delete_room_confirm_desc'),
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
            ),
            child: Text(
              AppTranslations.tr(lang, 'common.delete'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final repo = context.read<SupabaseNabarRepository>();
      final vm = context.read<TargetListViewModel>();
      await repo.deleteRoom(_room!.id);

      // Remove from local targets
      final localTarget = vm.targets.cast<TargetItem?>().firstWhere(
        (t) => t?.roomId == _room!.id || t?.id == _room!.id,
        orElse: () => null,
      );
      if (localTarget != null) {
        await vm.deleteTarget(localTarget.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTranslations.tr(lang, 'nabar.room_deleted')),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final repo = context.watch<SupabaseNabarRepository>();
    final currentUser = repo.currentUser;
    final vm = context.watch<TargetListViewModel>();
    final lang = vm.language;

    if (currentUser == null) {
      final bg = context.appBg;
      final cardBg = context.appCard;
      final cardBorder = context.appBorder;
      final textColor = context.appTextPrimary;
      final mutedTextColor = context.appTextMuted;

      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: Text(
            AppTranslations.tr(lang, 'nabar.room_title'),
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
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
                      color: context.appSurface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.user,
                      size: 24,
                      color: mutedTextColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppTranslations.tr(lang, 'nabar.google_not_connected'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppTranslations.tr(lang, 'nabar.google_required_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: mutedTextColor),
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
                      label: Text(
                        AppTranslations.tr(lang, 'nabar.connect_google_btn'),
                      ),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_room == null) {
      final bg = context.appBg;
      final cardBg = context.appCard;
      final cardBorder = context.appBorder;
      final textColor = context.appTextPrimary;
      final mutedTextColor = context.appTextMuted;

      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: Text(
            AppTranslations.tr(lang, 'nabar.room_title'),
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
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
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: context.appSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.users,
                      size: 26,
                      color: Color(0xFF7C8BFF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppTranslations.tr(lang, 'nabar.no_room_title'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppTranslations.tr(lang, 'nabar.no_room_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: mutedTextColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const CreateTargetModal(
                            initialType: TargetType.nabar,
                          ),
                        );
                      },
                      icon: const Icon(LucideIcons.plusCircle, size: 18),
                      label: Text(
                        AppTranslations.tr(lang, 'nabar.create_room_btn'),
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
            ),
          ),
        ),
      );
    }

    final room = _room!;
    final isOwner = room.userStatus == 'owner';
    final isPendingMember = room.userStatus == 'pending_member';

    final bg = context.appBg;
    final cardBg = context.appCard;
    final cardBorder = context.appBorder;
    final textColor = context.appTextPrimary;
    final mutedTextColor = context.appTextMuted;

    if (isPendingMember) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: Text(
            room.name,
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
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
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.clock,
                      size: 28,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppTranslations.tr(
                      lang,
                      'nabar.pending_verification_title',
                    ),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppTranslations.tr(
                      lang,
                      'nabar.pending_verification_desc',
                    ).replaceAll('{name}', room.name),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: mutedTextColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _fetchRoom,
                      icon: const Icon(LucideIcons.refreshCw, size: 16),
                      label: Text(
                        AppTranslations.tr(lang, 'nabar.check_status_btn'),
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
            ),
          ),
        ),
      );
    }

    final currentUserId = currentUser.id;
    double myDepositTotal = 0.0;
    double myWithdrawTotal = 0.0;
    for (final act in room.activities.where(
      (a) => a.userId == currentUserId && a.status == 'approved',
    )) {
      if (act.isDeposit) {
        myDepositTotal += act.amount;
      } else {
        myWithdrawTotal += act.amount;
      }
    }
    final myNetEquity = (myDepositTotal - myWithdrawTotal).clamp(
      0.0,
      double.infinity,
    );
    final myEquityPct = room.currentAmount > 0
        ? ((myNetEquity / room.currentAmount) * 100).clamp(0.0, 100.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          room.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.share2),
            tooltip: AppTranslations.tr(lang, 'share.title'),
            onPressed: () {
              ShareInviteModal.show(context, room);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.moreVertical),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (val) {
              if (val == 'delete') {
                _handleDeleteRoom();
              } else if (val == 'leave') {
                _handleLeaveRoom();
              }
            },
            itemBuilder: (ctx) => [
              if (isOwner)
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.trash2,
                        size: 18,
                        color: Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        AppTranslations.tr(lang, 'nabar.delete_room'),
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.logOut,
                        size: 18,
                        color: Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        AppTranslations.tr(lang, 'nabar.leave_room'),
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target Photo Banner (if available)
            if (room.coverUrl != null && room.coverUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(color: context.appSurface),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildCoverImage(room.coverUrl!),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 70,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.65),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 14,
                        right: 14,
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.target,
                              size: 14,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${AppTranslations.tr(lang, 'nabar.target_photo')}: ${room.name}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 1),
                                      blurRadius: 3,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

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
                        Text(
                          AppTranslations.tr(lang, 'nabar.collected'),
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        Text(
                          '${room.progressPercentage.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatRupiah(room.currentAmount),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    Text(
                      '${AppTranslations.tr(lang, 'nabar.target')} ${formatRupiah(room.targetAmount)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: room.progressPercentage / 100,
                        minHeight: 10,
                        backgroundColor: isDark
                            ? Colors.white12
                            : context.appSurface,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF7C8BFF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card: Porsi Tabungan Kamu (Personal Equity)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
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
                              color: const Color(0xFF7C8BFF)
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.pieChart,
                              color: Color(0xFF7C8BFF),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppTranslations.tr(lang, 'nabar.my_equity'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C8BFF)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          AppTranslations.tr(
                            lang,
                            'nabar.my_equity_share_badge',
                          ).replaceAll(
                            '{percent}',
                            myEquityPct.toStringAsFixed(1),
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C8BFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    formatRupiah(myNetEquity),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.shieldCheck,
                        size: 13,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          AppTranslations.tr(
                            lang,
                            'nabar.my_equity_hint',
                          ).replaceAll(
                            '{amount}',
                            formatRupiah(myNetEquity),
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card: Rekomendasi Setoran (Shared Pacing per Member)
            if (room.currentAmount < room.targetAmount) ...[
              _buildNabarPacingCard(
                context,
                room,
                vm,
                isDark,
                cardBg,
                cardBorder,
                mutedTextColor,
                textColor,
                myNetEquity,
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons: Setor & Tarik
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showTransactionModal(context, true, myNetEquity),
                      icon: const Icon(LucideIcons.plusCircle, size: 18),
                      label: Text(
                        AppTranslations.tr(lang, 'nabar.add_deposit'),
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
                          _showTransactionModal(context, false, myNetEquity),
                      icon: const Icon(
                        LucideIcons.arrowUpRight,
                        size: 18,
                        color: Color(0xFFDC2626),
                      ),
                      label: Text(
                        AppTranslations.tr(lang, 'nabar.withdraw_btn'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFFDC2626),
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
            const SizedBox(height: 20),

            // Room Link Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C8BFF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.link,
                      size: 18,
                      color: Color(0xFF7C8BFF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.tr(lang, 'nabar.room_link_label'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          'https://jagacuan-app.vercel.app/room/${room.id}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF7C8BFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      ShareInviteModal.show(context, room);
                    },
                    icon: const Icon(LucideIcons.share2, size: 14),
                    label: Text(AppTranslations.tr(lang, 'nabar.share_button')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C8BFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pending Member Approval Section (HOST ONLY)
            if (isOwner && room.pendingMembers.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF23242A)
                      : const Color(0xFFFAF6EF),
                  border: Border.all(color: const Color(0xFF3B82F6)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.userPlus,
                          color: Color(0xFF3B82F6),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppTranslations.tr(
                            lang,
                            'nabar.pending_member_requests',
                          ).replaceAll(
                            '{count}',
                            '${room.pendingMembers.length}',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...room.pendingMembers.map(
                      (mem) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1C1D22)
                              : const Color(0xFFEFEADF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage:
                                  mem.avatarUrl != null &&
                                      mem.avatarUrl!.isNotEmpty
                                  ? NetworkImage(mem.avatarUrl!)
                                  : null,
                              child:
                                  (mem.avatarUrl == null ||
                                      mem.avatarUrl!.isEmpty)
                                  ? Text(
                                      mem.name.isNotEmpty
                                          ? mem.name[0].toUpperCase()
                                          : 'M',
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                mem.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _approveMember(mem.userId, mem.name),
                                  icon: const Icon(LucideIcons.check, size: 14),
                                  label: Text(
                                    AppTranslations.tr(lang, 'nabar.approve'),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton(
                                  onPressed: () =>
                                      _rejectMember(mem.userId, mem.name),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                  ),
                                  child: Text(
                                    AppTranslations.tr(lang, 'nabar.reject'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Pending Host Verification Section for Deposits (HOST ONLY)
            if (isOwner && room.pendingActivities.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF23242A)
                      : const Color(0xFFFAF6EF),
                  border: Border.all(color: const Color(0xFFD97706)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.clock,
                          color: Color(0xFFD97706),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppTranslations.tr(
                            lang,
                            'nabar.pending_deposit_requests',
                          ).replaceAll(
                            '{count}',
                            '${room.pendingActivities.length}',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...room.pendingActivities.map(
                      (act) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1C1D22)
                              : const Color(0xFFEFEADF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: act.avatarUrl != null
                                  ? NetworkImage(act.avatarUrl!)
                                  : null,
                              child: act.avatarUrl == null
                                  ? Text(act.name[0])
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${act.name} - +${formatRupiah(act.amount)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${formatTimeAgo(act.timestamp, lang)} • ${AppTranslations.tr(lang, 'nabar.pending_host')}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    LucideIcons.check,
                                    color: Color(0xFF16A34A),
                                  ),
                                  onPressed: () => _approveTx(act.id),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    LucideIcons.x,
                                    color: Color(0xFFDC2626),
                                  ),
                                  onPressed: () => _rejectTx(act.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Anggota Room Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppTranslations.tr(lang, 'nabar.members_title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Chip(
                  label: Text(
                    AppTranslations.tr(
                      lang,
                      'nabar.member_count',
                    ).replaceAll('{count}', '${room.members.length}'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: room.members.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final mem = room.members[idx];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage:
                              mem.avatarUrl != null && mem.avatarUrl!.isNotEmpty
                              ? NetworkImage(mem.avatarUrl!)
                              : null,
                          child:
                              (mem.avatarUrl == null || mem.avatarUrl!.isEmpty)
                              ? Text(
                                  mem.name[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          mem.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Recent Activities
            Text(
              AppTranslations.tr(lang, 'nabar.recent_activities'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (room.activities.isEmpty)
              Text(AppTranslations.tr(lang, 'nabar.no_activities'))
            else
              ...room.activities.map(
                (act) => ListTile(
                  leading: CircleAvatar(
                    backgroundImage: act.avatarUrl != null
                        ? NetworkImage(act.avatarUrl!)
                        : null,
                    child: act.avatarUrl == null ? Text(act.name[0]) : null,
                  ),
                  title: Text(
                    act.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(formatTimeAgo(act.timestamp, lang)),
                  trailing: Text(
                    '+${formatRupiah(act.amount)}',
                    style: const TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Sneak-Peek Mini Bubble (appears for 3.5s on incoming messages)
          if (_showSneakPeek && _latestSneakPeekMessage != null)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showSneakPeek ? 1.0 : 0.0,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8, right: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                constraints: const BoxConstraints(maxWidth: 240),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.messageSquare,
                      size: 14,
                      color: Color(0xFF7C8BFF),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _latestSneakPeekMessage!.messageType == 'system'
                            ? _formatSystemMessage(
                                _latestSneakPeekMessage!.message,
                                lang,
                              )
                            : '${_latestSneakPeekMessage!.userName}: ${_latestSneakPeekMessage!.message}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Floating Chat Button
          FloatingActionButton.extended(
            heroTag: 'nabar_chat_fab',
            onPressed: () {
              setState(() {
                _showSneakPeek = false;
              });
              NabarChatBottomSheet.show(context, room);
            },
            backgroundColor: const Color(0xFF7C8BFF),
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(LucideIcons.messageSquare, size: 18),
            label: Text(
              AppTranslations.tr(lang, 'nabar.chat_button'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNabarPacingCard(
    BuildContext context,
    NabarRoom room,
    TargetListViewModel vm,
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color subText,
    Color textCol,
    double myNetEquity,
  ) {
    final remaining = (room.targetAmount - room.currentAmount).clamp(
      0.0,
      double.infinity,
    );
    final memberCount = room.members.isNotEmpty ? room.members.length : 1;
    final myShareRemaining = remaining / memberCount;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(
      room.targetDate.year,
      room.targetDate.month,
      room.targetDate.day,
    );
    final daysDiff = endDay.difference(today).inDays;
    final safeDays = daysDiff > 0 ? daysDiff : 1;

    double pacingAmount;
    String periodLabel;
    String hintText;

    if (_pacingMode == 'daily') {
      pacingAmount = (myShareRemaining / safeDays).ceilToDouble();
      periodLabel = '/ ${AppTranslations.tr(vm.language, 'detail.per_day')}';
      hintText = AppTranslations.tr(
        vm.language,
        'nabar.pacing_daily_hint',
      ).replaceAll('{members}', memberCount.toString());
    } else if (_pacingMode == 'weekly') {
      pacingAmount = (myShareRemaining / safeDays * 7)
          .clamp(0.0, myShareRemaining)
          .ceilToDouble();
      periodLabel = '/ ${AppTranslations.tr(vm.language, 'detail.per_week')}';
      hintText = AppTranslations.tr(
        vm.language,
        'nabar.pacing_weekly_hint',
      ).replaceAll('{members}', memberCount.toString());
    } else {
      final paydaysLeft = (safeDays / 30).ceil().clamp(1, 120);
      pacingAmount = (myShareRemaining / paydaysLeft).ceilToDouble();
      periodLabel = '/ ${AppTranslations.tr(vm.language, 'detail.per_payday')}';
      hintText = AppTranslations.tr(vm.language, 'nabar.pacing_payday_hint')
          .replaceAll('{members}', memberCount.toString())
          .replaceAll('{count}', paydaysLeft.toString());
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
              Expanded(
                child: Text(
                  AppTranslations.tr(vm.language, 'detail.pacing_title'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textCol,
                  ),
                ),
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

          // Shortcut Setor Pacing
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: () => _showTransactionModal(
                context,
                true,
                myNetEquity,
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

  void _showTransactionModal(
    BuildContext context,
    bool initialIsDeposit,
    double myNetEquity, {
    double? initialAmount,
  }) {
    final vm = context.read<TargetListViewModel>();
    final lang = vm.language;
    const curSymbol = 'Rp';
    bool isDeposit = initialIsDeposit;
    if (initialAmount != null && initialAmount > 0) {
      _amountController.text = formatAmountOnly(
        initialAmount.round(),
      );
    } else {
      _amountController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
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
                                    lang,
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
                                    lang,
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
                          LucideIcons.shieldCheck,
                          size: 16,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppTranslations.tr(
                              lang,
                              'nabar.my_equity_hint',
                            ).replaceAll(
                              '{amount}',
                              formatRupiah(myNetEquity),
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
                  onChanged: _onDepositAmountChanged,
                  decoration: InputDecoration(
                    labelText:
                        '${AppTranslations.tr(lang, 'detail.amount_nominal')} ($curSymbol)',
                    hintText: '50.000',
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
                    onPressed: () => _handleTransaction(isDeposit, myNetEquity),
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
                          ? AppTranslations.tr(lang, 'nabar.send_deposit_btn')
                          : AppTranslations.tr(lang, 'nabar.withdraw_btn'),
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
}
