import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../view_models/target_list_view_model.dart';
import '../../../../data/models/target_item.dart';
import '../../../core/formatters.dart';
import 'select_target_type_modal.dart';
import 'create_target_modal.dart';
import 'sidebar_drawer.dart';
import '../../target_detail/views/target_detail_view.dart';
import '../../nabar_room/views/nabar_room_view.dart';
import '../../nabar_room/views/connect_google_modal.dart';
import '../../calendar/views/calendar_modal.dart';
import '../../statistics/views/statistics_modal.dart';
import '../../../../data/repositories/supabase_nabar_repository.dart';
import '../../../core/i18n.dart';

class TargetListView extends StatelessWidget {
  const TargetListView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TargetListViewModel>();
    final isDark = vm.isDarkMode;

    final bg = isDark ? const Color(0xFF131418) : const Color(0xFFFAF7F2);
    final cardBg = isDark ? const Color(0xFF1F212A) : const Color(0xFFFAF6EF);
    final cardBorder = isDark ? const Color(0xFF333644) : const Color(0xFFE0D5C3);

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
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Builder(
                            builder: (ctx) => IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(LucideIcons.menu, color: isDark ? Colors.white : const Color(0xFF2C2418), size: 24),
                              onPressed: () => Scaffold.of(ctx).openDrawer(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Jagacuan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: isDark ? Colors.white : const Color(0xFF2C2418),
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
                            label: AppTranslations.tr(vm.language, 'page.calendar'),
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
                            label: AppTranslations.tr(vm.language, 'page.statistics'),
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
                            label: AppTranslations.tr(vm.language, 'page.rooms'),
                            iconColor: const Color(0xFF818CF8),
                            isDark: isDark,
                            onTap: () {
                              final supabaseRepo = context.read<SupabaseNabarRepository>();
                              if (supabaseRepo.currentUser == null) {
                                showDialog(
                                  context: context,
                                  builder: (_) => const ConnectGoogleModal(),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const NabarRoomView(roomId: 'demo_room')),
                                );
                              }
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                          hintText: AppTranslations.tr(vm.language, 'page.search_placeholder'),
                          hintStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFA0A5B5) : const Color(0xFF7A6F60)),
                          prefixIcon: Icon(LucideIcons.search, size: 16, color: isDark ? const Color(0xFFA0A5B5) : const Color(0xFF7A6F60)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        _buildSortChip(context, vm, SortOption.newest, AppTranslations.tr(vm.language, 'page.sort_newest'), const Color(0xFF7C8BFF)),
                        const SizedBox(width: 8),
                        _buildSortChip(context, vm, SortOption.highestProgress, AppTranslations.tr(vm.language, 'page.sort_progress'), const Color(0xFF16A34A)),
                        const SizedBox(width: 8),
                        _buildSortChip(context, vm, SortOption.closestDeadline, AppTranslations.tr(vm.language, 'page.sort_deadline'), const Color(0xFFDC2626)),
                      ],
                    ),
                  ),
                ],

                // Content Area / Empty State
                Expanded(
                  child: vm.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : vm.filteredTargets.isEmpty
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
                                                const Color(0xFF808CFF).withValues(alpha: 0.22),
                                                const Color(0xFF5B69FF).withValues(alpha: 0.08),
                                                Colors.transparent,
                                              ]
                                            : [
                                                const Color(0xFFFFC58D).withValues(alpha: 0.35),
                                                const Color(0xFFFFE3C7).withValues(alpha: 0.12),
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
                                                const Color(0xFF635BFF).withValues(alpha: 0.18),
                                                const Color(0xFF382D80).withValues(alpha: 0.06),
                                                Colors.transparent,
                                              ]
                                            : [
                                                const Color(0xFFB5C0FF).withValues(alpha: 0.32),
                                                const Color(0xFFDCE2FF).withValues(alpha: 0.10),
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
                                    padding: const EdgeInsets.only(top: 54, left: 24, right: 24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Image.asset(
                                          isDark
                                              ? 'assets/images/jagacuan-logo-dark.png'
                                              : 'assets/images/jagacuan-logo-light.png',
                                          height: 50,
                                          color: isDark ? null : const Color(0xFF2C2418),
                                          errorBuilder: (_, __, ___) => Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                LucideIcons.piggyBank,
                                                size: 36,
                                                color: isDark ? Colors.white : const Color(0xFF2C2418),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Jagacuan',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                  color: isDark ? Colors.white : const Color(0xFF2C2418),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 28),
                                        Text(
                                          vm.activeTabIndex == 0
                                              ? 'Belum ada target aktif'
                                              : 'Belum ada target selesai',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: isDark ? Colors.white : const Color(0xFF2C2418),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          AppTranslations.tr(vm.language, 'page.no_active_hint'),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 1.4,
                                            color: isDark ? const Color(0xFF9A9FAE) : const Color(0xFF7A6F60),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: vm.filteredTargets.length + (vm.activeTabIndex == 1 ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (vm.activeTabIndex == 1) {
                                  if (index == 0) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF163324) : const Color(0xFFE8F5E9),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF26593F) : const Color(0xFFA5D6A7),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Text(
                                          '${vm.filteredTargets.length} ${AppTranslations.tr(vm.language, "page.finished_count")}',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF15803D),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final target = vm.filteredTargets[index - 1];
                                  return _buildTargetCard(context, target, isDark, cardBg, cardBorder);
                                }
                                final target = vm.filteredTargets[index];
                                return _buildTargetCard(context, target, isDark, cardBg, cardBorder);
                              },
                            ),
                ),

                // Bottom Navigation Bar
                Container(
                  height: 78,
                  decoration: BoxDecoration(
                    color: bg,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF23252F) : const Color(0xFFE0D5C3),
                        width: 1,
                      ),
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
                              ? const EdgeInsets.symmetric(horizontal: 36, vertical: 10)
                              : const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          decoration: vm.activeTabIndex == 0
                              ? BoxDecoration(
                                  color: isDark ? const Color(0xFF282A37) : const Color(0xFFEFEADF),
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
                                    ? (isDark ? Colors.white : const Color(0xFF2C2418))
                                    : const Color(0xFF8A8F9E),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppTranslations.tr(vm.language, 'page.tab_active'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: vm.activeTabIndex == 0 ? FontWeight.bold : FontWeight.w500,
                                  color: vm.activeTabIndex == 0
                                      ? (isDark ? Colors.white : const Color(0xFF2C2418))
                                      : const Color(0xFF8A8F9E),
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
                              ? const EdgeInsets.symmetric(horizontal: 36, vertical: 10)
                              : const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          decoration: vm.activeTabIndex == 1
                              ? BoxDecoration(
                                  color: isDark ? const Color(0xFF282A37) : const Color(0xFFEFEADF),
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
                                    ? (isDark ? Colors.white : const Color(0xFF2C2418))
                                    : const Color(0xFF8A8F9E),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppTranslations.tr(vm.language, 'page.tab_finished'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: vm.activeTabIndex == 1 ? FontWeight.bold : FontWeight.w500,
                                  color: vm.activeTabIndex == 1
                                      ? (isDark ? Colors.white : const Color(0xFF2C2418))
                                      : const Color(0xFF8A8F9E),
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
          color: isDark ? const Color(0xFF1F212B) : const Color(0xFFFAF6EF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isDark ? const Color(0xFF2E3140) : const Color(0xFFE0D5C3),
            width: 1.2,
          ),
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
                color: isDark ? Colors.white : const Color(0xFF2C2418),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip(BuildContext context, TargetListViewModel vm, SortOption option, String label, Color activeColor) {
    final isSelected = vm.activeSort == option;
    final isDark = vm.isDarkMode;

    final selectedBg = const Color(0xFF808CFF);
    final unselectedBg = isDark ? const Color(0xFF222430) : const Color(0xFFE8E2D5);
    final selectedTextColor = Colors.white;
    final unselectedTextColor = isDark ? const Color(0xFFA0A5B5) : const Color(0xFF7A6F60);

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

  Widget _buildCoverImage(String url, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(url, width: width, height: height, fit: fit);
    } else {
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(file, width: width, height: height, fit: fit);
      }
      return Image.network(url, width: width, height: height, fit: fit);
    }
  }

  Widget _buildTargetCard(BuildContext context, TargetItem target, bool isDark, Color cardBg, Color cardBorder) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      child: InkWell(
        onTap: () {
          if (target.type == TargetType.nabar && target.roomId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NabarRoomView(roomId: target.roomId!)),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TargetDetailView(targetId: target.id)),
            );
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
                      color: isDark ? const Color(0xFF131418) : const Color(0xFFEFEADF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: (target.coverUrl != null && target.coverUrl!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _buildCoverImage(target.coverUrl!, width: 56, height: 56),
                          )
                        : Center(
                            child: Icon(
                              target.type == TargetType.nabar
                                  ? LucideIcons.users
                                  : (target.type == TargetType.berkala ? LucideIcons.trophy : LucideIcons.target),
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
                        Text(target.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          '${formatRupiah(target.currentAmount, context.watch<TargetListViewModel>().currency)} / ${formatRupiah(target.targetAmount, context.watch<TargetListViewModel>().currency)}',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${target.progressPercentage.toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF16A34A)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: target.progressPercentage / 100,
                  minHeight: 8,
                  backgroundColor: isDark ? Colors.white12 : const Color(0xFFEFEADF),
                  valueColor: AlwaysStoppedAnimation(
                    target.isCompleted ? const Color(0xFF16A34A) : const Color(0xFF7C8BFF),
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
