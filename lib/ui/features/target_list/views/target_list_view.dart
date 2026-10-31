import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:app_links/app_links.dart';

import '../view_models/target_list_view_model.dart';
import '../../../../data/models/target_item.dart';
import '../../../../data/models/nabar_room.dart';
import '../../../core/formatters.dart';
import 'select_target_type_modal.dart';
import 'create_target_modal.dart';
import 'sidebar_drawer.dart';
import '../../target_detail/views/target_detail_view.dart';
import '../../nabar_room/views/nabar_room_view.dart';
import '../../nabar_room/views/connect_google_modal.dart';
import '../../nabar_room/views/room_preview_modal.dart';
import '../../calendar/views/calendar_modal.dart';
import '../../statistics/views/statistics_modal.dart';
import '../../../core/i18n.dart';
import '../../../core/theme.dart';

import '../../../../data/repositories/local_storage_repository.dart';
import '../../../../data/repositories/supabase_nabar_repository.dart';
import '../../../core/notification_permission_dialog.dart';

class TargetListView extends StatefulWidget {
  const TargetListView({super.key});

  @override
  State<TargetListView> createState() => _TargetListViewState();
}

class _TargetListViewState extends State<TargetListView>
    with WidgetsBindingObserver {
  bool _checkedInitialNotif = false;
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  String? _lastHandledClipboardCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboardForInvite();
      _syncNabarTargets();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForInvite();
      _syncNabarTargets();
    }
  }

  Future<void> _syncNabarTargets() async {
    if (!mounted) return;
    try {
      final vm = context.read<TargetListViewModel>();
      final repo = context.read<SupabaseNabarRepository>();
      await vm.syncNabarRooms(repo);
    } catch (e) {
      debugPrint('Error syncing nabar targets in TargetListView: $e');
    }
  }

  Future<void> _checkClipboardForInvite() async {
    try {
      final clipData = await Clipboard.getData(Clipboard.kTextPlain);
      final rawText = clipData?.text?.trim() ?? '';
      if (rawText.isEmpty) return;

      if (!mounted) return;
      final repo = context.read<SupabaseNabarRepository>();
      final code = repo.extractCodeFromInput(rawText);
      if (code.isEmpty) return;

      // Do not prompt repeatedly for the exact same clipboard code
      if (_lastHandledClipboardCode == code) return;
      _lastHandledClipboardCode = code;

      if (repo.currentUser == null) return;

      final preview = await repo.getRoomPreview(code);
      if (preview != null && mounted) {
        _showClipboardInviteBottomSheet(preview);
      }
    } catch (e) {
      debugPrint('Auto clipboard check error: $e');
    }
  }

  void _showClipboardInviteBottomSheet(NabarRoomPreview preview) {
    final bg = context.appCard;
    final cardBorder = context.appBorder;
    final textColor = context.appTextPrimary;
    final lang = context.read<TargetListViewModel>().language;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.sparkles,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.tr(lang, 'invite.detected_title'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppTranslations.tr(lang, 'invite.detected_from_clipboard')
                            .replaceAll('{name}', preview.name),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppTranslations.tr(lang, 'common.ignore'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      RoomPreviewModal.show(context, preview);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C8BFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppTranslations.tr(lang, 'invite.view_room'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initDeepLinks() async {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleIncomingUri(uri);
      },
      onError: (err) {
        debugPrint('Deep link error: $err');
      },
    );

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleIncomingUri(initialUri);
      }
    } catch (e) {
      debugPrint('Failed to get initial deep link: $e');
    }
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    final repo = context.read<SupabaseNabarRepository>();
    final code = repo.extractCodeFromInput(uri.toString());
    if (code.isNotEmpty) {
      if (repo.currentUser == null) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => const ConnectGoogleModal(),
          );
        }
        return;
      }
      try {
        final preview = await repo.getRoomPreview(code);
        if (preview != null && mounted) {
          RoomPreviewModal.show(context, preview);
        } else {
          final room = await repo.joinRoomByInviteCode(code);
          if (room != null && mounted) {
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
            final lang = context.read<TargetListViewModel>().language;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppTranslations.tr(lang, 'invite.joined_success')
                      .replaceAll('{name}', room.name),
                ),
              ),
            );
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NabarRoomView(roomId: room.id)),
            );
            if (mounted) {
              await _syncNabarTargets();
            }
          }
        }
      } catch (e) {
        if (mounted) {
          final lang = context.read<TargetListViewModel>().language;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${AppTranslations.tr(lang, 'select_type.join_error')}: $e',
              ),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedInitialNotif) {
      _checkedInitialNotif = true;
      _checkInitialNotificationPrompt();
    }
  }

  Future<void> _checkInitialNotificationPrompt() async {
    final localRepo = context.read<LocalStorageRepository>();
    final prompted = await localRepo.hasPromptedInitialNotification();
    if (!prompted && mounted) {
      await localRepo.setPromptedInitialNotification();
      if (mounted) {
        checkAndShowNotificationPermissionDialog(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TargetListViewModel>();
    final isDark = vm.isDarkMode;

    final bg = context.appBg;
    final cardBg = context.appCard;
    final cardBorder = context.appBorder;

    return Scaffold(
      backgroundColor: bg,
      drawer: const SidebarDrawer(),
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content Column
            Column(
              children: [
                // Top Header Bar
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: 8,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Builder(
                            builder: (ctx) => IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                LucideIcons.menu,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF2C2418),
                                size: 24,
                              ),
                              onPressed: () => Scaffold.of(ctx).openDrawer(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Jagacuan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF2C2418),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Top Action Buttons Row (Right Aligned)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildTopActionButton(
                            context,
                            icon: LucideIcons.calendar,
                            label: AppTranslations.tr(
                              vm.language,
                              'page.calendar',
                            ),
                            iconColor: const Color(0xFFE67E22),
                            isDark: isDark,
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const CalendarModal(),
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          _buildTopActionButton(
                            context,
                            icon: LucideIcons.pieChart,
                            label: AppTranslations.tr(
                              vm.language,
                              'page.statistics',
                            ),
                            iconColor: const Color(0xFF22C55E),
                            isDark: isDark,
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const StatisticsModal(),
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          _buildTopActionButton(
                            context,
                            icon: LucideIcons.users,
                            label: AppTranslations.tr(
                              vm.language,
                              'page.rooms',
                            ),
                            iconColor: const Color(0xFF818CF8),
                            isDark: isDark,
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => const ConnectGoogleModal(),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Search Bar & Filter Chips (If Targets Exist)
                if (vm.targets.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: TextField(
                        onChanged: (val) => vm.setSearchQuery(val),
                        decoration: InputDecoration(
                          hintText: AppTranslations.tr(
                            vm.language,
                            'page.search_placeholder',
                          ),
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFFA0A5B5)
                                : const Color(0xFF7A6F60),
                          ),
                          prefixIcon: Icon(
                            LucideIcons.search,
                            size: 16,
                            color: isDark
                                ? const Color(0xFFA0A5B5)
                                : const Color(0xFF7A6F60),
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        _buildSortChip(
                          context,
                          vm,
                          SortOption.newest,
                          AppTranslations.tr(vm.language, 'page.sort_newest'),
                          const Color(0xFF7C8BFF),
                        ),
                        const SizedBox(width: 8),
                        _buildSortChip(
                          context,
                          vm,
                          SortOption.highestProgress,
                          AppTranslations.tr(vm.language, 'page.sort_progress'),
                          const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 8),
                        _buildSortChip(
                          context,
                          vm,
                          SortOption.closestDeadline,
                          AppTranslations.tr(vm.language, 'page.sort_deadline'),
                          const Color(0xFFDC2626),
                        ),
                      ],
                    ),
                  ),
                ],

                // Content Area / Empty State
                Expanded(
                  child: vm.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: () async {
                            await vm.loadTargets();
                            await _syncNabarTargets();
                          },
                          child: vm.filteredTargets.isEmpty
                              ? Stack(
                          children: [
                            // 1. Top-Right Ambient Glow (Cahaya Kanan Agak Atas)
                            Positioned(
                              top: -20,
                              right: -30,
                              child: Container(
                                width: 260,
                                height: 260,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: isDark
                                        ? [
                                            const Color(0xFF808CFF)
                                                .withValues(alpha: 0.22),
                                            const Color(0xFF5B69FF)
                                                .withValues(alpha: 0.08),
                                            Colors.transparent,
                                          ]
                                        : [
                                            const Color(0xFFFFC58D)
                                                .withValues(alpha: 0.35),
                                            const Color(0xFFFFE3C7)
                                                .withValues(alpha: 0.12),
                                            Colors.transparent,
                                          ],
                                    stops: const [0.0, 0.55, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            // 2. Bottom-Left Ambient Glow (Cahaya Kiri Agak Kebawah)
                            Positioned(
                              top: 180,
                              left: -40,
                              child: Container(
                                width: 280,
                                height: 280,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: isDark
                                        ? [
                                            const Color(0xFF635BFF)
                                                .withValues(alpha: 0.18),
                                            const Color(0xFF382D80)
                                                .withValues(alpha: 0.06),
                                            Colors.transparent,
                                          ]
                                        : [
                                            const Color(0xFFB5C0FF)
                                                .withValues(alpha: 0.32),
                                            const Color(0xFFDCE2FF)
                                                .withValues(alpha: 0.10),
                                            Colors.transparent,
                                          ],
                                    stops: const [0.0, 0.55, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            // Content Positioned Higher Up
                            Align(
                              alignment: Alignment.topCenter,
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.only(
                                  top: 54,
                                  left: 24,
                                  right: 24,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      isDark
                                          ? 'assets/images/jagacuan-logo-dark.png'
                                          : 'assets/images/jagacuan-logo-light.png',
                                      height: 50,
                                      color: isDark
                                          ? null
                                          : const Color(0xFF2C2418),
                                      errorBuilder: (_, _, _) => Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            LucideIcons.piggyBank,
                                            size: 36,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF2C2418),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Jagacuan',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF2C2418),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    Text(
                                      AppTranslations.tr(
                                        vm.language,
                                        vm.activeTabIndex == 0
                                            ? 'page.no_active'
                                            : 'page.no_completed',
                                      ),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF2C2418),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      AppTranslations.tr(
                                        vm.language,
                                        vm.activeTabIndex == 0
                                            ? 'page.no_active_hint'
                                            : 'page.no_completed_hint',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.4,
                                        color: isDark
                                            ? const Color(0xFF9A9FAE)
                                            : const Color(0xFF7A6F60),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount:
                              vm.filteredTargets.length +
                              (vm.activeTabIndex == 1 ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (vm.activeTabIndex == 1) {
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF163324)
                                          : const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF26593F)
                                            : const Color(0xFFA5D6A7),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Text(
                                      '${vm.filteredTargets.length} ${AppTranslations.tr(vm.language, "page.finished_count")}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? const Color(0xFF34D399)
                                            : const Color(0xFF15803D),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final target = vm.filteredTargets[index - 1];
                              return _buildTargetCard(
                                context,
                                target,
                                isDark,
                                cardBg,
                                cardBorder,
                              );
                            }
                            final target = vm.filteredTargets[index];
                            return _buildTargetCard(
                              context,
                              target,
                              isDark,
                              cardBg,
                              cardBorder,
                            );
                          },
                        ),
                ),
              ),

                // Bottom Navigation Bar
                Container(
                  height: 78,
                  decoration: BoxDecoration(
                    color: bg,
                    border: Border(
                      top: BorderSide(color: context.appBorder, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Tab 1: Berjalan
                      InkWell(
                        onTap: () => vm.setTabIndex(0),
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: vm.activeTabIndex == 0
                              ? const EdgeInsets.symmetric(
                                  horizontal: 36,
                                  vertical: 10,
                                )
                              : const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 8,
                                ),
                          decoration: vm.activeTabIndex == 0
                              ? BoxDecoration(
                                  color: context.appSurface,
                                  borderRadius: BorderRadius.circular(999),
                                )
                              : null,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.dollarSign,
                                size: 22,
                                color: vm.activeTabIndex == 0
                                    ? context.appTextPrimary
                                    : context.appTextMuted,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppTranslations.tr(
                                  vm.language,
                                  'page.tab_active',
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: vm.activeTabIndex == 0
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: vm.activeTabIndex == 0
                                      ? context.appTextPrimary
                                      : context.appTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Tab 2: Selesai
                      InkWell(
                        onTap: () => vm.setTabIndex(1),
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: vm.activeTabIndex == 1
                              ? const EdgeInsets.symmetric(
                                  horizontal: 36,
                                  vertical: 10,
                                )
                              : const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 8,
                                ),
                          decoration: vm.activeTabIndex == 1
                              ? BoxDecoration(
                                  color: context.appSurface,
                                  borderRadius: BorderRadius.circular(999),
                                )
                              : null,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.check,
                                size: 22,
                                color: vm.activeTabIndex == 1
                                    ? context.appTextPrimary
                                    : context.appTextMuted,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppTranslations.tr(
                                  vm.language,
                                  'page.tab_finished',
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: vm.activeTabIndex == 1
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: vm.activeTabIndex == 1
                                      ? context.appTextPrimary
                                      : context.appTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Floating Action Button (+)
            Positioned(
              right: 20,
              bottom: 96,
              child: SizedBox(
                width: 64,
                height: 64,
                child: FloatingActionButton(
                  onPressed: () => _showSelectTypeSheet(context),
                  backgroundColor: const Color(0xFF808CFF),
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: const CircleBorder(),
                  child: const Icon(LucideIcons.plus, size: 32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectTypeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SelectTargetTypeModal(
        onSelectType: (type) {
          Navigator.pop(context);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => CreateTargetModal(initialType: type),
          );
        },
      ),
    );
  }

  Widget _buildTopActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: context.appBorder, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip(
    BuildContext context,
    TargetListViewModel vm,
    SortOption option,
    String label,
    Color activeColor,
  ) {
    final isSelected = vm.activeSort == option;

    final selectedBg = const Color(0xFF808CFF);
    final unselectedBg = context.appSurface;
    final selectedTextColor = Colors.white;
    final unselectedTextColor = context.appTextMuted;

    return InkWell(
      onTap: () => vm.setSortOption(option),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? selectedTextColor : unselectedTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(
    String url, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
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
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => Center(
          child: Icon(
            LucideIcons.image,
            size: (width != null ? width / 2 : 24),
            color: Colors.grey,
          ),
        ),
      );
    } else {
      final file = File(resolvedUrl);
      if (file.existsSync()) {
        return Image.file(file, width: width, height: height, fit: fit);
      }
      return Center(
        child: Icon(
          LucideIcons.image,
          size: (width != null ? width / 2 : 24),
          color: Colors.grey,
        ),
      );
    }
  }

  Widget _buildTargetCard(
    BuildContext context,
    TargetItem target,
    bool isDark,
    Color cardBg,
    Color cardBorder,
  ) {
    final lang = context.watch<TargetListViewModel>().language;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      child: InkWell(
        onTap: () async {
          final vm = context.read<TargetListViewModel>();
          if (target.type == TargetType.nabar) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    NabarRoomView(roomId: target.roomId ?? target.id),
              ),
            );
            if (mounted) {
              await _syncNabarTargets();
            }
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TargetDetailView(targetId: target.id),
              ),
            );
            if (mounted) {
              await vm.loadTargets();
            }
          }
        },
        onLongPress: () async {
          final vm = context.read<TargetListViewModel>();
          final isNabar = target.type == TargetType.nabar;
          final titleKey = isNabar
              ? 'nabar.delete_room_confirm_title'
              : 'detail.delete_confirm_title';
          final descKey = isNabar
              ? 'nabar.delete_room_confirm_desc'
              : 'detail.delete_confirm_desc';

          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(AppTranslations.tr(vm.language, titleKey)),
              content: Text(AppTranslations.tr(vm.language, descKey)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(AppTranslations.tr(vm.language, 'common.cancel')),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                  child: Text(
                    AppTranslations.tr(vm.language, 'common.delete'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );

          if (confirm == true && context.mounted) {
            final supabaseRepo = context.read<SupabaseNabarRepository>();
            await vm.deleteTarget(target.id, supabaseRepo: supabaseRepo);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: context.appSurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child:
                        (target.coverUrl != null && target.coverUrl!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _buildCoverImage(
                              target.coverUrl!,
                              width: 56,
                              height: 56,
                            ),
                          )
                        : Center(
                            child: Icon(
                              target.type == TargetType.nabar
                                  ? LucideIcons.users
                                  : LucideIcons.target,
                              color: const Color(0xFF7C8BFF),
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
                            Flexible(
                              child: Text(
                                target.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (target.isArchived) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFF59E0B),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.trophy,
                                      size: 10,
                                      color: Color(0xFFF59E0B),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      AppTranslations.tr(
                                        lang,
                                        'card.archived',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (target.isCompleted) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF16A34A),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  AppTranslations.tr(
                                    lang,
                                    'detail.completed_badge',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatRupiah(target.currentAmount)} / ${formatRupiah(target.targetAmount)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${target.progressPercentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: target.progressPercentage / 100,
                  minHeight: 8,
                  backgroundColor: isDark ? Colors.white12 : context.appSurface,
                  valueColor: AlwaysStoppedAnimation(
                    target.isCompleted
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF7C8BFF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
