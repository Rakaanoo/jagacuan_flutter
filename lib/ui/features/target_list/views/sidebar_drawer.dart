import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../view_models/target_list_view_model.dart';
import '../../../../data/repositories/supabase_nabar_repository.dart';
import '../../nabar_room/views/connect_google_modal.dart';
import '../../../core/i18n.dart';
import '../../../core/theme.dart';

class SidebarDrawer extends StatelessWidget {
  const SidebarDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TargetListViewModel>();
    final isDark = vm.isDarkMode;
    final supabaseRepo = context.watch<SupabaseNabarRepository>();
    final currentUser = supabaseRepo.currentUser;

    final bg = context.appBg;
    final cardBg = context.appCard;
    final activeCardBg = context.appSurface;
    final textColor = context.appTextPrimary;
    final mutedTextColor = context.appTextMuted;
    final iconColor = isDark ? const Color(0xFFA4B1FF) : context.appTextPrimary;

    final googleAvatarUrl =
        currentUser?.userMetadata?['avatar_url'] ??
        currentUser?.userMetadata?['picture'];
    final userName = currentUser != null
        ? (currentUser.userMetadata?['full_name'] ??
              currentUser.userMetadata?['name'] ??
              currentUser.email ??
              'Eka putra')
        : 'Eka putra';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'E';

    return Drawer(
      backgroundColor: bg,
      width: 320,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header (Menu + Close Button X)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(LucideIcons.x, color: textColor, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: context.appBorder, height: 1),
              const SizedBox(height: 20),

              // User Profile Card (Google Belum Terhubung / Connected)
              currentUser == null
                  ? InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => const ConnectGoogleModal(),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.appBorder,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: context.appSurface,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.user,
                                size: 20,
                                color: mutedTextColor,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppTranslations.tr(
                                      vm.language,
                                      'sidebar.google_not_connected',
                                    ),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    AppTranslations.tr(
                                      vm.language,
                                      'sidebar.google_not_connected_desc',
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: mutedTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF0284C7),
                            backgroundImage:
                                googleAvatarUrl != null &&
                                    googleAvatarUrl.isNotEmpty
                                ? NetworkImage(googleAvatarUrl)
                                : null,
                            child:
                                (googleAvatarUrl == null ||
                                    googleAvatarUrl.isEmpty)
                                ? Text(
                                    userInitial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        userName,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      LucideIcons.checkCircle2,
                                      color: Color(0xFF10B981),
                                      size: 15,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppTranslations.tr(
                                    vm.language,
                                    'sidebar.google_connected_desc',
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: mutedTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
              const SizedBox(height: 24),

              // Sidebar Menu Items
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildDrawerItem(
                      context,
                      icon: LucideIcons.archive,
                      title: AppTranslations.tr(vm.language, 'sidebar.archive'),
                      iconColor: iconColor,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(context);
                        vm.setTabIndex(1);
                      },
                    ),
                    const SizedBox(height: 6),

                    _buildDrawerItem(
                      context,
                      icon: LucideIcons.globe,
                      title: AppTranslations.tr(
                        vm.language,
                        'sidebar.language',
                      ),
                      iconColor: iconColor,
                      textColor: textColor,
                      onTap: () {
                        _showLanguageDialog(context);
                      },
                    ),
                    const SizedBox(height: 6),

                    // Active Highlighted Theme Item
                    _buildDrawerItem(
                      context,
                      icon: isDark ? LucideIcons.moon : LucideIcons.sun,
                      title:
                          '${AppTranslations.tr(vm.language, 'sidebar.theme')}: ${isDark ? "Dark Mode" : "Light Mode"}',
                      iconColor: iconColor,
                      textColor: textColor,
                      isActive: true,
                      activeBg: activeCardBg,
                      onTap: () => vm.toggleTheme(),
                    ),
                    const SizedBox(height: 6),

                    _buildDrawerItem(
                      context,
                      icon: LucideIcons.arrowUpDown,
                      title: AppTranslations.tr(vm.language, 'sidebar.backup'),
                      iconColor: iconColor,
                      textColor: textColor,
                      onTap: () {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              AppTranslations.tr(
                                vm.language,
                                'sidebar.backup_saved_locally',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),

                    _buildDrawerItem(
                      context,
                      icon: LucideIcons.info,
                      title: AppTranslations.tr(vm.language, 'sidebar.info'),
                      iconColor: iconColor,
                      textColor: textColor,
                      onTap: () {
                        final parentCtx = context;
                        Navigator.pop(parentCtx);
                        showAboutDialog(
                          context: parentCtx,
                          applicationName: 'Jagacuan',
                          applicationVersion: '1.0.0',
                          applicationLegalese: '© 2026 Jagacuan Team',
                        );
                      },
                    ),
                    const SizedBox(height: 6),

                    _buildDrawerItem(
                      context,
                      icon: LucideIcons.star,
                      title: AppTranslations.tr(vm.language, 'sidebar.rating'),
                      iconColor: iconColor,
                      textColor: textColor,
                      onTap: () {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Terima kasih atas penilaian Anda! ⭐⭐⭐⭐⭐',
                            ),
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
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final vm = context.read<TargetListViewModel>();
    final currentLang = vm.language;
    final bg = context.appCard;
    final cardBg = context.appSurface;
    final textColor = context.appTextPrimary;
    final mutedTextColor = context.appTextMuted;

    final languages = [
      {'code': 'id', 'name': 'Bahasa Indonesia', 'flag': '🇮🇩'},
      {'code': 'en', 'name': 'English (US)', 'flag': '🇺🇸'},
      {'code': 'de', 'name': 'Deutsch (Jerman)', 'flag': '🇩🇪'},
      {'code': 'fr', 'name': 'Français (Prancis)', 'flag': '🇫🇷'},
      {'code': 'it', 'name': 'Italiano (Italia)', 'flag': '🇮🇹'},
      {'code': 'es', 'name': 'Español (Spanyol)', 'flag': '🇪🇸'},
      {'code': 'ja', 'name': '日本語 (Jepang)', 'flag': '🇯🇵'},
      {'code': 'zh', 'name': '中文 (China)', 'flag': '🇨🇳'},
      {'code': 'th', 'name': 'ไทย (Thailand)', 'flag': '🇹🇭'},
      {'code': 'hi', 'name': 'हिन्दी (India)', 'flag': '🇮🇳'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.65,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppTranslations.tr(currentLang, 'sidebar.language')} / Language',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: textColor,
                  ),
                ),
                IconButton(
                  icon: Icon(LucideIcons.x, size: 20, color: mutedTextColor),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: languages.length,
                separatorBuilder: (c, i) => const SizedBox(height: 6),
                itemBuilder: (c, i) {
                  final lang = languages[i];
                  final isSelected = lang['code'] == currentLang;
                  return ListTile(
                    tileColor: isSelected ? cardBg : Colors.transparent,
                    leading: Text(
                      lang['flag']!,
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: Text(
                      lang['name']!,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected ? const Color(0xFF7C8BFF) : textColor,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            LucideIcons.check,
                            color: Color(0xFF7C8BFF),
                            size: 20,
                          )
                        : null,
                    onTap: () {
                      final messenger = ScaffoldMessenger.of(context);
                      final langName = lang['name']!;
                      vm.setLanguage(lang['code']!);
                      Navigator.pop(ctx);
                      if (context.mounted) Navigator.pop(context);
                      messenger.showSnackBar(
                        SnackBar(content: Text('Bahasa diubah ke $langName')),
                      );
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color iconColor,
    required Color textColor,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeBg,
  }) {
    return Container(
      decoration: isActive
          ? BoxDecoration(
              color: activeBg,
              borderRadius: BorderRadius.circular(14),
            )
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        dense: true,
        leading: Icon(icon, color: iconColor, size: 20),
        title: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            fontSize: 15,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
