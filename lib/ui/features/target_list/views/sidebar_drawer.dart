import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../view_models/target_list_view_model.dart';
import '../../../../data/repositories/supabase_nabar_repository.dart';
import '../../../core/i18n.dart';

class SidebarDrawer extends StatelessWidget {
  const SidebarDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TargetListViewModel>();
    final isDark = vm.isDarkMode;
    final supabaseRepo = context.read<SupabaseNabarRepository>();
    final currentUser = supabaseRepo.currentUser;

    final bg = isDark ? const Color(0xFF16171E) : const Color(0xFFFAF7F2);
    final cardBg = isDark ? const Color(0xFF222432) : const Color(0xFFFAF6EF);
    final activeCardBg = isDark ? const Color(0xFF2B2D3C) : const Color(0xFFEFEADF);
    final textColor = isDark ? Colors.white : const Color(0xFF2C2418);
    final mutedTextColor = isDark ? const Color(0xFF8A8F9E) : const Color(0xFF7A6F60);
    final iconColor = isDark ? const Color(0xFFA4B1FF) : const Color(0xFF2C2418);

    final userName = currentUser != null
        ? (currentUser.userMetadata?['full_name'] ?? currentUser.email ?? 'Eka putra')
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
              Divider(
                color: isDark ? const Color(0xFF272A38) : const Color(0xFFE0D5C3),
                height: 1,
              ),
              const SizedBox(height: 20),

              // User Profile Card (Google Belum Terhubung / Connected)
              currentUser == null
                  ? InkWell(
                      onTap: () async {
                        try {
                          await supabaseRepo.signInWithGoogle();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Google Sign-In: $e')),
                            );
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E3142) : const Color(0xFFE0D5C3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2F40) : const Color(0xFFE5DDD0),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.user,
                                size: 20,
                                color: isDark ? const Color(0xFFA0A5B5) : const Color(0xFF7A6F60),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppTranslations.tr(vm.language, 'sidebar.google_not_connected'),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    AppTranslations.tr(vm.language, 'sidebar.google_not_connected_desc'),
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
                            child: Text(
                              userInitial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
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
                                  AppTranslations.tr(vm.language, 'sidebar.google_connected_desc'),
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
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Menu Arsip Target')),
                        );
                      },
                    ),
                    const SizedBox(height: 6),

                    _buildDrawerItem(
                      context,
                      icon: LucideIcons.globe,
                      title: AppTranslations.tr(vm.language, 'sidebar.language'),
                      iconColor: iconColor,
                      textColor: textColor,
                      onTap: () {
                        _showLanguageDialog(context);
                      },
                    ),
                    const SizedBox(height: 6),

                    _buildDrawerItem(
                      context,
                      icon: LucideIcons.refreshCw,
                      title: AppTranslations.tr(vm.language, 'sidebar.currency'),
                      iconColor: iconColor,
                      textColor: textColor,
                      onTap: () {
                        _showCurrencyDialog(context);
                      },
                    ),
                    const SizedBox(height: 6),

                    // Active Highlighted Theme Item
                    _buildDrawerItem(
                      context,
                      icon: isDark ? LucideIcons.moon : LucideIcons.sun,
                      title: '${AppTranslations.tr(vm.language, 'sidebar.theme')}: ${isDark ? "Dark Mode" : "Light Mode"}',
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
                          const SnackBar(content: Text('Data Celengan Tersimpan Aman di Lokal.')),
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
                          const SnackBar(content: Text('Terima kasih atas penilaian Anda! ⭐⭐⭐⭐⭐')),
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
    final languages = [
      {'code': 'id', 'name': 'Bahasa Indonesia', 'flag': '🇮🇩', 'currency': 'IDR'},
      {'code': 'en', 'name': 'English (US)', 'flag': '🇺🇸', 'currency': 'USD'},
      {'code': 'de', 'name': 'Deutsch (Jerman)', 'flag': '🇩🇪', 'currency': 'EUR'},
      {'code': 'fr', 'name': 'Français (Prancis)', 'flag': '🇫🇷', 'currency': 'EUR'},
      {'code': 'it', 'name': 'Italiano (Italia)', 'flag': '🇮🇹', 'currency': 'EUR'},
      {'code': 'es', 'name': 'Español (Spanyol)', 'flag': '🇪🇸', 'currency': 'EUR'},
      {'code': 'ja', 'name': '日本語 (Jepang)', 'flag': '🇯🇵', 'currency': 'JPY'},
      {'code': 'zh', 'name': '中文 (China)', 'flag': '🇨🇳', 'currency': 'CNY'},
      {'code': 'th', 'name': 'ไทย (Thailand)', 'flag': '🇹🇭', 'currency': 'THB'},
      {'code': 'hi', 'name': 'हिन्दी (India)', 'flag': '🇮🇳', 'currency': 'INR'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.6,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Bahasa / Language', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: languages.length,
                separatorBuilder: (c, i) => const SizedBox(height: 6),
                itemBuilder: (c, i) {
                  final lang = languages[i];
                  return ListTile(
                    leading: Text(lang['flag']!, style: const TextStyle(fontSize: 20)),
                    title: Text(lang['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Mata Uang: ${lang['currency']}', style: const TextStyle(fontSize: 12)),
                    onTap: () {
                      final vm = context.read<TargetListViewModel>();
                      final messenger = ScaffoldMessenger.of(context);
                      final langName = lang['name']!;
                      final currName = lang['currency']!;
                      vm.setLanguage(lang['code']!);
                      vm.setCurrency(lang['currency']!);
                      Navigator.pop(ctx);
                      if (context.mounted) Navigator.pop(context);
                      messenger.showSnackBar(
                        SnackBar(content: Text('Bahasa: $langName • Mata Uang: $currName')),
                      );
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyDialog(BuildContext context) {
    final currencies = [
      {'code': 'IDR', 'name': 'Rupiah (Rp)', 'flag': '🇮🇩'},
      {'code': 'USD', 'name': 'US Dollar (\$)', 'flag': '🇺🇸'},
      {'code': 'EUR', 'name': 'Euro (€)', 'flag': '🇪🇺'},
      {'code': 'JPY', 'name': 'Yen (¥)', 'flag': '🇯🇵'},
      {'code': 'CNY', 'name': 'Yuan (¥)', 'flag': '🇨🇳'},
      {'code': 'THB', 'name': 'Baht (฿)', 'flag': '🇹🇭'},
      {'code': 'INR', 'name': 'Rupee (₹)', 'flag': '🇮🇳'},
      {'code': 'GBP', 'name': 'Pound (£)', 'flag': '🇬🇧'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.6,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Mata Uang / Currency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: currencies.length,
                separatorBuilder: (c, i) => const SizedBox(height: 6),
                itemBuilder: (c, i) {
                  final cur = currencies[i];
                  return ListTile(
                    leading: Text(cur['flag']!, style: const TextStyle(fontSize: 20)),
                    title: Text('${cur['code']} - ${cur['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      final vm = context.read<TargetListViewModel>();
                      final messenger = ScaffoldMessenger.of(context);
                      final curCode = cur['code']!;
                      final curName = cur['name']!;
                      vm.setCurrency(curCode);
                      Navigator.pop(ctx);
                      if (context.mounted) Navigator.pop(context);
                      messenger.showSnackBar(
                        SnackBar(content: Text('Mata Uang diubah ke $curCode ($curName)')),
                      );
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

