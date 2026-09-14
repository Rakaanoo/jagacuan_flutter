import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> showNotificationPermissionDialog(BuildContext context) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const NotificationPermissionDialog(),
  );
}

Future<bool> checkAndShowNotificationPermissionDialog(BuildContext context) async {
  var status = await Permission.notification.status;
  if (status.isDenied) {
    status = await Permission.notification.request();
  }

  if (status.isGranted) {
    return true;
  }

  if (context.mounted) {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const NotificationPermissionDialog(),
    );
  }

  final postStatus = await Permission.notification.status;
  return postStatus.isGranted;
}

class NotificationPermissionDialog extends StatelessWidget {
  const NotificationPermissionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF1E202A) : const Color(0xFFFAF6EF);
    final cardBg = isDark ? const Color(0xFF272936) : const Color(0xFFEFEADF);
    final borderCol = isDark ? const Color(0xFF353848) : const Color(0xFFE0D5C3);
    final textCol = isDark ? Colors.white : const Color(0xFF2C2418);
    final subTextCol = isDark ? const Color(0xFFA0A5B5) : const Color(0xFF7A6F60);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderCol, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 25,
              offset: Offset(0, 10),
            )
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C8BFF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.bellOff,
                      color: Color(0xFF7C8BFF),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Izinkan Notifikasi?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textCol,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pengingat Tabungan Jagacuan',
                          style: TextStyle(fontSize: 12, color: subTextCol),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 20, color: subTextCol),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: borderCol, height: 1),
              const SizedBox(height: 16),

              Text(
                'Notifikasi saat ini belum aktif. Agar pengingat tabungan Anda berjalan tepat waktu, silakan aktifkan izin notifikasi pada perangkat Anda:',
                style: TextStyle(fontSize: 13, height: 1.4, color: textCol),
              ),
              const SizedBox(height: 14),

              // Instructions Box - HP
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.smartphone, size: 18, color: Color(0xFF7C8BFF)),
                        const SizedBox(width: 8),
                        Text(
                          'Panduan Aktivasi di HP (Android / iOS)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textCol,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Buka Pengaturan / Settings HP\n'
                      '2. Pilih menu Aplikasi -> Jagacuan\n'
                      '3. Pilih Notifikasi -> Aktifkan "Izinkan Notifikasi"',
                      style: TextStyle(fontSize: 12, height: 1.5, color: subTextCol),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Instructions Box - Laptop / Web Browser
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.laptop, size: 18, color: Color(0xFF16A34A)),
                        const SizedBox(width: 8),
                        Text(
                          'Panduan Aktivasi di Laptop / Browser',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textCol,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Klik ikon Gembok / Setelan (🔒) di sebelah URL web\n'
                      '2. Cari Notifikasi -> Ubah menjadi "Izinkan" (Allow)\n'
                      '3. Atau di Sistem (Windows/Mac) -> Notifikasi -> Izinkan Browser',
                      style: TextStyle(fontSize: 12, height: 1.5, color: subTextCol),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: borderCol),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Saya Mengerti',
                        style: TextStyle(fontSize: 13, color: textCol, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        openAppSettings();
                      },
                      icon: const Icon(LucideIcons.settings, size: 16),
                      label: const Text('Setting HP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C8BFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
