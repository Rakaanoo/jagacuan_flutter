import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../data/repositories/supabase_nabar_repository.dart';
import '../../target_list/view_models/target_list_view_model.dart';
import '../../../core/i18n.dart';

class ConnectGoogleModal extends StatelessWidget {
  const ConnectGoogleModal({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TargetListViewModel>();
    final isDark = vm.isDarkMode;
    final repo = context.read<SupabaseNabarRepository>();

    final bg = isDark ? const Color(0xFF181920) : const Color(0xFFFAF6EF);
    final cardBg = isDark ? const Color(0xFF222432) : const Color(0xFFEFEADF);
    final iconBoxBg = isDark ? const Color(0xFF2B2D3D) : const Color(0xFFE0D9CC);
    final cardBorder = isDark ? const Color(0xFF2E3142) : const Color(0xFFE0D5C3);
    final textColor = isDark ? Colors.white : const Color(0xFF2C2418);
    final mutedTextColor = isDark ? const Color(0xFF9A9FAE) : const Color(0xFF7A6F60);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cardBorder, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 30,
                offset: Offset(0, 10),
              )
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header Row (Icon + Title + Close X)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.users,
                        color: textColor,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        AppTranslations.tr(vm.language, 'connect_google.header'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(LucideIcons.x, color: mutedTextColor, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Divider(color: isDark ? const Color(0xFF2A2D3C) : const Color(0xFFE0D5C3), height: 1),
              const SizedBox(height: 20),

              // Main Inner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? const Color(0xFF2E3142) : const Color(0xFFE0D5C3), width: 1),
                ),
                child: Column(
                  children: [
                    // Top Icon Container
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: iconBoxBg,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.logIn,
                          color: Color(0xFF808CFF),
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title Text
                    Text(
                      AppTranslations.tr(vm.language, 'connect_google.title'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Subtitle Text
                    Text(
                      AppTranslations.tr(vm.language, 'connect_google.desc'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: mutedTextColor,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Green Security Badge Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF16251E) : const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF234D3A) : const Color(0xFFA5D6A7),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            LucideIcons.shieldCheck,
                            color: Color(0xFF22C55E),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              AppTranslations.tr(vm.language, 'connect_google.safe_notice'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF9ECBAF) : const Color(0xFF1B5E20),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // White Google Sign-In Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1F212D),
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/google-logo.png',
                              height: 20,
                              errorBuilder: (_, __, ___) => const Text(
                                'G',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF4285F4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              AppTranslations.tr(vm.language, 'connect_google.button'),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F212D),
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
        ),
      ),
    );
  }
}
