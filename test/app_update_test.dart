import 'package:flutter_test/flutter_test.dart';
import 'package:jagacuan_app/core/services/update_service.dart';

void main() {
  group('App Update System Tests', () {
    test('AppUpdateInfo parses Day 1 response correctly (2 buttons mode)', () {
      final json = {
        'latest_version': '1.0.12',
        'build_number': 13,
        'release_date': '2026-11-02T20:45:00Z',
        'title': 'Pembaruan Jaga Cuan Tersedia! 🎉',
        'description': 'Versi terbaru membawa fitur baru.',
        'changelog': [
          'Diagram Keaktifan Anggota',
          'Sistem In-App Auto Update',
        ],
        'apk_url': 'https://jagacuan-app.vercel.app/download/jagacuan.apk',
        'apk_size_mb': 59.0,
      };

      final info = AppUpdateInfo.fromJson(json, isForceUpdate: false, hasUpdate: true);

      expect(info.latestVersion, '1.0.12');
      expect(info.buildNumber, 13);
      expect(info.isForceUpdate, false);
      expect(info.hasUpdate, true);
      expect(info.changelog.length, 2);
      expect(info.apkSizeMb, 59.0);
    });

    test('AppUpdateInfo parses Day 2+ response correctly (force update mode)', () {
      final json = {
        'latest_version': '1.0.12',
        'build_number': 13,
        'title': 'Pembaruan Wajib',
        'description': 'Pembaruan penting diperlukan.',
        'changelog': ['Perbaikan keamanan'],
        'apk_url': 'https://jagacuan-app.vercel.app/download/jagacuan.apk',
        'apk_size_mb': 59.0,
      };

      final info = AppUpdateInfo.fromJson(json, isForceUpdate: true, hasUpdate: true);

      expect(info.isForceUpdate, true);
      expect(info.changelog.length, 1);
    });

    test('Local build number vs remote build number update flag', () {
      expect(14 > UpdateService.currentBuildNumber, true);
      expect(13 > UpdateService.currentBuildNumber, false);
    });
  });
}
